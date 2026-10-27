from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ContentPublishingViewSet, InstagramViewSet, instagram_callback, instagram_public_image

router = DefaultRouter()
router.register("instagram", InstagramViewSet, basename="instagram")
router.register("content", ContentPublishingViewSet, basename="content-publishing")

urlpatterns = [
    path("instagram/callback/", instagram_callback, name="instagram-callback"),
    path("instagram/media/<str:token>/", instagram_public_image, name="instagram-public-image"),
    path("", include(router.urls)),
]
