import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.sources.models import Source, Transcript
from .models import ContentItem, GenerationEvent


@pytest.mark.django_db
def test_generation_creates_platform_adapted_items_and_history():
    user = User.objects.create_user(email="author@example.com", password="Strong-pass-192!")
    source = Source.objects.create(user=user, title="Climate notes", text="Cities can become greener with trees and safe walking routes.")
    Transcript.objects.create(source=source, text=source.text)
    client = APIClient()
    client.force_authenticate(user)
    response = client.post("/api/generate/", {
        "source_id": source.id, "platforms": ["instagram", "linkedin"],
        "content_types": ["caption", "short_post"],
    }, format="json")
    assert response.status_code == 201
    assert len(response.data) == 4
    assert ContentItem.objects.filter(user=user).count() == 4
    assert GenerationEvent.objects.filter(user=user, event_type="generated").count() == 4


@pytest.mark.django_db
def test_content_is_scoped_to_owner():
    owner = User.objects.create_user(email="owner@example.com", password="Strong-pass-192!")
    stranger = User.objects.create_user(email="stranger@example.com", password="Strong-pass-192!")
    item = ContentItem.objects.create(user=owner, platform="linkedin", content_type="caption", body="Private post")
    client = APIClient()
    client.force_authenticate(stranger)
    assert client.get(f"/api/content/{item.id}/").status_code == 404
