from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("accounts", "0001_initial"),
        ("sources", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ContentItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("platform", models.CharField(choices=[("instagram", "Instagram"), ("facebook", "Facebook"), ("linkedin", "LinkedIn")], max_length=20)),
                ("content_type", models.CharField(choices=[("caption", "Caption"), ("hook", "Hook"), ("title", "Title"), ("description", "Description"), ("hashtags", "Hashtags"), ("short_post", "Short post")], max_length=20)),
                ("body", models.TextField()),
                ("generation_mode", models.CharField(default="demo", max_length=10)),
                ("status", models.CharField(choices=[("draft", "Draft"), ("scheduled", "Scheduled"), ("cancelled", "Cancelled")], default="draft", max_length=12)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("source", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="content_items", to="sources.source")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="content_items", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("-updated_at",)},
        ),
        migrations.CreateModel(
            name="GenerationEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("event_type", models.CharField(max_length=40)),
                ("snapshot", models.JSONField(blank=True, default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("content", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="history", to="generation.contentitem")),
                ("source", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to="sources.source")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="generation_events", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("-created_at",)},
        ),
    ]
