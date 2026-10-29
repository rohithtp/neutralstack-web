#!/usr/bin/env bash
# ==============================================================================
# NeutralStack Web - Phase Verification Script
# Verifies workspace deliverables against docs/plans/implementation-roadmap.md
# ==============================================================================

set -uo pipefail

TARGET_PHASE="${1:-all}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_file() {
  local file="$1"
  local description="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ -f "$file" ]]; then
    echo -e "  [${GREEN}PASS${NC}] $description ($file)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] Missing $description: $file"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

check_dir() {
  local dir="$1"
  local description="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ -d "$dir" ]]; then
    echo -e "  [${GREEN}PASS${NC}] $description ($dir/)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] Missing $description: $dir/"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

check_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ -f "$file" ]] && grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  [${GREEN}PASS${NC}] $description"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] Pattern not found: '$pattern' in $file ($description)"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

verify_phase_1() {
  echo -e "\n${BLUE}=== Verifying Phase 1: Workspace & Tooling Initialization ===${NC}"
  check_file ".gitignore" "Root Gitignore configuration"
  check_pattern ".gitignore" "\*\.p12" "P12 certificates blocked in .gitignore"
  check_pattern ".gitignore" "^\.env" "Environment variables blocked in .gitignore"
  check_file ".dockerignore" "Root Dockerignore configuration"
  check_file "package.json" "Root Workspace package.json"
  check_file ".env.example" "Root Environment Template"
}

verify_phase_2() {
  echo -e "\n${BLUE}=== Verifying Phase 2: Frontend Engineering (React + Vite + Tailwind) ===${NC}"
  check_dir "frontend" "Frontend Directory"
  check_file "frontend/package.json" "Frontend package.json"
  check_file "frontend/vite.config.ts" "Frontend Vite configuration"
  check_file "frontend/tsconfig.json" "Frontend TypeScript configuration"
  check_file "frontend/tailwind.config.js" "Frontend Tailwind configuration"
  check_file "frontend/nginx.conf" "Frontend NGINX production configuration"
  check_dir "frontend/src" "Frontend Source Directory"
}

verify_phase_3() {
  echo -e "\n${BLUE}=== Verifying Phase 3: Backend Microservice (Fastify LTS) ===${NC}"
  check_dir "backend" "Backend Directory"
  check_file "backend/package.json" "Backend package.json"
  check_file "backend/tsconfig.json" "Backend TypeScript configuration"
  check_file "backend/src/app.ts" "Backend App factory"
  check_file "backend/src/server.ts" "Backend Server entry point"
}

verify_phase_4() {
  echo -e "\n${BLUE}=== Verifying Phase 4: Containerization & Local Orchestration ===${NC}"
  check_file "frontend/Dockerfile" "Frontend Multi-Stage Dockerfile"
  check_file "backend/Dockerfile" "Backend Multi-Stage Dockerfile"
  check_file "docker-compose.yml" "Docker Compose Orchestration"
}

verify_phase_5() {
  echo -e "\n${BLUE}=== Verifying Phase 5: Security Hardening & Certificate Lifecycle ===${NC}"
  check_file "scripts/extract-p12-certs.sh" "P12 Extraction Script"
  check_file "scripts/monitor-cert-expiry.sh" "Cert Expiration Monitoring Script"
  
  # Audit Git status for tracked secrets
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  local leaked_secrets
  leaked_secrets=$(git ls-files | grep -E "(\.p12|\.pfx|\.pem|\.key|\.crt|\.env$)" || true)
  if [[ -z "$leaked_secrets" ]]; then
    echo -e "  [${GREEN}PASS${NC}] Zero-Commit Secret Audit (No private keys or .env tracked)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] Leaked secrets detected in git index:\n$leaked_secrets"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

verify_phase_6() {
  echo -e "\n${BLUE}=== Verifying Phase 6: Declarative K3s Deployment & Quality Gates ===${NC}"
  check_dir "k8s" "Kubernetes Manifests Directory"
  check_file "k8s/00-namespace.yaml" "K8s Namespace Manifest"
  check_file "k8s/01-configmap-secrets.yaml" "K8s ConfigMap & Secrets Manifest"
  check_file "k8s/10-frontend-deployment.yaml" "K8s Frontend Deployment & Service"
  check_file "k8s/20-backend-deployment.yaml" "K8s Backend Deployment & Service"
  check_file "k8s/30-ingress.yaml" "K8s Ingress Path Routing"
}

case "$TARGET_PHASE" in
  1) verify_phase_1 ;;
  2) verify_phase_2 ;;
  3) verify_phase_3 ;;
  4) verify_phase_4 ;;
  5) verify_phase_5 ;;
  6) verify_phase_6 ;;
  all)
    verify_phase_1
    verify_phase_2
    verify_phase_3
    verify_phase_4
    verify_phase_5
    verify_phase_6
    ;;
  *)
    echo -e "${RED}Invalid phase: $TARGET_PHASE. Usage: $0 [1|2|3|4|5|6|all]${NC}"
    exit 1
    ;;
esac

echo -e "\n------------------------------------------------------------"
echo -e "Verification Summary for Phase: ${TARGET_PHASE}"
echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC} / ${TOTAL_CHECKS}"
if [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "Pending / Failed: ${RED}${FAILED_CHECKS}${NC}"
  exit 1
else
  echo -e "${GREEN}All target phase checks passed successfully!${NC}"
  exit 0
fi
