from rest_framework.routers import DefaultRouter
from django.urls import path

from .views import ContentViewSet, GenerateView, HistoryView

router = DefaultRouter()
router.register("content", ContentViewSet, basename="content")
urlpatterns = [path("generate/", GenerateView.as_view(), name="generate"), path("history/", HistoryView.as_view(), name="history")] + router.urls
