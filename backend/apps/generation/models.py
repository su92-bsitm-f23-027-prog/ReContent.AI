from django.conf import settings
from django.db import models


class ContentItem(models.Model):
    class Platform(models.TextChoices):
        INSTAGRAM = "instagram", "Instagram"
        FACEBOOK = "facebook", "Facebook"
        LINKEDIN = "linkedin", "LinkedIn"

    class ContentType(models.TextChoices):
        CAPTION = "caption", "Caption"
        HOOK = "hook", "Hook"
        TITLE = "title", "Title"
        DESCRIPTION = "description", "Description"
        HASHTAGS = "hashtags", "Hashtags"
        SHORT_POST = "short_post", "Short post"

    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        SCHEDULED = "scheduled", "Scheduled"
        CANCELLED = "cancelled", "Cancelled"
        PUBLISHED = "published", "Published"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="content_items")
    source = models.ForeignKey("sources.Source", on_delete=models.SET_NULL, null=True, blank=True, related_name="content_items")
    platform = models.CharField(max_length=20, choices=Platform.choices)
    content_type = models.CharField(max_length=20, choices=ContentType.choices)
    body = models.TextField()
    image = models.ImageField(upload_to="social-images/%Y/%m/", blank=True)
    instagram_media_id = models.CharField(max_length=80, blank=True)
    published_at = models.DateTimeField(null=True, blank=True)
    generation_mode = models.CharField(max_length=10, default="demo")
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at",)

    def __str__(self):
        return f"{self.get_content_type_display()} for {self.get_platform_display()}"


class GenerationEvent(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="generation_events")
    source = models.ForeignKey("sources.Source", on_delete=models.SET_NULL, null=True, blank=True)
    content = models.ForeignKey(ContentItem, on_delete=models.SET_NULL, null=True, blank=True, related_name="history")
    event_type = models.CharField(max_length=40)
    snapshot = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
