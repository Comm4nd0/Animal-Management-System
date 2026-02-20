"""Views for serving the Flutter web frontend."""

import os
from django.http import HttpResponse
from django.conf import settings


def frontend(request):
    """Serve the Flutter web app's index.html for all non-API routes.

    WhiteNoise serves the JS/CSS/image assets automatically via STATICFILES_DIRS.
    This view only needs to return index.html so Flutter's router can take over.
    """
    index_path = os.path.join(settings.BASE_DIR, 'frontend', 'index.html')
    try:
        with open(index_path, 'r') as f:
            return HttpResponse(f.read(), content_type='text/html')
    except FileNotFoundError:
        return HttpResponse(
            '<h1>Frontend not built</h1>'
            '<p>Run <code>make build-web</code> to build the Flutter web app, '
            'then copy the output to <code>backend/frontend/</code>.</p>',
            content_type='text/html',
            status=404,
        )
