"""Django settings for notesy."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Make this dynamic so a user running on a local machine can override, default to prod for safety
DEBUG = os.getenv("DJANGO_DEBUG", "False").lower() in ("1", "true", "yes")


def get_secret_key():
    key = os.getenv("DJANGO_SECRET_KEY")
    if key:
        return key
    
    # Require environment variable key in all environments
    raise RuntimeError("DJANGO_SECRET_KEY must be set")

SECRET_KEY = get_secret_key()


# Since we don't know the actual URL just use localhost for now
# If this was deployed for real we'd know the desired URL
ALLOWED_HOSTS = ["127.0.0.1","::1","localhost"]


INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "apps.notes.apps.NotesConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "notesy.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "notesy.wsgi.application"


DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}


SESSION_ENGINE = "django.contrib.sessions.backends.file"
SESSION_FILE_PATH = str(BASE_DIR / ".sessions")
os.makedirs(SESSION_FILE_PATH, exist_ok=True)


AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True


STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"


LOGIN_URL = "/login/"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/login/"
