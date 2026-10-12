# Public demo deployment

The local Flutter web server and Django development server are for development only. They use `localhost` addresses and cannot be shared with a teacher. This project is prepared for a small public demo using Firebase Hosting for Flutter Web and a Render web service with PostgreSQL for Django.

## Before deploying

- Create a GitHub repository and push this project. Keep `.env`, `.venv`, local databases, media uploads, and API keys out of Git.
- Sign in to Firebase and Render with accounts you control.
- The Render blueprint uses a free web service and free PostgreSQL database for a short demo. Free Render web services sleep after inactivity; free PostgreSQL expires 30 days after creation. Use a persistent paid database if demo data must remain beyond that period.
- The free web service filesystem is ephemeral. For this demo, use text sources or plan external object storage for uploaded media.

## Deploy Django on Render

1. In Render, create a **Blueprint** from the GitHub repository and apply `render.yaml`.
2. Wait for the API deploy to pass its `/health/` check. Copy the service URL, for example `https://recontent-api.onrender.com`.
3. The blueprint creates a secret key and database, sets `AI_MODE=demo`, and runs migrations at service startup.
4. After creating the Firebase site, set Render's `FRONTEND_ORIGINS` environment variable to the exact Firebase origin, such as `https://your-project.web.app`. Include the `firebaseapp.com` origin too only if you plan to use it. Save the variable and redeploy.
5. Leave `DJANGO_DEBUG=false`. Keep `DJANGO_ALLOWED_HOSTS` restricted to the API hostname if you change the default service name/domain.

## Deploy Flutter Web on Firebase Hosting

From `frontend/`, build with the deployed API base URL (no trailing slash after `api`):

```powershell
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://recontent-api.onrender.com/api
```

Install the Firebase CLI if needed, sign in, then initialize Hosting in `frontend/` and select `build/web` as the public directory. The checked-in `firebase.json` already configures that directory and a single-page app rewrite. Link an existing Firebase project when prompted, then deploy:

```powershell
firebase deploy --only hosting
```

Firebase prints a public `https://<project-id>.web.app` address. Open it in a private/incognito browser to test registration, login, and text-based content generation. Share that HTTPS address with the teacher.

## Production configuration notes

- The frontend must be built with the public HTTPS API URL. `API_BASE_URL` is compiled into Flutter; changing it in the browser is not enough.
- Django must have `DEBUG=false`, a generated `DJANGO_SECRET_KEY`, an appropriate `DJANGO_ALLOWED_HOSTS`, and the Firebase origin in `FRONTEND_ORIGINS`.
- Do not add an OpenAI API key to Flutter or Git. Demo mode needs no key. If provider-backed generation is enabled, set the key only in the backend host's secret environment variables.
- Django media uploads currently use the service filesystem. Render free web services do not persist local files across restarts, so hosted file uploads need external object storage for durable use.
