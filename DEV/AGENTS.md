# DEV Overview

## Contexto do Projeto
- **Produto**: Chatwoot v4.16.2 — plataforma de suporte ao cliente / conversas em vários canais (web, mobile, WhatsApp, Telegram, Facebook, etc).
- **Stack principal**: Ruby 3.4.4 / Rails 7.2.3.1 + Vite (Vue 3 / TS frontend) + PostgreSQL 16 (com pgvector) + Redis 7.
- **Arquitetura de processos**: Rails (Puma web) + Sidekiq (background jobs) + ActionCable (WebSocket via Redis adapter). Vite compila assets no build time (não roda no container de produção).

## Stack Docker existente + novos requisitos (Supabase/TS)

- `docker/Dockerfile`: multi-stage build (pre-builder + final), Alpine, assets pré-compilados em `RAILS_ENV=production`. Publicado como `chatwoot/chatwoot:latest`.
- `docker-compose.yaml`: **desenvolvimento** — rails, sidekiq, vite, postgres, redis, mailhog. Volumes bind-mount para hot-reload.
- `docker-compose.production.yaml`: **produção mínima** — rails, sidekiq, postgres, redis. Usa imagem pública `chatwoot/chatwoot:latest`. Ports bound to `127.0.0.1`.
- `deployment/nginx_chatwoot.conf`: config de proxy reverso manual (Heroku/Ubuntu style), NÃO containerizada.
- `Procfile`: release/web/worker (Heroku-style). `release` roda `rails db:chatwoot_prepare`.

## Novos requisitos do usuário (Supabase + TypeScript)

- **Frontend**: JS/Vue 3 puro (app/javascript). NENHUM `.ts` em runtime; o único `tsconfig.json`
  está em `tests/playwright`. Vite/Vue já compilam `lang="ts"` via esbuild, mas o pipeline
  não está habilitado (sem `tsconfig.json` de app, sem `typescript` na deps).
- **Banco de dados**: Chatwoot depende de PG + extensões `pg_stat_statements`, `pg_trgm`,
  `pgcrypto`, `plpgsql`, **`vector` (pgvector)** (usado por `neighbor`/`pgvector` para embeddings).
  Ver `db/schema.rb:15-19`. Todas suportadas pelo Supabase.
- **Redis**: DEPENDÊNCIA CRÍTICA — Sidekiq, ActionCable, Rack::Attack ($velma), cache ($alfred).
  Sem Redis: sem background jobs, sem WebSocket, rate-limit cai. Supabase NÃO oferece Redis.
- `.nvmrc`: Node 24.13.0; `engines.node=24.x`.
- Nenhum serviço (k8s/helm/capistrano) — deploy é apenas Docker Compose.

## Status do DEV/
- (Este diretório foi criado para esta task.)
- Arquivos ativos relevantes: `ANALISE_PRODUCAO_DOCKER.md`, `WORKLOG.md`, `HANDOFF.md`.
