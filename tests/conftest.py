"""Shared pytest fixtures."""

from __future__ import annotations

import os
from collections.abc import Iterator

import pytest


@pytest.fixture
def clean_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Strip BGS_* and AWS_* vars so each test starts from a known state."""
    for key in list(os.environ):
        if key.startswith(("BGS_", "AWS_")):
            monkeypatch.delenv(key, raising=False)
    yield


@pytest.fixture
def aws_creds(monkeypatch: pytest.MonkeyPatch) -> None:
    """Fake credentials so moto / boto3 don't try to hit real AWS."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
