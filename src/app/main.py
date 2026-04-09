"""Minimal FastAPI service — hello + healthz + info.

Deployed to AWS ECS Fargate via Terraform + GitHub Actions. See README.md.
"""

from __future__ import annotations

import logging
import os
import sys

from fastapi import FastAPI
from pythonjsonlogger import json as jsonlogger


def _configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        jsonlogger.JsonFormatter(
            "%(asctime)s %(levelname)s %(name)s %(message)s",
            rename_fields={"asctime": "ts", "levelname": "level", "name": "logger"},
        )
    )
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


_configure_logging()
log = logging.getLogger("app")

app = FastAPI(title="bgs-hello", version=os.environ.get("APP_VERSION", "0.0.0"))


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "hello from bgs-hello"}


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/info")
def info() -> dict[str, str]:
    return {
        "service": os.environ.get("SERVICE_NAME", "bgs-hello"),
        "env": os.environ.get("APP_ENV", "dev"),
        "version": os.environ.get("APP_VERSION", "0.0.0"),
        "sha": os.environ.get("GIT_SHA", "unknown"),
    }
