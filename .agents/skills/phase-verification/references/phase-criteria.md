# Phase Verification Criteria Reference

This document details the exact acceptance criteria and definition of done for each phase in the NeutralStack Web roadmap.

---

### Phase 1: Workspace & Tooling Initialization
* **Root Configuration:** `package.json` with npm/pnpm/yarn workspaces defined.
* **Source Guard:** `.gitignore` rejecting `.env*`, `*.p12`, `*.pfx`, `*.pem`, `*.key`, `*.crt`.
* **Container Isolation:** `.dockerignore` excluding `.git`, `node_modules`, `dist`, `.env*`, and local secrets.
* **Environment Example:** `.env.example` documenting all non-sensitive configuration keys.

### Phase 2: Frontend Engineering
* **Mobile-First CSS:** Layouts constructed using min-width breakpoints (`sm: 640px`, `md: 768px`, `lg: 1024px`, `xl: 1280px`).
* **Interactive Touch Targets:** Navigation and button touch surfaces meet or exceed 44x44px.
* **Asset Fingerprinting:** Vite/Rollup configured to produce `assets/[name].[hash].[ext]`.
* **Caching Directives:** `nginx.conf` sets `max-age=31536000, immutable` for `/assets/*` and `no-cache, no-store, must-revalidate` for `index.html`.

### Phase 3: Backend Microservice
* **Architecture:** Fastify instance instantiated via app factory pattern (`app.ts`).
* **Validation:** All inputs validated against JSON / TypeBox schemas using `@fastify/env`.
* **Security Headers:** `@fastify/helmet` configured with strict Content-Security-Policy.
* **Rate Limiting:** `@fastify/rate-limit` enabled on all public API endpoints.
* **Probes:** Unauthenticated, fast-return `/healthz` and `/readyz` endpoints.

### Phase 4: Containerization & Local Orchestration
* **Non-Root Runtime:** Frontend container uses `nginxinc/nginx-unprivileged:alpine`. Backend runs under Node.js user UID 1000.
* **Multi-Stage Builds:** Development dependencies discarded in final image stages.
* **Docker Compose:** Single command `docker compose up` brings up connected frontend and backend containers.

### Phase 5: Security Hardening & Certificate Lifecycle
* **P12 Isolation:** P12 archive parsed external to git; extracted keys piped directly into K3s `Secret` and temporary files shredded.
* **Monitoring:** Automated cron or health script alerts when cluster TLS certificate expires within 30 days.

### Phase 6: Declarative K3s Deployment & Quality Gates
* **Declarative Manifests:** 100% vendor-neutral YAML files in `k8s/`.
* **Zero Cloud Lock-in:** No cloud provider annotations (e.g. `alb.ingress.kubernetes.io` or `eks.amazonaws.com`).
* **Lighthouse Audits:** Mobile Performance > 90, Accessibility = 100, Best Practices = 100, SEO = 100.
* **Latency:** Backend p95 latency under 30ms for landing and health endpoints.

