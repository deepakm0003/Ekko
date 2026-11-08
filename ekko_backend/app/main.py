"""Ekko API — FastAPI application factory, middleware and health checks."""
import logging
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from .config import settings
from .db import Base, engine
from .routers import auth, orders, people, plans
from .services import services

logging.basicConfig(level=logging.INFO, format='{"t":"%(asctime)s","lvl":"%(levelname)s","msg":"%(message)s"}')
log = logging.getLogger("ekko")

DESCRIPTION = """
**Ekko backend** — the server half of Ekko (Team Code Sync, Airtel Sync 2026).

* **Never trust the client:** orders are re-validated against every catalogue rule and re-priced here.
* **AI is optional:** the advisor understands answers with deterministic rules; an LLM (Groq) is used only as a fallback.
* **Privacy by design (DPDP Act 2023):** masked identifiers, consent log, export and erasure endpoints, audit trail.
"""


def create_app() -> FastAPI:
    app = FastAPI(title="Ekko API", version="1.1.0", description=DESCRIPTION,
                  docs_url="/docs", redoc_url="/redoc", openapi_url="/openapi.json")
    app.state.log = log
    Base.metadata.create_all(engine)
    services()  # load catalogue, registries and model once at startup

    if settings.cors_origins:
        app.add_middleware(CORSMiddleware, allow_origins=list(settings.cors_origins), allow_methods=["*"],
                           allow_headers=["Authorization", "Content-Type"])

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        rid = request.headers.get("X-Request-ID", uuid.uuid4().hex[:16])[:32]
        request.state.request_id = rid
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            log.exception("unhandled error rid=%s path=%s", rid, request.url.path)
            response = JSONResponse({"detail": "internal error", "requestId": rid}, status_code=500)
        ms = (time.perf_counter() - start) * 1000
        response.headers.update({
            "X-Request-ID": rid, "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY",
            "Referrer-Policy": "no-referrer", "Cache-Control": "no-store",
            "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        })
        log.info("%s %s %s %.1fms rid=%s", request.method, request.url.path, response.status_code, ms, rid)
        return response

    @app.get("/health", tags=["ops"], summary="Liveness")
    def health():
        return {"ok": True, "version": app.version}

    @app.get("/ready", tags=["ops"], summary="Readiness: database and reference data loaded")
    def ready():
        with engine.connect() as c:
            c.execute(text("SELECT 1"))
        s = services()
        gst, udyam = s.registry.counts
        return {"ok": True, "database": "up", "products": len(s.catalogue.by_id), "gstinRecords": gst,
                "udyamRecords": udyam, "modelAuc": s.propensity.auc, "ai": settings.ai_provider if settings.ai_provider != "none" else "rules-only"}

    for r in (auth.router, plans.router, orders.router, people.router):
        app.include_router(r)
    return app


app = create_app()
