"""Instagram Login and Content Publishing API helpers."""
import base64
import hashlib
import time
from datetime import timedelta

import requests
from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings
from django.core import signing
from django.utils import timezone
from rest_framework.exceptions import APIException

from .models import InstagramConnection


class InstagramUnavailable(APIException):
    status_code = 503
    default_detail = "Instagram publishing is not configured yet."
    default_code = "instagram_unavailable"


class InstagramRequestFailed(APIException):
    status_code = 502
    default_detail = "Instagram could not complete the request."
    default_code = "instagram_request_failed"


def configured():
    return bool(
        settings.INSTAGRAM_APP_ID
        and settings.INSTAGRAM_APP_SECRET
        and settings.INSTAGRAM_REDIRECT_URI
    )


def _cipher():
    digest = hashlib.sha256(settings.SECRET_KEY.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_token(token):
    return _cipher().encrypt(token.encode("utf-8")).decode("ascii")


def decrypt_token(connection):
    try:
        return _cipher().decrypt(connection.access_token_encrypted.encode("ascii")).decode("utf-8")
    except (InvalidToken, ValueError, UnicodeDecodeError) as exc:
        raise InstagramUnavailable(
            "The saved Instagram connection cannot be read. Disconnect and connect it again."
        ) from exc


def exchange_code(code):
    if not configured():
        raise InstagramUnavailable()
    try:
        response = requests.post(
            "https://api.instagram.com/oauth/access_token",
            data={
                "client_id": settings.INSTAGRAM_APP_ID,
                "client_secret": settings.INSTAGRAM_APP_SECRET,
                "grant_type": "authorization_code",
                "redirect_uri": settings.INSTAGRAM_REDIRECT_URI,
                "code": code,
            },
            timeout=20,
        )
        short = response.json()
        if response.status_code >= 400 or "access_token" not in short:
            raise InstagramRequestFailed("Instagram sign-in could not be completed. Check the Meta app settings and callback URL.")
        long_response = requests.get(
            "https://graph.instagram.com/access_token",
            params={
                "grant_type": "ig_exchange",
                "client_secret": settings.INSTAGRAM_APP_SECRET,
                "access_token": short["access_token"],
            },
            timeout=20,
        )
        long_data = long_response.json()
        if long_response.status_code >= 400 or "access_token" not in long_data:
            raise InstagramRequestFailed("Instagram could not issue a long-lived connection. Please connect again.")
        token = long_data["access_token"]
        profile = requests.get(
            f"https://graph.instagram.com/{settings.INSTAGRAM_GRAPH_VERSION}/me",
            params={"fields": "user_id,username", "access_token": token},
            timeout=20,
        )
        profile_data = profile.json()
        if profile.status_code >= 400 or not (profile_data.get("user_id") or profile_data.get("id")):
            raise InstagramRequestFailed("Instagram did not return the professional account details.")
        expires_in = long_data.get("expires_in", 5_184_000)
        return {
            "access_token": token,
            "instagram_user_id": str(profile_data.get("user_id") or profile_data["id"]),
            "username": profile_data.get("username", ""),
            "expires_at": timezone.now() + timedelta(seconds=int(expires_in)),
        }
    except (requests.RequestException, ValueError) as exc:
        raise InstagramRequestFailed("Could not reach Instagram while connecting your account.") from exc


def get_access_token(connection):
    token = decrypt_token(connection)
    if connection.expires_at and connection.expires_at <= timezone.now() + timedelta(days=7):
        try:
            response = requests.get(
                "https://graph.instagram.com/refresh_access_token",
                params={"grant_type": "ig_refresh_token", "access_token": token},
                timeout=20,
            )
            data = response.json()
            if response.status_code < 400 and data.get("access_token"):
                token = data["access_token"]
                connection.access_token_encrypted = encrypt_token(token)
                connection.expires_at = timezone.now() + timedelta(seconds=int(data.get("expires_in", 5_184_000)))
                connection.save(update_fields=("access_token_encrypted", "expires_at", "updated_at"))
        except (requests.RequestException, ValueError):
            pass
    if connection.expires_at and connection.expires_at <= timezone.now():
        raise InstagramUnavailable("The Instagram connection expired. Disconnect and reconnect it.")
    return token


def publish_image(connection, image_url, caption):
    token = get_access_token(connection)
    base = f"https://graph.instagram.com/{settings.INSTAGRAM_GRAPH_VERSION}"
    try:
        created = requests.post(
            f"{base}/{connection.instagram_user_id}/media",
            data={"image_url": image_url, "caption": caption, "access_token": token},
            timeout=45,
        )
        container = created.json()
        if created.status_code >= 400 or not container.get("id"):
            raise InstagramRequestFailed(_instagram_error(container, "Instagram rejected the image or caption."))
        container_id = container["id"]

        for _ in range(15):
            status_response = requests.get(
                f"{base}/{container_id}",
                params={"fields": "status_code,status", "access_token": token},
                timeout=20,
            )
            state = status_response.json()
            if status_response.status_code >= 400:
                raise InstagramRequestFailed(_instagram_error(state, "Instagram could not prepare the image."))
            status_code = state.get("status_code")
            if status_code in (None, "FINISHED", "PUBLISHED"):
                break
            if status_code == "ERROR":
                raise InstagramRequestFailed(state.get("status") or "Instagram could not process this image.")
            time.sleep(2)
        else:
            raise InstagramRequestFailed("Instagram is still processing the image. Please try publishing again shortly.")

        published = requests.post(
            f"{base}/{connection.instagram_user_id}/media_publish",
            data={"creation_id": container_id, "access_token": token},
            timeout=45,
        )
        result = published.json()
        if published.status_code >= 400 or not result.get("id"):
            raise InstagramRequestFailed(_instagram_error(result, "Instagram did not publish the post."))
        return str(result["id"])
    except (requests.RequestException, ValueError) as exc:
        raise InstagramRequestFailed("Could not reach Instagram while publishing. Check your connection and retry.") from exc


def _instagram_error(data, fallback):
    error = data.get("error", {}) if isinstance(data, dict) else {}
    message = error.get("message") if isinstance(error, dict) else None
    return message or fallback


def make_oauth_state(user_id):
    return signing.dumps({"user_id": user_id}, salt="instagram-oauth")


def read_oauth_state(value):
    data = signing.loads(value, salt="instagram-oauth", max_age=600)
    return int(data["user_id"])

