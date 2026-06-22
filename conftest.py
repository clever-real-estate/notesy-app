"""Pytest defaults when no .env is present (e.g. CI)."""
import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-secret-key-not-for-production")
os.environ.setdefault("DJANGO_DEBUG", "True")
os.environ.setdefault("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,testserver")
# Keep tests on SQLite even when a developer .env points at Postgres.
os.environ["DATABASE_URL"] = ""
