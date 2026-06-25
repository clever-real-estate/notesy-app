"""Django settings for notesy."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Make this dynamic so a user running on a local machine can override, default to prod for safety
DEBUG = os.getenv("DJANGO_DEBUG", "False").lower() in ("1", "true", "yes")


# If secret key env var is empty then error out
def get_secret_key():
    key = os.getenv("DJANGO_SECRET_KEY")
    if key:
        return key
    
    # Require environment variable key in all environments
    raise RuntimeError("DJANGO_SECRET_KEY must be set")

# Set secret key used for session/state encryption
SECRET_KEY = get_secret_key()

# If old secret key is set return it otherwise empty list
def get_old_secret_key():
    key = os.getenv("DJANGO_OLD_SECRET_KEY")
    if key:
        return [key]
    return []

# Set old secret key, if needed, to allow rotation
SECRET_KEY_FALLBACKS = get_old_secret_key()

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
    #'django.middleware.csp.ContentSecurityPolicyMiddleware',
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


# TODO: Production should use a different backend cache.  Redis would work.  If time allows change this.
SESSION_ENGINE = "django.contrib.sessions.backends.file"
SESSION_FILE_PATH = str(BASE_DIR / ".sessions")
os.makedirs(SESSION_FILE_PATH, exist_ok=True)


AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {
            # Require at least a 12 character password, longer would be better
            "min_length": 12
        }},
    # Filter out common passwords from being used
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    # Filter out passwords that are all numbers
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"}
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



# If there's time work on this, this is a strong security setting for websites
#SECURE_CSP = {
#    'default-src': ["'self'"],
#    'script-src': ["'self'"],  # Add trusted script origins or use nonces
#    'style-src': ["'self'"],
#    'object-src': ["'none'"],
#}

# Prevent site from being loaded in iFrames, Clickjacking protection
X_FRAME_OPTIONS = 'DENY'

# Prevents some mime-type vulnerabilities
SECURE_CONTENT_TYPE_NOSNIFF = True

# Prevent some types of XSS attacks via this header
SECURE_BROWSER_XSS_FILTER = True

# Referrer Policy
SECURE_REFERRER_POLICY = 'same-origin'

# Cross-Origin Isolation (if handling highly sensitive cross-origin context isolation)
SECURE_CROSS_ORIGIN_OPENER_POLICY = 'same-origin'

# Setup HTSTS with 1 year enforcement and include sub domains
# Note: this is not enabled because turning it on without HTTPS will break the site
#SECURE_HSTS_SECONDS = 31536000
#SECURE_HSTS_INCLUDE_SUBDOMAINS = True
#SECURE_HSTS_PRELOAD = True

# Force redirect to HTTPS from HTTP
# Note: this is not enabled because HTTPS is not yet setup
SECURE_SSL_REDIRECT = False

# Protect Django session cookie from being sent to other sites
SESSION_COOKIE_SAMESITE = 'Strict'

# Protects Django session cookie from being viewed by javascript
SESSION_COOKIE_HTTPONLY = True

# Control session cookie age.  Without knowing the app requirements setting to 7d
SESSION_COOKIE_AGE = 10080

# Protect Django session cookie by only sending over HTTPS not HTTP
# Note: currently false because no HTTPS server enabled yet
SESSION_COOKIE_SECURE = False

# Protect Django CSRF cookie from being sent to other sites
CSRF_COOKIE_SAMESITE = 'Strict'

# Protects Django CSRF cookie from being viewed by javascript
CSRF_COOKIE_HTTPONLY = True  

# Protect Django CSRF cookie by only sending over HTTPS not HTTP
# Note: currently false because no HTTPS server enabled yet
CSRF_COOKIE_SECURE = False
