from pathlib import Path

from rest_framework import serializers

from .models import Source, SourceAnalysis, Transcript

TEXT_EXTENSIONS = set()
AUDIO_EXTENSIONS = {".mp3", ".wav", ".m4a", ".ogg", ".flac", ".webm", ".mp4"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".webm"}


class TranscriptSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transcript
        fields = ("text", "updated_at")
        read_only_fields = ("updated_at",)


class AnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = SourceAnalysis
        fields = ("topic", "summary", "key_points", "important_ideas", "updated_at")


class SourceSerializer(serializers.ModelSerializer):
    file = serializers.FileField(source="uploaded_file", required=False, write_only=True)
    file_name = serializers.SerializerMethodField()
    transcript = TranscriptSerializer(read_only=True)
    analysis = AnalysisSerializer(read_only=True)
    state = serializers.CharField(read_only=True)
    error_message = serializers.CharField(read_only=True)

    class Meta:
        model = Source
        fields = ("id", "title", "kind", "text", "file", "file_name", "state", "error_message", "transcript", "analysis", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")

    def get_file_name(self, obj):
        return Path(obj.uploaded_file.name).name if obj.uploaded_file else ""

    def validate(self, attrs):
        kind = attrs.get("kind", getattr(self.instance, "kind", Source.Kind.TEXT))
        text = attrs.get("text", getattr(self.instance, "text", ""))
        uploaded = attrs.get("uploaded_file")
        request = self.context.get("request")
        if request and request.method in ("POST", "PUT", "PATCH"):
            if kind == Source.Kind.TEXT and not text.strip():
                raise serializers.ValidationError({"text": "Enter source text before continuing."})
            if kind in (Source.Kind.AUDIO, Source.Kind.VIDEO) and not uploaded and not (self.instance and self.instance.uploaded_file):
                raise serializers.ValidationError({"file": "Choose an audio or video file."})
            if uploaded:
                from django.conf import settings
                suffix = Path(uploaded.name).suffix.lower()
                allowed = AUDIO_EXTENSIONS if kind == Source.Kind.AUDIO else VIDEO_EXTENSIONS
                if suffix not in allowed:
                    raise serializers.ValidationError({"file": f"This file type is not supported for {kind}."})
                if uploaded.size > settings.MAX_UPLOAD_BYTES:
                    raise serializers.ValidationError({"file": f"Choose a file smaller than {settings.MAX_UPLOAD_MB} MB."})
        return attrs

    def create(self, validated_data):
        if validated_data.get("kind") == Source.Kind.TEXT:
            validated_data.setdefault("state", Source.State.READY)
        else:
            validated_data["state"] = Source.State.READY
        return super().create(validated_data)
