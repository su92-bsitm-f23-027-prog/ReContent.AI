from django.utils import timezone
from rest_framework import serializers

from apps.generation.models import ContentItem
from .models import ScheduledPost


class ScheduledPostSerializer(serializers.ModelSerializer):
    content_title = serializers.CharField(source="content.source.title", read_only=True, default="")
    body_preview = serializers.SerializerMethodField()
    platform = serializers.CharField(source="content.platform", read_only=True)
    content_type = serializers.CharField(source="content.content_type", read_only=True)

    class Meta:
        model = ScheduledPost
        fields = ("id", "content", "content_title", "body_preview", "platform", "content_type", "scheduled_for", "state", "created_at", "updated_at")
        read_only_fields = ("id", "content_title", "body_preview", "platform", "content_type", "state", "created_at", "updated_at")

    def get_body_preview(self, obj):
        return obj.content.body[:150]

    def validate_content(self, value):
        user = self.context["request"].user
        if value.user_id != user.id:
            raise serializers.ValidationError("Content not found.")
        if value.status == ContentItem.Status.CANCELLED:
            raise serializers.ValidationError("Restore this content as a draft before scheduling it again.")
        return value

    def validate_scheduled_for(self, value):
        if value <= timezone.now():
            raise serializers.ValidationError("Choose a date and time in the future.")
        return value
