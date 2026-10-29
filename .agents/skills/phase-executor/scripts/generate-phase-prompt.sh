#!/usr/bin/env bash
# ==============================================================================
# NeutralStack Web - Phase Prompt Generator
# Generates a customized execution prompt to start a new subagent or conversation
# ==============================================================================

set -uo pipefail

PHASE="${1:-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

case "$PHASE" in
  1)
    TITLE="Workspace & Tooling Initialization"
    TASKS="- Multi-package workspace scaffolding (root package.json with npm/pnpm workspaces).
- Create .dockerignore excluding node_modules, build caches, and sensitive keys.
- Create .env.example with documented configuration variables.
- Validate .gitignore rejects *.p12, *.pem, *.key, and .env* files."
    ;;
  2)
    TITLE="Frontend Engineering (React + Vite + Tailwind CSS)"
    TASKS="- Initialize frontend/ with React, Vite, and TypeScript.
- Configure Tailwind CSS mobile-first breakpoints (sm: 640px, md: 768px, lg: 1024px, xl: 1280px).
- Implement responsive component tree with 44x44px min touch targets.
- Configure Vite/Rollup deterministic chunk hashing: assets/[name].[hash].[ext].
- Configure frontend/nginx.conf with immutable asset caching and no-cache index.html."
    ;;
  3)
    TITLE="Backend Microservice (Fastify LTS)"
    TASKS="- Initialize backend/ with Fastify, TypeScript, and app factory pattern.
- Implement @fastify/env schema validation for runtime configuration.
- Register @fastify/helmet, @fastify/cors, and @fastify/rate-limit.
- Implement RFC 7807 problem details error envelopes.
- Implement /healthz and /readyz liveness/readiness probes."
    ;;
  4)
    TITLE="Containerization & Local Orchestration"
    TASKS="- Build multi-stage frontend/Dockerfile with unprivileged Alpine NGINX (UID 101).
- Build multi-stage backend/Dockerfile with non-root Node.js LTS (UID 1000).
- Create docker-compose.yml bridging frontend and backend services."
    ;;
  5)
    TITLE="Security Hardening & Certificate Lifecycle"
    TASKS="- Create scripts/extract-p12-certs.sh to extract PKCS#12 bundles external to git into K3s TLS secret.
- Create scripts/monitor-cert-expiry.sh to alert on certificates expiring within 30 days.
- Ensure strict zero-commit secret audit passes."
    ;;
  6)
    TITLE="Declarative K3s Deployment & Quality Gates"
    TASKS="- Create k8s/00-namespace.yaml, k8s/01-configmap-secrets.yaml.
- Create k8s/10-frontend-deployment.yaml and k8s/20-backend-deployment.yaml with non-root security contexts.
- Create k8s/30-ingress.yaml routing /assets/* and /* to frontend, /api/v1/* to backend.
- Validate Lighthouse score > 90 and backend p95 API latency < 30ms."
    ;;
  *)
    echo "Usage: $0 [1|2|3|4|5|6]" >&2
    exit 1
    ;;
esac

cat <<EOF
You are an expert full-stack engineer and site reliability specialist pair programming on **NeutralStack Web** (\`neutralstack-web\`).

### Mission Objective:
Implement, build, and verify **Phase $PHASE: $TITLE** in strict adherence to the project architecture, build, and security specifications.

### Project Context & Specifications:
1. Architectural Tenets & Topology: \`docs/architecture-spec.md\`
2. Build, Packaging & Rollup Hashing: \`docs/build-spec.md\`
3. Security, Zero-Commit & P12 Certificates: \`docs/security-k3s-blueprint.md\`
4. Implementation Roadmap & Milestones: \`docs/plans/implementation-roadmap.md\`

### Target Deliverables for Phase $PHASE:
$TASKS

### Execution Protocol:
1. **Implement Phase Requirements:**
   - Write clean, type-safe, production-ready code with vendor-neutral standards.
   - Respect zero-commit policy: NEVER hardcode or commit \`.env\`, \`*.p12\`, \`*.key\`, \`*.pem\`, \`*.crt\` files.
   - Adhere to non-root execution profiles for all containers and microservices.

2. **Verify Phase Deliverables:**
   - Execute the automated phase verifier:
     \`bash .agents/skills/phase-verification/scripts/verify-phase.sh $PHASE\`
   - Ensure all acceptance criteria pass with zero errors.

3. **Verify Build & Asset Hashes:**
   - Execute the build and hash integrity pipeline:
     \`bash .agents/skills/build-verification/scripts/verify-build.sh\`
   - If frontend assets are built, ensure all production assets under \`frontend/dist/assets/\` carry deterministic cryptographic content hashes and meet size budgets.

4. **Update Implementation Roadmap:**
   - Update \`docs/plans/implementation-roadmap.md\` by marking completed milestone items with \`[x]\`.

5. **Final Output:**
   - Provide a concise summary of created/modified files, test results, and next steps for subsequent phases.
EOF

