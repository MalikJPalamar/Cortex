"""Production observability + anti-abuse rate limiting for the Centaurion backend.

Single-operator dashboard — NOT multi-user. This module deliberately does NOT
add authentication, sessions, or tenancy. It only provides:

  1. Structured request logging (one line per request to stdout).
  2. A lightweight in-process, per-IP rate limiter (anti-abuse, NOT auth).

Both are stdlib-only and dependency-free so they stay cheap on Render.
"""

from __future__ import annotations

import logging
import os
import sys
import time
from collections import defaultdict, deque
from threading import Lock

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

# --- Logging setup --------------------------------------------------------

#: Logger name used for structured request lines.
LOGGER_NAME = "centaurion.access"

#: Paths exempt from rate limiting (keep-warm pings must never be throttled).
RATE_LIMIT_EXEMPT_PATHS = frozenset({"/api/health"})

#: Default per-IP request budget per 60s window.
DEFAULT_RATE_LIMIT_PER_MIN = 120

#: Sliding window length in seconds.
_WINDOW_SECONDS = 60.0


def _build_logger() -> logging.Logger:
    """Configure a stdout logger for one-line structured request records.

    Render captures stdout, so a plain StreamHandler is all we need. We avoid
    propagating to the root logger to keep output to exactly one line/request.
    """
    logger = logging.getLogger(LOGGER_NAME)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(logging.Formatter("%(message)s"))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.propagate = False
    return logger


_logger = _build_logger()


def get_rate_limit_per_min() -> int:
    """Resolve the per-IP rate limit from CENTAURION_RATE_LIMIT_PER_MIN.

    Falls back to DEFAULT_RATE_LIMIT_PER_MIN when unset, empty, or invalid.
    """
    raw = os.environ.get("CENTAURION_RATE_LIMIT_PER_MIN", "")
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_RATE_LIMIT_PER_MIN
    return value if value > 0 else DEFAULT_RATE_LIMIT_PER_MIN


def _client_ip(request: Request) -> str:
    """Best-effort client IP. Honors the first hop of X-Forwarded-For (Render
    sits behind a proxy) and falls back to the socket peer."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    client = request.client
    return client.host if client else "unknown"


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log one structured line per request: method, path, status, duration_ms.

    Deliberately does NOT log request/response bodies, headers, query strings,
    or any credentials — only safe routing metadata.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.monotonic()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
            return response
        finally:
            duration_ms = round((time.monotonic() - start) * 1000.0, 2)
            _logger.info(
                "method=%s path=%s status=%s duration_ms=%s",
                request.method,
                request.url.path,
                status,
                duration_ms,
            )


class RateLimitMiddleware(BaseHTTPMiddleware):
    """In-process sliding-window per-IP rate limiter (anti-abuse, NOT auth).

    Keyed by client IP. Exempt paths (e.g. /api/health) are never throttled so
    keep-warm pings keep working. State is per-process and resets on restart;
    that's acceptable for single-operator abuse protection.
    """

    def __init__(self, app, limit_per_min: int | None = None) -> None:
        super().__init__(app)
        self._limit = (
            limit_per_min if limit_per_min is not None else get_rate_limit_per_min()
        )
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = Lock()

    def _allow(self, ip: str, now: float) -> bool:
        cutoff = now - _WINDOW_SECONDS
        with self._lock:
            bucket = self._hits[ip]
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()
            if len(bucket) >= self._limit:
                return False
            bucket.append(now)
            return True

    async def dispatch(self, request: Request, call_next) -> Response:
        if request.url.path in RATE_LIMIT_EXEMPT_PATHS:
            return await call_next(request)

        ip = _client_ip(request)
        if not self._allow(ip, time.monotonic()):
            retry_after = int(_WINDOW_SECONDS)
            return JSONResponse(
                status_code=429,
                content={
                    "error": "rate_limited",
                    "detail": (
                        f"Rate limit exceeded ({self._limit} requests/min). "
                        "Retry later."
                    ),
                },
                headers={"Retry-After": str(retry_after)},
            )
        return await call_next(request)
