# Verify

## Ambiente de verificação
- Host: Windows 11 (PowerShell 5.1), cwd `C:\Users\paulo\chatwoot`.
- Disponível: **Node v22.17.1**, npm 11.12.1, corepack → pnpm 10.2.0.
- **Ausentes** neste host: Ruby/rbenv, PostgreSQL, Redis, Docker. (O projeto exige Ruby 3.4.4 + PG16 + Redis + Node 24.)

## Validações realizadas (lightweight, on-lobe)

### Rebrand Woodesk técnico (2026-09-09) — ✅ parcial (host sem docker/ruby)
- **JSON**: todos os `.json` alterados/criados parseiam via `node JSON.parse` (i18n, swagger, package). Falso negativo: `.devcontainer/devcontainer.json` é JSONC (comenta `//`) — válido para devcontainer tooling.
- **SDK**: `pnpm build:sdk` → `✓ built in 2.15s`, `public/packs/js/sdk.js` 29.14 kB. Build contém `$woodesk` (50 ocorrências), `woodeskSDK`, `woodeskSettings`; **0** ocorrências de `chatwoot`/`chatwootSDK`. Avisos não-bloqueantes: engine node 22 vs 24, browserslist, publicDir==outDir.
- **Greps de leftovers** (case-insensitive em app/lib/config/docker/enterprise/db/spec/swagger/deployment/.circleci): sem `chatwoot` fora das exclusions intencionais — `@chatwoot/*` deps, `chatwoot_record_*` (restaurados), `enterprise/LICENSE`, binário `ding.mp3`. Removidos: `ChatWoot` (pt/ru locales), `namespace :chatwoot` em `variant_toggle.rake`.
- **Renames**: `git status` mostra 19 `RM` (lib/*, enterprise/lib, specs, deployment/*, .circleci/setup_woodesk.sql).
- **Compose novo** `docker-compose.woodesk.yaml` + `.env.woodesk.example`: revisados estruturalmente (indentação, `depends_on condition`, healthcheck) — sem parser YAML/docker neste host.

### 2026-09-09 — Etapa 1 Woodesk (tradução pt_BR) — ✅
- Backend: PyYAML comparou `config/locales/en.yml` (456 chaves) vs `pt_BR.yml` (456 chaves) → **0 faltando / 0 extras** após correções; YAML parseia OK.
- Dashboard: script Node (flatten keys) em 48 arquivos `en/*.json` vs `pt_BR/*.json` → **0 chaves faltando**.
- Widget e Survey: `en.json` vs `pt_BR.json` → **0 chaves faltando**.
- Valores idênticos en==pt_BR (len>2): 207, revisados manualmente — maioria legítima (marcas: WhatsApp/SMS/SLA/CSAT; jargão tech: Status/Slug/Link/Macros/Beta; URLs e placeholders). Caso de não-tradução real corrigido: `REMOVE_ASSIGNED_AGENT` → "Remover atendente atribuído" (2x).
- Encoding: 0 caracteres U+FFFD em `pt_BR/conversation.json` e `pt_BR.yml` (arquivos UTF-8 íntegros; mojibake anterior era só de console).

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
- `docker compose -f docker-compose.supabase.yaml config` e `-f docker-compose.woodesk.yaml config` (validação real do YAML + `.env.woodesk`).
- `docker build -f docker/Dockerfile` (imagem `woodesk/chat`).
- `GET /health` 200 + Sidekiq Redis ping via Upstash/container.
- `rails db:woodesk_prepare` contra uma base PostgreSQL real.
- `bundle exec rubocop -a` e rspecs dos arquivos renomeados/alterados (`spec/lib/woodesk_*`, `spec/services/data_imports/*`).
- Smoke: login superadmin + widget com globals `$woodesk`.
