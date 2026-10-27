# Firebase Google sign-in setup

The Flutter web app uses Firebase Authentication for the Google popup. It sends the resulting Firebase ID token to Django, and Django verifies that token with Firebase Admin before issuing the ReContent API session token. The Firebase Admin service-account credential is server-only and must never be added to Flutter or Git.

## 1. Create or choose a Firebase project

Use a Firebase project intended for ReContent AI. The account previously showed a project named `SkillBridge`; leave that project unchanged unless it is specifically meant for ReContent AI.

In Firebase Console:

1. Open **Authentication → Sign-in method** and enable **Google**.
2. Add `localhost` to **Authentication → Settings → Authorized domains** for local development. After hosting the frontend, add its `*.web.app` domain there as well.
3. In **Project settings → General → Your apps**, add a **Web app** and copy its Firebase configuration values.
4. Copy `frontend/firebase.client.example.json` to `frontend/firebase.client.json` and replace its values with the web app's `apiKey`, `appId`, `messagingSenderId`, `projectId`, and `authDomain`. The local file is ignored by Git.

Firebase's client configuration identifies the Firebase web app. It is not the Admin service-account key. Do not paste a private key into this frontend file.

## 2. Configure Django's Firebase Admin credentials

The backend requires a Firebase Admin service account to verify ID tokens.

For local development, create a service-account key in **Project settings → Service accounts**, save it outside the repository, and set these values in the ignored `backend/.env` file:

```dotenv
FIREBASE_PROJECT_ID=your-firebase-project-id
GOOGLE_APPLICATION_CREDENTIALS=C:\path\outside\the\repo\service-account.json
```

Alternatively, set `FIREBASE_SERVICE_ACCOUNT_JSON` to the service-account JSON content. Never commit that JSON file or its contents.

For Render, set `FIREBASE_PROJECT_ID` and the secret `FIREBASE_SERVICE_ACCOUNT_JSON` in the service's environment settings. The blueprint includes placeholders for these values; keep the service-account JSON private.

## 3. Install and run locally

From PowerShell, start Django in one terminal:

```powershell
cd C:\Users\HP\Documents\ReContent.AI\backend
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

In a second terminal, start Flutter Web:

```powershell
cd C:\Users\HP\Documents\ReContent.AI\frontend
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase.client.json --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

The backend overview is at `http://127.0.0.1:8000/`; the JSON health check is at `http://127.0.0.1:8000/health/`. The Google sign-in button appears on the Flutter login and registration screen. If Firebase client settings are missing, the rest of the app still opens and the button explains that setup is required.

## 4. Build the hosted frontend

Build Flutter with the local Firebase client config and the deployed API URL:

```powershell
flutter build web --release --dart-define-from-file=firebase.client.json --dart-define=API_BASE_URL=https://YOUR-RENDER-SERVICE.onrender.com/api
```

Deploy `frontend/build/web` to Firebase Hosting using the existing `frontend/firebase.json`. Add the resulting Firebase Hosting domain to Firebase Authentication's authorized domains and Django's `FRONTEND_ORIGINS` and `CSRF_TRUSTED_ORIGINS` values.
