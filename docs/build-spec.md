# Build & Packaging Specification

**Project:** NeutralStack Web (`neutralstack-web`) - Vendor-Neutral Responsive Mobile-First Application  
**Version:** 1.0.0-POC  
**Status:** Approved Build Spec  

---

## 1. Project Directory Structure

The repository is organized as a clean multi-package workspace to support independent containerization, distinct CI/CD lifecycles, and unified orchestration.

```
neutralstack-web/
├── .dockerignore
├── .gitignore
├── docker-compose.yml             # Unified local orchestration
├── docs/
│   ├── architecture-spec.md
│   ├── build-spec.md
│   └── security-k3s-blueprint.md
├── k8s/                           # K3s / Kubernetes declarative manifests
│   ├── 00-namespace.yaml
│   ├── 01-configmap-secrets.yaml
│   ├── 10-frontend-deployment.yaml
│   ├── 20-backend-deployment.yaml
│   └── 30-ingress.yaml
├── frontend/                      # React + Vite + Tailwind CSS
│   ├── Dockerfile
│   ├── nginx.conf                 # Production NGINX static configuration
│   ├── package.json
│   ├── postcss.config.js
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── src/
│       ├── App.tsx
│       ├── main.tsx
│       └── index.css
└── backend/                       # Fastify Node.js microservice
    ├── Dockerfile
    ├── package.json
    ├── tsconfig.json
    └── src/
        ├── app.ts
        └── server.ts
```

---

## 2. Frontend Build Configuration (Vite + Tailwind)

### 2.1 `frontend/vite.config.ts`
Ensures Rollup outputs fingerprinted chunks with deterministic naming conventions:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: process.env.VITE_BACKEND_PROXY_URL || 'http://localhost:5000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].[hash].js',
        chunkFileNames: 'assets/[name].[hash].js',
        assetFileNames: 'assets/[name].[hash].[ext]',
      },
    },
  },
});
```

### 2.2 `frontend/tailwind.config.js`
Enforces mobile-first responsive breakpoints:

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    screens: {
      'sm': '640px',
      'md': '768px',
      'lg': '1024px',
      'xl': '1280px',
      '2xl': '1536px',
    },
    extend: {
      colors: {
        brand: {
          50: '#f0f9ff',
          500: '#0284c7',
          900: '#0c4a6e',
        },
      },
    },
  },
  plugins: [],
}
```

---

## 3. Containerization Strategy (Multi-Stage Dockerfiles)

### 3.1 Frontend `frontend/Dockerfile`
Uses a two-stage build:
1. `node:22-alpine` compiles the static production bundle with fingerprinting.
2. `nginxinc/nginx-unprivileged:alpine` serves static files without root privileges, enforcing immutable caching headers.

```dockerfile
# Stage 1: Build static assets
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve with non-root NGINX
FROM nginxinc/nginx-unprivileged:alpine

# Remove default configuration and inject vendor-neutral NGINX template
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### 3.2 Frontend `frontend/nginx.conf`
Enforces the strict immutable caching rules and security headers:

```nginx
server {
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;

    # Immutable static assets (JS, CSS, images, media)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        access_log off;
        try_files $uri =404;
    }

    # SPA Entrypoint (Always revalidate)
    location / {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
```

### 3.3 Backend `backend/Dockerfile`
Multi-stage build compiling TypeScript, discarding dev dependencies, running as non-root user `node`.

```dockerfile
# Stage 1: Build TypeScript bundle
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci

COPY src ./src
RUN npm run build

# Stage 2: Minimal Production Runtime
FROM node:22-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=5000

# Install dumb-init for proper PID 1 signal handling
RUN apk add --no-cache dumb-init

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/dist ./dist

# Run as unprivileged standard user
USER node

EXPOSE 5000

HEALTHCHECK --interval=20s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/healthz', (res) => res.statusCode === 200 ? process.exit(0) : process.exit(1))"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

---

## 4. Unified Local Orchestration (`docker-compose.yml`)

Unifies the React frontend, Fastify backend, and reverse proxy gateway into an identical-to-production local stack.

```yaml
version: '3.8'

services:
  # Ingress / Gateway: Emulates edge routing
  gateway:
    image: nginx:alpine
    container_name: neutralstack_gateway
    ports:
      - "80:80"
    volumes:
      - ./docker/gateway.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      frontend:
        condition: service_healthy
      backend:
        condition: service_healthy
    networks:
      - neutralstack-net

  # Frontend Service
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: neutralstack_frontend
    environment:
      - NODE_ENV=production
    networks:
      - neutralstack-net

  # Fastify Backend Service
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: neutralstack_backend
    environment:
      - NODE_ENV=production
      - HOST=0.0.0.0
      - PORT=5000
      - CORS_ORIGIN=http://localhost
    networks:
      - neutralstack-net

networks:
  neutralstack-net:
    driver: bridge
```

### 4.1 Gateway Configuration (`docker/gateway.conf`)
Routes edge requests across containers:

```nginx
upstream frontend_upstream {
    server frontend:8080;
}

upstream backend_upstream {
    server backend:5000;
}

server {
    listen 80;
    server_name localhost;

    location /api/ {
        proxy_pass http://backend_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /healthz {
        proxy_pass http://backend_upstream/healthz;
    }

    location / {
        proxy_pass http://frontend_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 5. Build, Lint & Verification Lifecycle

Developers and CI/CD pipelines run standard commands:

| Stage | Command | Purpose |
| :--- | :--- | :--- |
| **Install** | `npm ci` (in `frontend` and `backend`) | Deterministic dependency tree installation |
| **Lint & Typecheck** | `npm run lint && npm run typecheck` | Static analysis & TypeScript compiler validation |
| **Test** | `npm test` | Unit and route integration test execution |
| **Bundle Build** | `npm run build` | Fingerprinted Vite build & TypeScript compilation |
| **Container Build** | `docker compose build --no-cache` | Multi-stage image build validation |
| **Stack Validation** | `docker compose up -d && docker compose ps` | Orchestrated end-to-end local validation |

