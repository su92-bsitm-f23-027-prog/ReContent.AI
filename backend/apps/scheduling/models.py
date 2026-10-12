from django.conf import settings
from django.db import models


class ScheduledPost(models.Model):
    class State(models.TextChoices):
        SCHEDULED = "scheduled", "Scheduled"
        CANCELLED = "cancelled", "Cancelled"

    content = models.OneToOneField("generation.ContentItem", on_delete=models.CASCADE, related_name="schedule")
    scheduled_for = models.DateTimeField()
    state = models.CharField(max_length=12, choices=State.choices, default=State.SCHEDULED)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="scheduled_posts")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("scheduled_for",)


class ScheduleChange(models.Model):
    schedule = models.ForeignKey(ScheduledPost, on_delete=models.CASCADE, related_name="changes")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    action = models.CharField(max_length=20)
    previous_time = models.DateTimeField(null=True, blank=True)
    new_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
