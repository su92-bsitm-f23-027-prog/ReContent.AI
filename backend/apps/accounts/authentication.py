from datetime import timedelta

from django.utils import timezone
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import AuthenticationFailed


class ExpiringTokenAuthentication(TokenAuthentication):
    """DRF tokens expire after 14 days; signing in issues a fresh token."""
    keyword = "Bearer"

    def authenticate_credentials(self, key):
        user, token = super().authenticate_credentials(key)
        if token.created < timezone.now() - timedelta(days=14):
            token.delete()
            raise AuthenticationFailed("Your session expired. Please sign in again.")
        return user, token
