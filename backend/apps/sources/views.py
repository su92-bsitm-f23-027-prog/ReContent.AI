from django.db import transaction
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from apps.generation.models import GenerationEvent
from apps.generation.services import analyze_source_text
from .models import Source, SourceAnalysis, Transcript
from .serializers import SourceSerializer, TranscriptSerializer
from .services import transcribe


class SourceViewSet(viewsets.ModelViewSet):
    serializer_class = SourceSerializer

    def get_queryset(self):
        return Source.objects.filter(user=self.request.user).select_related("transcript", "analysis")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=["post"])
    def process(self, request, pk=None):
        source = self.get_object()
        source.state = Source.State.PROCESSING
        source.error_message = ""
        source.save(update_fields=("state", "error_message", "updated_at"))
        try:
            if source.kind == Source.Kind.TEXT:
                text = source.text.strip()
            else:
                text = transcribe(source)
            if len(text) < 3:
                raise ValidationError({"detail": "Add more source text before analyzing it."})
            with transaction.atomic():
                Transcript.objects.update_or_create(source=source, defaults={"text": text})
                analysis_data = analyze_source_text(text)
                SourceAnalysis.objects.update_or_create(source=source, defaults=analysis_data)
                source.state = Source.State.READY
                source.error_message = ""
                source.save(update_fields=("state", "error_message", "updated_at"))
                GenerationEvent.objects.create(
                    user=request.user, source=source, event_type="source_processed",
                    snapshot={"title": source.title, "kind": source.kind},
                )
        except Exception as exc:
            source.state = Source.State.FAILED
            source.error_message = str(getattr(exc, "detail", exc))[:300]
            source.save(update_fields=("state", "error_message", "updated_at"))
            if hasattr(exc, "status_code"):
                raise
            raise ValidationError({"detail": "Source processing failed. Please retry."}) from exc
        source.refresh_from_db()
        return Response(self.get_serializer(source).data)

    @action(detail=True, methods=["patch"])
    def transcript(self, request, pk=None):
        source = self.get_object()
        transcript, _ = Transcript.objects.get_or_create(source=source, defaults={"text": source.text})
        serializer = TranscriptSerializer(transcript, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
