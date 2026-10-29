# Build & Asset Fingerprinting Guidelines

This reference details the build standards, hashing algorithms, and HTTP caching mechanics enforced in NeutralStack Web.

---

## 1. Rollup / Vite Fingerprinting Mechanics

In `frontend/vite.config.ts`, Rollup chunk names must be configured deterministically:

```typescript
build: {
  outDir: 'dist',
  assetsDir: 'assets',
  rollupOptions: {
    output: {
      entryFileNames: 'assets/[name].[hash].js',
      chunkFileNames: 'assets/[name].[hash].js',
      assetFileNames: 'assets/[name].[hash].[ext]',
    },
  },
}
```

### Why Deterministic Content Hashing?
1. **Cache Invalidation:** Content hashes change if and only if the source code or asset payload changes.
2. **Infinite Static Caching:** Reverse proxies and CDNs safely cache `/assets/*` forever with `Cache-Control: public, max-age=31536000, immutable`.
3. **Atomic Deployments:** New deployments introduce new filenames without breaking clients holding older versions in active browser sessions.

---

## 2. Dynamic Entrypoint Strategy (`index.html`)

* `index.html` references the newly hashed bundles:
  ```html
  <script type="module" crossorigin src="/assets/index.a8f21bc9.js"></script>
  <link rel="stylesheet" crossorigin href="/assets/index.73d2a901.css">
  ```
* Because `index.html` acts as the pointer to the latest asset hashes, **it must never be aggressively cached**:
  ```http
  Cache-Control: no-cache, no-store, must-revalidate
  Pragma: no-cache
  Expires: 0
  ```

---

## 3. Bundle Budgets & Limits

| Asset Category | Target Budget | Action on Exceeding |
| :--- | :--- | :--- |
| Initial JS Chunk | `<= 250 KB` uncompressed | Code-split using `React.lazy()` / dynamic imports |
| Initial CSS Chunk | `<= 50 KB` uncompressed | Purge unused Tailwind classes |
| Total Initial Payload | `<= 300 KB` uncompressed | Audit bundle using `rollup-plugin-visualizer` |

