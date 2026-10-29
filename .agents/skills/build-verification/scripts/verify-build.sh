#!/usr/bin/env bash
# ==============================================================================
# NeutralStack Web - Full Build & Verification Runner
# Orchestrates frontend and backend builds, hash audits, and container validations
# ==============================================================================

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  NeutralStack Web: Automated Build & Verification Pipeline   ${NC}"
echo -e "${BLUE}============================================================${NC}"

# Step 1: Frontend Build & Compilation
echo -e "\n${BLUE}--> Step 1: Checking Frontend Build...${NC}"
if [[ -f "frontend/package.json" ]]; then
  echo "Building frontend workspace..."
  if command -v npm >/dev/null 2>&1; then
    (cd frontend && npm run build) || { echo -e "${RED}[FAIL] Frontend build failed.${NC}"; exit 1; }
  else
    echo -e "${YELLOW}[SKIP] npm not installed in host environment. Checking existing dist...${NC}"
  fi
else
  echo -e "${YELLOW}[SKIP] frontend/package.json not yet created. Skipping compilation step.${NC}"
fi

# Step 2: Hash & Asset Fingerprint Audit
echo -e "\n${BLUE}--> Step 2: Auditing Asset Fingerprints and Hashes...${NC}"
if [[ -d "frontend/dist" ]]; then
  bash "${ROOT_DIR}/.agents/skills/build-verification/scripts/verify-build-hashes.sh" "frontend/dist" || exit 1
else
  echo -e "${YELLOW}[INFO] frontend/dist does not exist yet. Run this step after frontend scaffolding.${NC}"
fi

# Step 3: Backend TypeScript Compilation Check
echo -e "\n${BLUE}--> Step 3: Checking Backend Microservice Compilation...${NC}"
if [[ -f "backend/package.json" ]]; then
  echo "Compiling backend TypeScript..."
  if command -v npm >/dev/null 2>&1; then
    (cd backend && npm run build) || { echo -e "${RED}[FAIL] Backend build failed.${NC}"; exit 1; }
  else
    echo -e "${YELLOW}[SKIP] npm not installed in host environment.${NC}"
  fi
else
  echo -e "${YELLOW}[SKIP] backend/package.json not yet created. Skipping compilation step.${NC}"
fi

# Step 4: Docker Configuration & Syntax Linting
echo -e "\n${BLUE}--> Step 4: Verifying Container Configurations...${NC}"
for dockerfile in "frontend/Dockerfile" "backend/Dockerfile"; do
  if [[ -f "$dockerfile" ]]; then
    echo -e "Auditing $dockerfile for non-root security compliance..."
    if grep -qE "(USER|nginx-unprivileged)" "$dockerfile"; then
      echo -e "  [${GREEN}PASS${NC}] Non-root runtime directive present in $dockerfile"
    else
      echo -e "  [${YELLOW}WARN${NC}] $dockerfile does not explicitly specify a non-root USER or unprivileged image"
    fi
  else
    echo -e "  [${YELLOW}INFO${NC}] $dockerfile not yet created."
  fi
done

echo -e "\n${GREEN}Build & verification run complete!${NC}"
exit 0

