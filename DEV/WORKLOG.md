# Worklog

## 2026-09-10 — Fase 0 — smoke local leve (preparação)
- Criado `docker-compose.smoke.yaml` (descartável): rails (1 réplica, threads baixas) + migrate + redis + postgres local `pgvector/pgvector:pg16` (sem sidekiq/caddy/banco externo), env inline com valores de dev (zero-config). `db:woodesk_prepare` cuida de schema+seed em DB novo; healthchecks via `pg_isready` e `/health`. YAML validado (js-yaml).

## 2026-09-10 — Fase 0 (S0.1–S0.3) — execução aprovada ("sim para tudo")
- Decisões do maestro: (1) CSP removida do Caddy (só Rails emite, nonce-aware); (2) Redis local no compose para MVP; (3) ordem S0.2+S0.3 (sem Docker) → S0.1+S0.4.
- **S0.2 Segurança**: `docker/caddy/Caddyfile` sem `Content-Security-Policy` (mantidos HSTS/X-Content-Type-Options/X-Frame-Options/Referrer-Policy). `.env.woodesk.example` com bloco Caddy (`CADDY_DOMAIN/EMAIL/RAILS_HOST/PORT`), secrets reais gerados via `node crypto` (SECRET_KEY_BASE + 3 chaves AR encryption), comentário Redis corrigido.
- **S0.1 Docker**: `docker-compose.woodesk.yaml` agora tem serviço `caddy` (ports 80/443, healthcheck, volumes caddy_data/caddy_config, depends_on rails healthy); porta externa do `rails` removida (só interno); `.env.woodesk.example` recebeu CADDY_*.
- **FORCE_SSL** no `.env.woodesk.example` virou `false` (Caddy termina TLS; `force_ssl=true` quebraria o healthcheck interno `/health` em http://127.0.0.1:3000 — cookies seguros seguem via `X-Forwarded-Proto` + `trusted_proxies`).
- **S0.3 Formatação BR (frontend)**: novo `app/javascript/shared/helpers/brLocale.js` (locale date-fns ptBR **default export**, imports de `format` corrigidos, `formatNumberBR/CurrencyBR/PercentBR/ForCSV`; bug do `formatPercentBR` corrigido); `timeHelper.js` migrado p/ BR (messageStamp/messageTimestamp/relativeDayTimestamp/dynamicTime/dateFormat) e `shortTimestamp` reescrito suportando EN (legacy) + PT (há/cerca de/mais de/quase, atrás); `DateHelper.js` default `dd/MM/yyyy` com locale ptBR.
- Bugs encontrados e corrigidos via verificação real com date-fns@2.21.1 isolado: named import `{ ptBR }` → `undefined` (locale é **default export** no subpath); `$1` retornava literal; plural `months` e prefixos `há cerca de`/`há quase`/`há menos de` mal tratados.
- **S0.3 Formatação BR (backend/CSV)**: `pt_BR.yml` ganhou blocos `date/time/number/currency/percentage/human/datetime.distance_in_words/support/i18n.transliterate`; CSV de CSAT (`api/v1/.../download.csv.erb`) e 5 reports V2 (`agents/inboxes/labels/teams/conversations_summary.csv.erb`) formatam datas via `I18n.l(..., format: :short)` (dd/MM).
- **Specs atualizadas**: `timeHelper.spec.js` (expectativas pt-BR verificadas contra date-fns 2.21.1: '15:35', '10/02/2021', '10 de fevereiro de 2021 às 15:35', 'há cerca de 2 anos', EN+PT shortTimestamp) e `DateHelper.spec.js` (default '14/12/2019').
- Verificação: YAML de `pt_BR.yml` e `docker-compose.woodesk.yaml` parseados (js-yaml); date-fns outputs conferidos por script isolado (temp `opencode/dfcheck`); Caddyfile confere com env CADDY_*. Build Docker/rspec real continuam bloqueados (não há docker/ruby neste host).

## 2026-09-09 — Etapa Rebrand Woodesk (técnico completo) — EXECUTADO
- Bulk-rebrand `chatwoot→woodesk` herdado (1735→1743 arquivos) **validado e completado**; decisão do maestro: rebrand TOTAL (descartado o reset recomendado na análise anterior). Sem commit.
- Renames (`git mv`): `lib/chatwoot_{app,hub,exception_tracker,captcha,markdown_renderer}.rb` → `woodesk_*`; `enterprise/lib/enterprise/chatwoot_hub.rb`; specs correspondentes; `.circleci/setup_chatwoot.sql`; `deployment/{chatwoot→woodesk, nginx_chatwoot.conf→nginx_woodesk.conf, chatwoot-web/worker*.service/.target → woodesk-*}`.
- Fixups: `package.json` name → `@woodesk/chat` (deps `@chatwoot/*` mantidas); Hub URL via `WOODESK_HUB_URL` (`lib/woodesk_hub.rb` + enterprise); restauro `chatwoot_record_*` (migrations `20260702000001|2` + schema.rb + data_import models/services/specs + migration de guarda `20260909000001`); mailer default `Woodesk <accounts@woodesk.com>` (override `MAILER_SENDER_EMAIL`); bundle IDs `com.woodesk.app` conferidos.
- Docker → imagem `woodesk/chat:latest` em `docker-compose.production.yaml`, `docker-compose.supabase.yaml`, `.env.supabase.example`, comentário `docker/entrypoints/rails.prod.sh`. Criados `docker-compose.woodesk.yaml` (Portainer; PostgreSQL externo) + `.env.woodesk.example`.
- Limpeza de leftovers: `lib/tasks/dev/variant_toggle.rake` (namespace `:woodesk`, strings), `ChatWoot`→`Woodesk` em `pt/generalSettings.json` + `ru/conversation.json`; `.env.example` documenta `WOODESK_HUB_URL`.
- Verificação: JSON (todos os `.json` alterados parseiam; `devcontainer.json` é JSONC de propósito), `pnpm build:sdk` ✓ 2.15s (sdk.js 29.14 kB; `$woodesk`×50, 0 `chatwoot`), greps de leftovers limpos exceto exclusions (deps, LICENSE, docs/README/.github, `chatwootbr/`, `ding.mp3`).
- Não verificável neste host (sem docker/ruby): compose config/build, `db:woodesk_prepare` real, rubocop/rspec.

## 2026-09-10 — Documento Final Woodesk (14 seções + Roadmap)
- Criado `DEV/WOODESK_DOCUMENTO_FINAL.md` com FASE 3 (classificação de 126 funcionalidades: 78 manter, 26 adaptar, 8 melhorar, 3 remover, 11 novas), FASE 4A (adaptação Brasil: CPF/CNPJ, telefone, WhatsApp, LGPD, feriados, formatação), arquitetura de 7 módulos novos (CRM, Funil, Agenda, PIX, White Label, IA, Automações), e roadmap com 20 sprints / 44 semanas.
- Classificação: 62% manter, 21% adaptar, 6% melhorar, 0% refazer, 2% remover, 9% novas.
- Módulos novos: Deal/Pipeline/Stage (CRM), Activity (Agenda), Payment (PIX), Branding config (White Label), ConsentRecord + Anonimização (LGPD).
- Roadmap: 6 fases (Fundação → PIX/WhatsApp → CRM/Funil → Agenda → IA/Automações → White Label → LGPD/Escala).
- 8 decisões pendentes documentadas para aprovação do maestro.

## 2026-09-09 — Etapa 1 Woodesk: auditoria pt_BR + análise de lacunas BR
- Diagnóstico do working tree: rebrand automático `chatwoot→woodesk` não-commitado em 1735 arquivos/5786 linhas, com **renomes técnicos** (module Chatwoot→Woodesk, classes Woodesk*, colunas `data_import_*` → `woodesk_record_*` em migrations já aplicadas, `WOODESK_INBOX_TOKEN`, URLs falsas). Base HEAD ("WooTalk") íntegra: `module Chatwoot`, `default_locale :pt_BR`, fuso São Paulo.
- Auditoria de tradução (Node + PyYAML):
  - Dashboard pt_BR: 48 arquivos, **0 chaves faltando**; widget/survey: **0**; backend `pt_BR.yml`: **0 faltando / 0 extras** após correções.
  - Qualidade: termos do glossário já naturais (Atendente, Caixa de Entrada, Etiquetas...); encoding UTF-8 OK.
- Correções aplicadas: `errors.saml.multi_account_invitation_not_allowed` + `super_admin.push_diagnostics.subscriptions_deleted {one,other}` em `config/locales/pt_BR.yml`; `REMOVE_ASSIGNED_AGENT` → "Remover atendente atribuído" em `automation.json` e `macros.json`.
- Criado `DEV/ANALISE_MERCADO_BRASIL.md` (lacunas/oportunidades BR, priorizadas P0→P2, mapeadas a módulos existentes) e `DEV/SPECS/ACTIVE.md` (contrato da etapa 1).
- SEM commit/push. Working tree do rebrand intacto (não alterado).

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
