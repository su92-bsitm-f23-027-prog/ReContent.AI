# FYP demonstration checklist

## Local setup

1. Install Python 3.12+, Flutter stable, and (for video) FFmpeg.
2. Follow the commands in the root README to create the Python environment, install packages, configure `.env`, and run migrations.
3. Start Django on port 8000 and the Flutter client in Chrome. For Android Emulator, set the API URL to `http://10.0.2.2:8000/api`.
4. Keep `AI_MODE=demo` for a no-key walkthrough, or configure a provider key and model if live AI output is required.

## Walkthrough

1. Register a new account; log out and sign back in to show account persistence.
2. Paste a short source paragraph and process it. Review the topic, summary, key points, and transcript.
3. Select multiple platforms and output types, then generate drafts.
4. Open My Content. Edit a draft, copy it, download it as TXT, and regenerate it.
5. Schedule a post for a future time. Show it on the calendar, reschedule it, then cancel it.
6. Open the cancelled item from the library and restore it as a draft.
7. Review Generation History and the dashboard counts.
8. Try an audio/video file when provider keys are configured; for video, confirm FFmpeg is available.

## Verification commands

- Backend: `python -m pytest` from `backend/`.
- Flutter: `flutter test` from `frontend/`.
- Manual API smoke checks can use the Django REST Framework requests in the test suite or an API client, with all routes under `/api/`.
