"""Smoke tests for the FastAPI endpoints."""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_hello() -> None:
    r = client.get("/")
    assert r.status_code == 200
    assert "hello" in r.json()["message"].lower()


def test_healthz_returns_ok() -> None:
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_info_contains_expected_keys() -> None:
    r = client.get("/info")
    assert r.status_code == 200
    body = r.json()
    for key in ("service", "env", "version", "sha"):
        assert key in body
