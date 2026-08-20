# Auditoria Inicial — Chatwoot CE v4.16.2 → ChatwootBR (React/TS/NestJS/Prisma/Supabase)

> Escopo: reconstrução do código-fonte original **sem alterações** (leitura somente: `glob`/`grep`/`read`).
> Versão origem: **4.16.2** (conf. `VERSION_CW:1`, `config/app.yml:2`, `package.json:3`).
> Stack destino: **React + TypeScript + NestJS + Prisma + Supabase** (PostgreSQL gerenciado, Auth, Realtime, Storage).
> Toda evidência abaixo usa a notação `caminho:linha`.

---

## 1. Stack

| Camada | Atual (CE 4.16.2) | Origem |
|---|---|---|
| Backend | Ruby 3.4.4 + Rails 7.2.3.1 (`Gemfile:3-8`) | monolite Rails, API + Server-Side Render |
| Frontend | Vue 3.5 + Vite 6.4 + Tailwind 3.4 (`package.json:99,146,148`) | SPA dashboard + widget + portal + SDK |
| DB | PostgreSQL 15 (extensões) (`config/database.yml:2`, `db/schema.rb:13-19`) | `pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql`, `vector` |
| Cache/Fila | Redis 5/6 + Sidekiq 7.3.10 (`Gemfile:67,137`, `config/sidekiq.yml:1`) | 2 pools: Alfred (presença/email) + Velma (rate-limit) |
| Busca | OpenSearch opcional via `searchkick`/`opensearch-ruby` (`Gemfile:72-73`) | `Message.searchkick` (`app/models/message.rb:42`) |
| Realtime | ActionCable adapter Redis (`config/cable.yml:2-7`, `app/channels/room_channel.rb:1-59`) | broadcast por `pubsub_token` |
| Upload | ActiveStorage → S3 / GCS / Azure / local (`Gemfile:56-59`, `config/storage.yml:1-45`) | 4 serviços + `image_processing` |
| AI | `ruby-openai`, `ruby_llm`, `ai-agents`, `pgvector` (`Gemfile:196-213`) | embeddings `vector(1536)` (`db/schema.rb:196,467`) |
| Auth | Devise 4, devise_token_auth, devise-two-factor, JWT, Omniauth (`Gemfile:85-94`) | tokens JSON + MFA/2FA com `otp_secret` (`app/models/user.rb:22-23`) |
| Authz | Pundit policies (`Gemfile:94`) | `app/policies/application_policy.rb:1-59` |
| Task runner | Rake + `lib/tasks/` (25 rakefiles) (`lib/tasks/` lista) | sidekiq-cron (`config/schedule.yml`) |
| APM/Monitoring | Datadog, Elastic APM, NewRelic, Sentry, Scout (`Gemfile:127-134`) | condicional por ENV (`config/application.rb:15-28`) |
| I18n | `rails-i18n`, Crowdin (`crowdin.yml:1`) | `app/javascript/*/i18n`, `config/locales` |

**Destino proposto:** Node 22 + NestJS 10 (TypeScript) + Prisma 6 (PostgreSQL/Supabase) + React 3.5 (Vite/Tailwind) + BullMQ (Upstash) + Supabase Realtime (Realtime Server/WebSocket) + Supabase Auth (JWT/MFA) + Supabase Storage (S3).

---

## 2. Estrutura do repositório

```
chatwoot/                          (repo raiz)
  app/                             Rails app
    controllers/{api/v1,api/v2,platform,public,widget}
    models/{*.rb}                  57 models (lista em app/models)
    services/                      244 services (33 subdirs)
    jobs/                          98 jobs (18 pastas aninhadas)
    channels/{room_channel,connection}
    listeners/                     12 listeners (eventos → broadcast)
    actions/                       ações de domínio (contact_merge_action.rb:59)
  config/                          46 arquivos (routes.rb:1192 lin, cable.yml, storage.yml, database.yml:31, sidekiq.yml:39, app.yml)
  db/schema.rb                     1492 lin / 97 tabelas / 5 extensões / 70 colunas jsonb / 6 colunas vector
  db/migrate/                      174 migrations (até 20260807101420)
  enterprise/                      overlay EE — 382 arquivos .rb (models 49, controllers 59, services 142, policies 16, listeners, jobs, views, config/premium_features.yml)
  lib/                             9 subdirs + 17 arquivos (tasks 25 rake, events/types.rb, redis/{config,keys,lock_manager}.rb, integrations/, captain/, webhooks/)
  app/javascript/                  frontend monorepo (8 entrypoints: dashboard.js, widget.js, portal.js, sdk.js, superadmin.js, survey.js, v3app.js, superadmin_pages.js)
    dashboard/                     SPA principal (Vue3 + Vite)
      api/                         40+ arquivos de API REST
      components/                  ~90 pastas de componentes
      modules/                     Vuex modules (conversas, contatos, etc.)
      channels/                    WebSocket client
      stores/                      Pinia stores (migrado de Vuex)
      routes/                      Vue Router
    widget/                        chatbot embarcável (App.vue, router.js)
    sdk/                           SDK público (build dedicado, limit 40KB `size-limit`)
    portal/                        help-center público
    superadmin/                    admin de instância
  public/                          assets estáticos + packs
  docker/                          Docker + docker-compose (incl. .supabase.yaml:5307 lin)
  Procfile                         3 processos: release, web (rails s), worker (sidekiq) (Procfile:1-3)
  Makefile                         targets de dev
  AGENTS.md                        diretrizes do projeto
```

**Múltiplos apps no frontend** — dashboard/admin/widget/portal/sdk têm configs Vite separadas (`vite.config.ts`, `vite.lib.config.ts`).

---

## 3. Arquitetura atual

- **Monolito Rails API+vISTAS** — um servidor Rails atende API REST (namespaces `/api/v1`, `/api/v2`, `/platform/api/v1`, `/public/api/v1`, `/widget`) e server-side render do dashboard (`DashboardController#index` SPA fallback, `config/routes.rb:14-39`).
- **Camada de entrada**: Controllers → Policies Pundit (`include Pundit::Authorization`, `application_controller.rb:4`) → Services (DDD via `app/services/`) → Jobs (Sidekiq) → Models (AR). Camada de integração externa em `lib/integrations/{facebook,slack,line,twitter,...}`.
- **Overlay Enterprise** — `enterprise/` é injetado via `prepend_mod_with`/`include_mod_with` (`lib/captain/base_task_service.rb:19`, `lib/captain/reply_suggestion_service.rb:46`, `lib/chatwoot_hub.rb:133`) e `config/application.rb:43-53` adiciona paths ao eager_load. `ChatwootApp.enterprise?` detecta presença do diretório (`lib/chatwoot_app.rb:21-24`).
- **Eventos/Wisper** — Dispatcher singleton (`lib/chatwoot_hub.rb`) publica eventos em `lib/events/types.rb` (25 eventos: conversas, mensagens, contatos, notificações). 12 listeners (`app/listeners/`) reagem (ex.: `action_cable_listener.rb:1-59` faz broadcast ActionCable).
- **Multi-tenancy** — `account_id` presente na maioria das tabelas; escopo obrigatório em queries (ex.: `Conversation` index `account_id`-scoped em 9 indexes). SuperAdmin herda de User (`app/models/super_admin.rb:47`).
- **Publicação de presença** — `RoomChannel` (ActionCable) com `pubsub_token` (por User/ContactInbox) (`app/channels/room_channel.rb:12-48`).

---

## 4. Models

- **57 models** em `app/models/` (lista: `account.rb`, `user.rb`, `conversation.rb`, `message.rb`, `contact.rb`, `inbox.rb`, `account_user.rb`, `note.rb`, `notification.rb`, `label.rb`, `team.rb`, `article.rb`, `portal.rb`, `macro.rb`, `automation_rule.rb`, `campaign.rb`, `canned_response.rb`, `data_import.rb`, `webhook.rb`, `working_hour.rb`, ...). ARQUIVOS incluem concerns: `application_record.rb` (base).
- **Herança STI**: `SuperAdmin < User` (mesma tabela `users`), `AgentBot < ApplicationRecord`, `Channel*` herança de `Channel::Base` (`app/models/channel/base.rb`).
- **Enums**: `Account.status` (active/suspended), `Conversation.status` (open/pending/resolved/...), `Message.message_type`/`content_type`/`status`, `Contact.contact_type`, `Notification.notification_type`, `AgentBot.bot_type` (webhook).
- **Polymorphic**: `Message.sender_type/sender_id`, `Attachment.record_type/record_id`, `Notification.primary_actor/secondary_actor`, `Tagging.taggable`, `PlatformAppPermissible.permissible`.
- **Bitflags**: `accounts.feature_flags` (FlagShihTzu, bigint), `notification_settings.email_flags`/`push_flags`.
- **JSONB stores**: `accounts.settings/limits/custom_attributes/internal_attributes`, `conversations.cached_label_list`, `messages.content_attributes/experimental/...` (70 colunas jsonb no schema).
- **Embeddings (pgvector)**: `article_embeddings.embedding vector(1536)` (schema:196), `captain_faq_suggestions.embedding vector(1536)` (schema:467) — índice IVFFlat cosíneo.

---

## 5. Banco

- **PostgreSQL** único, conexões via pool (`config/database.yml:7-8` — pool baseado `RAILS_MAX_THREADS`).
- **Extensões** habilitadas (`db/schema.rb:15-19`): `pg_stat_statements`, `pg_trgm`, `pgcrypto` (gen_random_uuid usado `conversations.uuid` schema:839), `plpgsql`, `vector`.
- **97 tabelas** — schema divide em: contas/tenancy (`accounts`, `account_users`, `account_saml_settings`), conversas/mensagens (`conversations`, `messages`, `conversation_participants`, `conversation_outcomes`), contatos (`contacts`, `contact_inboxes`, `companies`, `notes`), canais/inbox (`inboxes`, 10 `channel_*` tables), IA (`captain_*`: assistants, documents, faq_suggestions, faq_observations, scenarios, custom_tools, agent_sessions, copilot_threads/messages, message_reports), notificações (`notifications`, `notification_settings`, `notification_subscriptions`), knowledge-base (`articles`, `article_embeddings`, `portals`, `categories`, `folders`), configuração (`automation_rules`, `macros`, `labels`, `canned_responses`, `campaigns`, `custom_attribute_definitions`, `custom_filters`, `sla_policies/applied_slas`, `teams`, `working_hours`, `tags/taggings`), imports (`data_imports/*`), storage (`active_storage_blobs/attachments/variant_records`, `attachments`), webhooks/integrations (`webhooks`, `integrations_hooks`, `platform_apps`).
- **Chaves estrangeiras** — poucas FK declaradas no schema (ex.: `inboxes.portal_id` → `portals.id`, schema:1127); integridade referencial é de fato por aplicação.
- **Índices** — 0 `add_index` no schema.rb (índices são inline via `t.index`), ~90+ indexes compostos e parciais (ex.: GIN em jsonb, IVFFlat em vector, índices parciais parcial `WHERE nonempty_fields`).
- **Migrações de DB** — migrations usam `hairtrigger` (Gemfile:154) para triggers em produção.

---

## 6. Migrations

- **174 migrations** (`db/migrate/`) — versão latest `20260807_101420` (`db/schema.rb:13`).
- Padrão Rails `db/migrate/*.rb`; timestamps YYYYMMDDHHMMSS.
- Tarefas rake customizadas de migração/rollup: `lib/tasks/db_enhancements.rake`, `reporting_events_rollup_timezone_setup.rake`, `assignment_v2_migration.rake`, `captain_assistant_migration.rake`, `storage_migrations.rake`.
- `schema.rb` é fonte de verdade para `db:schema:load` (`db/schema.rb:2-8`); squasher usado para compressão em dev (`Gemfile:234`).
- **Vector migrations** — `add_column ... vector` usado com `enable_extension 'vector'`.

---

## 7. Controllers

- **Estrutura**: `config/routes.rb:1192 linhas` — namespaces:
  - `api/v1/` (scoped por conta, linhas 43-47) — maior bloco: accounts, agents, conversations, contacts, inboxes, labels, notifications, automation_rules, macros, campaigns, csat, reporting, search, data_imports, etc.
  - `api/v2/` (linhas 510-548) — relatórios/summary/v2 (live_reports, year_in_review).
  - `platform/api/v1/` (linhas 577-599) — administração de instância/usuários/agent_bots/accounts.
  - `public/api/v1/` (linhas 603-624) — portais/help-center (`hc/:slug`), csat survey.
  - `widget/` (linhas 476-507) — API pública do widget (conversas/mensagens/contatos para visitantes).
  - `enterprise/api/v1/` (linhas 552-573) — checkout/subscription Stripe, webhooks stripe/firecrawl (EE only).
  - Webhooks externos (linhas 650-661) — Facebook, Twitter, LINE, Telegram, SMS, WhatsApp, Instagram, TikTok, Shopify (montados via `mount`/`post`).
  - SuperAdmin (linhas 700-743) — `devise_for :super_admins`, Sidekiq Web mount (`sidekiq/web`), CRUD de accounts/users/access_tokens/installation_configs/agent_bots/platform_apps.
  - OAuth callbacks (linhas 687-691) — microsoft/google/instagram/tiktok/notion.
- **Base controllers**: `ApplicationController < ActionController::Base` (`application_controller.rb:1`) — inclui `DeviseTokenAuth::SetUserByToken`, `Pundit`, `RequestExceptionHandler`, `SwitchLocale`, `TrackSessionActivity`; `skip_before_action :verify_authenticity_token` (API). `Api::V1::BaseController` (herda e adiciona scope de conta).
- **Enterprise controllers**: 59 controllers sob `enterprise/app/controllers/` (enterprise/`enterprise/api/v1/...`, `super_admin/`, `api/v1/accounts/captain/...`).
- ~15 controllers por namespace contam; padrões RESTful com `member`/`collection` customizados (clone, execute, import/export, filter, sync_templates...).

---

## 8. Services

- **244 services** em `app/services/` (33 subdirs: `conversations/`, `contacts/`, `messages/`, `auto_assignment/`, `automation_rules/`, `macros/`, `data_imports/`, `reporting/`, `llm_formatter/`, `onboarding/`, `inbox/`, `captain/`...).
- **Padrão**: serviços recebem hash de params, orquestram lógica de domínio e chamam `.perform`/workers; retornam resultados. `Base::SendOnChannelService` (`app/services/base/send_on_channel_service.rb:10`) abstrai envio por canal.
- Subdirs por provedor: `facebook/`, `twitter/`, `twilio/`, `whatsapp/`, `sms/`, `telegram/`, `instagram/`, `tiktok/`, `line/`, `slack/`, `google/`, `microsoft/`, `mailbox/`, `imap/`, `email/`.
- **Enterprise services**: 142 services sob `enterprise/app/services/` incl. `captain/`, `documents/`, `copilot/`, `tools/`, `onboarding/`, `billing/`, `conversations/`, `messages/`, `contacts/`, `auto_assignment/`, `macros/`, `whatsapp/`, `voice/`, `llm/`, `enterprise/accounts/`.
- Serviços de IA: `lib/captain/{base_task_service,reply_suggestion_service,summary_service,follow_up_service,label_suggestion_service,overview_summary_service,rewrite_service}.rb` — extensíveis via `prepend_mod_with`.

---

## 9. APIs

- **REST + JSON** sob `/api/v1` (e `/platform`, `/public`, `/widget`, `/super_admin`).
- **API pública do widget** (`config/routes.rb:476-507`): visitantes criam conversas/mensagens sem login, autenticados por `inbox.token` (pubsub_token).
- **Platform API** (`config/routes.rb:577-599`): login de usuário (`users#login/token`), provisionamento de contas/agentes (integração pública).
- **Portal/help-center** (`config/routes.rb:627-638`): `hc/:slug` server-side render + sitemap + busca artigos.
- **Webhook inbound** (`config/routes.rb:650-661`): Facebook Messenger (mount), Twitter, LINE, Telegram, SMS/Twilio, WhatsApp, Instagram, TikTok, Shopify.
- **Spec OpenAPI/Swagger**: `swagger/` + `SwaggerController` (`config/routes.rb:752`) gera docs a partir de serializers.

---

## 10. Jobs

- **98 jobs** (`app/jobs/` + subdirs; enterprise jobs incluídos) — todos `< ApplicationJob < ActiveJob::Base` (`app/jobs/application_job.rb:1`).
- Filas declaradas via `queue_as`: `:critical, :high, :medium, :default, :low, :mailers, :scheduled_jobs, :deferred, :purgable, :action_mailbox_routing` (config/sidekiq.yml:17-33 define 15 queues).
- Padrão: `class FooJob < ApplicationJob` com `queue_as :<name>`.
- Categorias de jobs:
  - **Conversa/mensagem**: `Conversations::ActivityMessageJob`, `ConversationReplyEmailJob`, `SendReplyJob`, `UpdateMessageStatusJob`, `Conversations::ReopenSnoozedConversationsJob`.
  - **Importação/migração**: `DataImportJob`, `DataImports::*PageJob`, `ImportJob`.
  - **Webhook/integração**: `WebhookJob`, `HookJob`, `AgentBots::WebhookJob`, `FacebookDeliveryJob`, `FacebookEventsJob`, `InstagramEventsJob`, `WhatsAppEventsJob`, `TwilioDeliveryStatusJob`, `TelegramEventsJob`, `TikTokEventsJob`, `SmsEventsJob`.
  - **IA/captain**: `AddSearchIndexesJob`, `ArticleIndexingJob` (enterprise), `ValidateOpenaiHooksJob`.
  - **Manutenção**: `ProcessStaleRedisKeysJob`, `RemoveStaleContactsJob`, `RemoveStaleNotificationsJob`, `RemoveOrphanConversationsJob`, `TriggerScheduledItemsJob`, `PeriodicAssignmentJob`, `UpdateFirstResponseTimeJob`.
- **Mutex pattern**: `MutexApplicationJob` (`app/jobs/mutex_application_job.rb:14`) com lock distribuído (Redis) para jobs concorrentes.

---

## 11. Sidekiq

- **Sidekiq 7.3.10** (`Gemfile:137`), config via `config/sidekiq.yml` (concorrência 10, timeout 25, max_retries 3).
- **15 queues** priorizadas: `critical > high > medium > default > mailers > action_mailbox_routing > low > scheduled_jobs > deferred > purgable > housekeeping > async_database_migration > bulk_reindex_low > active_storage_analysis > active_storage_purge > action_mailbox_incineration`.
- **Sidekiq-cron** (`Gemfile:139`) para jobs periódicos via `config/schedule.yml` (daily/hourly/anacron).
- **Sidekiq-alive** healthcheck (`Gemfile:141`).
- NewRelic Sidekiq metrics (`Gemfile:130`).
- Web UI montado em `/monitoring/sidekiq` autenticado SuperAdmin (`config/routes.rb:741`).
- `Procfile:3` — worker único: `bundle exec sidekiq -C config/sidekiq.yml`.

---

## 12. Redis

- **2 pools de conexão** via `config/initializers/01_redis.rb`:
  - **Alfred** (`lib/redis/alfred.rb`): size `REDIS_ALFRED_SIZE` (default 5) — presença online, round-robin, conversa por email.
  - **Velma** (`lib/redis/velma.rb`): size `REDIS_VETMA_SIZE` (default 10) — rate limiting via `rack-attack`.
- Config central: `lib/redis/config.rb:2-49` — URL de `REDIS_URL`, suporte a Sentinel (`REDIS_SENTINELS`), `ssl_params.verify_mode`, `reconnect_attempts: 2`, `timeout: 1`. Test usa `MockRedis` (`01_redis.rb:10`).
- **Keys namespaceadas** (`lib/redis/redis_keys.rb`): `CONVERSATION::%<id>d::MUTED`, `UNREAD_CONVERSATIONS::V1|V2::ACCOUNT::%<id>d::...` (built-in + filtered + assignee variants), `ROUND_ROBIN_AGENTS:%<inbox_id>d`, locks de mutex.
- ActionCable também usa Redis (`config/cable.yml:2`).
- **Upstash compatível** (`.env.supabase.example:64`): `REDIS_URL=rediss://...` já suportado.

---

## 13. ActionCable

- Adapter **Redis** (`config/cable.yml:2-7`, `config/initializers/actioncable.rb:1-15`).
- `ApplicationCable::Connection < ActionCable::Connection::Base` vazio (`app/channels/application_cable/connection.rb:1-2`) — auth via `pubsub_token` no `RoomChannel`.
- **`RoomChannel`** (`app/channels/room_channel.rb:1-59`): `subscribed` resolve `current_user` (User ou ContactInbox→Contact) e `current_account`, faz `stream_from pubsub_token` + `stream_from "account_#{id}"`, broadcast de presença (`OnlineStatusTracker`).
- Broadcasts via `ActionCableBroadcastJob` (fila `:critical`, `app/jobs/action_cable_broadcast_job.rb:1-2`).
- Eventos broadcastados definidos em `app/listeners/action_cable_listener.rb` (25 eventos de `lib/events/types.rb`): CONVERSATION_CREATED, CONVERSATION_STATUS_CHANGED, MESSAGE_CREATED, MESSAGE_UPDATED, CONTACT_CREATED, NOTIFICATION_CREATED, ASSIGNEE_CHANGED, CONVERSATION_TYPING_ON, etc.

---

## 14. ActiveStorage

- Gems: `aws-sdk-s3`, `azure-blob`, `google-cloud-storage`, `image_processing` (`Gemfile:56-59`). Previewers desativados (`application.rb:71`).
- Serviços: `amazon`(S3), `google`(GCS), `microsoft`(Azure), `s3_compatible`(MinIO/Other), `local`, `test` (`config/storage.yml:1-44`).
- Service ativo via ENV `ACTIVE_STORAGE_SERVICE` (default `local`).
- Tabelas: `active_storage_blobs` (key, filename, content_type, metadata, byte_size, checksum, service_name), `active_storage_attachments` (polymorphic record), `active_storage_variant_records` (`db/schema.rb:89-115`).
- Anexos: avatares de User/Inbox/AgentBot (`Avatarable`), mensagens/attachment (`Message` → `has_many :attachments`), article images.

---

## 15. Frontend Vue

- **8 entrypoints** (`app/javascript/entrypoints/`): `dashboard.js` (agente), `widget.js` (chat embarcado), `portal.js` (help-center), `sdk.js` (embed, limit 40KB), `superadmin.js`, `superadmin_pages.js`, `survey.js`, `v3app.js`.
- **Vue 3.5 + Composition API + `<script setup>`** (`package.json:99`); Vue Router (~4.4.5), Pinia 3 (migrado de Vuex 4), Vite 6.4.
- **State**: `app/javascript/dashboard/stores/` (Pinia) e `modules/` (Vuex legacy).
- **API client**: `app/javascript/dashboard/api/` (40+ arquivos: `ApiClient.js`, `conversations.js`, `contacts.js`, `messages.js`, `inboxes.js`, `notifications.js`, `auth.js`, enterprise `api/enterprise/`, `captain/`).
- **Realtime**: WebSocket cliente ActionCable em `app/javascript/dashboard/channels/` — reconecta com `pubsub_token` passado via query string.
- Build: Vite configurado por app (`vite.config.ts`, `vite.lib.config.ts`).

---

## 16. Design system

- **`app/javascript/dashboard/components`** (~90 pastas): componentes por domínio (Conversation, Contacts, Inbox, Settings, Editor, message, call, whatsapp, captain, copilot, table, ui, button, form, etc.).
- **`design-system`** (raiz `app/javascript/design-system/`) — tokens/componentes compartilhados entre dashboard e widget.
- **TailwindCSS 3.4** (`tailwind.config.js:156`, package.json:146) — utility classes, sem CSS customizado (`AGENTS.md` regra).
- Ícones: `@iconify-json/*` (fluent, material-symbols, lucide, ri, teenyicons, logos).
- Componentização: `components-next/` mencionado em `AGENTS.md` para message bubbles (deprecated parcial).

---

## 17. Canais (chat channels/integrations)

- **Channel model STI**: `Channel::Base` (`app/models/channel/base.rb`) → subclasses: `Channel::Api`, `Channel::Email`, `Channel::FacebookPage`, `Channel::Instagram`, `Channel::Line`, `Channel::Sms`, `Channel::Telegram`, `Channel::Tiktok`, `Channel::TwilioSms`, `Channel::TwitterProfile`, `Channel::WebWidget`, `Channel::Whatsapp` (10 tabelas `channel_*` em schema).
- **Fluxo de inbound**: `lib/integrations/incoming_message_builder.rb` (`app/services/messages/message_creator.rb`) parseia payload de cada provedor → cria `Message` → broadcast.
- Provedores suportados: Facebook Messenger (mount `Facebook::Messenger::Server`, `routes.rb:650`), WhatsApp (Twilio + API própria), LINE, Telegram, SMS/Twilio, Instagram, TikTok, Twitter/X, Microsoft, Google, Email (IMAP/SMTP), Web Widget, API channel.

---

## 18. Integrações

- **CRM/Import**: `data_imports/` com provedores Freshdesk, Intercom, Messenger, Leadsquared (`DataImports::*PageJob`).
- **Produtividade**: Slack (bot + unfurl + mensagens), Microsoft Teams/Graph, Google Workspace, Linear (`lib/integratives/linear`), Notion, Shopify (`shopify_api` Gemfile:211), Dyte (videoconferência), Cloudflare.
- **Pagamento**: Stripe (`Gemfile:170`, `config/initializers/stripe.rb`, webhook Enterprise `enterprise/webhooks/stripe_controller.rb`).
- **AI/LLM**: `lib/llm/`, `lib/captain/*`, `ruby-openai`/`ruby_llm` (`Gemfile:198-203`), `ai-agents` (`Gemfile:199`), `firecrawl-sdk` para scrapes (`Gemfile:213`).
- **Notificação push**: `fcm`, `web-push` (`Gemfile:144-145`) + `lib/vapid_service.rb`.
- **Geolocalização**: `geocoder`, `maxminddb` (`Gemfile:149-151`) + `IpLookupService`.
- Webhooks outbound via `WebhookJob` → `lib/integrations/hook_builder.rb`.

---

## 19. Auth

- **Devise 4** como base (`Gemfile:85`); **devise_token_auth** para tokens JSON (mount em `/auth`, `routes.rb:3-9`, controllers `devise_overrides/`).
- **Omniauth** providers: google-oauth2, SAML, oauth2 genérico (`Gemfile:180-188`, `config/initializers/01_omniauth.rb`-implícito, `enterprise/config/initializers/omniauth_saml.rb`).
- **2FA/MFA**: `devise-two-factor` + Active Record Encryption (`Gemfile:91`, `application.rb:74-85`) — `otp_secret`, `otp_backup_codes`, `mfa_controller` (`routes.rb:466`).
- **JWT** (`Gemfile:93`) para tokens de API.
- **Contas públicas**: signup controlado `ENABLE_ACCOUNT_SIGNUP` (`Procfiles`/env). `AccountCreator` (`lib/lib/account_creator.rb`).
- Usuário master institucional: `SuperAdmin < User` (mesma tabela).

---

## 20. Permissões

- **Pundit** (`Gemfile:94`, `application_controller.rb:4`) — policies em `app/policies/` (26 policies: account, agent_bot, article, automation_rule, campaign, canned_response, contact, conversation, inbox, label, macro, notification, portal, profile, report, sla, team, user, webhook...).
- **Enterprise policies**: 16 policies em `enterprise/app/policies/` (sla_policy, article, assistant, company, contact, conversation, csat_survey_response, custom_role, faq_suggestion, portal, report, scenario, custom_tool, account_saml_settings, agent_capacity_policy).
- `pundit_user` = `{user, account, account_user}` (`application_controller.rb:21-27`) — escopo de conta passado para policies.
- **Roles**: AccountUser.role enum (owner/agent/administrator/agent_custom_role); Enterprise: `custom_roles`, `agent_capacity_policies`, `assignment_policies`.
- Audit trail: gem `audited` (`Gemfile:182`) — tabela `audits` (`db/schema.rb:264`).

---

## 21. Community vs Enterprise

- Community (CE) é o codebase base (`app/`, `lib/`). **Enterprise (EE)** é um overlay em `enterprise/` carregado condicionalmente (`ChatwootApp.enterprise?`, `lib/chatwoot_app.rb:21-24`).
- Mecanismo de extensão:
  - **prepend**: `prepend_mod_with`/`include_mod_with` (`lib/captain/base_task_service.rb:19`, `lib/captain/reply_suggestion_service.rb:46`, `lib/chatwoot_hub.rb:133`).
  - **policies/models/controllers**: EE substitui via carregamento em `enterprise/app/` (`application.rb:42-49`, `46-47`).
  - **premium_features.yml** (`enterprise/config/premium_features.yml:1-9`): `disable_branding, audit_logs, sla, custom_roles, captain_integration, captain_integration_v2, captain_document_auto_sync, csat_review_notes, conversation_required_attributes`.
- **Diferenças técnicas**: EE adiciona `sla_policies`/`applied_slas`/`sla_events`, `custom_roles`/`custom_attribute_definitions` reforçados, `companies`/`contacts` CRM, `calls`/`whatsapp_calls`/`twilio voice`, `captain` (agentes de IA v2), `scenarios`, `copilot`, `documents`, `custom_tools`, `assignment_policies`, `audit_logs`, `branded_email_layout`, checkout Stripe (`enterprise/api/v1/accounts checkout/subscription`).
- 382 arquivos `.rb` em `enterprise/` (49 models, 59 controllers, 142 services, 16 policies).

---

## 22. Deps críticas (Ruby)

| Gem | Linha Gemfile | Uso | Risco migração |
|---|---|---|---|
| rails 7.2.3.1 | 8 | framework | alto (troca monolito→NestJS) |
| pg | 66 | driver PG | — (Supabase usa PG) |
| redis + redis-namespace | 67-68 | cache/fila/cable | alto (redis) |
| sidekiq 7.3.10 + sidekiq-cron | 137-139 | background jobs | alto (→ BullMQ) |
| devise + devise_token_auth + two-factor | 85,88,91 | auth/MFA | alto (→ Supabase Auth) |
| pundit | 94 | authz | médio (→ políticas NestJS) |
| stripe 18.0 | 170 | billing | baixo (mantém Stripe SDK) |
| searchkick/opensearch-ruby | 72-73 | busca | médio (→ Supabase PG search / Elasticsearch) |
| activerecord-import | 70 | bulk import | — (Prisma bulk) |
| hairtrigger | 154 | DB triggers | alto (DDL personalizado) |
| flag_shih_tzu | 31 | bitset feature flags | médio (→ booleano/jsonb) |
| neighbor + pgvector | 192-193 | embeddings vectorial | alto (Supabase vector nativo) |
| gem 'audited' | 182 | audit log | médio |
| openai/llm/agents | 196-213 | AI/captain | médio (→ OpenAI SDK) |
| omniauth + providers | 180-188 | SSO | baixo (Supabase SSO) |

---

## 23. Deps entre módulos (acoplamento)

- **Models → Services**: models chamam services (ex.: callbacks `after_commit` em `Conversation` disparando `ConversationReplyEmailJob`, `Mention.notify_mentioned_user` → dispatcher). Services recebem models por params (tight coupling AR).
- **Services → Jobs**: quase todos os services enfileiram jobs (`ConversationReplyEmailJob`, `WebhookJob`, `HookJob`, `UpdateMessageStatusJob`, `ActivityMessageJob`).
- **Jobs → Redis**: locks via `$alfred`/mutex (`MutexApplicationJob`). Presence via `OnlineStatusTracker` (Redis sorted sets).
- **Listeners → ActionCable**: `action_cable_listener.rb` lê eventos do dispatcher e faz `broadcast` — acoplamento forte entre eventos e WebSocket.
- **Controllers → Pundit → Models**: policies recebem scopes AR (ex.: `ConversationPolicy::Scope` queryia `account_id`).
- **Frontend → API**: client REST em `app/javascript/dashboard/api/` + WebSocket pubsub_token.
- **Enterprise → Core**: via `prepend_mod_with` e overrides em `enterprise/app/`; `routes.rb` guarda features com `if ChatwootApp.enterprise?`.

---

## 24. Risco (avaliação geral de migração)

| Dimensão | Nível | Justificativa |
|---|---|---|
| **Banco** | Médio-Alto | 97 tabelas bem normalizadas, mas 70 colunas jsonb (sem schema fixo) e 6 colunas `vector` (pgvector) precisam migrar para Supabase mantendo `vector` extension + IVFFlat. |
| **Schema AR → Prisma** | Alto | Nenhum `add_foreign_key` declarado — integridade por app; 25 eventos Wisper + ActionCable; 90+ indexes compostos/parciais a recrear. |
| **Jobs** | Alto | 98 jobs Sidekiq (15 queues) → BullMQ; locks Redis distribuídos; cron via sidekiq-cron → BullMQ scheduler. |
| **Realtime** | Alto | ActionCable custom (RoomChannel, pubsub_token, 25 eventos broadcast) → Supabase Realtime/Realtime Server; listeners precisam reescritos como triggers DB ou functions. |
| **Auth/Authz** | Alto | Devise+TokenAuth+MFA+JWT → Supabase Auth + policies; Pundit 26 policies → NestJS Guards. |
| **AI/Captain** | Médio-Alto | ruby_llm/openai embeddings, vector search, agent sessions → reescrita Node com OpenAI SDK + Supabase vector. |
| **Enterprise overlay** | Alto | 382 arquivos EE via prepend/include — decisão: migrar EE ou manter como features separadas. |
| **Frontend** | Médio | Vue3→React (8 entrypoints, Pinia, 90 pastas componentes, ActionCable client). |
| **Integrações webhook** | Médio-Alto | 10 provedores de canal inbound + 5 CRM + produtividade; payload parsing por provedor. |
| **ActiveStorage** | Baixo-Médio | 3 serviços de storage (S3/GCS/Azure) → Supabase Storage (S3 compatível). |

---

## 25. Supabase compatibilidade (Banco)

- **Compatible** — Chatwoot usa PostgreSQL nativo; Supabase é Postgres gerenciado. `.env.supabase.example` já referencia Supabase (`.env.supabase.example:41-59`).
- **Extensões Supabase** (SQL required `create extension if not exists`): `pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql` já são default/no Supabase; `vector` está disponível como extensão Supabase (`db/schema.rb:19`).
- **pgbouncer** — `DATABASE_URL` pooler usado no `.env.supabase.example:44` (pooler endpoint recomendado free tier). Compatível.
- **DDL**: migrations Rails usam `enable_extension`/`add_column`/`t.index`; Supabase aceita via `supabase db push` ou migrations SQL.
- **Incompatibilidades**: `gen_random_uuid()` (pgcrypto) funciona no Supabase; triggers `hairtrigger` e functions PL/pgSQL customizadas migrar para SQL DDL.

---

## 26. Prisma compatibilidade

- Prisma 6 suporta **PostgreSQL + extensão `pgvector`** (`postgresql` connector + preview `vector` types) — cobre as 6 colunas vector (`db/schema.rb:196,467`, `article_embeddings`, `captain_faq_suggestions`).
- **jsonb** → Prisma `Json` type (70 colunas). OK, mas perde tipagem runtime.
- **Enums PostgreSQL** (status, message_type, contact_type...) → Prisma enum (migrar `enum` PG → Prisma `enum`).
- **STI** (`SuperAdmin < User`, `Channel::Api`) → Prisma single-table + discriminador (`type` string) — mapear explicitamente.
- **Indexes compostos/parciais/GIN/IVFFlat**: Prisma schema suporta `@@index`, `@@unique`, `type: Gin`, blocos `CONCURRENTLY` parciais via SQL custom em migrations.
- **Polymorphic** (`messages.sender_type/sender_id`, `attachments.record_type`) → Prisma `relation` polimórfica não nativa; modelar como `Json` + aplicação ou tabelas de join.
- **Foreign keys não declaradas** — Prisma exige FK explícitas; backlog de criação.
- Recomendação: gerar schema Prisma via introspecção `prisma db pull` a partir do Supabase, depois refino manual.

---

## 27. Estratégia de migração do Banco

1. **Dump & introspecção**: `pg_dump` do Supabase → `prisma db pull` → `schema.prisma` inicial (97 tabelas).
2. **DDL custom**: migrar `enable_extension` (vector, pg_trgm, pgcrypto, pg_stat_statements) e triggers `hairtrigger` para SQL no `supabase/migrations`.
3. **Fase de dados**: migrar dados via `pg_dump`/`pg_restore` ou replicador (accounts → contacts → conversations → ...). Ordem de FK: `accounts`, `users`, `account_users`, `inboxes`/`channels`, `contacts`/`contact_inboxes`, `conversations`, `messages`, `attachments`, notas/notificações, captain.
4. **Validações**: verificar `null:false`, unique, partial indexes, uuid default `gen_random_uuid()`.
5. **Vector**: preservar índices IVFFlat (`opclass: :vector_cosine_ops`) em SQL migration Supabase.
6. **Backfill**: `processed_message_content`, `cached_label_list`, `display_id` contadores por conta — job backfill.

---

## 28. Supabase Storage

- Mapear `active_storage_blobs/attachments` + `attachments` para **Supabase Storage** (bucket S3-compatível).
- `ACTIVE_STORAGE_SERVICE=amazon` (`.env.supabase.example:80`) aponta S3 — mas destino é bucket Supabase Storage.
- Migração de blobs: `open` (`lib/active_storage` custom) + signed URLs.
- Avatares/mensagens → buckets `avatars`, `message-attachments`, `article-images`.
- URL pública preservada; `image_processing` variants migrado para transformações via URL do Storage ou processamento no backend.

---

## 29. Auth (destino)

- **Supabase Auth** como provider único (replaces Devise + devise_token_auth + Omniauth SAML + MFA).
- **MFA/2FA**: Supabase Auth suporta TOTP + OTP (`otp_required_for_login` users → `factor_id`).
- **Social/OAuth**: providers via Supabase Auth (Google, SAML via `enterprise/config/initializers/omniauth_saml.rb`).
- **JWT**: Supabase Auth emite JWT (`jwt` gem → `supabase-js` decodifica); claims incluem `ref` (account) → política.
- **Tokens de acesso**: `access_tokens` migrados para `supabase_functions`/política; `pubsub_token` (tokens públicos) preservado como coluna.
- **SuperAdmin**: manter via `type='SuperAdmin'` na tabela `users`, protegido por política `is_super_admin`.

---

## 30. RLS (Row-Level Security)

- **Tenant isolation**: todas as tabelas com `account_id` recebem política `auth.uid()` filtrada por `account_id`.
- **Super admin**: bypass via claim JWT `is_super_admin = true` (`app/models/user.rb`) → política `USING (true)`.
- **Tabelas críticas** (account-scoped): `conversations`, `messages`, `contacts`, `contact_inboxes`, `inboxes`, `notifications`, `notes`, `labels`, `macros`, `automation_rules`, `custom_attribute_definitions`, `reporting_events`, `articles`, `campaigns`, `canned_responses`, `custom_filters`, `portals/categories`, `applied_slas`, `csat_survey_responses`, `captain_*`.
- **Tabelas globais** (não account): `installation_configs`, `platform_apps`, `platform_banners`, `super_admins` (tipo `users` STI), `access_tokens`, `audits` — políticas restritas a `is_super_admin`.
- **Políticas base** (`app/policies/application_policy.rb:1-59` já escopo por `account_id`) → replicar como `RLS USING (account_id = account_id_jws())`.
- **RLS positivo/negativo**: testes de acesso cobrindo agente vs administrador vs contact vs outro tenant.

---

## 31. Realtime

- **ActionCable → Supabase Realtime**: Supabase Realtime (socket.io / Postgres Realtime) publica mudanças de tabela.
- **Mapear eventos** (`lib/events/types.rb:17-65`) → triggers Realtime no Postgres: `notify` em `conversation.created/updated`, `message.created`, `contact.*`, `notification.*`, `conversation.typing_on/off`, `conversation.unread_count_changed`, `conversation.assigned`, `assignee.changed`.
- `RoomChannel` (`app/channels/room_channel.rb`) assinatura `account_{id}` e `pubsub_token` → migrar para channels Supabase Realtime (`realtime.channel('account:{id}')`).
- Presence (online status) — `OnlineStatusTracker` (Redis sorted sets) → presença via Supabase Realtime Presence API ou tabela `user_status`.
- Broadcast server-side de eventos de negócio (ex.: `conversation.bot_handoff`) → triggers/edge functions.

---

## 32. Redis / BullMQ

- **Alfred + Velma** (`config/initializers/01_redis.rb:5-20`, `lib/redis/config.rb:2-49`) substituídos em dois momentos:
  - **Upstash Redis** (compatível `rediss://`, `.env.supabase.example:64`) mantém backward compat — usado pelo menos na fase 1.
  - **BullMQ** (NestJS `@nestjs/bullmq` + `ioredis`) como fila de jobs → migração dos 98 Sidekiq jobs.
- **Queues** (15): replicar em BullMQ (`queues: critical, high, medium, default, mailers, scheduled_jobs, ...`).
- **Locks/mutex** (`MutexApplicationJob` `lib/redis/lock_manager.rb`) → `@nestjs/bullmq Queue.add` com `jobId` + idempotency key.
- **Cron** (`sidekiq-cron` → `config/schedule.yml`) → BullMQ Scheduler (`@nestjs/bullmq` ScheduleModule) rodando os rakes (`trigger_hourly_scheduled_items_job`, `trigger_daily_scheduled_items_job`).
- **Presence** (Redis sorted sets `OnlineStatusTracker`) → migrar para tabela `user_status` + Realtime Presence ou manter Redis short-lived.

---

## 33. Ordem de migração

| Fase | Módulo | Prioridade | Dependências |
|---|---|---|---|
| 1 | Auth/Authz + Accounts + Users | Crítica | Devise→Supabase Auth, Pundit→Guards |
| 2 | DB core (accounts, account_users, users, inboxes, channels, contacts, contact_inboxes) | Crítica | Account scoping, FK |
| 3 | Conversations + Messages + Attachments (ActiveStorage→Supabase Storage) | Crítica | Inboxes, Contacts |
| 4 | Notifications + Notification settings/subscriptions | Alta | Users, Accounts |
| 5 | Labels, macros, canned_responses, automation_rules, campaigns, custom_attributes | Alta | Conversations, Contacts |
| 6 | Teams, working_hours, inbox_members, assignable_agents, SLA (EE) | Média | Inboxes, Users |
| 7 | Portals, articles, categories, folders, article_embeddings (vector) | Média | Accounts |
| 8 | Data imports + reports + reporting_events rollups | Média | Contacts, Conversations |
| 9 | Captain AI (assistants, documents, faq_suggestions, scenarios, agent_sessions, copilot) | Alta | vector engine, embeddings |
| 10 | Integrações (slack, facebook, whatsapp, email, twilio, shopify, linear, notion) | Média-Alta | Webhooks, Messages |
| 11 | Jobs/Sidekiq→BullMQ + cron | Alta | Redis/Alfred |
| 12 | Realtime (ActionCable→Supabase Realtime) | Alta | Conversations, Messages, Contacts |
| 13 | Frontend (Vue dashboard→React) | Média-Alta | API |
| 14 | Enterprise overlay (feature flags + premium) | Baixa-Média | Core |

---

## 34. Primeira fase (MVP ChatwootBR-Core)

- **Objetivo**: dashboard agente + widget embarcado com conversas de teste (sem canais sociais ainda).
- **Backend NestJS**:
  - Auth: Supabase Auth (signup, login, MFA, OAuth).
  - Módulos: `AccountsModule`, `UsersModule`, `ContactsModule`, `ConversationsModule`, `MessagesModule`, `InboxesModule`.
  - Prisma schema com RLS (account-scoped).
- **Jobs**: BullMQ com Redis Upstash; migrar jobs críticos (`conversation_reply_email`, `notification`, `activity_message`).
- **Realtime**: Supabase Realtime channels para `message.created`, `conversation.*`.
- **Storage**: Supabase Storage buckets (avatares, attachments).
- **Frontend**: React + Vite + Tailwind; dashboard conversa/contato; widget embed script.
- **Fora do MVP**: channels sociais, captain AI, enterprise features, relatórios avançados, importações CRM.

---

## Matriz de migração (módulos)

| Módulo | Atual | Destino | Complexidade | Risco | Dependências | Ordem |
|---|---|---|---|---|---|---|
| Auth | Devise + devise_token_auth + JWT + MFA | Supabase Auth + JWT claims | Alta | Alto | Users, Accounts | 1 |
| Account | `accounts` (jsonb settings/limits/flags) | Prisma `accounts` + tabela `account_settings` | Média | Médio | nenhuma | 2 |
| User | `users` STI + pubsub_token | Supabase users + metadados | Média | Médio | Auth | 2 |
| Inbox/Channel | 10 `channel_*` STI | NestJS + enum channel_type | Alta | Médio-Alto | Accounts | 2 |
| Contact | `contacts` + `contact_inboxes` | Prisma contacts | Média | Médio | Accounts, Inboxes | 3 |
| Conversation | `conversations` + status/uuid | Prisma conversations | Média | Médio | Account, Contact, Inbox, Team | 3 |
| Message | `messages` + sender polimórfico + attachments | Prisma messages + enum | Alta | Alto | Conversation, Sender | 4 |
| Notification | `notifications` polimórfico | Prisma notifications | Alta | Médio-Alto | Users, Conversations | 5 |
| ActiveStorage | blobs/attachments (S3/GCS/Azure) | Supabase Storage | Média | Baixo | messages, users, avatars | 4 |
| Reports | `reporting_events` + rollups | Materialized views Supabase | Alta | Médio | Conversations, Messages | 8 |
| Search | `searchkick`/OpenSearch | Supabase PG search / `pg_trgm` | Alta | Médio | Messages, Contacts, Articles | 8 |
| Labels/Macros/Canned | jsonb listas em conversation | Tabelas join Prisma | Baixa | Baixo | Conversations | 5 |
| Automation | `automation_rules` condições jsonb | Rule engine NestJS | Alta | Alto | Conversations, Contacts | 5 |
| Campaigns | `campaigns` + trigger_schedule | BullMQ jobs | Média | Médio | Conversations | 5 |
| SLA (EE) | `sla_policies/applied_slas` | Prisma + jobs | Média | Médio | Conversations | 6 |
| Knowledge Base | `articles/portals/categories` + embeddings | Prisma + vector | Média-Alta | Médio | Accounts, Portals | 7 |
| Captain AI | `captain_*` + embeddings + agent_sessions | NestJS OpenAI + Supabase vector | Alta | Alto | vector, Messages | 9 |
| Webhooks/Integrations | 10 provedores (lib/integrations) | NestJS modules por provedor | Alta | Alto | Messages, Conversations | 10 |
| Jobs/Fila | Sidekiq (98 jobs, 15 queues) | BullMQ + scheduler | Alta | Alto | Redis, Alfred/Velma | 11 |
| Realtime | ActionCable RoomChannel + 25 eventos | Supabase Realtime channels | Alta | Alto | Conversations, Messages, Notifications | 12 |
| Widget | Vue3 embed sdk | React widget embed | Média | Médio | API pública | 13 |
| Frontend Dashboard | Vue3 (dashboard.js) | React (dashboard) | Alta | Médio-Alto | API REST | 13 |
| Enterprise overlay | 382 arquivos EE (prepend) | Feature flags/Supabase | Alta | Alto | Core | 14 |

---

## Decisões

### Decisão 1 — Banco (PostgreSQL/Supabase)
**Supabase PostgreSQL gerenciado** como destino. Chatwoot já usa PostgreSQL com as mesmas extensões (`pgcrypto`, `pg_trgm`, `pg_stat_statements`, `vector`). `.env.supabase.example:44-59` confirma compatibilidade (pooler pgbouncer). Nenhum vendor lock-in SQL; `gen_random_uuid() OK`. **Risco**: DDL de triggers `hairtrigger` migrar para SQL no `supabase/migrations`.

### Decisão 2 — Prisma (ORM)
**Sim — Prisma 6** como ORM do NestJS. Introspecção via `prisma db pull` do Supabase → schema inicial. Tratar: `vector` (preview), `jsonb`→`Json`, enums PG→Prisma enum, STI (`users.type`) e polymorphic associations (não nativo → modelar via tabelas de join ou Json). **Risco**: polimorfismo `messages.sender`/`notifications.primary_actor` exige redesign relacional.

### Decisão 3 — Auth
**Supabase Auth** substitui Devise 4 + devise_token_auth + devise-two-factor + Omniauth SAML. MFA TOTP via Supabase Auth factors. JWT claims carregam `account_id` + `is_super_admin`. `pubsub_token` preservado como coluna para compatibilidade do widget. **Risco Alto** — logout de sessão/token e migração de tokens existentes.

### Decisão 4 — RLS
**RLS forte no Supabase (PgBouncer pooler)** sobre todas as tabelas `account_id`-scoped; bypass via claim `is_super_admin`. Políticas replicam `ApplicationPolicy` (`app/policies/application_policy.rb:1-59`). **Risco Médio-Alto** — performance de policies + testes de isolamento multi-tenant.

### Decisão 5 — Storage
**Supabase Storage (S3-compatible)** substitui ActiveStorage. Buckets: `avatars`, `message-attachments`, `article-images`. Migração de blobs via `open` + signed URLs. Manter `image_processing` server-side ou migrar para transformações URL. **Risco Baixo-Médio**.

### Decisão 6 — Realtime
**Supabase Realtime** (Postgres Realtime) substitui ActionCable. Mapear 25 eventos (`lib/events/types.rb:17-65`) → `NOTIFY`/triggers Postgres + channels Realtime cliente. Presence → Realtime Presence API ou tabela `user_status`. **Risco Alto** — latência e volume de broadcasts.

### Decisão 7 — Redis / BullMQ
**Upstash Redis (serverless)** como bridge transitória (`redis` gem já suporta `rediss://` `.env.supabase.example:64`); **BullMQ** (`@nestjs/bullmq`) como processor de jobs (98 jobs, 15 queues, locks mutex, cron). Migration incremental: Sidekiq jobs → BullMQ processors. **Risco Alto**.

### Decisão 8 — Frontend
**React 19 (LTS) + Vite 6 + TypeScript + Tailwind** substitui Vue 3.5. Migrar SPA `dashboard.js` (dashboard) e `widget.js` (SDK) mantendo os mesmos contracts de API. **Risco Médio-Alto** — reescrita total da UI.

### Decisão 9 — API
**NestJS REST + controllers** seguem o mesmo *contract* `/api/v1/*`; migrar namespaces gradualmente (`api/v1`, `platform`, `public`, `widget`). **Risco Médio-Alto** — 1192 linhas de routes.rb com guards `enterprise?`.

---

## Sumário de cobertura de evidências

| Fonte | Evidência |
|---|---|
| Versão | `VERSION_CW:1` = 4.16.2; `config/app.yml:2`; `package.json:3`; `git tag` (v4.9.2 latest tag, mas VERSION_CW:4.16.2) |
| Stack | `Gemfile:1-281` (281 lin); `package.json:1-180` |
| Rotas | `config/routes.rb:1192` |
| Schema | `db/schema.rb:1492` (97 tabelas, schema:15-19 extensões) |
| Models | `app/models/` (57 arquivos) |
| Controllers | `app/controllers/api/v1` + base (lista em app/controllers) |
| Services | `app/services/` (244) + `enterprise/app/services/` (142) |
| Jobs | `app/jobs/` (98) |
| Redis | `config/sidekiq.yml:39`; `config/initializers/01_redis.rb:20`; `lib/redis/config.rb:49`; `lib/redis/redis_keys.rb` |
| ActionCable | `config/cable.yml:20`; `config/initializers/actioncable.rb:15`; `app/channels/room_channel.rb:59`; `app/listeners/action_cable_listener.rb` |
| Storage | `config/storage.yml:45`; `Gemfile:56-59` |
| Frontend | `app/javascript/entrypoints/` (8); `app/javascript/dashboard/`; `package.json:99-169` |
| Enterprise | `enterprise/` (382 .rb); `enterprise/config/premium_features.yml:9`; `lib/chatwoot_app.rb:21-24` |
| Eventos | `lib/events/types.rb` (25 eventos) |
| Integrações | `lib/integrations/` subdirs; `Gemfile:106-213` |
| Supabase | `.env.supabase.example` (vars); `docker-compose.supabase.yaml` |
