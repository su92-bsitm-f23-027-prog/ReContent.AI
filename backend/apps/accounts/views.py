from rest_framework import generics, permissions, status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from .firebase_auth import FirebaseAuthConfigurationError, verify_firebase_id_token
from .models import User
from .serializers import LoginSerializer, RegistrationSerializer, UserSerializer


def issue_token(user):
    # One active session per account keeps logout and token expiry easy to explain.
    Token.objects.filter(user=user).delete()
    token = Token.objects.create(user=user)
    return token.key


class RegisterView(generics.GenericAPIView):
    serializer_class = RegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response({"token": issue_token(user), "user": UserSerializer(user).data}, status=status.HTTP_201_CREATED)


class LoginView(generics.GenericAPIView):
    serializer_class = LoginSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        return Response({"token": issue_token(user), "user": UserSerializer(user).data})


class FirebaseLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        id_token = request.data.get("id_token")
        if not isinstance(id_token, str) or not id_token.strip():
            return Response(
                {"detail": "A Firebase ID token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            decoded = verify_firebase_id_token(id_token.strip())
        except FirebaseAuthConfigurationError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Exception as exc:
            raise AuthenticationFailed("The Google sign-in token is invalid or expired.") from exc

        provider = (decoded.get("firebase") or {}).get("sign_in_provider")
        email = (decoded.get("email") or "").strip().lower()
        if provider != "google.com" or not email or not decoded.get("email_verified"):
            raise AuthenticationFailed("Use a verified Google account to sign in.")

        display_name = (decoded.get("name") or "").strip().split()
        first_name = display_name[0] if display_name else ""
        last_name = " ".join(display_name[1:]) if len(display_name) > 1 else ""
        user, created = User.objects.get_or_create(
            email=email,
            defaults={"first_name": first_name, "last_name": last_name},
        )
        if created:
            user.set_unusable_password()
            user.save(update_fields=["password"])
        if not user.is_active:
            raise AuthenticationFailed("This account is inactive.")

        changed_fields = []
        if not user.first_name and first_name:
            user.first_name = first_name
            changed_fields.append("first_name")
        if not user.last_name and last_name:
            user.last_name = last_name
            changed_fields.append("last_name")
        if changed_fields:
            user.save(update_fields=changed_fields)

        return Response(
            {"token": issue_token(user), "user": UserSerializer(user).data},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class LogoutView(APIView):
    def post(self, request):
        request.auth.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user
