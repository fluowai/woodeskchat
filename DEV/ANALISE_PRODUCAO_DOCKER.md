# Análise: Produção Multi-Container Docker

> **Objetivo**: avaliar o que falta para levar o Chatwoot a produção via Docker containers (multi-container, não apenas um monolito).

## 1. O que JÁ existe e funciona

| Área | Estado atual | Arquivo |
|------|-------------|---------|
| **Build de imagem** | Multi-stage, Alpine, assets pré-compilados, linux/amd64 + arm64 (CI). Produção usa imagem pública `chatwoot/chatwoot:latest`. | `docker/Dockerfile` |
| **Web server** | Puma (config em `config/puma.rb`), threads/workers via env. | `config/puma.rb` |
| **Background jobs** | Sidekiq + sidekiq-cron, JSON logging em prod, múltiplas filas (critical…housekeeping). | `config/sidekiq.yml`, `config/initializers/sidekiq.rb` |
| **WebSockets** | ActionCable com adapter Redis. | `config/cable.yml`, `config/initializers/actioncable.rb` |
| **Database** | PostgreSQL 16 + extensão `pgvector` (para AI/embeddings). Schema load via `db:chatwoot_prepare`. | `config/database.yml` |
| **Cache/bus** | Redis (pool único via `Redis::Config.app`, $alfred/$velma connection pools). | `lib/redis/config.rb`, `config/initializers/01_redis.rb` |
| **Rate limiting** | Rack::Attack com backend Redis + safelist para `/health`. | `config/initializers/rack_attack.rb` |
| **Health checks app** | `/health` (status `woot`) e `/api` (version/timestamp/redis/postgres status). | `app/controllers/health_controller.rb`, `app/controllers/api_controller.rb` |
| **Storage** | ActiveStorage: local (default) ou S3/GCS/Azure configurável. | `config/storage.yml`, `ACTIVE_STORAGE_SERVICE` env |
| **Assets frontend** | Vite build pré-compilado no Dockerfile; `RAILS_SERVE_STATIC_FILES=true` no image de prod. | `vite.config.ts`, `docker/Dockerfile` |
| **CI Docker** | Buildx multi-arch, push para DockerHub (`chatwoot/chatwoot`). | `.github/workflows/publish_foss_docker.yml`, `publish_ee_docker.yml` |

**Conclusão parcial**: A base funciona. O `docker-compose.production.yaml` JÁ é multi-container (rails, sidekiq, postgres, redis). O problema é que ele não é adequado a produção real sem reforço.

---

## 2. Gaps críticos para produção (o que FALTA / é insuficiente)

### 2.1 — TLS / HTTPS termination (CRÍTICO, fora do escopo atual)
- `docker-compose.production.yaml` expõe a porta 3000 direto. Nada faz validação TLS.
- `FORCE_SSL=false` por padrão em `.env.example`. Sem TLS, o navegador bloqueia secure cookies e o chatao widget via HTTPS falha.
- `deployment/nginx_chatwoot.conf` existe mas **não é containerizado** — é um config manual de server.
- **→ Precisa de um container de reverse proxy (nginx ou caddy) com TLS termination.**

### 2.8 — Redis senha vazia em dev/prod compose (CRÍTICO)
- Em ambos os compose, `POSTGRES_PASSWORD=` está vazio e `REDIS_PASSWORD` vem do `.env` (vazio em `.env.example`).
- Redis do container roda com `--requirepass "$REDIS_PASSWORD"` → senha vazia = sem proteção.
- Postgres expõe porta 5432 direto (prod binda a `127.0.0.1` mas não tem senha).
- **→ Precisa de secrets reais gerenciados (Docker secrets / .env.prod / vault).**

### 2.3 — Segurança de cookies/secret key (CRÍTICO)
- `SECRET_KEY_BASE` é apenas um placeholder (`replace_with_lengthy_secure_hex`).
- Active Record Encryption keys (MFA/2FA) estão **comentadas** no `.env.example` — 2FA fica desativado.
- CSP está **comentada** (`content_security_policy.rb` todo commented out) — sem proteção XSS via CSP.
- `cors.rb` permite `origins '*'` para `/public/api/*` e uploads — pode vazar.
- **→ Precisa: SECRET_KEY_BASE gerado, chaves de criptografia definidas, CSP habilitada, CORS restrito.**

### 2.4 — Migrations DB não rodam automaticamente no container (CRÍTICO)
- `docker/entrypoints/rails.sh` espera pelo Postgres e roda `bundle install`, mas **não roda `rails db:chatwoot_prepare` / `db:migrate`**.
- O `Procfile.release` (Heroku) roda migrações, mas em Docker isso é tratado via `release:` command — não automático no container.
- **→ Precisa de um init-container / run de migrate antes do Rails startar, ou um job de migração.**

### 2.5 — Storage persistente e backups (ALTO)
- Compose prod tem `storage_data:/app/storage` mas **sem backup**. ActiveStorage local = dados perdidos se container morrer.
- Postgres/Redis têm volumes mas sem estratégia de backup/restore.
- **→ Precisa: S3 (recomendado para produção) + backup automatizado do Postgres.**

### 2.6 — OpenSearch não provisionado (ALTO, se usa busca avançada)
- Busca avançada exige `OPENSEARCH_URL` mas **não há container OpenSearch** nos compose files.
- `config/sidekiq.yml` e `searchkick` usam searchkick → dependem de OpenSearch.
- **→ Precisa container OpenSearch se funcionalidade de busca avançada for usada.**

### 2.7 — Sem resource limits / healthcheck no compose (MÉDIO)
- Nenhum `healthcheck`, `deploy.resources`, `restart` em containers de app (rails/sidekiq não têm restart no prod compose; postgres/redis sim).
- Sidekiq worker sem limite de memória (no systemd tem `MemoryMax=60%`, mas no Docker não).
- **→ Precisa healthchecks + limits de recursos.**

### 2.8 — Logs não estruturados / sem shipper (MÉDIO)
- Logs vão para stdout (configurado), mas sem log shipper nem rotação definida em container.
- Logrotate via `LOG_SIZE` é para file logging, não stdout.
- **→ O stdout já é coletado pelo orquestrador; mas precisa de config de retenção no host/orquestrador.**

### 2.9 — Sidekiq não escalável por fila (MÉDIO)
- Compose prod tem 1 sidekiq. As filas (critical, high, medium, default, mailers, low, housekeeping, scheduled_jobs, bulk_reindex_low, active_storage_analysis…) competem no mesmo pool.
- Em produção de alta demanda, você quer workers dedicados: um para webhooks (critical), um para low/housekeeping (pesado), etc.
- **→ Particionar workers por prioridade/fila usando `-q` flags ou múltiplas services.**

### 2.10 — ActionCable escala limitada (MÉDIO)
- ActionCable (WebSocket) é servido pelo mesmo processo Rails (Puma). Em multi-replica, precisa sticky session ou dedicar um processo `cable` só para websockets + Redis pub/sub.
- **→ Container `cable` dedicado ou sticky sessions no proxy.**

### 2.11 — Monitoramento / APM ausente (BAJO)
- Gems de APM (sentry, datadog, newrelic, scout) instaladas mas **não configuradas** → falham silenciosamente se env não setada.
- Sidekiq::Web em `/monitoring/sidekiq` (autenticado super_admin) mas sem documentação/expose.
- **→ Configurar Sentry APM + health dashboard.**

### 2.12 — Variáveis de domínio/URL (ALTO)
- `FRONTEND_URL=http://0.0.0.0:3000` (placeholder). Em prod precisa do domínio real + HTTPS.
- `MAILER_SENDER_EMAIL` e config SMTP não provisionados.
- `ENABLE_ACCOUNT_SIGNUP=false` — mas precisa de decisão sobre onboarding público.
- **→ `.env.production` completo com domínio + SMTP.**

### 2.13 — Enterprise overlay (BAJO, só se usar EE)
- Projeto tem overlay `enterprise/`. Image oficial EE é `chatwoot/chatwoot:latest` (não `-ce`).
- CI publica CE (strip enterprise) e EE separados.
- **→ Decidir CE vs EE; se EE, usar imagem correta.**

#### 2.14 — Frontend widget separado
- O widget (chat embed) é parte do build do Rails/Vite. Não há CDN separada para assets do widget.
- `size-limit` configura `public/vite/assets/widget-*.js` (300KB max).

---

## 7. Análise Supabase (sem banco na stack) + Redis gerenciado + TypeScript

> Requisito do usuário: "preciso que rode com supabase ... nada de banco de dados na stack ... typescript tambem".

### 7.1 Conectividade ao Supabase PostgreSQL

**Compatibilidade**: Supabase roda PostgreSQL 15+ e Supabase suporta TODAS as extensões que Chatwoot exige:
`pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql`, `vector` (pgvector) — ver `db/schema.rb:15-19`.

**Configuração de conexão**:
- `DATABASE_URL` (ou `POSTGRES_HOST/PORT/USERNAME/PASSWORD`) aponta para `db.<project_ref>.supabase.co:5432/postgres`.
- **Recomendado**: usar o **pooler** de Supabase para Rails/Sidekiq (concorrência de threads > 20):
  `postgres://postgres.<project_ref>:<password>@<project_ref>-pooler.supabase.co:5432/postgres`.
  Isso usa PgBouncer e evita "too many connections".
- O usuário de conexão deve ser o `postgres` (default do Supabase proj) para poder rodar `CREATE EXTENSION`
  (schema load / migrations). Supabase concede isso ao role `postgres`.

**Migrações**: o entrypoint de produção precisa rodar `rails db:chatwoot_prepare` uma vez. Com Supabase isso funciona
normalmente, mas:
- Supabase impõe limites de conexão (free tier = 20, paid = até 200). Ajuste `RAILS_MAX_THREADS` baixo
  (ex: 5) e use o pooler.
- Supabase free tier tem limites de storage (500MB) e banda (500MB/mês para novos projetos) — verificar antes.

### 7.2 O PROBLEMA do Redis (não é "banco", mas é stateful)

Supabase **não oferece Redis**. Chatwoot usa Redis em 4 caminhos críticos de produção:
1. **Sidekiq** (background jobs) — sem ele: zero jobs assíncronos (e-mails, webhooks, processamento).
2. **ActionCable** (WebSocket/chat ao vivo) — sem ele: chat em tempo real cai.
3. **Rack::Attack** (`$velma`, $alfred pools) — sem ele: rate-limiting cai para memória (não distribuído).
4. **Cache** (`$alfred`) — presença online, round-robin.

**→ Decisão**: para ter "nada de banco/stateful na stack de containers", adote **Redis gerenciado externo**:
- **Upstash Redis** (serverless, pay-per-request, free tier 10k ops/dia) — integra bem com Supabase,
  é a escolha mais limpa (zero containers stateful). `REDIS_URL=rediss://default:<key>@<upstash-endpoint>`.
- Alternativa: **Supabase não tem** → se insistir em zero containers, Upstash é o caminho.
- Fallback mínimo (menos ideal): um container `redis:7-alpine` dedicado — mas isso viola o princípio de
  "nada de DB na stack". Recomendo Upstash.

### 7.3 TypeScript no frontend

O frontend (`app/javascript/`) é **JavaScript/Vue 3 puro** — nenhum arquivo `.ts` de runtime,
nenhum `tsconfig.json` de app (apenas `tests/playwright/tsconfig.json`).

**Opção A — Mínima (recomendada para "rodar com TypeScript"):**
1. `pnpm add -D typescript @types/node @types/jest` (e tipos usados via imports).
2. Criar `tsconfig.json` na raiz com `"allowJs": true, "checkJs": false` → Vite transpila TS
   e Vue SFC `lang="ts"` (esbuild já vem no Vite).
3. Novos arquivos podem ser `.ts`/`.vue(lang=ts)` sem migration massiva. Build existing JS continua igual.
   → produção compila, "roda com TypeScript" sem risco de regressão.

**Opção B — Migração completa (grande esforço, NÃO recomendado sem escopo dedicado):**
- Migrar ~500 `.vue`/`.js` para TS. Alto risco de regressão. Fora do escopo de "ir pra produção".

**Config do Vite**: já usa `vite-plugin-ruby` + `@vue/compiler-sfc`; suporta TS nativamente.
Nenhum Dockerfile change needed (Node 24 já tem tudo). Apenas `tsconfig.json` + types na build.

### 7.4 Stack Docker final (Supabase + Upstash + TS, sem containers stateful)

```
                    ┌──────────────────────────┐
                    │  nginx  (ou caddy)       │  ← TLS (Let's Encrypt via certbot)
                    │  reverse proxy + assets  │  ← NÃO existe ainda (criar)
                    └───────────┬──────────────┘
                                │
   ┌─────────────┬──────────────┼──────────────┬──────────────┐
   │             │              │              │              │
┌──▼──┐      ┌───▼────┐    ┌────▼───┐    ┌─────▼───┐    ┌────▼───┐
│rails│      │rails   │    │sidekiq │    │sidekiq │    │ cable  │
│web.1│      │web.2   │    │crit    │    │low     │    │(WS)   │
└──┬──┘      └───┬────┘    └────┬─────┘    └──────┬──┘    └───┬────┘
   │             │              │                 │           │
   └─────────────┴──────────────┴─────────────────┴───────────┘
         REDIS_URL ────► Upstash Redis (serverless, gerenciado)
         DATABASE_URL ──► Supabase PostgreSQL (gerenciado, +pooler)
         (NÃO há containers de postgres/redis na stack)
```

### 7.5 Tarefas específicas para o stack Supabase + TS

| # | Tarefa | Arquivo alvo | Esfço |
|---|--------|--------------|-------|
| S1 | Criar `docker-compose.supabase.yaml` sem `postgres`/`redis` services; rails/sidekiq/cable + nginx TLS | novo compose | Médio |
| S2 | Adicionar container `nginx` (ou caddy) com TLS + config reverse proxy | `docker/nginx/Dockerfile` + conf | Médio |
| S3 | Criar `docker/entrypoints/rails.prod.sh` que roda `rails db:chatwoot_prepare` idempotente antes de `exec rails s` | novo entrypoint | Pequeno |
| S4 | `.env.supabase.example` com DATABASE_URL pooler, REDIS_URL (Upstash), SECRET_KEY_BASE, encryption keys, FRONTEND_URL https, S3 | novo .env | Pequeno |
| S5 | Adaptar `config/database.yml`/redis para ler `DATABASE_URL`/`REDIS_URL` (já suportado pelo helper `pg_database_url.rb` e `Redis::Config.app`) | existente (já ok) | Nenhum |
| S6 | Criar `tsconfig.json` + instalar types (typescript) | raiz + package.json | Pequeno |
| S7 | Adicionar `healthcheck` Docker em rails/sidekiq/cable | compose | Pequeno |
| S8 | Habilitar CSP + restringir CORS (produção) | `content_security_policy.rb`, `cors.rb` | Médio |

### 7.6 Riscos Supabase específicos

| Risco | Detalhe | Severidade |
|-------|---------|-----------|
| Limite de conexões Supabase | free=20 conexões; Rails 5 threads × N web = rápido de estourar. Usar pooler + baixar threads. | ALTO |
| pgvector no Supabase | Suportado, mas habilidade de `CREATE EXTENSION vector` exige role postgres (ok no default). | BAIXO |
| Upstash latency | serverless Redis tem latência "cold start" em first byte; aceitável para Chatwoot. | MÉDIO |
| Backups | Supabase faz backup gerenciado (point-in-time no pago); local era responsabilidade nossa. | BAIXO (melhora) |
| Storage de arquivos | AtivoStorage Local não escala multi-container; usar S3/Supabase Storage. | ALTO |

### 7.7 Checklist de migração DB → Supabase

1. Criar projeto Supabase; note `PROJECT_REF` e `DB_PASSWORD`.
2. Grant extensões: `create extension if not exists vector;`, `pgcrypto`, `pg_trgm`, `pg_stat_statements` (via SQL ou migration).
3. Exportar dump do PG local: `pg_dump -Fc chatwoot_production > dump.sql`.
4. Importar via Supabase SQL editor ou `pg_restore`.
5. Ajustar `DATABASE_URL` para o pooler.
6. Rodar `RAILS_ENV=production bundle exec rails db:migrate` (idempotente) para aplicar migrations novas.
7. Validar conexões: `rails runner "ActiveRecord::Base.connection.execute('select 1')"` e `Redis.new(...).ping`.

---

## 8. Status da implementação (Fase A concluída — 13/08/2026)

### Já implementado neste ciclo
- [x] `docker-compose.supabase.yaml` — services `caddy` (TLS auto), `rails` (Puma + healthcheck), `sidekiq-critical`, `sidekiq-low`, `migrate` (one-shot). **Sem containers postgres/redis**. Imagem `chatwoot/chatwoot:latest`.
- [x] `docker/caddy/Caddyfile` — TLS ACME + reverse proxy + headers de segurança + websocket `/cable`.
- [x] `.env.supabase.example` — DATABASE_URL (pooler Supabase) + POSTGRES_*, REDIS_URL (Upstash), SECRET_KEY_BASE, encryption keys (2FA), S3, SMTP, Caddy domain/email, WEB_CONCURRENCY/threads.
- [x] `docker/entrypoints/rails.prod.sh` — entrypoint alternativo (migration idempotente + eval pg_database_url + exec). Compose usa padrão **init-service** (`migrate` one-shot) para compatibilidade com a imagem oficial publicada.
- [x] CSP habilitada (`config/initializers/content_security_policy.rb`) + CORS restrito (`config/initializers/cors.rb`): públicos/liberados `*`; autenticados (`/api/*`,` /auth/*`, `/widget/*`) travados a `FRONTEND_URL`.
- [x] `config/initializers/trusted_proxies.rb` — confia RFC1918 para honrar X-Forwarded-* atrás do proxy.
- [x] `tsconfig.json` + `typescript` devDependency → build/run com TypeScript (Vite/esbuild transpila `.ts`/`lang="ts"`; JS existente intocado via `allowJs:true`).
- [x] `healthcheck` Docker em rails (`GET /health`) e sidekiq (ping Redis).

### Pendente (validar antes de declarar produção OK)
- Build da imagem local + smoke `rails db:chatwoot_prepare` contra Supabase sandbox.
- Verificar `force_ssl` redirect via Caddy (trusted_proxies deve resolver).
- Validar CSP não quebra o dashboard (ajustar `unsafe-hashes` se necessário).
- `pnpm install` para atualizar `pnpm-lock.yaml` após add `typescript`.

---

## 3. Arquitetura recomendada (particionamento em containers)

```
                    ┌────────────────────┐
                    │  Reverse Proxy     │  (nginx:alpine ou caddy)
                    │  TLS termination   │  - certs via Let's Encrypt (certbot)
                    │  + static assets   │  - proxy /api, /cable para rails
                    └────────┬───────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
┌─────────▼────────┐ ┌──────▼────────┐ ┌──────▼────────┐
│  Rails (Puma)    │ │  Sidekiq      │ │  ActionCable  │
│  web.1, web.2    │ │  (1 replica)  │ │  (1+ replicas)│
│  - static assets │ │  - all queues │ │  - Redis pub/ │
│  - /api          │ │  - cron jobs  │ │    sub        │
└────────┬─────────┘ └──────┬────────┘ └──────┬────────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │     Shared Services       │
              │  PostgreSQL 16 + pgvector │
              │  Redis 7 (cache/bus)      │
              │  OpenSearch (opcional)   │
              └───────────────────────────┘
```

### Containers propostos (compose stacks)

| Container | Purpose | Replicas | Observação |
|-----------|---------|----------|------------|
| `nginx` (ou caddy) | TLS termination + reverse proxy + static asset cache | 1-2 | Precisa novo Dockerfile/composto |
| `postgres` | Banco principal | 1 (primary), opcionalmente 1 readonly | pgvector extension, backup cron |
| `redis` | Cache, Sidekiq, ActionCable, Rack::Attack | 1 (stand-alone) | senha forte; opcional cluster Redis |
| `opensearch` | Busca avançada (searchkick) | 1-2 | opcional, só se usar search |
| `rails` (web) | Puma web server | 2-4 | `--preload`/`preload_app`, WEB_CONCURRENCY workers |
| `cable` | ActionCable WebSocket | 1-N | dedicado se alta concorrência WS |
| `sidekiq` | Background jobs | 1-N (split por fila) | web/critical × low/housekeeping |
| `sidekiq-cron` | (opcional) jobs agendados isolados | 1 | ou unir no sidekiq principal |

**Estratégia de particionamento de Sidekiq por fila (recomendado):**
- `sidekiq-critical`: `-q critical -q high -q default` (latência baixa, webhooks)
- `sidekiq-low`: `-q low -q housekeeping -q bulk_reindex_low -q scheduled_jobs` (pesado, tolera atraso)
- `sidekiq-mailers`: `-q mailers` (e-mail)
- `sidekiq-storage`: `-q active_storage_analysis -q active_storage_purge`

---

## 4. Plano de Ação (checklist de implementação)

### Fase A — Hardening mínimo (produção básica)
- [A1] Criar `docker-compose.prod.yaml` derivado do `.production.yaml`:
  - Adicionar container `nginx` (ou caddy) com TLS (certbot + Let's Encrypt ou secrets TLS).
  - Adicionar `healthcheck` em Rails (curl `/health`), Redis, Postgres, Nginx.
  - Adicionar `secrets:` (POSTGRES_PASSWORD, REDIS_PASSWORD, SECRET_KEY_BASE) via `.env.prod` ou Docker secrets.
  - `restart: unless-stopped` em todos.
- [A2] `.env.production.example`: template completo com todos os valores prod (domínio HTTPS, SMTP, S3, keys).
- [A3] Modificar entrypoint `rails.sh` para rodar `rails db:chatwoot_prepare` (migration + seed) no startup **com idempotência** (rescue NoDatabase) — OU usar init-container para migrations.
- [A4] Habilitar CSP e restringir CORS (editar `content_security_policy.rb` e `cors.rb`).
- [A5] Gerar `SECRET_KEY_BASE` e Active Record Encryption keys no `.env.prod`.

### Fase B — Produção robusta (escalável)
- [B1] Separar Sidekiq por filas (`sidekiq-critical.yml`, `sidekiq-low.yml`, etc.) ou `command: ["sidekiq", "-q", "critical", "-q", "high", ...]`.
- [B2] Container `cable` dedicado para ActionCable (ou sticky sessions no nginx).
- [B3] Provisionar OpenSearch (`docker-compose` service) se usar busca avançada.
- [B4] S3 como `ACTIVE_STORAGE_SERVICE=amazon` + bucket dedicado (evita perda local).
- [B5] Configurar backups do Postgres (script cron ou job sidecar).
- [B6] APM: configurar Sentry (SENTRY_DSN) ou Datadog.
- [B7] Resource limits (`mem_limit`, `cpus`) + replica count via orchestrator.
- [B8] Escalar Rails web horizontalmente (WEB_CONCURRENCY=2+).

### Fase C — Observabilidade e operação
- [C1] Structured JSON logging já existe (Sidekiq) — aplicar também a Rails logs (lograge via env ou default).
- [C2] Metrics endpoint para Prometheus (gem `prometheus_exporter` + sidecar) — **não instalada**, opcional.
- [C3] Sistema de alertas (uptime, Sidekiq queue depth).
- [C4] Processo de release: migration job + rollback strategy.

---

## 5. Riscos se for para produção sem ajustes

| Item | Risco | Severidade |
|------|-------|-----------|
| Sem TLS | Cookies inseguros, falha de widget HTTPS, dados na internet | CRÍTICO |
| Redis/Postgres sem senha | DB acessível/aberto | CRÍTICO |
| Migrations não rodam no deploy | App sobe com schema desatualizado → exceptions | CRÍTICO |
| Storage local sem backup | Perda de anexos/conversas | ALTO |
| CSP/CORS abertos | XSS/abuse de API pública | ALTO |
| 2FA sem encryption keys | MFA desativado (senha em plaintext) | ALTO |
| Sem rate limit no proxy | DDoS direto | MÉDIO |
| Sidekiq único sem priorização | Jobs críticos travados por jobs pesados | MÉDIO |
| ActionCable single-Puma | WebSocket cai ao reiniciar web | MÉDIO |

---

## 6. Decisão: CE vs EE
- Projeto raiz NÃO tem `CW_EDITION` env (é injetado no build da CI).
- Se usar Enterprise: imagem `chatwoot/chatwoot:latest` (sem `-ce`). Se CE: usar `--ce`.
- Enterprise adiciona: chamadas, relatórios avançados, SAML/SSO, etc.
- **Stack proposta pelo usuário**: Supabase (PostgreSQL gerenciado, nada de container DB) + Redis gerenciado (Upstash, serverless) + TypeScript (tsconfig/types adicionados; migração full dos componentes fora de escopo).

---

## 7. Análise Supabase (sem DB na stack) + Redis gerenciado + TypeScript

