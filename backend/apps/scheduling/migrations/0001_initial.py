from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("accounts", "0001_initial"),
        ("generation", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ScheduledPost",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("scheduled_for", models.DateTimeField()),
                ("state", models.CharField(choices=[("scheduled", "Scheduled"), ("cancelled", "Cancelled")], default="scheduled", max_length=12)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("content", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="schedule", to="generation.contentitem")),
                ("created_by", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="scheduled_posts", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("scheduled_for",)},
        ),
        migrations.CreateModel(
            name="ScheduleChange",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("action", models.CharField(max_length=20)),
                ("previous_time", models.DateTimeField(blank=True, null=True)),
                ("new_time", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("schedule", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="changes", to="scheduling.scheduledpost")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("-created_at",)},
        ),
    ]
