.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Cross-platform: detect Windows vs Unix so the same Makefile works in
# Git Bash / WSL / Linux / macOS.
# ---------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
    PY       ?= python
    VENV     ?= .venv
    BIN      := $(VENV)/Scripts
    EXE      := .exe
    RM_RF    := cmd /c rmdir /s /q
    FIND_RM  := for /d /r . %%d in (__pycache__) do @if exist "%%d" rmdir /s /q "%%d"
else
    SHELL    := /bin/bash
    PY       ?= python3
    VENV     ?= .venv
    BIN      := $(VENV)/bin
    EXE      :=
    RM_RF    := rm -rf
    FIND_RM  := find . -type d -name __pycache__ -exec rm -rf {} +
endif

PIP     := $(BIN)/pip$(EXE)
PYTHON  := $(BIN)/python$(EXE)
RUFF    := $(BIN)/ruff$(EXE)
MYPY    := $(BIN)/mypy$(EXE)
PYTEST  := $(BIN)/pytest$(EXE)
AUDIT   := $(BIN)/pip-audit$(EXE)

IMAGE   ?= bgs-hello
TAG     ?= dev

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: venv
venv: ## Create the virtualenv only
	$(PY) -m venv $(VENV)

.PHONY: install
install: venv ## Create venv and install deps
	$(PIP) install --upgrade pip wheel
	$(PIP) install -e ".[dev]"

.PHONY: fmt
fmt: ## Format code
	$(RUFF) format src tests
	$(RUFF) check --fix src tests

.PHONY: lint
lint: ## Lint + format check
	$(RUFF) check src tests
	$(RUFF) format --check src tests

.PHONY: type
type: ## Type check
	$(MYPY) src

.PHONY: test
test: ## Run tests with coverage
	$(PYTEST)

.PHONY: audit
audit: ## Dependency vulnerability scan (runtime deps only)
	$(AUDIT) -r src/app/requirements.txt --strict --ignore-vuln CVE-2025-62727

.PHONY: check
check: lint type test audit ## All pre-merge checks

.PHONY: build-image
build-image: ## Build the container image
	docker build -t $(IMAGE):$(TAG) .

.PHONY: run-local
run-local: ## Run the container locally on :8080
	docker run --rm -p 8080:8080 -e APP_ENV=local -e APP_VERSION=$(TAG) $(IMAGE):$(TAG)

.PHONY: tf-fmt
tf-fmt: ## Format all terraform
	terraform -chdir=terraform/app fmt -recursive

.PHONY: tf-validate
tf-validate: ## Validate app terraform (no backend)
	terraform -chdir=terraform/app init -backend=false
	terraform -chdir=terraform/app validate

.PHONY: clean
clean: ## Remove build + cache artifacts
	-$(RM_RF) build 2>nul || true
	-$(RM_RF) dist 2>nul || true
	-$(RM_RF) .pytest_cache 2>nul || true
	-$(RM_RF) .mypy_cache 2>nul || true
	-$(RM_RF) .ruff_cache 2>nul || true
	-$(RM_RF) htmlcov 2>nul || true
	-$(FIND_RM) 2>nul || true

.PHONY: nuke
nuke: clean ## Also remove venv
	-$(RM_RF) $(VENV) 2>nul || true
