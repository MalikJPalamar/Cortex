"""Production hardening for the Centaurion FastAPI backend.

Single-operator dashboard — NOT multi-user. This module deliberately does NOT
add authentication or tenancy. It only:

  1. Builds a locked-down CORS allowlist (no wildcard + credentials).
  2. Sets defensive security headers on every response.

The SPA is served same-origin from the same FastAPI app, so the dashboard does
not need a wildcard CORS origin to function.
"""

from __future__ import annotations

import os

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Sensible production default: the Render-hosted dashboard plus local dev origins.
DEFAULT_ALLOWED_ORIGINS = (
    "https://centaurion.onrender.com",
    "http://localhost:5173",  # Vite dev server
    "http://localhost:8000",  # local uvicorn (same-origin dev)
)

# CSP for a same-origin SPA. script-src is locked to 'self' (no inline scripts —
# the Vite build emits external module bundles). style-src allows 'unsafe-inline'
# because React inline style props and runtime-injected styles need it, plus the
# Google Fonts stylesheet. Font files come from fonts.gstatic.com.
CONTENT_SECURITY_POLICY = (
    "default-src 'self'; "
    "script-src 'self'; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
    "font-src 'self' https://fonts.gstatic.com; "
    "img-src 'self' data:; "
    "connect-src 'self'; "
    "base-uri 'self'; "
    "form-action 'self'; "
    "frame-ancestors 'none'; "
    "object-src 'none'"
)

SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Content-Security-Policy": CONTENT_SECURITY_POLICY,
    # Modern guidance: disable the legacy XSS auditor rather than enable it.
    "X-XSS-Protection": "0",
    # HSTS intentionally NOT set here — Render terminates TLS at its edge and
    # manages HTTPS redirects. Setting a hard max-age from the app risks pinning
    # the wrong policy. Documented as a deliberate omission.
}


def get_allowed_origins() -> list[str]:
    """Resolve the CORS allowlist from CENTAURION_ALLOWED_ORIGINS (comma-separated).

    Falls back to DEFAULT_ALLOWED_ORIGINS when the env var is unset or empty.
    """
    raw = os.environ.get("CENTAURION_ALLOWED_ORIGINS", "")
    origins = [o.strip() for o in raw.split(",") if o.strip()]
    return origins or list(DEFAULT_ALLOWED_ORIGINS)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Attach defensive security headers to every response."""

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        for header, value in SECURITY_HEADERS.items():
            response.headers.setdefault(header, value)
        return response
