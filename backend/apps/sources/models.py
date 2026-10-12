from django.conf import settings
from django.db import models


class Source(models.Model):
    class Kind(models.TextChoices):
        TEXT = "text", "Text"
        AUDIO = "audio", "Audio"
        VIDEO = "video", "Video"

    class State(models.TextChoices):
        READY = "ready", "Ready"
        PROCESSING = "processing", "Processing"
        FAILED = "failed", "Failed"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sources")
    title = models.CharField(max_length=180)
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.TEXT)
    text = models.TextField(blank=True)
    uploaded_file = models.FileField(upload_to="sources/%Y/%m/", blank=True)
    state = models.CharField(max_length=12, choices=State.choices, default=State.READY)
    error_message = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return self.title


class Transcript(models.Model):
    source = models.OneToOneField(Source, on_delete=models.CASCADE, related_name="transcript")
    text = models.TextField()
    updated_at = models.DateTimeField(auto_now=True)


class SourceAnalysis(models.Model):
    source = models.OneToOneField(Source, on_delete=models.CASCADE, related_name="analysis")
    topic = models.CharField(max_length=300, blank=True)
    summary = models.TextField(blank=True)
    key_points = models.JSONField(default=list, blank=True)
    important_ideas = models.JSONField(default=list, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
