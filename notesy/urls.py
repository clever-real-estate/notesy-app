from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # Production sites should not enable admin path globally
    # Since we don't have a load balancer or anything to restrict access at the moment comment out
    # path("admin/", admin.site.urls),
    path("", include("apps.notes.urls")),
]
