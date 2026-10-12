"""Transcription helpers. Video audio extraction uses the optional FFmpeg binary."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from django.conf import settings
from rest_framework.exceptions import APIException


class ProcessingUnavailable(APIException):
    status_code = 503
    default_detail = "Media processing is not configured."
    default_code = "processing_unavailable"


def transcribe(source):
    if not settings.OPENAI_API_KEY:
        raise ProcessingUnavailable("Set OPENAI_API_KEY in backend/.env to transcribe audio or video.")
    if not source.uploaded_file:
        raise ProcessingUnavailable("The source file is missing. Upload it again and retry.")

    path = Path(source.uploaded_file.path)
    temporary = None
    if source.kind == "video":
        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            raise ProcessingUnavailable("FFmpeg is required to extract audio from video files.")
        temporary = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        temporary.close()
        completed = subprocess.run(
            [ffmpeg, "-y", "-i", str(path), "-vn", "-ac", "1", "-ar", "16000", "-b:a", "64k", temporary.name],
            capture_output=True, text=True, timeout=300, check=False,
        )
        if completed.returncode != 0 or os.path.getsize(temporary.name) == 0:
            Path(temporary.name).unlink(missing_ok=True)
            raise ProcessingUnavailable("We couldn't extract audio from this video. Try another file.")
        path = Path(temporary.name)

    try:
        from openai import OpenAI
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        with path.open("rb") as media:
            response = client.audio.transcriptions.create(model=settings.TRANSCRIPTION_MODEL, file=media)
        text = response.text.strip()
        if not text:
            raise ProcessingUnavailable("No speech was found in this file.")
        return text
    except ProcessingUnavailable:
        raise
    except Exception as exc:
        raise ProcessingUnavailable("Transcription failed. Check the file and provider settings, then retry.") from exc
    finally:
        if temporary:
            Path(temporary.name).unlink(missing_ok=True)
