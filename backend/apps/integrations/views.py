import html
import mimetypes
from io import BytesIO

from django.conf import settings
from django.core.files.base import ContentFile
from django.core import signing
from django.core.files.storage import default_storage
from django.http import FileResponse, HttpResponse
from django.urls import reverse
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import APIException, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from PIL import Image, UnidentifiedImageError

from apps.generation.models import ContentItem, GenerationEvent
from apps.generation.serializers import ContentSerializer
from .models import InstagramConnection
from .services import (
    InstagramUnavailable,
    configured,
    encrypt_token,
    exchange_code,
    make_oauth_state,
    publish_image,
    read_oauth_state,
)


class InstagramViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["get"])
    def status(self, request):
        connection = InstagramConnection.objects.filter(user=request.user).first()
        return Response({
            "configured": configured(),
            "connected": bool(connection),
            "username": connection.username if connection else "",
            "expires_at": connection.expires_at if connection else None,
        })

    @action(detail=False, methods=["post"])
    def connect(self, request):
        if not configured():
            raise InstagramUnavailable(
                "Add INSTAGRAM_APP_ID, INSTAGRAM_APP_SECRET, and INSTAGRAM_REDIRECT_URI to the backend settings first."
            )
        state = make_oauth_state(request.user.pk)
        from urllib.parse import urlencode

        query = urlencode({
            "client_id": settings.INSTAGRAM_APP_ID,
            "redirect_uri": settings.INSTAGRAM_REDIRECT_URI,
            "response_type": "code",
            "scope": "instagram_business_basic,instagram_business_content_publish",
            "state": state,
        })
        return Response({"authorization_url": f"https://www.instagram.com/oauth/authorize?{query}"})

    @action(detail=False, methods=["delete"])
    def disconnect(self, request):
        InstagramConnection.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ContentPublishingViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=True, methods=["post"], parser_classes=[MultiPartParser, FormParser])
    def image(self, request, pk=None):
        try:
            item = ContentItem.objects.get(pk=pk, user=request.user)
        except ContentItem.DoesNotExist as exc:
            raise ValidationError({"detail": "Content draft not found."}) from exc
        image = request.FILES.get("image")
        if image is None:
            raise ValidationError({"image": "Choose a photo to upload."})
        if image.size > settings.MAX_UPLOAD_BYTES:
            raise ValidationError({"image": f"Choose a photo smaller than {settings.MAX_UPLOAD_MB} MB."})
        if image.content_type not in {"image/jpeg", "image/png", "image/webp"}:
            raise ValidationError({"image": "Choose a JPG, PNG, or WebP image."})
        try:
            with Image.open(image) as source:
                source.load()
                if source.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValidationError({"image": "Choose a JPG, PNG, or WebP photo."})
                if source.mode in ("RGBA", "LA"):
                    rgba = source.convert("RGBA")
                    background = Image.new("RGB", rgba.size, "white")
                    background.paste(rgba, mask=rgba.getchannel("A"))
                    normalized = background
                else:
                    normalized = source.convert("RGB")
                output = BytesIO()
                normalized.save(output, format="JPEG", quality=90, optimize=True)
                output.seek(0)
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise ValidationError({"image": "That file is not a readable image. Choose another photo."}) from exc
        if item.image:
            item.image.delete(save=False)
        item.image.save(f"instagram-{item.pk}.jpg", ContentFile(output.read()), save=False)
        item.save(update_fields=("image", "updated_at"))
        return Response(ContentSerializer(item, context={"request": request}).data)

    @action(detail=True, methods=["post"])
    def publish(self, request, pk=None):
        try:
            item = ContentItem.objects.get(pk=pk, user=request.user)
        except ContentItem.DoesNotExist as exc:
            raise ValidationError({"detail": "Content draft not found."}) from exc
        if item.platform != ContentItem.Platform.INSTAGRAM:
            raise ValidationError({"detail": "Automatic publishing is currently configured for Instagram only."})
        if not item.image:
            raise ValidationError({"image": "Upload a photo before publishing."})
        caption = str(request.data.get("caption", item.body)).strip()
        if not caption:
            raise ValidationError({"caption": "Add a caption before publishing."})
        if len(caption) > 2200:
            raise ValidationError({"caption": "Instagram captions can be up to 2,200 characters."})
        connection = InstagramConnection.objects.filter(user=request.user).first()
        if connection is None:
            raise ValidationError({"detail": "Connect your Instagram professional account first."})
        if not settings.PUBLIC_API_ORIGIN.startswith("https://"):
            raise InstagramUnavailable(
                "Publishing needs the deployed HTTPS API address so Instagram can fetch the image. Set PUBLIC_API_ORIGIN in the backend."
            )
        token = signing.dumps({"content_id": item.pk}, salt="instagram-publish-image")
        image_path = reverse("instagram-public-image", kwargs={"token": token})
        image_url = f"{settings.PUBLIC_API_ORIGIN}{image_path}"
        media_id = publish_image(connection, image_url, caption)
        item.body = caption
        item.status = ContentItem.Status.PUBLISHED
        item.instagram_media_id = media_id
        item.published_at = timezone.now()
        item.save(update_fields=("body", "status", "instagram_media_id", "published_at", "updated_at"))
        GenerationEvent.objects.create(
            user=request.user,
            source=item.source,
            content=item,
            event_type="published",
            snapshot={"platform": "instagram", "media_id": media_id},
        )
        return Response(ContentSerializer(item, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([AllowAny])
def instagram_callback(request):
    error = request.query_params.get("error_description") or request.query_params.get("error")
    if error:
        return HttpResponse(_callback_page("Instagram connection was not completed", html.escape(error)), status=400)
    code = request.query_params.get("code")
    state = request.query_params.get("state")
    if not code or not state:
        return HttpResponse(_callback_page("Instagram connection failed", "The callback did not include a code and state."), status=400)
    try:
        user_id = read_oauth_state(state)
        from django.contrib.auth import get_user_model

        user = get_user_model().objects.get(pk=user_id)
        data = exchange_code(code)
        InstagramConnection.objects.update_or_create(
            user=user,
            defaults={
                "access_token_encrypted": encrypt_token(data["access_token"]),
                "instagram_user_id": data["instagram_user_id"],
                "username": data["username"],
                "expires_at": data["expires_at"],
            },
        )
    except Exception as exc:
        detail = getattr(exc, "detail", "Instagram authorization expired or could not be verified.")
        return HttpResponse(_callback_page("Instagram connection failed", html.escape(str(detail))), status=400)
    return HttpResponse(_callback_page("Instagram connected", "Your professional account is connected. Return to ReContent to publish your photo and caption."))


def instagram_public_image(request, token):
    try:
        payload = signing.loads(token, salt="instagram-publish-image", max_age=3600)
        item = ContentItem.objects.get(pk=payload["content_id"])
    except (signing.BadSignature, ContentItem.DoesNotExist, KeyError, TypeError):
        return HttpResponse(status=404)
    if not item.image or not default_storage.exists(item.image.name):
        return HttpResponse(status=404)
    response = FileResponse(default_storage.open(item.image.name, "rb"), content_type="image/jpeg")
    response["Cache-Control"] = "private, max-age=3600"
    response["X-Robots-Tag"] = "noindex, nofollow"
    return response


def _callback_page(title, message):
    return f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><body style="font:16px system-ui;max-width:560px;margin:12vh auto;padding:24px;color:#20233b"><h1>{title}</h1><p>{message}</p><p>Use your browser's Back button to return to ReContent, then refresh the page.</p></body></html>"""
