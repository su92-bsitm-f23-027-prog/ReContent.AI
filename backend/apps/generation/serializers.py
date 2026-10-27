from django.conf import settings
from django.core import signing
from django.urls import reverse
from rest_framework import serializers

from .models import ContentItem, GenerationEvent


class ContentSerializer(serializers.ModelSerializer):
    source_title = serializers.CharField(source="source.title", read_only=True, default="")
    platform_label = serializers.CharField(source="get_platform_display", read_only=True)
    content_type_label = serializers.CharField(source="get_content_type_display", read_only=True)
    schedule_id = serializers.SerializerMethodField()
    scheduled_for = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ContentItem
        fields = ("id", "source", "source_title", "platform", "platform_label", "content_type", "content_type_label", "body", "image_url", "generation_mode", "status", "schedule_id", "scheduled_for", "published_at", "created_at", "updated_at")
        read_only_fields = ("id", "source", "status", "created_at", "updated_at")

    def get_schedule_id(self, obj):
        try:
            return obj.schedule.id
        except Exception:
            return None

    def get_scheduled_for(self, obj):
        try:
            return obj.schedule.scheduled_for
        except Exception:
            return None

    def get_image_url(self, obj):
        if not obj.image:
            return ""
        request = self.context.get("request")
        token = signing.dumps({"content_id": obj.pk}, salt="instagram-publish-image")
        path = reverse("instagram-public-image", kwargs={"token": token})
        origin = settings.PUBLIC_API_ORIGIN.rstrip("/")
        if not origin and request:
            origin = request.build_absolute_uri("/").rstrip("/")
        return f"{origin}{path}" if origin else path



class GenerateSerializer(serializers.Serializer):
    source_id = serializers.IntegerField()
    platforms = serializers.ListField(child=serializers.ChoiceField(choices=ContentItem.Platform.choices), allow_empty=False)
    content_types = serializers.ListField(child=serializers.ChoiceField(choices=ContentItem.ContentType.choices), allow_empty=False)


class HistorySerializer(serializers.ModelSerializer):
    platform = serializers.CharField(source="content.platform", read_only=True, default="")
    content_type = serializers.CharField(source="content.content_type", read_only=True, default="")
    source_title = serializers.CharField(source="source.title", read_only=True, default="")

    class Meta:
        model = GenerationEvent
        fields = ("id", "source_title", "platform", "content_type", "event_type", "snapshot", "created_at")
