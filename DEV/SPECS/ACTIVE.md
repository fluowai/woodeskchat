# Rebrand Woodesk — fases BR

> Status: Fase 0 de execução do roadmap em andamento (S0.1–S0.3 concluídas; S0.4 exige Docker/Ruby) · Últ. atualização: 2026-09-10 · Contrato da etapa.

## Objetivo
Transformar o produto em **Woodesk** para o mercado brasileiro: rebrand completo (apresentação + estrutura técnica), tradução PT-BR natural, fundação BR e execução do roadmap do documento final.

## Escopo (referência: `DEV/WOODESK_DOCUMENTO_FINAL.md`)
1. **Rebrand Woodesk técnico completo** — `Woodesk*`, `lib/woodesk_*.rb`, deployment (systemd/nginx/circleci), Docker (`woodesk/chat`), globals widget/SDK (`$woodesk`, `WOODESK_INBOX_TOKEN`). Exceções: colunas `chatwoot_record_type/id` (+ migration de guarda), deps `@chatwoot/*`, LICENSE/docs/.github.
2. **Tradução PT-BR natural** — auditada/completa (dashboard, widget, survey, backend).
3. **Stack de deploy BR** — `docker-compose.woodesk.yaml` (Portainer, PostgreSQL externo, Caddy TLS) + `.env.woodesk.example`.
4. **Fase 0 (em execução)**:
   - S0.1 Docker/Portainer: serviço `caddy` (80/443, healthcheck, volumes), porta externa do `rails` removida, env CADDY_* — **arquivos prontos**.
   - S0.2 Segurança: CSP só via Rails (Caddyfile limpo), `FORCE_SSL=false` no stack (Caddy termina TLS; healthcheck interno OK) — **concluída**.
   - S0.3 Formatação BR: `brLocale.js` (novo), `timeHelper.js`/`DateHelper.js` em pt-BR, `pt_BR.yml` (number/currency/date/time/distance_in_words), CSVs BR (`I18n.l format: :short`), specs atualizadas e verificadas contra date-fns 2.21.1 — **concluída**.
   - S0.4 Smoke checklist (login, widget `$woodesk`, conversa web, WhatsApp Cloud, relatórios, Captain, portal, `/api`, `/cable`) — **pronto para rodar** via `docker-compose.smoke.yaml` (leve: rails+migrate+redis+postgres local, sem sidekiq/caddy) em host com Docker; aguardando execução.

## Critérios de aceite
- [x] Rebrand em app/lib/config/docker/enterprise/db/spec/swagger/deployment/.circleci (grep limpo fora de exclusions).
- [x] Globals `$woodesk`/`woodeskConfig`/`woodeskSettings`/`woodeskSDK`/`WOODESK_INBOX_TOKEN`; `pnpm build:sdk` OK.
- [x] Renames `git mv` (19) sem quebra (Zeitwerk/gem/require).
- [x] `chatwoot_record_*` restaurados + migration `20260909000001` de guarda.
- [x] JSON de i18n/swagger/package parseiam.
- [x] Backend/dashboard/widget/survey pt_BR com 0 chaves faltando.
- [x] YAML `pt_BR.yml` e `docker-compose.woodesk.yaml` parseiam (js-yaml).
- [x] Specs `timeHelper`/`DateHelper` atualizadas; expectativas conferidas com date-fns@2.21.1 real (temp); bugs de import/locale/apostrofos corrigidos.
- [ ] (pendente, outro host) `docker compose config`, build imagem, `db:woodesk_prepare` real, rubocop/rspec/jest do repo, smoke S0.4.

## Pendências/decisões para aprovação do maestro
1. ~~Restaurar identificadores técnicos~~ — **resolvido**: rebrand total aprovado.
2. Fase 1 do roadmap (próxima após smoke S0.4): PIX + WhatsApp Cloud onboarding na imagem/stack.
3. Validar stack Portainer (`docker-compose.woodesk.yaml` + `.env.woodesk`) em ambiente com Docker — desbloqueia build e S0.4.
4. 8 decisões do documento final (multi-tenant, EE vs CE, plano gratuito, etc.).