from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import CalendarView, DashboardView, ScheduleViewSet

router = DefaultRouter()
router.register("schedules", ScheduleViewSet, basename="schedule")
urlpatterns = [path("calendar/", CalendarView.as_view(), name="calendar"), path("dashboard/", DashboardView.as_view(), name="dashboard")] + router.urls
