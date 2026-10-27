from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("generation", "0001_initial")]

    operations = [
        migrations.AddField(
            model_name="contentitem",
            name="image",
            field=models.ImageField(blank=True, upload_to="social-images/%Y/%m/"),
        ),
        migrations.AddField(
            model_name="contentitem",
            name="instagram_media_id",
            field=models.CharField(blank=True, max_length=80),
        ),
        migrations.AddField(
            model_name="contentitem",
            name="published_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name="contentitem",
            name="status",
            field=models.CharField(
                choices=[
                    ("draft", "Draft"),
                    ("scheduled", "Scheduled"),
                    ("cancelled", "Cancelled"),
                    ("published", "Published"),
                ],
                default="draft",
                max_length=12,
            ),
        ),
    ]
