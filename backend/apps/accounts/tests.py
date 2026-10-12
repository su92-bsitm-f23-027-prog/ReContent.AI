from datetime import timedelta

import pytest
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from .models import User


@pytest.mark.django_db
def test_registration_login_and_logout():
    client = APIClient()
    response = client.post("/api/auth/register/", {
        "email": "creator@example.com", "password": "Strong-pass-192!", "first_name": "Rae",
    }, format="json")
    assert response.status_code == 201
    user = User.objects.get(email="creator@example.com")
    assert user.password != "Strong-pass-192!"
    token = response.data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    assert client.get("/api/auth/me/").data["email"] == user.email
    assert client.post("/api/auth/logout/").status_code == 204
    assert not Token.objects.filter(user=user).exists()


@pytest.mark.django_db
def test_expired_token_is_rejected_and_deleted():
    user = User.objects.create_user(email="old@example.com", password="Strong-pass-192!")
    token = Token.objects.create(user=user)
    Token.objects.filter(pk=token.pk).update(created=timezone.now() - timedelta(days=15))
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.key}")
    assert client.get("/api/auth/me/").status_code == 401
    assert not Token.objects.filter(pk=token.pk).exists()
