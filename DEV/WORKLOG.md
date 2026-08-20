# Worklog

## 2026-08-13 — Análise + implementação Fase A (Supabase + TS)
- Lidos globais orquestrador + AGENTS.md Chatwoot. Inspecionada stack Docker (Dockerfile multi-stage, compose dev/prod, Procfile, deployment/nginx+systemd).
- Mapeeados processos: Puma, Sidekiq (15 queues), ActionCable (Redis), Vite (assets pré-compilados).
- Verificadas configs: redis ($alfred/$velma), database.yml (pgvector), storage.yml (local default), security (Rack::Attack ok; CSP/CORS abertos; secrets placeholder).
- **Supabase**: compatível (extensões pg_trgm/pgcrypto/vector suportadas em db/schema.rb). Conexão via pooler `-pooler.supabase.co`.
- **Redis é hard dependency** → recomendado Upstash (serverless) para stack 100% stateless.
- **TypeScript**: frontend era JS puro → tsconfig.json + `typescript` devDep. Vite/esbuild já transpila TS; não requer migração massiva.

### Implementado na sessão
- `docker-compose.supabase.yaml` (caddy rails sidekiq-critical sidekiq-low migrate; sem postgres/redis containers).
- `docker/caddy/Caddyfile` (TLS ACME + reverse proxy + WS /cable + headers).
- `.env.supabase.example` (pooler, Upstash, keys, S3, SMTP, Caddy domain).
- `docker/entrypoints/rails.prod.sh` (migration idempotente alternativa).
- `config/initializers/content_security_policy.rb` (CSP ativada).
- `config/initializers/cors.rb` (restrito: públicos `*`, API travado a FRONTEND_URL).
- `config/initializers/trusted_proxies.rb` (RFC1918 para X-Forwarded-* atrás do proxy).
- `tsconfig.json` + `typescript` em package.json devDependencies.
- healthcheck Docker em rails (`/health`) e sidekiq (Redis ping).

## 2026-08-13b — Validação "rode localhost" (executada)
- Host Windows: Node 22 + pnpm 10.2.0 disponíveis; Ruby/Postgres/Redis/Docker AUSENTES.
- `pnpm install` OK (typescript 5.9.3). `pnpm build:sdk` → `✓ built in 2.68s`, `public/packs/js/sdk.js` 29.20kB. Type-check TS puro exit 0. **Pipeline TS validado.**
- App Rails completo NÃO roda neste host (necessita Ruby 3.4.4 + PG16 + Redis + Docker).
- Documentado em `DEV/VERIFY.md`.

### Arquivos entregues
- `docker-compose.supabase.yaml`, `docker/caddy/Caddyfile`, `.env.supabase.example`, `docker/entrypoints/rails.prod.sh`.
- `config/initializers/{content_security_policy,cors,trusted_proxies}.rb`.
- `tsconfig.json`, `package.json` (+typescript devDep), `pnpm-lock.yaml` (atualizado).
