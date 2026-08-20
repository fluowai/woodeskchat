# Verify

## Ambiente de verificação
- Host: Windows 11 (PowerShell 5.1), cwd `C:\Users\paulo\chatwoot`.
- Disponível: **Node v22.17.1**, npm 11.12.1, corepack → pnpm 10.2.0.
- **Ausentes** neste host: Ruby/rbenv, PostgreSQL, Redis, Docker. (O projeto exige Ruby 3.4.4 + PG16 + Redis + Node 24.)

## Validações realizadas (lightweight, on-lobe)

### TypeScript (frontend) — ✅
- `pnpm install --no-frozen-lockfile` → `typescript@5.9.3` instalado; lockfile atualizado.
- `pnpm build:sdk` (`vite build --config vite.lib.config.ts`) → `✓ built in 2.68s`, artefato
  `public/packs/js/sdk.js` (29.20 kB). Confirma Vite + esbuild transpilam com o novo tsconfig.
- `npx tsc --noEmit` em arquivo `.ts` de teste → exit 0 (nenhum erro de tipo). Confirma o
  compilador TS + `tsconfig.json` resolvem aliases e transpilam TS puro.
- Observação: Node 22 (host) vs Node 24 (exigido por `.nvmrc`/`engines`) — apenas *warning*
  de engine; build sucedeu.

### JSON — ✅
- `tsconfig.json` e `package.json` parseados como JSON válido (node `JSON.parse`).

### YAML / compose — ⚠️ (não-executado)
- Docker ausente → não rodou `docker compose -f docker-compose.supabase.yaml config`.
- Revisado estruturalmente (indentação 2-space, long-form `depends_on condition`, healthchecks).

### Ruby / initializers — ⚠️ (não-executado)
- Ruby ausente → não rodou `bundle exec rubocop` ni `ruby -c` não initializers.
- Revisado estruturalmente: balanceamento `do/end`/`if/end` OK em `cors.rb`,
  `content_security_policy.rb`, `trusted_proxies.rb`.

## O que NÃO foi validado (precisa de environment com Docker/Ruby)
- `docker compose -f docker-compose.supabase.yaml up` (Caddy TLS, rails, sidekiq).
- `GET /health` 200 + Sidekiq Redis ping via Upstash.
- `rails db:chatwoot_prepare` contra uma base Supabase sandbox.
- Build da imagem local (`docker build -f docker/Dockerfile`).
- `pnpm dev` / `overmind start -f Procfile.dev` (precisa Ruby + Redis + Postgres local).
- Smoke de CSP no navegador (dashboard Rails).
