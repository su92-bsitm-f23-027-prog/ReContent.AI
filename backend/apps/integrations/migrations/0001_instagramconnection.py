import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [("accounts", "0001_initial")]

    operations = [
        migrations.CreateModel(
            name="InstagramConnection",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("access_token_encrypted", models.TextField()),
                ("instagram_user_id", models.CharField(max_length=80)),
                ("username", models.CharField(blank=True, max_length=150)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("connected_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="instagram_connection", to=settings.AUTH_USER_MODEL)),
            ],
            options={"verbose_name": "Instagram connection"},
        ),
    ]
