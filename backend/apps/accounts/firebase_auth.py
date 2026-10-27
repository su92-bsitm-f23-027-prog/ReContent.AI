"""Firebase Admin helpers for validating client-issued Firebase ID tokens."""

import json
import os


class FirebaseAuthConfigurationError(Exception):
    """Raised when the server has not been given Firebase Admin credentials."""


def _firebase_admin_app():
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError as exc:
        raise FirebaseAuthConfigurationError(
            "Firebase sign-in is unavailable because the Firebase Admin package is not installed."
        ) from exc

    app_name = "recontent-ai"
    try:
        return firebase_admin.get_app(app_name)
    except ValueError:
        pass

    project_id = os.getenv("FIREBASE_PROJECT_ID", "").strip()
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if service_account_json:
        try:
            service_account_info = json.loads(service_account_json)
            credential = credentials.Certificate(service_account_info)
            project_id = project_id or service_account_info.get("project_id", "")
        except (ValueError, TypeError) as exc:
            raise FirebaseAuthConfigurationError(
                "FIREBASE_SERVICE_ACCOUNT_JSON is not valid service-account JSON."
            ) from exc
    elif os.getenv("GOOGLE_APPLICATION_CREDENTIALS") and project_id:
        credential = credentials.ApplicationDefault()
    else:
        raise FirebaseAuthConfigurationError(
            "Set FIREBASE_PROJECT_ID and provide Firebase Admin credentials to enable Google sign-in."
        )

    if not project_id:
        raise FirebaseAuthConfigurationError(
            "The Firebase project ID is missing from server configuration."
        )

    return firebase_admin.initialize_app(
        credential,
        options={"projectId": project_id},
        name=app_name,
    )


def verify_firebase_id_token(id_token):
    app = _firebase_admin_app()
    from firebase_admin import auth

    return auth.verify_id_token(id_token, app=app)
