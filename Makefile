SHELL := /bin/bash
.DEFAULT_GOAL := help

# ---- Config ----
APP_NAME        ?= demo-app
NAMESPACE       ?= default
PORT            ?= 8080

# Local image settings
IMAGE_LOCAL     ?= $(APP_NAME):local
DOCKERFILE      ?= app/Dockerfile
BUILD_CONTEXT   ?= app

# Kustomize overlay
OVERLAY_LOCAL   ?= k8s/overlays/local

# kind cluster name (only used if you choose kind)
KIND_CLUSTER    ?= dev

# ---- Helpers ----
define print_header
	@echo ""
	@echo "==> $(1)"
endef

help: ## Show commands
	@grep -E '^[a-zA-Z0-9_.-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

check-tools: ## Check required tools
	$(call print_header,Checking tools)
	@command -v kubectl >/dev/null || (echo "kubectl not found" && exit 1)
	@command -v docker  >/dev/null || (echo "docker not found" && exit 1)
	@command -v curl    >/dev/null || (echo "curl not found" && exit 1)

context: ## Show current kubectl context
	$(call print_header,Current kubectl context)
	@kubectl config current-context

nodes: ## Show nodes
	$(call print_header,Nodes)
	@kubectl get nodes -o wide

# ---- Local cluster ----
local-up: check-tools ## Ensure local cluster is ready (kind if missing; otherwise uses current context)
	$(call print_header,Ensuring local cluster)
	@CTX=$$(kubectl config current-context 2>/dev/null || true); \
	if [[ "$$CTX" == kind-* ]]; then \
		echo "Using existing kind context: $$CTX"; \
	elif [[ "$$CTX" == docker-desktop* ]]; then \
		echo "Using Docker Desktop Kubernetes context: $$CTX"; \
	else \
		if command -v kind >/dev/null; then \
			echo "No kind/docker-desktop context detected. Creating kind cluster '$(KIND_CLUSTER)'..."; \
			kind get clusters | grep -qx '$(KIND_CLUSTER)' || kind create cluster --name '$(KIND_CLUSTER)'; \
			kubectl config use-context "kind-$(KIND_CLUSTER)"; \
		else \
			echo "No Kubernetes context found (kind/docker-desktop). Install kind or enable Docker Desktop Kubernetes."; \
			exit 1; \
		fi; \
	fi; \
	kubectl cluster-info

local-down: ## Delete kind cluster (no-op for docker-desktop)
	$(call print_header,Deleting kind cluster if present)
	@if command -v kind >/dev/null; then \
		kind get clusters | grep -qx '$(KIND_CLUSTER)' && kind delete cluster --name '$(KIND_CLUSTER)' || true; \
	else \
		echo "kind not installed; nothing to delete."; \
	fi

# ---- Build & deploy ----
build: check-tools ## Build local image (demo-app:local)
	$(call print_header,Building image $(IMAGE_LOCAL))
	@docker build -t $(IMAGE_LOCAL) -f $(DOCKERFILE) $(BUILD_CONTEXT)

load: ## Load image into kind (only if current context is kind-*)
	$(call print_header,Loading image into kind if needed)
	@CTX=$$(kubectl config current-context); \
	if [[ "$$CTX" == kind-* ]]; then \
		CLUSTER=$${CTX#kind-}; \
		echo "kind cluster: $$CLUSTER"; \
		kind load docker-image $(IMAGE_LOCAL) --name "$$CLUSTER"; \
	else \
		echo "Not a kind context ($$CTX). Skip kind load."; \
	fi

local-deploy: local-up build load ## Deploy local overlay via kustomize
	$(call print_header,Deploying overlay $(OVERLAY_LOCAL))
	@kubectl apply -k $(OVERLAY_LOCAL)
	@kubectl rollout status deploy/$(APP_NAME) -n $(NAMESPACE) --timeout=180s
	@kubectl get pods -n $(NAMESPACE) -o wide | grep -E '^$(APP_NAME)-' || true

local-test: ## Smoke test via scripts/smoke-test.sh (auto debug dump on failure)
	$(call print_header,Smoke test)
	@APP_NAME=$(APP_NAME) NAMESPACE=$(NAMESPACE) PORT=$(PORT) ./scripts/smoke-test.sh || \
	  (APP_NAME=$(APP_NAME) NAMESPACE=$(NAMESPACE) ./scripts/k8s-debug-dump.sh && exit 1)
	@set -e; \
	kubectl -n $(NAMESPACE) port-forward deploy/$(APP_NAME) $(PORT):$(PORT) >/tmp/pf-$(APP_NAME).log 2>&1 & \
	PF_PID=$$!; \
	sleep 2; \
	trap "kill $$PF_PID >/dev/null 2>&1 || true" EXIT; \
	echo "curl http://127.0.0.1:$(PORT)/health"; \
	curl -fsS "http://127.0.0.1:$(PORT)/health"; \
	echo ""; \
	echo "✅ smoke test passed"

local-reset: ## Delete deployment and re-deploy (fast reset)
	$(call print_header,Resetting deployment)
	@kubectl delete deploy/$(APP_NAME) -n $(NAMESPACE) --ignore-not-found
	@kubectl delete svc/$(APP_NAME) -n $(NAMESPACE) --ignore-not-found
	@$(MAKE) local-deploy

logs: ## Tail app logs
	$(call print_header,Tailing logs)
	@kubectl logs -n $(NAMESPACE) -l app=$(APP_NAME) --tail=200 -f

describe: ## Describe pods
	$(call print_header,Describe pods)
	@kubectl describe pod -n $(NAMESPACE) -l app=$(APP_NAME) | tail -n 120