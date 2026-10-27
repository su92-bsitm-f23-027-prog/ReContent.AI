# ReContent AI

ReContent AI is a Final Year Project that turns a video, audio recording, or text source into editable social content for Instagram, Facebook, and LinkedIn. It includes account registration, source analysis, a transcript editor, a content library, generation history, and a calendar for managing planned post times.

The calendar stores planned times as reminders. The Instagram content editor now includes photo upload and an official Meta publishing flow with a **Publish now** confirmation. Instagram publishing still needs a Meta developer app, a connected Creator/Business account, and a deployed HTTPS backend; Facebook and LinkedIn remain manual share flows.

## Project layout

```text
frontend/   Flutter responsive client
backend/    Django REST API
docs/       project notes and API overview
```

## Requirements

- Flutter stable SDK and Dart (the Dart SDK is included with Flutter).
- Python 3.12 or newer recommended for the Django environment.
- PostgreSQL for a deployment database; SQLite is configured by default for local development.
- An OpenAI API key and an available text model name for provider-backed generation and transcription. The default `AI_MODE=demo` works without a key and is clearly labeled; it uses simple local templates rather than an AI model.
- FFmpeg on `PATH` to extract audio from uploaded video. Audio transcription accepts common audio formats directly.
- Android Studio and an Android SDK only if you want to build/run the Android target.

Django 5.2 LTS and Django REST Framework 3.18 are used as the backend baseline. Flutter uses one responsive codebase for browser and mobile layouts. The client switches navigation patterns as the available window changes size.

## Start the Django API (Windows PowerShell)

```powershell
Set-Location .\backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

The API is available at `http://127.0.0.1:8000/api/`. Create an account from the Flutter app. Django admin is available at `/admin/` after creating a superuser with `python manage.py createsuperuser`.

The default SQLite database is created at `backend/db.sqlite3`. To use PostgreSQL, change `DATABASE_URL` in `backend/.env`, for example:

```text
DATABASE_URL=postgresql://recontent:your-password@127.0.0.1:5432/recontent
```

### Provider-backed AI and transcription

For real model responses, set `AI_MODE=openai`, `OPENAI_API_KEY`, and `OPENAI_MODEL` in `backend/.env`. Media transcription uses `OPENAI_API_KEY` and `TRANSCRIPTION_MODEL`. The key stays on the Django server and must never be put in Flutter or committed. Provider use may incur charges and is subject to provider limits. Keep `AI_MODE=demo` for a no-key presentation; generated drafts are marked “Demo mode” in the editor.

Media uploads are limited to 20 MB by default. Video processing requires FFmpeg. Processing is synchronous in this FYP version, so use short clips; a background task queue can be added if larger files become a requirement.

## Start the Flutter client

```powershell
Set-Location .\frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

For an Android emulator, point the app at the host machine through `10.0.2.2`:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For a physical device, replace that address with the computer's LAN address and allow the API port through the local firewall. The backend's development CORS setting accepts local development origins; set `FRONTEND_ORIGINS` explicitly for deployment.

## Tests

Run backend tests from `backend/`:

```powershell
python -m pytest
```

Run Flutter tests from `frontend/`:

```powershell
flutter test
```

## Instagram publishing

Follow [docs/INSTAGRAM_PUBLISHING.md](docs/INSTAGRAM_PUBLISHING.md) to configure the Meta app, backend environment, HTTPS callback, and public image endpoint before using **Publish now**.

## Main API routes

| Area | Routes |
|---|---|
| Authentication | `POST /api/auth/register/`, `POST /api/auth/login/`, `POST /api/auth/logout/`, `GET/PATCH /api/auth/me/` |
| Sources | `GET/POST /api/sources/`, `POST /api/sources/{id}/process/`, `PATCH /api/sources/{id}/transcript/` |
| Generation | `POST /api/generate/`, `GET /api/history/` |
| Library | `GET/POST /api/content/`, `GET/PATCH/DELETE /api/content/{id}/`, `POST /api/content/{id}/regenerate/`, `POST /api/content/{id}/restore_draft/` |
| Scheduling | `GET /api/calendar/`, `GET/POST /api/schedules/`, `PATCH /api/schedules/{id}/`, `POST /api/schedules/{id}/cancel/` |
| Dashboard | `GET /api/dashboard/` |
| Instagram | `GET /api/integrations/instagram/status/`, `POST /api/integrations/instagram/connect/`, `DELETE /api/integrations/instagram/disconnect/` |

All private API routes require `Authorization: Bearer <token>`. Tokens expire after 14 days, and each sign-in rotates the account's active token. Production deployments must use HTTPS, a strong secret key, explicit allowed hosts and CORS origins, and a protected database.
