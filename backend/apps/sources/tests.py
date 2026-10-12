import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from .models import Source, SourceAnalysis, Transcript


@pytest.mark.django_db
def test_text_source_processes_and_saves_analysis():
    user = User.objects.create_user(email="writer@example.com", password="Strong-pass-192!")
    client = APIClient()
    client.force_authenticate(user)
    source = client.post("/api/sources/", {
        "title": "A short talk", "kind": "text",
        "text": "Small habits make creative work easier. Consistency helps ideas grow.",
    }, format="json")
    assert source.status_code == 201
    processed = client.post(f"/api/sources/{source.data['id']}/process/", {}, format="json")
    assert processed.status_code == 200
    item = Source.objects.get(pk=source.data["id"])
    assert item.state == Source.State.READY
    assert Transcript.objects.get(source=item).text.startswith("Small habits")
    assert SourceAnalysis.objects.get(source=item).topic


@pytest.mark.django_db
def test_users_cannot_read_another_users_source():
    owner = User.objects.create_user(email="one@example.com", password="Strong-pass-192!")
    stranger = User.objects.create_user(email="two@example.com", password="Strong-pass-192!")
    source = Source.objects.create(user=owner, title="Private", text="Secret text")
    client = APIClient()
    client.force_authenticate(stranger)
    assert client.get(f"/api/sources/{source.id}/").status_code == 404
