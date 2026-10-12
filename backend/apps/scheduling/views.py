from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework import generics, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from apps.generation.models import ContentItem, GenerationEvent
from apps.generation.serializers import ContentSerializer
from apps.sources.models import Source
from .models import ScheduleChange, ScheduledPost
from .serializers import ScheduledPostSerializer


class ScheduleViewSet(viewsets.ModelViewSet):
    serializer_class = ScheduledPostSerializer

    def get_queryset(self):
        queryset = ScheduledPost.objects.filter(created_by=self.request.user).select_related("content", "content__source")
        if self.action == "list":
            queryset = queryset.filter(state=ScheduledPost.State.SCHEDULED)
        return queryset

    def perform_create(self, serializer):
        content = serializer.validated_data["content"]
        with transaction.atomic():
            existing = ScheduledPost.objects.filter(content=content).first()
            old_time = existing.scheduled_for if existing else None
            schedule, created = ScheduledPost.objects.update_or_create(
                content=content,
                defaults={"scheduled_for": serializer.validated_data["scheduled_for"], "state": ScheduledPost.State.SCHEDULED, "created_by": self.request.user},
            )
            content.status = ContentItem.Status.SCHEDULED
            content.save(update_fields=("status", "updated_at"))
            ScheduleChange.objects.create(schedule=schedule, user=self.request.user, action="scheduled" if created else "rescheduled", previous_time=old_time, new_time=schedule.scheduled_for)
            GenerationEvent.objects.create(user=self.request.user, source=content.source, content=content, event_type="scheduled", snapshot={"scheduled_for": schedule.scheduled_for.isoformat()})

    def perform_update(self, serializer):
        schedule = self.get_object()
        old_time = schedule.scheduled_for
        with transaction.atomic():
            schedule = serializer.save(state=ScheduledPost.State.SCHEDULED)
            content = schedule.content
            content.status = ContentItem.Status.SCHEDULED
            content.save(update_fields=("status", "updated_at"))
            ScheduleChange.objects.create(schedule=schedule, user=self.request.user, action="rescheduled", previous_time=old_time, new_time=schedule.scheduled_for)
            GenerationEvent.objects.create(user=self.request.user, source=content.source, content=content, event_type="rescheduled", snapshot={"from": old_time.isoformat(), "to": schedule.scheduled_for.isoformat()})

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        schedule = self.get_object()
        if schedule.state == ScheduledPost.State.CANCELLED:
            return Response(self.get_serializer(schedule).data)
        with transaction.atomic():
            old_time = schedule.scheduled_for
            schedule.state = ScheduledPost.State.CANCELLED
            schedule.save(update_fields=("state", "updated_at"))
            schedule.content.status = ContentItem.Status.CANCELLED
            schedule.content.save(update_fields=("status", "updated_at"))
            ScheduleChange.objects.create(schedule=schedule, user=request.user, action="cancelled", previous_time=old_time)
            GenerationEvent.objects.create(user=request.user, source=schedule.content.source, content=schedule.content, event_type="cancelled", snapshot={"scheduled_for": old_time.isoformat()})
        return Response(self.get_serializer(schedule).data)

    @action(detail=True, methods=["post"])
    def restore_draft(self, request, pk=None):
        schedule = self.get_object()
        schedule.content.status = ContentItem.Status.DRAFT
        schedule.content.save(update_fields=("status", "updated_at"))
        schedule.state = ScheduledPost.State.CANCELLED
        schedule.save(update_fields=("state", "updated_at"))
        return Response(ContentSerializer(schedule.content).data)


class CalendarView(generics.ListAPIView):
    serializer_class = ScheduledPostSerializer

    def get_queryset(self):
        queryset = ScheduledPost.objects.filter(
            created_by=self.request.user,
            state=ScheduledPost.State.SCHEDULED,
            scheduled_for__gte=timezone.now() - timedelta(days=365),
        ).select_related("content", "content__source")
        start = self.request.query_params.get("start")
        end = self.request.query_params.get("end")
        if start:
            queryset = queryset.filter(scheduled_for__gte=start)
        if end:
            queryset = queryset.filter(scheduled_for__lte=end)
        return queryset


class DashboardView(generics.GenericAPIView):
    def get(self, request):
        content = ContentItem.objects.filter(user=request.user).select_related("source")
        recent = content[:5]
        upcoming = ScheduledPost.objects.filter(
            created_by=request.user, state=ScheduledPost.State.SCHEDULED,
            scheduled_for__gte=timezone.now(),
        ).select_related("content", "content__source")[:5]
        return Response({
            "total_sources": Source.objects.filter(user=request.user).count(),
            "generated_content": content.count(),
            "drafts": content.filter(status=ContentItem.Status.DRAFT).count(),
            "scheduled_posts": ScheduledPost.objects.filter(created_by=request.user, state=ScheduledPost.State.SCHEDULED, scheduled_for__gte=timezone.now()).count(),
            "recent_content": ContentSerializer(recent, many=True).data,
            "upcoming": ScheduledPostSerializer(upcoming, many=True).data,
        })
