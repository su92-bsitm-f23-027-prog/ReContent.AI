from django.conf import settings
from django.db import models


class InstagramConnection(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="instagram_connection",
    )
    access_token_encrypted = models.TextField()
    instagram_user_id = models.CharField(max_length=80)
    username = models.CharField(max_length=150, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    connected_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Instagram connection"

    def __str__(self):
        return f"Instagram connection for user {self.user_id}"
