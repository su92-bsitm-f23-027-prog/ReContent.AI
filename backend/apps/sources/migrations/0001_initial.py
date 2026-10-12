from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [("accounts", "0001_initial")]

    operations = [
        migrations.CreateModel(
            name="Source",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=180)),
                ("kind", models.CharField(choices=[("text", "Text"), ("audio", "Audio"), ("video", "Video")], default="text", max_length=10)),
                ("text", models.TextField(blank=True)),
                ("uploaded_file", models.FileField(blank=True, upload_to="sources/%Y/%m/")),
                ("state", models.CharField(choices=[("ready", "Ready"), ("processing", "Processing"), ("failed", "Failed")], default="ready", max_length=12)),
                ("error_message", models.CharField(blank=True, max_length=300)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="sources", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("-created_at",)},
        ),
        migrations.CreateModel(
            name="Transcript",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("text", models.TextField()),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("source", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="transcript", to="sources.source")),
            ],
        ),
        migrations.CreateModel(
            name="SourceAnalysis",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("topic", models.CharField(blank=True, max_length=300)),
                ("summary", models.TextField(blank=True)),
                ("key_points", models.JSONField(blank=True, default=list)),
                ("important_ideas", models.JSONField(blank=True, default=list)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("source", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="analysis", to="sources.source")),
            ],
        ),
    ]
