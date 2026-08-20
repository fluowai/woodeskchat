# Handoff

## Estado atual (sessão 13/08/2026)
Análise + **Fase A implementada**. Stack: Supabase (PostgreSQL gerenciado) + Upstash Redis (gerenciado) + TypeScript no build. **Nenhum container DB/Redis na stack.**

## Arquivos criados/modificados
- `docker-compose.supabase.yaml` (novo) — caddy(rails/rails2/sidekiq-crit/sidekiq-low/migrate; sem postgres/redis.
- `docker/caddy/Caddyfile` (novo) — TLS ACME + reverse proxy + WS /cable + headers.
- `.env.supabase.example` (novo) — template produção (pooler, Upstash, keys, S3, SMTP, Caddy).
- `docker/entrypoints/rails.prod.sh` (novo) — entrypoint alternativo (migration idempotente).
- `config/initializers/content_security_policy.rb` — CSP ativada.
- `config/initializers/cors.rb` — públicos `*` / API restrito a FRONTEND_URL.
- `config/initializers/trusted_proxies.rb` (novo) — RFC1918 para X-Forwarded-.*.
- `tsconfig.json` (novo) + `typescript` em package.json devDeps.

## Decisões
- **TLS**: Caddy 2 (auto Let'sEncrypt). Alt: nginx + certbot (config existente em `deployment/nginx_chatwoot.conf`).
- **Redis**: Upstash (serverless). É hard dependency — Supabase não oferece. Não há como eliminar Redis sem re-escrever Sidekiq/Cable/Rack::Attack.
- **Migrations**: padrão `migrate` one-shot service (compatível com imagem oficial `chatwoot/chatwoot:latest`); entrypoint `rails.prod.sh` como alternativa para builds locais.
- **TypeScript**: tsconfig `allowJs:true` → produção compila TS sem tocar o JS existente. Migração full dos componentes fora de escopo.

## Validação real (não executada aqui)
- Ambiente local carece de docker/pnpm/ruby/node neste host. Validado estruturalmente: JSON (tsconfig/package) via node OK; balanceamento do/end ruby OK; YAML revisado visualmente.
- Pendente: `docker compose -f docker-compose.supabase.yaml config` (valida YAML), `pnpm install` (lockfile), `docker compose up` smoke + `GET /health` + Sidekiq Redis ping + migração contra Supabase sandbox.
- Pendente: validar CSP não quebra o dashboard (inline scripts podem precisar de `unsafe-hashes` ou nonce em templates).

## Branch / commit
- Nenhum commit. Nenhum push. Worktree default (sem branch dedicada).
- Próxima: criar branch `feat/prod-supabase-ts`? (não fazer sem autorização).
