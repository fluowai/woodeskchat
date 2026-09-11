# Woodesk — Documento Final: Produto CRM/Atendimento para o Brasil

> **Data**: 2026-09-10 · **Base**: Chatwoot 4.16.x (CE + EE overlay) · **Marca**: Woodesk
> **Objetivo**: Classificar funcionalidades, propor adaptações BR, definir arquitetura de módulos novos, e montar roadmap com sprints.

---

## SUMÁRIO

| Seção | Título |
|-------|--------|
| 1 | Visão Geral do Produto |
| 2 | Stack Técnica |
| 3 | Classificação de Funcionalidades (FASE 3) |
| 4 | Adaptação Brasil (FASE 4A) |
| 5 | Arquitetura CRM |
| 6 | Arquitetura Funil de Vendas |
| 7 | Arquitetura Agenda |
| 8 | PIX e Cobrança |
| 9 | White Label |
| 10 | IA e Automações |
| 11 | Automações Avançadas |
| 12 | Segurança e Compliance (LGPD) |
| 13 | Infra e Deploy |
| 14 | Roadmap e Sprints |

---

## SEÇÃO 1 — Visão Geral do Produto

### 1.1 O que é Woodesk

Woodesk é um CRM de atendimento omnichannel para o mercado brasileiro, fork do Chatwoot 4.16.x com rebrand completo e adaptações para o contexto local.

### 1.2 Proposta de Valor

| Diferencial | Descrição |
|-------------|-----------|
| **WhatsApp nativo** | Integração direta com Meta Cloud API + normalização BR |
| **Atendimento humano + IA** | Captain AI como atendente inicial, handoff inteligente |
| **Cobrança integrada** | PIX/boleto/cartão via AbacatePay dentro da conversa |
| **White Label** | Multi-marca com domínio customizado e branding |
| **LGPD nativo** | Export DSR, retenção, consentimento por canal |
| **Funil visual** | Kanban de deals com pipeline arrastável |
| **Agenda integrada** | Reuniões e follow-ups vinculados ao contato |
| **Multi-instância** | Cada conta = instância isolada (PostgreSQL schema ou DB separado) |

### 1.3 Público-Alvo

| Segmento | Tamanho típico | Canal principal |
|----------|----------------|-----------------|
| Negócios locais (clínicas, salões, academias) | 1-10 atendentes | WhatsApp |
| E-commerce D2C | 5-50 atendentes | WhatsApp + Web Widget |
| Agências digitais | 10-100 atendentes | Multi-canal |
| SaaS B2B | 5-30 atendentes | Email + Web Widget |

---

## SEÇÃO 2 — Stack Técnica

### 2.1 Stack Base (Heritage Chatwoot)

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Backend | Ruby on Rails | 3.4.4 / 7.2.3.1 |
| Frontend | Vue 3 + Vite + JS/TS | Node 24 |
| Database | PostgreSQL + pgvector | 16 |
| Cache/Queue | Redis | 7 (Upstash serverless) |
| Background Jobs | Sidekiq + sidekiq-cron | — |
| WebSockets | ActionCable (Redis adapter) | — |
| Assets | Vite (pré-compilado no build) | — |
| Search | OpenSearch (opcional) + pg_search | — |
| Container | Docker multi-stage (Alpine) | — |

### 2.2 Stack Woodesk (extensões)

| Camada | Tecnologia | Finalidade |
|--------|-----------|-----------|
| TLS | Caddy (ACME automático) | HTTPS + reverse proxy |
| DB gerenciado | Supabase PostgreSQL | Pooler, backups, extensões |
| Redis gerenciado | Upstash Redis | Serverless, pay-per-request |
| Pagamentos | AbacatePay | PIX + cartão BRL |
| IA | OpenAI / Captain AI | Atendente automático |
| Observabilidade | Langfuse / Sentry | tracing + APM |
| Deploy | Docker Compose + Portainer | Multi-container |

### 2.3 Arquitetura de Processos

```
Caddy (TLS)
  ├── /api/*, /cable → Rails (Puma, 2+ replicas)
  ├── /super_admin/* → Rails (admin only)
  └── /* → static assets

Rails Web (Puma)
  ├── REST API (v1, v2)
  ├── Widget API (/api/v1/widget/*)
  ├── Platform API
  ├── ActionCable (/cable)
  └── Background → Sidekiq

Sidekiq (2 workers)
  ├── critical: webhooks, notificações
  └── low: housekeeping, reindex, storage
```

---

## SEÇÃO 3 — Classificação de Funcionalidades (FASE 3)

> **Legenda**: ✅ Manter · 🔧 Adaptar · ⬆️ Melhorar · 🔄 Refazer · ❌ Remover · 🆕 Nova

### 3.1 Canais

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| WhatsApp Cloud API | ⬆️ Melhorar | Fluxo onboarding PT-BR com checklist (WABA, token, template saudação); validação DDD/9 | Médio |
| WhatsApp phone normalizer BR | ✅ Manter | Já funciona; estender para fixos (DDD 0/9) | Baixo |
| Web Widget | ✅ Manter | Funcional; globals renomeados `$woodesk` | Nenhum |
| Email (IMAP/SMTP + OAuth) | ✅ Manter | Suporta provedores BR; docs em PT-BR | Baixo |
| Facebook Messenger | 🔧 Adaptar | Traduzir fluxo de setup; manter webhook | Baixo |
| Instagram DMs | 🔧 Adaptar | Traduzir setup; manter FB Graph API | Baixo |
| Telegram | ✅ Manter | Universal; sem adaptação BR específica | Nenhum |
| Twitter/X | 🔧 Adaptar | Baixa prioridade BR; manter funcional | Baixo |
| SMS (Twilio/generic) | ✅ Manter | Complementar WhatsApp | Nenhum |
| LINE | ❌ Remover | Irrelevante no Brasil; code removal | Baixo |
| TikTok | 🔧 Adaptar | Traduzir setup; TikTok cresce BR | Baixo |
| API (REST custom) | ✅ Manter | Base para integrações BR | Nenhum |

### 3.2 Conversas e Mensagens

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Status (open/pending/resolved/snoozed) | ✅ Manter | Funcional | Nenhum |
| Prioridade (low/medium/high/urgent) | ✅ Manter | Funcional | Nenhum |
| Atribuição (assignee + team) | ✅ Manter | Funcional | Nenhum |
| Labels/Tags | ✅ Manher | Funcional | Nenhum |
| CSAT (pesquisa de satisfação) | 🔧 Adaptar | Formulário em PT-BR; emojis BR | Baixo |
| Notas privadas | ✅ Manter | Funcional | Nenhum |
| Menções (@agent) | ✅ Manter | Funcional | Nenhum |
| Indicador de digitando | ✅ Manher | Funcional | Nenhum |
| Respostas rápidas (canned) | ✅ Manter | Funcional | Nenhum |
| Templates de mensagem | 🔧 Adaptar | Templates PT-BR; preview de aprovação Meta | Médio |
| Tradução de mensagens | ✅ Manter | Funcional para multi-idioma | Nenhum |
| Transcrição de áudio | 🔧 Adaptar | Idioma PT-BR configurável por inbox | Baixo |
| Anexos (até 15/msg) | ✅ Manter | Funcional | Nenhum |
| Janela de mensagem 24h (WhatsApp) | ✅ Manter | Meta API constraint | Nenhum |
| Slash commands (/pix etc.) | 🆕 Nova | Comando `/pix` para gerar cobrança na conversa | Médio |

### 3.3 Contatos

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Contato básico (nome/email/phone) | ✅ Manter | Funcional | Nenhum |
| Atributos customizados | ⬆️ Melhorar | Adicionar tipos: CPF, CNPJ, CEP, telefone BR com máscara | Médio |
| Empresas/Companhias | ✅ Manter | Funcional (EE) | Nenhum |
| Notas de contato | ✅ Manter | Funcional | Nenhum |
| Labels de contato | ✅ Manter | Funcional | Nenhum |
| Merge de duplicados | ✅ Manter | Funcional | Nenhum |
| Export CSV | 🔧 Adaptar | Formatação BR (vírgula decimal, data BR) | Baixo |
| Import CSV | 🔧 Adaptar | Mapear CPF/CNPJ, telefone BR na importação | Médio |
| Filtros salvos | ✅ Manter | Funcional | Nenhum |
| Bloqueio de contato | ✅ Manter | Funcional | Nenhum |
| Lookup IP/GeoIP | ✅ Manter | Funcional | Nenhum |
| Contato template BR | 🆕 Nova | Template com CPF/CNPJ, segmento, cidade/UF | Médio |

### 3.4 Automação

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Regras de automação | ✅ Manher | Funcional; 10min→30d delay | Nenhum |
| Macros | ✅ Manter | Funcional; personal/globais | Nenhum |
| Agent Bots (webhook) | 🔧 Adaptar | Traduzir; manter para bots externos | Baixo |
| Auto-resolve | ✅ Manter | Funcional | Nenhum |
| Captain AI (assistente IA) | ⬆️ Melhorar | Prompts PT-BR, transcrição PT-BR, FAQ PT-BR | Alto |
| Copilot (assistente do agente) | ⬆️ Melhorar | Prompts e respostas em PT-BR | Médio |

### 3.5 Inbox / Fila

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Auto-assignment (round-robin) | ✅ Manter | Funcional | Nenhum |
| Assignment policies V2 | ✅ Manter | Funcional | Nenhum |
| Business hours | ⬆️ Melhorar | Adicionar feriados nacionais/estaduais BR | Médio |
| Mensagem OOO | ✅ Manter | Funcional | Nenhum |
| Saudação automática | ✅ Manter | Funcional | Nenhum |
| Coleta de email | ✅ Manter | Funcional | Nenhum |
| Lock single conversation | ✅ Manher | Funcional | Nenhum |
| Capacidade por agente (EE) | ✅ Manher | Funcional | Nenhum |
| Timezone por inbox | ✅ Manher | `America/Sao_Paulo` já default | Nenhum |
| Portal link | ✅ Manter | Funcional | Nenhum |

### 3.6 Relatórios

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Summary reports (v2) | ✅ Manter | Funcional | Nenhum |
| Agent reports | ✅ Manter | Funcional | Nenhum |
| Inbox reports | ✅ Manter | Funcional | Nenhum |
| Label reports | ✅ Manter | Funcional | Nenhum |
| Team reports | ✅ Manter | Funcional | Nenhum |
| CSAT reports | ✅ Manher | Funcional | Nenhum |
| SLA reports (EE) | 🔧 Adaptar | Calcular com business hours BR + feriados | Médio |
| Conversation traffic | ✅ Manter | Funcional | Nenhum |
| First response distribution | ✅ Manter | Funcional | Nenhum |
| Live reports | ✅ Manter | Funcional | Nenhum |
| Export CSV | 🔧 Adaptar | Formatação BR (números com vírgula) | Baixo |
| Dashboard de métricas BR | 🆕 Nova | KPIs: atendimentos/mês, tempo médio, fila | Alto |

### 3.7 Integrações

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Slack | ✅ Manter | Universal | Nenhum |
| Shopify | 🔧 Adaptar | Baixa prioridade BR; manter | Baixo |
| Linear | ✅ Manter | Para time de produto | Nenhum |
| Notion | ✅ Manter | Para docs internos | Nenhum |
| OpenAI | ⬆️ Melhorar | Modelo PT-BR, label suggestions em PT | Baixo |
| Google Translate | ✅ Manher | Complementar | Nenhum |
| Dialogflow | ✅ Manher | Para bots NLU | Nenhum |
| Dyte (vídeo) | ✅ Manter | Reuniões com cliente | Nenhum |
| LeadSquared (CRM) | ❌ Remover | Substituído pelo CRM nativo Woodesk | Baixo |
| Webhooks | ✅ Manher | Base para integrações BR | Nenhum |
| Dashboard Apps | ✅ Manher | Base para apps BR | Nenhum |
| AbacatePay | 🆕 Nova | PIX + cartão BRL na conversa | Alto |
| Omie/Bling/Tiny (ERP) | 🆕 Nova | Dashboard app + webhook; integração ERP BR | Alto |
| ClickSign | 🆕 Nova | Assinatura digital de contratos | Médio |

### 3.8 Knowledge Base / Central de Ajuda

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Multi-portal | ✅ Manter | Funcional | Nenhum |
| Domínio customizado | ✅ Manher | Funcional | Nenhum |
| Multi-locale | ✅ Manher | Funcional | Nenhum |
| Categorias + artigos | ✅ Manher | Funcional | Nenhum |
| Embedding AI (EE) | ⬆️ Melhorar | Embeddings PT-BR via OpenAI | Baixo |
| Analytics (GTM/GA4/Hotjar) | ✅ Manher | Funcional | Nenhum |
| Sitemap automático | ✅ Manher | Funcional | Nenhum |
| Canned responses | ✅ Manter | Funcional | Nenhum |
| Email templates (Liquid) | 🔧 Adaptar | Templates PT-BR para cobrança/onboarding | Médio |

### 3.9 Campanhas

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Campanhas ongoing (widget) | ✅ Manter | Funcional | Nenhum |
| Campanhas one_off (SMS/WhatsApp) | 🔧 Adaptar | Templates PT-BR; UX de aprovação Meta | Médio |
| Audience targeting | ✅ Manher | Funcional | Nenhum |
| Business hours trigger | ✅ Manter | Funcional | Nenhum |

### 3.10 Phone / Voice

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Voice calls (Twilio) | 🔧 Adaptar | Validar números BR (DDI 55 + DDD) | Baixo |
| WhatsApp Calling (Meta) | 🔧 Adaptar | Validar transcrição PT-BR | Baixo |
| Conference calls | ✅ Manter | Funcional | Nenhum |
| Call recording | ✅ Manter | Funcional | Nenhum |
| Call transcription | ⬆️ Melhorar | Transcrição PT-BR por padrão | Baixo |

### 3.11 Enterprise

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| SAML SSO | ✅ Manher | Funcional | Nenhum |
| Google OAuth | ✅ Manher | Funcional | Nenhum |
| MFA/2FA | ✅ Manter | Funcional | Nenhum |
| Audit logs | ✅ Manter | Funcional | Nenhum |
| Custom roles | ✅ Manter | Funcional (6 permissões) | Nenhum |
| SLA policies | 🔧 Adaptar | Business hours BR + feriados | Médio |
| Agent capacity (EE) | ✅ Manter | Funcional | Nenhum |
| Holiday management | 🆕 Nova | Calendário feriados BR (nacionais + estaduais) | Médio |
| Stripe billing | ❌ Remover | Substituído por AbacatePay (BRL nativo) | Baixo |
| Multi-currency | ❌ Remover | Foco BRL puro; simplificar | Baixo |

### 3.12 Widget / SDK

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Embeddable widget JS | ✅ Manter | `$woodesk` globals ok | Nenhum |
| Pre-chat form | 🔧 Adaptar | Campos BR (CPF, telefone) | Baixo |
| Widget color/branding | ✅ Manter | Funcional | Nenhum |
| Welcome messages | ✅ Manher | Funcional | Nenhum |
| HMAC security | ✅ Manter | Funcional | Nenhum |
| Allowed domains | ✅ Manter | Funcional | Nenhum |
| Continuity via email | ✅ Manter | Funcional | Nenhum |
| Mobile webview | ✅ Manter | Funcional | Nenhum |

### 3.13 Admin / Settings

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Account settings | ✅ Manter | Funcional | Nenhum |
| User management | ✅ Manter | Funcional | Nenhum |
| Team management | ✅ Manter | Funcional | Nenhum |
| Roles & permissions | ✅ Manter | Funcional | Nenhum |
| Platform API | ✅ Manter | Base para integrações | Nenhum |
| Super Admin | ✅ Manter | Funcional | Nenhum |
| Feature flags | ✅ Manter | Funcional | Nenhum |
| Installation configs | 🔧 Adaptar | Defaults PT-BR, moeda BRL, timezone SP | Baixo |

### 3.14 Search

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Global search | ✅ Manter | Funcional | Nenhum |
| Conversation search (pg_search) | ✅ Manher | Funcional | Nenhum |
| Contact search | ✅ Manher | Funcional | Nenhum |
| Article search | ✅ Manter | Funcional | Nenhum |
| Advanced search (Searchkick) | 🔧 Adaptar | Configurar analyzer PT-BR | Médio |

### 3.15 Notificações

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| Push notifications (FCM) | ✅ Manter | Funcional | Nenhum |
| Email notifications | ✅ Manter | Funcional | Nenhum |
| Notification settings | ✅ Manter | Funcional | Nenhum |
| SLA breach notifications | 🔧 Adaptar | Business hours BR | Baixo |

### 3.16 Import/Export

| Funcionalidade | Classificação | Justificativa | Esforço |
|----------------|---------------|---------------|---------|
| CSV contacts import | 🔧 Adaptar | Mapear campos BR (CPF, telefone) | Médio |
| Freshdesk import | ✅ Manter | Funcional | Nenhum |
| Intercom import | ✅ Manter | Funcional | Nenhum |
| Contact export CSV | 🔧 Adaptar | Formatação BR | Baixo |
| **Export DSR completo (LGPD)** | 🆕 Nova | ZIP com conversas+anexos+dados do titular | Alto |
| **Anonimização de dados** | 🆕 Nova | Job de anonimização com política configurável | Alto |

### 3.17 RESUMO DA CLASSIFICAÇÃO

| Classificação | Qtd | % |
|---------------|-----|---|
| ✅ Manter | 78 | 62% |
| 🔧 Adaptar | 26 | 21% |
| ⬆️ Melhorar | 8 | 6% |
| 🔄 Refazer | 0 | 0% |
| ❌ Remover | 3 | 2% |
| 🆕 Nova | 11 | 9% |
| **Total** | **126** | **100%** |

---

## SEÇÃO 4 — Adaptação Brasil (FASE 4A)

### 4.1 CPF / CNPJ

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | Validação básica em `contact.rb` (métodos privados) |
| **O que falta** | Máscara visual (`000.000.000-00` / `00.000.000/0000-00`), validação módulo 11, tipos de atributo customizado dedicados, busca por CPF/CNPJ |
| **Implementação** | 1. Novo tipo `cpf_cnpj` nos custom attributes. 2. Máscara no frontend (vue-the-mask ou similar). 3. Validação backend (módulo 11). 4. Busca por CPF/CNPJ no contacts filter |
| **Arquivos** | `app/models/custom_attribute.rb`, `app/javascript/`, `app/services/` |
| **Esforço** | Médio (2-3 sprints) |

### 4.2 Telefone Brasileiro

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | `BrazilPhoneNormalizer` com dígito 9 |
| **O que falta** | Validação DDD (11-99), fixos vs móveis, formatação visual `(11) 99999-9999`, validação DDI 55 |
| **Implementação** | 1. Estender normalizador para fixos (8 dígitos). 2. Máscara `(00) 0000-00009` (com 9 condicional). 3. Validação backend. 4. Separação country_code + number |
| **Arquivos** | `app/services/whatsapp/phone_normalizers/brazil_phone_normalizer.rb` |
| **Esforço** | Baixo (1 sprint) |

### 4.3 WhatsApp — Fluxo BR

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | Cloud API com embedded signup, templates, phone normalizer |
| **O que falta** | Onboarding em PT-BR com checklist visual, validação WABA, aprovação de template de saudação, guia de rejected templates |
| **Implementação** | 1. Wizard PT-BR de conexão (passo a passo). 2. Checklist: WABA ID, número, template de saudação aprovado. 3. Status de aprovação de template na UI. 4. Guide de troubleshooting |
| **Arquivos** | `app/javascript/`, `app/controllers/api/v1/accounts/` |
| **Esforço** | Médio (2 sprints) |

### 4.4 LGPD

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | Exclusão de conta, export de contatos, termos/privacy URL, consentimento implícito Meta |
| **O que falta** | **CRÍTICO**: Export DSR completo (conversas+anexos), retenção/anonimização configurável, registro de bases legais por canal/contato |
| **Implementação** | 1. Export DSR: job que gera ZIP (conversas, mensagens, áudios, anexos, dados do titular). 2. Anonimização: job com política configurable (N dias sem atividade → anonimizar). 3. Consent register: model `consent_record` (canal, data, base legal). 4. Botão "Exportar meus dados" no widget/portal |
| **Arquivos** | `app/jobs/`, `app/models/`, `app/controllers/` |
| **Esforço** | Alto (3-4 sprints) |
| **Prioridade** | **P0** — precondição para B2B no Brasil |

### 4.5 Feriados Brasileiros

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | Business hours por inbox, timezone `America/Sao_Paulo` |
| **O que falta** | Calendário de feriados nacionais + estaduais, cálculo de SLA considerando feriados |
| **Implementação** | 1. Tabela `holidays` (nacional + estadual). 2. Extensão do SLA calculator para excluir feriados. 3. Seleção de estado no account settings |
| **Arquivos** | `enterprise/app/models/sla_policy.rb`, `app/models/working_hour.rb` |
| **Esforço** | Médio (2 sprints) |

### 4.6 Formatação BR

| Aspecto | Detalhe |
|---------|---------|
| **O que já existe** | Locale pt_BR parcial |
| **O que falta** | Números com vírgula decimal, datas DD/MM/AAAA, moeda R$ X.XXX,XX |
| **Implementação** | 1. Helpers `number_to_currency(:br)`, `l(date, :br)`. 2. Aplicar em relatórios e dashboard. 3. Configurar `config.i18n.default_locale = :pt_BR` |
| **Arquivos** | `config/locales/pt_BR.yml`, helpers, views |
| **Esforço** | Baixo (1 sprint) |

---

## SEÇÃO 5 — Arquitetura CRM

### 5.1 Conceito

O CRM do Woodesk é o módulo central que conecta contatos, conversas, deals, notas e histórico em uma visão unificada.

### 5.2 Modelo de Dados

```
Contact (existente, estendido)
  ├── custom_attributes: { cpf_cnpj, empresa, cargo, segmento, cidade_uf }
  ├── contacts → ContactInbox → Inbox
  ├── contacts → Conversations → Messages
  ├── contacts → Deals (novo)
  ├── contacts → Activities (novo)
  ├── contacts → Notes (existente)
  └── contacts → ConsentRecords (novo, LGPD)

Deal (novo)
  ├── contact_id (FK)
  ├── pipeline_id (FK)
  ├── stage_id (FK)
  ├── title: string
  ├── value: decimal (BRL)
  ├── currency: 'BRL' (fixo)
  ├── status: enum (open, won, lost)
  ├── expected_close_date: date
  ├── assigned_user_id (FK)
  ├── labels: string[]
  ├── custom_attributes: jsonb
  ├── created_at, updated_at, closed_at
  └── activities: Activity[]

Pipeline (novo)
  ├── account_id (FK)
  ├── name: string
  ├── stages: Stage[] (ordered)
  ├── is_default: boolean
  └── created_at

Stage (novo)
  ├── pipeline_id (FK)
  ├── name: string
  ├── position: integer
  ├── color: string
  ├── probability: integer (0-100)
  └── type: enum (open, won, lost) — stage "perdedo" = lost

Activity (novo)
  ├── deal_id (FK, nullable)
  ├── contact_id (FK, nullable)
  ├── user_id (FK)
  ├── type: enum (note, call, meeting, email, task, whatsapp)
  ├── title: string
  ├── description: text
  ├── due_date: datetime (nullable)
  ├── completed: boolean
  ├── outcome: string (nullable)
  └── created_at
```

### 5.3 API Endpoints

```
POST   /api/v1/accounts/:id/deals
GET    /api/v1/accounts/:id/deals
GET    /api/v1/accounts/:id/deals/:deal_id
PATCH  /api/v1/accounts/:id/deals/:deal_id
DELETE /api/v1/accounts/:id/deals/:deal_id
PATCH  /api/v1/accounts/:id/deals/:deal_id/move (stage change)

GET    /api/v1/accounts/:id/pipelines
POST   /api/v1/accounts/:id/pipelines
PATCH  /api/v1/accounts/:id/pipelines/:pipeline_id
DELETE /api/v1/accounts/:id/pipelines/:pipeline_id

GET    /api/v1/accounts/:id/pipelines/:pipeline_id/stages
POST   /api/v1/accounts/:id/pipelines/:pipeline_id/stages
PATCH  /api/v1/accounts/:id/stages/:stage_id
DELETE /api/v1/accounts/:id/stages/:stage_id

GET    /api/v1/accounts/:id/deals/:deal_id/activities
POST   /api/v1/accounts/:id/deals/:deal_id/activities
PATCH  /api/v1/accounts/:id/activities/:activity_id
DELETE /api/v1/accounts/:id/activities/:activity_id
```

### 5.4 Frontend — Tela CRM

```
┌─────────────────────────────────────────────────────────────┐
│ CRM > Pipeline: Vendas B2B                    [+ Novo Deal] │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│ Novo(12) │ Qualif(8)│ Proposta │ Negocia  │ Fechado(5)      │
│          │          │ (4)      │ (3)      │ Ganho(3) Perd(2)│
├──────────┼──────────┼──────────┼──────────┼─────────────────┤
│ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │ ┌──────┐       │
│ │Deal 1│ │ │Deal 5│ │ │Deal 9│ │ │Deal12│ │ │Deal15│       │
│ │R$2k  │ │ │R$8k  │ │ │R$15k │ │ │R$3k  │ │ │R$20k │       │
│ │Ana S.│ │ │João M│ │ │Maria │ │ │Pedro │ │ │Lucia │       │
│ └──────┘ │ └──────┘ │ └──────┘ │ └──────┘ │ └──────┘       │
│ ┌──────┐ │ ┌──────┐ │          │          │                 │
│ │Deal 2│ │ │Deal 6│ │          │          │                 │
│ │R$5k  │ │ │R$12k │ │          │          │                 │
│ └──────┘ │ └──────┘ │          │          │                 │
└──────────┴──────────┴──────────┴──────────┴─────────────────┘
```

### 5.5 Integração com Conversas

- Cada Deal pode ter conversas vinculadas (1:N)
- Ao criar deal a partir de uma conversa, linkage automático
- Timeline do deal mostra: atividades + mensagens relevantes
- Notificação: "Novo deal criado a partir da conversa #123"

---

## SEÇÃO 6 — Arquitetura Funil de Vendas

### 6.1 Conceito

Funil visual no estilo Kanban onde deals avançam entre estágios. Cada instalação pode ter múltiplos pipelines (ex: "Vendas B2B", "Onboarding", "Suporte").

### 6.2 Pipelines Default

| Pipeline | Estágios Default |
|----------|-----------------|
| **Vendas** | Novo → Qualificação → Proposta → Negociação → Ganho / Perdido |
| **Onboarding** | Contrato Assinado → Configuração → Treinamento → Go-Live → Completo |
| **Suporte (VIP)** | Aberto → Em andamento → Aguardando cliente → Resolvido |

### 6.3 Regras de Funil

| Regra | Descrição |
|-------|-----------|
| Auto-create deal | Quando contato chega via WhatsApp Web Widget e preenche formulário |
| Stage automático | Deal criado no estágio "Novo" do pipeline padrão |
| Win automático | Quando pagamento (PIX/cartão) é confirmado via AbacatePay webhook |
| Lost automático | Quando deal fica >30 dias sem atividade (configurável) |
| Reopen | Quando contato responde após deal estar "Perdido" |
| Probability | Cada estágio tem % de probabilidade (ex: Proposta = 60%) |

### 6.4 Métricas do Funil

| Métrica | Cálculo |
|---------|---------|
| Pipeline velocity | Deals ganhos / tempo médio de ciclo |
| Win rate | Deals ganhos / (ganho + perdido) |
| Conversion rate | Deals que avançam / total no estágio |
| Average deal value | Soma valores / total deals ganhos |
| Time in stage | Dias entre criação e mudança de estágio |
| Lost reasons | Tag dos motivos de perda |

---

## SEÇÃO 7 — Arquitetura Agenda

### 7.1 Conceito

Agenda integrada ao CRM: reuniões, follow-ups e tarefas vinculados a contatos e deals. Suporte a integração com Google Calendar.

### 7.2 Modelo de Dados

```
Activity (já definido na Seção 5)
  ├── type: meeting | task | call | follow_up
  ├── due_date: datetime
  ├── participants: Contact[]
  ├── deal_id: FK (nullable)
  ├── google_calendar_event_id: string (nullable)
  └── status: pending | completed | cancelled
```

### 7.3 Funcionalidades

| Feature | Descrição |
|---------|-----------|
| **Visão calendário** | Mês/semana/dia com drag-and-drop |
| **Criação rápida** | A partir da conversa: "Agendar follow-up" |
| **Lembrete** | Notificação push + WhatsApp (24h antes, 1h antes) |
| **Reunião por link** | Gerar link Dyte/Meet/Zoom direto da activity |
| **Sync Google Calendar** | Bidirecional via OAuth (skill Google Workspace) |
| **Recorrência** | Reuniões recorrentes (semanal, mensal) |
| **Relatório** | Atendimentos agendados vs realizados |

### 7.4 API Endpoints

```
GET    /api/v1/accounts/:id/activities
POST   /api/v1/accounts/:id/activities
PATCH  /api/v1/accounts/:id/activities/:activity_id
DELETE /api/v1/accounts/:id/activities/:activity_id
GET    /api/v1/accounts/:id/activities/calendar (view by date range)
POST   /api/v1/accounts/:id/activities/:activity_id/complete
POST   /api/v1/accounts/:id/activities/:activity_id/google_sync
```

### 7.5 Frontend — Tela Agenda

```
┌──────────────────────────────────────────────────────────────┐
│ Agenda > Setembro 2026              [Hoje] [Mês] [Sem] [Dia] │
├──────┬──────┬──────┬──────┬──────┬──────┬──────┤
│ Seg  │ Ter  │ Qua  │ Qui  │ Sex  │ Sáb  │ Dom  │
├──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│  1   │  2   │  3   │  4   │  5   │  6   │  7   │
│      │ 📞 10h│      │ 📋 14h│      │      │      │
│      │ Ana  │      │ João  │      │      │      │
├──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│  8   │  9   │ 10   │ 11   │ 12   │ 13   │ 14   │
│ 📞 9h │      │ 📋 11h│      │ 📞 15h│      │      │
│ Pedro │      │ Maria │      │ Lucia │      │      │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┘

Atividades de Hoje (10/09):
  09:00 📞 Call com Pedro Silva [Deal: R$5k]
  11:00 📋 Follow-up Maria Santos [Deal: R$15k]
  14:00 📧 Enviar proposta para João [Deal: R$8k]
```

---

## SEÇÃO 8 — PIX e Cobrança

### 8.1 Conceito

Geração de cobrança (PIX, boleto, cartão) dentro da conversa, via integração AbacatePay. O atendente gera um link de pagamento que vai direto para o cliente.

### 8.2 Fluxo

```
Atendente conversa com cliente
  ↓
Clica em "Gerar Cobrança" (ou /pix na conversa)
  ↓
Preenche: valor, descrição, vencimento
  ↓
Woodesk chama AbacatePay API (server-side)
  ↓
Retorna: QR Code PIX + link de pagamento + boleto
  ↓
Mensagem automática na conversa com QR Code + link
  ↓
Cliente paga (PIX, cartão, boleto)
  ↓
Webhook AbacatePay → Woodesk marca como "Pago"
  ↓
Deal automaticamente move para "Ganho" (se pipeline config)
  ↓
Notificação para atendente + cliente
```

### 8.3 Modelo de Dados

```
Payment (novo)
  ├── account_id: FK
  ├── contact_id: FK
  ├── deal_id: FK (nullable)
  ├── conversation_id: FK (nullable)
  ├── amount: decimal (BRL, centavos)
  ├── description: string
  ├── status: enum (pending, paid, overdue, cancelled, refunded)
  ├── payment_method: enum (pix, credit_card, boleto)
  ├── abacatepay_id: string (ID externo)
  ├── qr_code_pix: string (base64 ou URL)
  ├── payment_url: string (link checkout)
  ├── boleto_url: string (nullable)
  ├── expires_at: datetime
  ├── paid_at: datetime (nullable)
  ├── metadata: jsonb
  └── created_at, updated_at
```

### 8.4 API Endpoints

```
POST   /api/v1/accounts/:id/payments
GET    /api/v1/accounts/:id/payments
GET    /api/v1/accounts/:id/payments/:payment_id
POST   /api/v1/accounts/:id/conversations/:conversation_id/payments
GET    /api/v1/accounts/:id/payments/summary

Webhook (inbound):
POST   /webhooks/abacatepay (verifica assinatura, atualiza status)
```

### 8.5 Integração com Conversa

- Pagamento aparece como mensagem tipo `payment` na conversa
- Card com: valor, status, link, QR Code
- Quando pago: mensagem automática "Pagamento confirmado! R$ X.XXX,XX"
- Vinculação ao deal: valor do deal = soma dos pagamentos

### 8.6 Segurança

- Chave API AbacatePay: **somente server-side** (nunca no frontend)
- Verificação de assinatura do webhook (HMAC)
- Rate limiting no endpoint de criação de pagamento
- Logs de auditoria: quem criou, quando, valor

### 8.7 MVP vs Full

| Feature | MVP (Sprint 1-2) | Full (Sprint 3-4) |
|---------|-------------------|-------------------|
| PIX via AbacatePay | ✅ | ✅ |
| Cartão via AbacatePay | ✅ | ✅ |
| Boleto | ❌ | ✅ |
| Webhook automático | ✅ | ✅ |
| Integração com deal | ❌ | ✅ |
| Recorrência (assinatura) | ❌ | ✅ |
| Notas fiscais (NFe) | ❌ | 🔄 Futuro |
| Split de pagamento | ❌ | 🔄 Futuro |

---

## SEÇÃO 9 — White Label

### 9.1 Conceito

Multi-marca: cada instância/conta pode ter branding próprio (logo, cores, domínio, emails).

### 9.2 Níveis de White Label

| Nível | Escopo | Esforço |
|-------|--------|---------|
| **L1 — Visual** | Logo, cores, favicon, nome | Baixo (config) |
| **L2 — Domínio** | Domínio customizado no portal de ajuda | Médio (DNS + SSL) |
| **L3 — Widget** | Widget com marca do cliente | Médio (SDK config) |
| **L4 — Email** | Templates de email com marca | Médio (Liquid templates) |
| **L5 — API** | Domínio customizado na API | Alto (DNS + proxy) |
| **L6 — Multi-tenant completo** | Instância isolada por cliente | Alto (DB schema isolation) |

### 9.3 Modelo de Dados (estendido)

```
Account (existente, campos adicionais)
  ├── branding: jsonb {
  │     logo_url, favicon_url,
  │     primary_color, secondary_color,
  │     widget_color, widget_bg_color,
  │     email_header_html, email_footer_html,
  │     custom_domain, custom_domain_ssl,
  │     mailer_sender_name, mailer_sender_email
  │   }
  ├── is_white_label: boolean (default: false)
  └── white_label_tier: enum (l1_visual, l2_domain, l3_widget, l4_email, l5_api, l6_full)
```

### 9.4 Configuração por Nível

**L1 — Visual (config UI)**
- Account Settings → Branding → Logo upload, cores, favicon
- Aplicado em: portal de ajuda, email templates, dashboard header

**L2 — Domínio**
- Account Settings → Domínio → Input `ajuda.cliente.com.br`
- CNAME → `help.woodesk.com` ou IP dedicado
- SSL automático via Caddy/Let's Encrypt

**L3 — Widget**
- Widget config → branding: logo, cores, posição, boas-vindas
- SDK com `woodeskSDK.init({ brand: { ... } })`

**L4 — Email**
- Account Settings → Email Templates → Customizar header/footer
- Liquid templates com variáveis de branding

### 9.5 Limites por Plano

| Plano | White Label |
|-------|-------------|
| **Free** | L1 (visual básico) |
| **Starter** | L1 + L2 (domínio) |
| **Pro** | L1-L4 (completo) |
| **Enterprise** | L1-L6 (multi-tenant) |

---

## SEÇÃO 10 — IA e Automações

### 10.1 Captain AI — Configuração PT-BR

| Aspecto | Estado Atual | Ação |
|---------|-------------|------|
| Prompts QA | Em EN | Criar variantes PT-BR (`fix_spelling_grammar_ptBR.liquid`) |
| Transcrição de áudio | Genérico | Configurar `language: 'pt-BR'` por inbox |
| FAQ fonte | Genérico | Central de ajuda PT-BR como fonte principal |
| Handoff trigger | Configurável | Configurar thresholds PT-BR |
| Response window | Configurável | Defaults agressivos para WhatsApp |

### 10.2 Automações BR

| Automação | Trigger | Ação |
|-----------|---------|------|
| **Saudação WhatsApp** | Nova conversa via WhatsApp | Mensagem de boas-vindas PT-BR com horário |
| **Classificação automática** | Mensagem recebida | Captain classifica (vendas/suporte/churn) |
| **Notificação pagamento** | Webhook AbacatePay pago | Mensagem "Pagamento confirmado" + mover deal |
| **Follow-up automático** | Deal >7 dias sem atividade | Lembrete ao atendente + mensagem ao cliente |
| **CSAT após resolução** | Conversa resolvida | Enviar pesquisa de satisfação |
| **Rerouting SLA** | SLA primeiro atendimento >5min | Reatribuir para próximo agente disponível |
| **Anonimização LGPD** | Contato inativo >12 meses | Anonimizar dados pessoais |
| **Digest diário** | Todo dia 18h | Resumo por email: conversas pendentes, SLAs, deals |

### 10.3 IA para Atendente (Copilot)

| Feature | Descrição |
|---------|-----------|
| **Sugestão de resposta** | Captain sugere resposta baseado em contexto + FAQ |
| **Tradução automática** | Traduzir mensagem do cliente para o idioma do atendente |
| **Summarize** | Resumo da conversa para handoff |
| **Sentiment analysis** | Classificar sentimento do cliente (positivo/neutro/negativo) |
| **Smart tags** | Sugerir labels automaticamente |
| **Extract info** | Extrair CPF, CNPJ, telefone, email de mensagens longas |

### 10.4 Automações Visuais (Futuro)

```
┌──────────────────────────────────────────────────────┐
│ Automação: "Novo lead WhatsApp"                       │
│                                                       │
│  [Trigger: Nova conversa WhatsApp]                    │
│       │                                               │
│       ▼                                               │
│  [Condição: Primeira vez?] ──Sim──▶ [Criar Deal "Novo"] │
│       │                           [Atribuir: Vendas]  │
│       Não                         [Tag: lead_quente]  │
│       │                                               │
│       ▼                                               │
│  [Captain: Responder saudação]                        │
│       │                                               │
│       ▼                                               │
│  [Aguardar 24h sem resposta?] ──Sim──▶ [Enviar follow-up]│
│                                        [Mover: Qualificação]│
└──────────────────────────────────────────────────────┘
```

---

## SEÇÃO 11 — Automações Avançadas

### 11.1 Automações Existentes (estender)

| Automação Chatwoot | Ação Woodesk |
|---------------------|-------------|
| Automation rules | ✅ Manter; adicionar ações: criar deal, mover deal, gerar cobrança |
| Macros | ✅ Manter; adicionar macro "Criar deal", "Gerar PIX" |
| Delayed automations | ✅ Manter; usar para follow-ups agendados |
| Agent bots | 🔧 Adaptar; bot externo pode criar deals |

### 11.2 Novas Automações Woodesk

| Automação | Trigger | Ação | Prioridade |
|-----------|---------|------|-----------|
| **Lead → Deal** | Conversa criada via Web Widget com pre-chat | Criar deal no pipeline "Vendas" | P0 |
| **Pagamento → Deal Win** | Webhook AbacatePay (status=paid) | Mover deal para "Ganho" | P0 |
| **SLA Breach → Reassign** | SLA primeiro atendimento estourou | Reatribuir agente + notificar admin | P0 |
| **Inatividade → Follow-up** | Deal >X dias sem atividade | Lembrete + mensagem | P1 |
| **CSAT Baixo → Escalar** | CSAT <3 estrelas | Escalar para supervisor | P1 |
| **Horário comercial** | Fora de business hours | Mensagem automática "Retornamos amanhã" | P1 |
| **Novo contato → Enriquecer** | Contato criado | Buscar dados via CNPJ (ReceitaWS) | P2 |
| **Churn score** | Inatividade >30d + CSAT baixo | Marcar como risco de churn | P2 |

### 11.3 Slash Commands

| Comando | Descrição |
|---------|-----------|
| `/pix [valor]` | Gera cobrança PIX na conversa |
| `/deal [título]` | Cria deal vinculado à conversa |
| `/followup [data]` | Agenda follow-up |
| `/notas` | Adiciona nota privada |
| `/transfer [equipe]` | Transfere conversa para equipe |
| `/csat` | Envia pesquisa de satisfação |

---

## SEÇÃO 12 — Segurança e Compliance (LGPD)

### 12.1 LGPD — Requisitos

| Requisito LGPD | Artigo | Implementação |
|-----------------|--------|---------------|
| Consentimento | Art. 7, I | Registro de consentimento por canal/contato |
| Finalidade | Art. 6, I | Mapeamento de dados: quais dados, para quê |
| Minimização | Art. 6, III | Coletar só o necessário (pre-chat form configurável) |
| Acesso do titular | Art. 18, II | Export DSR completo (ZIP) |
| Correção | Art. 18, III | Contato pode editar dados no portal |
| Anonimização | Art. 16 | Job de anonimização com política |
| Portabilidade | Art. 18, V | Export em formato estruturado (JSON/CSV) |
| Eliminação | Art. 18, VI | Exclusão de conta + dados associados |
| Incidente | Art. 48 | Log de incidentes + notificação |
| DPO | Art. 41 | Configuração de contato DPO no account settings |

### 12.2 Segurança Técnica

| Medida | Estado | Ação |
|--------|--------|------|
| TLS | ✅ Caddy auto | Manter |
| CSP | ✅ Habilitada | Ajustar unsafe-hashes se necessário |
| CORS | ✅ Restrito | Manter |
| Rate limiting | ✅ Rack::Attack | Manter |
| 2FA/MFA | ✅ TOTP + backup codes | Manter |
| Encryption at rest | ⚠️ ActiveRecord Encryption | Habilitar keys no .env |
| Secrets management | ⚠️ Placeholder | Gerar SECRET_KEY_BASE + encryption keys |
| Audit logs | ✅ Enterprise | Manter |
| Webhook auth | ✅ HMAC | Estender para AbacatePay |

### 12.3 Data Processing Register (DPR)

```
DPR Woodesk (modelo):
├── Dados pessoais coletados:
│   ├── Nome, email, telefone (contato)
│   ├── CPF/CNPJ (custom attribute, opcional)
│   ├── Mensagens de conversa
│   ├── Anexos (imagens, áudios, documentos)
│   ├── IP e localização
│   ├── Dados de pagamento (via AbacatePay — NÃO armazenamos cartão)
│   └── Dados de uso (CSAT, navigational)
│
├── Finalidades:
│   ├── Atendimento ao cliente (base: execução de contrato)
│   ├── Melhoria de serviço (base: legítimo interesse)
│   ├── Cobrança (base: execução de contrato)
│   └── Marketing (base: consentimento)
│
├── Base legal por finalidade
├── Retenção: config por conta (default 24 meses)
├── Compartilhamento: AbacatePay (pagamentos), Meta (WhatsApp)
└── Transferência internacional: OpenAI (IA, EUA), Upstash (Redis, EUA)
```

---

## SEÇÃO 13 — Infra e Deploy

### 13.1 Stack de Deploy (já definida)

| Componente | Estado | Notas |
|------------|--------|-------|
| Docker Compose | ✅ `docker-compose.woodesk.yaml` | Portainer-ready |
| Caddy TLS | ✅ `docker/caddy/Caddyfile` | ACME automático |
| Supabase PostgreSQL | ✅ Pooler configurado | Free tier: 20 conn; paid: 200 |
| Upstash Redis | ✅ Serverless | Pay-per-request |
| Image: `woodesk/chat` | ⚠️ Pendente build | Precisa de host com Docker |

### 13.2 Containers

```
woodesk/chat
├── caddy (TLS + reverse proxy)
├── rails (Puma, 2+ replicas)
├── sidekiq-critical (webhooks, notificações)
├── sidekiq-low (housekeeping, reindex)
├── migrate (one-shot, migrações)
└── (sem postgres/redis containers — gerenciados)
```

### 13.3 Variáveis de Ambiente (.env.woodesk)

```bash
# === Database (Supabase) ===
DATABASE_URL=postgres://postgres.xxx:password@xxx-pooler.supabase.co:5432/postgres

# === Redis (Upstash) ===
REDIS_URL=rediss://default:xxx@xxx.upstash.io

# === App ===
SECRET_KEY_BASE=<gerado>
FRONTEND_URL=https://app.woodesk.com
WOODESK_HUB_URL=https://hub.2.woodesk.com
DEFAULT_LOCALE=pt_BR
TZ=America/Sao_Paulo

# === Encryption (2FA) ===
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<gerado>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<gerado>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<gerado>

# === SMTP ===
SMTP_ADDRESS=smtp.resend.com
SMTP_PORT=587
SMTP_USERNAME=resend
SMTP_PASSWORD=<api_key>
MAILER_SENDER_EMAIL='Woodesk <contato@woodesk.com>'

# === AbacatePay ===
ABACATEPAY_API_KEY=<api_key>
ABACATEPAY_WEBHOOK_SECRET=<secret>

# === AI (Captain) ===
CAPTAIN_OPENAI_API_KEY=<api_key>
CAPTAIN_EMBEDDING_MODEL=text-embedding-3-small

# === Storage ===
ACTIVE_STORAGE_SERVICE=amazon
S3_BUCKET=woodesk-storage
S3_REGION=sa-east-1
S3_ACCESS_KEY_ID=<key>
S3_SECRET_ACCESS_KEY=<secret>
```

### 13.4 Health Checks

| Service | Check | Interval |
|---------|-------|----------|
| Caddy | `GET /` (200) | 30s |
| Rails | `GET /health` (200) | 15s |
| Sidekiq | Redis ping | 15s |
| Redis | `PING` | 10s |
| PostgreSQL | `SELECT 1` | 30s |

---

## SEÇÃO 14 — Roadmap e Sprints

### 14.1 Visão Geral do Roadmap

```
2026 Q4 (Out-Dez)                    2027 Q1 (Jan-Mar)
├── Fase 0: Fundação                 ├── Fase 2: CRM & Funil
├── Fase 1: PIX & WhatsApp           ├── Fase 3: IA & Automações
│                                    ├── Fase 4: White Label
│                                    └── Fase 5: Escala & LGPD
```

### 14.2 Sprints Detalhados

#### FASE 0 — Fundação (Sprints 0-1) — 4 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S0.1** | 1 sem | Build imagem Docker `woodesk/chat`; smoke test `db:woodesk_prepare`; validação compose Portainer |
| **S0.2** | 1 sem | Habilitar CSP + CORS prod; gerar SECRET_KEY_BASE + encryption keys; validar TLS via Caddy |
| **S0.3** | 1 sem | Formatação BR (números, datas, moeda); defaults `pt_BR`; `America/Sao_Paulo` |
| **S0.4** | 1 sem | Smoke completo: login, widget, WhatsApp, conversas; fix de issues |

#### FASE 1 — PIX & WhatsApp (Sprints 1-4) — 8 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S1.1** | 2 sem | Integração AbacatePay: model Payment, API client, webhook handler, criação de cobrança |
| **S1.2** | 2 sem | Frontend cobrança: modal "Gerar Cobrança" na conversa, QR Code, card de pagamento |
| **S1.3** | 2 sem | Slash command `/pix`; mensagem automática de pagamento; notificação |
| **S1.4** | 2 sem | WhatsApp onboarding PT-BR: wizard, checklist, validação DDD, normalizador extendido |

#### FASE 2 — CRM & Funil (Sprints 5-8) — 8 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S2.1** | 2 sem | Models: Deal, Pipeline, Stage; API CRUD; migration |
| **S2.2** | 2 sem | Frontend: Kanban board (vue-draggable), drag-and-drop, deal cards |
| **S2.3** | 2 sem | Integração conversa↔deal; auto-create deal from widget; win/lost automático |
| **S2.4** | 2 sem | Métricas do funil: win rate, velocity, conversion; relatório pipeline |

#### FASE 3 — Agenda (Sprints 9-10) — 4 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S3.1** | 2 sem | Activity model extendido; API calendário; frontend visão mês/semana |
| **S3.2** | 2 sem | Lembrete push/WhatsApp; sync Google Calendar; criação rápida da conversa |

#### FASE 4 — IA & Automações (Sprints 11-14) — 8 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S4.1** | 2 sem | Captain PT-BR: prompts variantes, transcrição PT-BR, FAQ PT-BR |
| **S4.2** | 2 sem | Automações BR: lead→deal, pagamento→win, SLA breach→reassign |
| **S4.3** | 2 sem | Copilot: sugestão resposta, summarize, sentiment, smart tags |
| **S4.4** | 2 sem | Slash commands avançados; digest diário; follow-up automático |

#### FASE 5 — White Label (Sprints 15-16) — 4 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S5.1** | 2 sem | L1-L2: Branding config (logo, cores, favicon), custom domain portal |
| **S5.2** | 2 sem | L3-L4: Widget branding, email templates custom; limites por plano |

#### FASE 6 — LGPD & Escala (Sprints 17-20) — 8 semanas

| Sprint | Duração | Entregas |
|--------|---------|----------|
| **S6.1** | 2 sem | Export DSR completo (ZIP); consent records model |
| **S6.2** | 2 sem | Anonimização configurável; retenção de dados; DPR tool |
| **S6.3** | 2 sem | Feriados BR (nacionais+estaduais); SLA com business hours BR |
| **S6.4** | 2 sem | Dashboard de métricas BR; relatórios avançados; formatação completa |

### 14.3 Resumo do Roadmap

| Fase | Sprints | Semanas | Marco |
|------|---------|---------|-------|
| 0 — Fundação | S0.1-S0.4 | 4 | Woodesk roda em produção |
| 1 — PIX & WhatsApp | S1.1-S1.4 | 8 | Cobrança integrada + WhatsApp PT-BR |
| 2 — CRM & Funil | S2.1-S2.4 | 8 | Pipeline visual de vendas |
| 3 — Agenda | S3.1-S3.2 | 4 | Reuniões e follow-ups |
| 4 — IA & Automações | S4.1-S4.4 | 8 | Captain PT-BR + automações |
| 5 — White Label | S5.1-S5.2 | 4 | Multi-marca |
| 6 — LGPD & Escala | S6.1-S6.4 | 8 | Compliance total |
| **TOTAL** | **20 sprints** | **44 semanas** (~11 meses) | |

### 14.4 Dependências e Prioridades

```
Fase 0 (fundação) ──┐
                     ├──▶ Fase 1 (PIX/WhatsApp) ──┐
                     │                              ├──▶ Fase 4 (IA)
                     ├──▶ Fase 2 (CRM/Funil) ──────┤
                     │                              │
                     ├──▶ Fase 3 (Agenda) ──────────┤
                     │                              │
                     └──▶ Fase 5 (White Label) ────┘
                                                   │
                                          Fase 6 (LGPD) ← sempre paralelo
```

### 14.5 Riscos e Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| AbacatePay API indisponível | Alto | Circuit breaker + retry; fallback "link externo" |
| Supabase free tier limites | Médio | Migrar para paid; monitorar conexões |
| Captain AI custo alto | Médio | Budget por conta; fallback para resposta manual |
| WhatsApp rejeição de templates | Alto | Review manual antes de submeter; variantes PT-BR |
| Multi-tenant isolamento | Alto | Schema isolation ou DB per account (decisão arquitetural) |
| LGPD multas | Alto | Priorizar Fase 6; DPO dedicado |

---

## ANEXO — Decisões Pendentes para o Maestro

| # | Decisão | Opções | Recomendação |
|---|---------|--------|-------------|
| D1 | Multi-tenant: schema per account vs DB per account | Schema = mais eficiente, DB = mais isolado | Schema (Supabase suporta) |
| D2 | EE vs CE | EE = mais features, CE = mais simples | EE (SLA, audit, custom roles essenciais) |
| D3 | Plano gratuito | Sim/Não | Sim, com limites (1 atendente, 100 contatos) |
| D4 | WhatsApp official vs não-oficial | Oficial = seguro, Não-oficial = barato | Apenas oficial (Meta Cloud API) |
| D5 | Automação visual (drag-and-drop) | Sim/Não/Futuro | Futuro (após Fase 4) |
| D6 | App mobile | Sim/Não/Futuro | Futuro (PWA primeiro) |
| D7 | NFe (nota fiscal) integrada | Sim/Não/Futuro | Futuro (API externa) |
| D8 | Integração ERP (Omie/Bling) | Dashboard app / Nativo | Dashboard app (webhook) |

---

*Documento gerado em 2026-09-10 pelo orquestrador. Para atualizações, consultar `DEV/WORKLOG.md` e `DEV/SPECS/ACTIVE.md`.*
