from django.conf import settings
from django.db import transaction
from rest_framework import generics, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from apps.sources.models import Source
from .models import ContentItem, GenerationEvent
from .serializers import ContentSerializer, GenerateSerializer, HistorySerializer
from .services import generate_text, generate_variants


class GenerateView(generics.GenericAPIView):
    serializer_class = GenerateSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            source = Source.objects.get(id=data["source_id"], user=request.user)
        except Source.DoesNotExist as exc:
            raise ValidationError({"source_id": "Source not found."}) from exc
        if source.state != Source.State.READY:
            raise ValidationError({"detail": "Process this source before generating content."})
        transcript = getattr(source, "transcript", None)
        text = transcript.text if transcript else source.text
        created = []
        try:
            with transaction.atomic():
                for platform in dict.fromkeys(data["platforms"]):
                    content_types = list(dict.fromkeys(data["content_types"]))
                    variants = generate_variants(text, platform, content_types)
                    for content_type in content_types:
                        body = variants[content_type]
                        item = ContentItem.objects.create(
                            user=request.user, source=source, platform=platform,
                            content_type=content_type, body=body, generation_mode=settings.AI_MODE,
                        )
                        GenerationEvent.objects.create(
                            user=request.user, source=source, content=item,
                            event_type="generated", snapshot={"body": body, "platform": platform, "content_type": content_type},
                        )
                        created.append(item)
        except Exception:
            raise
        return Response(ContentSerializer(created, many=True).data, status=status.HTTP_201_CREATED)


class ContentViewSet(viewsets.ModelViewSet):
    serializer_class = ContentSerializer

    def get_queryset(self):
        queryset = ContentItem.objects.filter(user=self.request.user).select_related("source")
        status_filter = self.request.query_params.get("status")
        if status_filter in {choice[0] for choice in ContentItem.Status.choices}:
            queryset = queryset.filter(status=status_filter)
        return queryset

    def perform_update(self, serializer):
        before = self.get_object().body
        item = serializer.save()
        if item.body != before:
            GenerationEvent.objects.create(
                user=self.request.user, source=item.source, content=item,
                event_type="edited", snapshot={"body": item.body},
            )

    @action(detail=True, methods=["post"])
    def regenerate(self, request, pk=None):
        item = self.get_object()
        source = item.source
        text = (getattr(source, "transcript", None).text if source and hasattr(source, "transcript") else source.text) if source else item.body
        body = generate_text(text, item.platform, item.content_type)
        item.body = body
        item.generation_mode = settings.AI_MODE
        item.status = ContentItem.Status.DRAFT
        item.save(update_fields=("body", "generation_mode", "status", "updated_at"))
        GenerationEvent.objects.create(
            user=request.user, source=source, content=item, event_type="regenerated",
            snapshot={"body": body},
        )
        return Response(self.get_serializer(item).data)

    @action(detail=True, methods=["post"])
    def restore_draft(self, request, pk=None):
        item = self.get_object()
        item.status = ContentItem.Status.DRAFT
        item.save(update_fields=("status", "updated_at"))
        return Response(self.get_serializer(item).data)


class HistoryView(generics.ListAPIView):
    serializer_class = HistorySerializer

    def get_queryset(self):
        return GenerationEvent.objects.filter(user=self.request.user).select_related("source", "content")[:200]
