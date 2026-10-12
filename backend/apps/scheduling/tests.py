from datetime import timedelta

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.generation.models import ContentItem, GenerationEvent
from .models import ScheduleChange, ScheduledPost


@pytest.mark.django_db
def test_schedule_can_be_rescheduled_and_cancelled_without_deleting_content():
    user = User.objects.create_user(email="planner@example.com", password="Strong-pass-192!")
    item = ContentItem.objects.create(user=user, platform="instagram", content_type="caption", body="Post copy")
    client = APIClient()
    client.force_authenticate(user)
    first_time = (timezone.now() + timedelta(days=2)).isoformat()
    response = client.post("/api/schedules/", {"content": item.id, "scheduled_for": first_time}, format="json")
    assert response.status_code == 201
    schedule_id = response.data["id"]
    second_time = (timezone.now() + timedelta(days=3)).isoformat()
    changed = client.patch(f"/api/schedules/{schedule_id}/", {"scheduled_for": second_time}, format="json")
    assert changed.status_code == 200
    cancelled = client.post(f"/api/schedules/{schedule_id}/cancel/", {}, format="json")
    assert cancelled.status_code == 200
    item.refresh_from_db()
    assert item.status == ContentItem.Status.CANCELLED
    assert ContentItem.objects.filter(pk=item.pk).exists()
    assert ScheduleChange.objects.filter(schedule_id=schedule_id).count() == 3
    assert GenerationEvent.objects.filter(content=item, event_type="cancelled").exists()


@pytest.mark.django_db
def test_schedule_rejects_past_datetime():
    user = User.objects.create_user(email="future@example.com", password="Strong-pass-192!")
    item = ContentItem.objects.create(user=user, platform="facebook", content_type="caption", body="Post")
    client = APIClient()
    client.force_authenticate(user)
    response = client.post("/api/schedules/", {
        "content": item.id, "scheduled_for": (timezone.now() - timedelta(minutes=1)).isoformat(),
    }, format="json")
    assert response.status_code == 400
    assert not ScheduledPost.objects.exists()
