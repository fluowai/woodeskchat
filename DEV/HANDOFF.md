# Handoff

## Estado atual (sessão 10/09/2026) — Fase 0 em execução (S0.1–S0.3 concluídas, S0.4 pendente)
- **Documento completo criado**: `DEV/WOODESK_DOCUMENTO_FINAL.md` — 14 seções, roadmap 20 sprints/44 semanas.
- **S0.1 Docker concluída (arquivos, sem build)**: `docker-compose.woodesk.yaml` com serviço `caddy` (80/443, healthcheck, volumes); porta externa do `rails` removida; `.env.woodesk.example` com CADDY_*.
- **S0.2 Segurança concluída**: CSP removida do Caddyfile; `FORCE_SSL=false` (Caddy termina TLS; healthcheck interno 200; cookies seguros via X-Forwarded-Proto+trusted_proxies).
- **S0.3 Formatação BR concluída (frontend+backend+specs)**: `brLocale.js` (novo), `timeHelper.js`, `DateHelper.js`, `pt_BR.yml` (blocos number/date/time/distance_in_words), CSVs (CSAT+5 reports V2) com `I18n.l`; specs `timeHelper`/`DateHelper` atualizadas e expectativas **verificadas contra date-fns 2.21.1 real**. Detalhes/bugs no `WORKLOG.md`.
- **S0.4 em preparo**: novo `docker-compose.smoke.yaml` (leve, descartável) permite rodar o smoke completo com só Docker Desktop — criado e validado (YAML). Falta só executar: `docker compose -f docker-compose.smoke.yaml up -d --build`.
- **Pendente do documento**: 8 decisões do maestro (multi-tenant, EE vs CE, plano gratuito, etc.) + validação docker/ruby do stack.

## Estado anterior (sessão 09/09/2026) — Rebrand Woodesk (técnico completo)
- **Decisão do maestro**: rebrand TOTAL chatwoot→woodesk, incluindo estrutura técnica (classes, libs, deployment, Docker). A recomendação anterior de `git reset --hard` (preservar estrutura) foi **descartada**.
- Rework executado em `feat/woodesk-rebrand` (~1743 arquivos alterados, SEM commit).
- Tradução pt_BR mantida completa (etapa anterior); `DEV/ANALISE_MERCADO_BRASIL.md` segue como lacunas BR.

## Decisões desta sessão
- **CSP**: removida do Caddy (ineficaz sem nonce); Rails segue como fonte única (`content_security_policy.rb`), headers de transporte no Caddy.
- **Redis**: manter container local no compose para MVP; migrar p/ Upstash depois (README/comment no compose).
- **Ordem de execução (aprovada "sim para tudo")**: S0.2 + S0.3 (sem Docker) primeiro; S0.1 (arquivos) + S0.4 (smoke, exige Docker) depois.
- **FORCE_SSL=false** no stack Portainer (Caddy termina TLS; `force_ssl=true` quebraria healthcheck Rails interno; cookies seguros via `X-Forwarded-Proto` + `trusted_proxies` RFC1918).
- **date-fns**: locale ptBR importado como **default export** do subpath `date-fns/locale/pt-BR` (em v2.21.1 o named `{ ptBR }` é `undefined`).
- Mailer default: `'Woodesk <accounts@woodesk.com>'` mantido (sobrescrevível via `MAILER_SENDER_EMAIL`).
- Imagem Docker: **`woodesk/chat`** (`wooodesk` do briefing era typo).
- Colunas `chatwoot_record_type/id` (data imports) **mantidas** com esse nome + migration de guarda `20260909000001_rename_woodesk_record_columns_to_chatwoot.rb` para bancos que tenham rodado o nome `woodesk_record_*`.
- Hub URL sobrescrevível via **`WOODESK_HUB_URL`** (default https://hub.2.woodesk.com).
- Widget/SDK globals **renomeados** (`$woodesk`, `woodeskConfig`, `woodeskSettings`, `woodeskSDK`, `WOODESK_INBOX_TOKEN`) — contrato público atualizado.
- Deployment → nomenclatura `woodesk` (systemd `*.service/.target`, nginx, sudoers) e `.circleci/setup_woodesk.sql`.

## Exclusions intencionais (ainda contêm "chatwoot")
- Deps `@chatwoot/*` (ninja-keys, prosemirror-schema, utils) + comentários de imports.
- `enterprise/LICENSE` (licença legal inalterada), `README.md`, `docs/`, `tests/playwright/README.md`, `.github/*` (workflows, ISSUE_TEMPLATE, FUNDING), `chatwootbr/`, binário `app/javascript/shared/assets/audio/ding.mp3`.
- URLs placeholder `github.com/woodesk/woodesk` e imagem codespace `ghcr.io/woodesk/woodesk_codespace` (comentários dev).

## Novos artefatos
- `docker-compose.woodesk.yaml` (Portainer) — stack caddy/rails/sidekiq/migrate/redis; **PostgreSQL externo**.
- `app/javascript/shared/helpers/brLocale.js` (novo) — locale/formatos BR centralizados (date-fns + Intl).
- `.env.woodesk.example` — template produção (secrets, SMTP, S3, pooler, REDIS_URL, WOODESK_HUB_URL, bloco Caddy).
- `db/migrate/20260909000001_rename_woodesk_record_columns_to_chatwoot.rb` (novo, guardado com `column_exists?`).
- `.env.example`: seção `WOODESK_HUB_URL`/hub adicionada.

## Validação executada neste host (Windows, sem docker/ruby)
- Todos os `.json` alterados/criados parseiam (exceto `devcontainer.json`, JSONC de propósito).
- `pnpm build:sdk` ✅ → `public/packs/js/sdk.js` (29.14 kB); contém `$woodesk`×50, `woodeskSDK`, `woodeskSettings`; **0** `chatwoot`.
- Greps: nenhum `chatwoot` em app/lib/config/docker/enterprise/db/spec/swagger/deployment/.circleci fora das exclusions; variante `ChatWoot` removida; `variant_toggle.rake` limpo.
- Renames confirmados: 19 (lib, enterprise/lib, spec, deployment, .circleci setar sql).

## Pendente (requer Docker/Ruby — outro host ou CI)
- `docker compose -f docker-compose.woodesk.yaml config` (validação real do YAML + env).
- `docker build -f docker/Dockerfile` (imagem `woodesk/chat`).
- `bundle exec rails db:woodesk_prepare` contra Postgres real; `bundle exec rubocop`; rspecs dos arquivos renomeados.
- Smoke: subir stack, acessar `/health`, fazer login superadmin, verificar widget com globals woodesk.

## Branch / commit
- Branch `feat/woodesk-rebrand` (existia). Nenhum commit feito — rebrand completo aguarda validação docker/ruby e revisão do maestro.
- Fase A (Supabase + TS) documentada em `WORKLOG.md`/`ANALISE_PRODUCAO_DOCKER.md` permanece vigente no working tree.