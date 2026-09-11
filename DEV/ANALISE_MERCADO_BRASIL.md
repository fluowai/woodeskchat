# Woodesk — Análise de Lacunas e Oportunidades para o Mercado Brasileiro

> Data: 2026-09-09 · Base: Chatwoot 4.16.x (CE + overlay Enterprise) · Foco: produtos de atendimento no Brasil.
> Regra-mãe: **estender o que já existe**; complementar o parcial; só criar módulo novo sem equivalente.
> Escala de prioridade: P0 (bloqueia o produto BR), P1 (forte diferencial), P2 (oportunidade).

---

## 1. Canais (WhatsApp é o canal rei no Brasil)

### 1.1 WhatsApp — provedores e onboarding (P0)
- **O que já existe**: canal WhatsApp (`app/models/channel/whatsapp.rb`), providers `default` (360dialog) e `whatsapp_cloud` (Meta Cloud API, com embedded signup e chamadas via Meta Calling); normalizador de telefone BR com o dígito "9" (`app/services/whatsapp/phone_normalizers/brazil_phone_normalizer.rb`). Campanhas outbound via template Meta existem.
- **Lacuna real**: para o mercado BR o onboarding oficial ainda é fricção (WABA + token + aprovação de templates). Não há agregadores BR prontos (onboarding via parceiros como Weni/Twilio CPaaS) e não há provedores não-oficiais (Evolution API/Z-API) — esses são viáveis só como produto separado, fora do Cloud API.
- **Recomendação (extensão)**: melhorar o passo a passo de conexão Cloud API em PT-BR com checklist (WABA, número, template de saudação aprovado) e validação via `provider_service`. Evoluir o normalizador BR (DDD com 0/9, números fixos).
- **Decisão de negócio (não iniciar sem autorização)**: suportar provedores não-oficiais = módulo novo + risco de bloqueio pela Meta; tratar como linha de produto separada.

### 1.2 Voz / WhatsApp Calling (P1)
- Existe voz via Twilio (EE) e Meta Calling (`enterprise/.../whatsapp_calls_controller.rb`, `call.rb`, transcrição de áudio). BR: validar números BR (DDI 55 + DDD) e transcrição em PT-BR hoje.

### 1.3 E-mail (P1)
- Canal e-mail (POP3/IMAP + SMTP) já existe. Lacuna BR: docs de configuração com provedores populares (Imovirtual/Brevo/Mailgun/Resend) e SPF/DKIM; `MAILER_INBOUND_EMAIL_DOMAIN` p/ continuidade de conversa.

---

## 2. Compliance LGPD (P0 — precondição para B2B no Brasil)

- **O que já existe**: exclusão de conta, exclusão de caixa de entrada, export de contatos (`app/jobs/account/contacts_export_job.rb`), central de ajuda + termos/privacy (config `TERMS_URL`/`PRIVACY_URL`), consentimento implícito no fluxo da Meta.
- **Lacunas reais**:
  1. **Export completo do titular (DSR)**: o export atual cobre contatos; faltam conversas, mensagens, áudios e anexos do contato — base legal/portabilidade (LGPD art. 18).
  2. **Retenção / anonimização**: sem política de retenção configurável por instalação; dado de contato inativo fica indefinidamente (job `process_stale_contacts` existe p/ outros fins).
  3. **Registro de bases legais / consentimento registrado** por canal e por contato.
- **Recomendação**: estender export por contato (zip com conversas+anexos) e adicionar job de anonimização com política configurável — sem criar módulo externo.

---

## 3. Contatos e dados BR (P1)

- **O que já existe**: atributos customizados, etiquetas, empresas/companhias, notas, segmentos/filtros, import Intercom/CSV.
- **Lacunas**:
  1. Máscaras/validação BR nos tipos de atributo: CPF, CNPJ, CEP, telefone com DDD — estender os tipos de custom attribute (hoje text/number/list/etc).
  2. Campos sugeridos p/ o template de contato BR (CPF/CNPJ, segmento, cidade/UF) via `conversation_required_attributes`/custom attributes.

---

## 4. SLAs com contexto BR (P1)

- **O que já existe**: política SLA por inbox (EE, `sla` premium), atividade de SLA, resolução automática por prazo.
- **Lacuna**: calendário de feriados nacionais BR (e de feriados estaduais) para cálculo de tempo de resposta real — extensão na camada de SLA (definição de "business hours" + feriados).
- Já há fuso `America/Sao_Paulo` no `config/application.rb` (base). Garantir que relatórios usem esse fuso.

---

## 5. Captain AI em PT-BR (P0/P1 — grande diferencial competitivo)

- **O que já existe (EE)**: assistente com sugestões de resposta, auto-resolve, transferência (handoff), FAQ tool, sync de documentos, avaliação de conversa (outcomes), transcrição de áudio.
- **Lacunas**:
  1. Prompts de QA internos em EN: `lib/integrations/openai/openai_prompts/fix_spelling_grammar.liquid` e `tone_rewrite.liquid` — adicionar variantes PT-BR (ou rotear por idioma da conversa).
  2. Transcrição de áudio com idioma PT-BR configurável por inbox.
  3. FAQ/artigos em PT-BR como fonte (já é o caso se a central de ajuda estiver em PT-BR).
- **Recomendação**: não criar "bot próprio"; configurar o Captain existente como atendente inicial automático em WhatsApp Cloud API.

---

## 6. Cobrança / PIX (P2 — decisão de monetização)

- **O que já existe**: nada nativo. Templates WhatsApp com link; dashboard apps (JS) e webhooks permitem extensões.
- **Lacuna real**: cobrança na conversa (PIX/boleto/cartão).
- **Recomendação**: começar como **dashboard app + webhook** para provedor BR (skill AbacatePay existente), sem backend novo dentro do Woodesk; nativo só se houver sinal de mercado. Não é módulo núcleo.

---

## 7. Campanhas e templates PT-BR (P1)

- **O que já existe**: campanhas outbound/inbound; envio via template WhatsApp (Meta) com aprovação.
- **Lacuna**: UX de templates em PT-BR (preview de aprovação/status na UI), categoria (marketing/utility), e variáveis leves no editor. Complementar o fluxo existente, sem novo motor.

---

## 8. Relatórios e métricas BR (P2)

- **O que já existe**: relatórios de conversa, respostas, CSAT, SLA; heatmaps; export CSV.
- **Lacunas**: recorte por horário comercial BR, comparação feriados, e a sigla "atendimentos/mês" no formato BR (números com vírgula). Ajustar formatação de número/data no locale pt_BR (parte já em `config/locales/pt_BR.yml`).

---

## 9. Integrações/ecossistema BR (P1/P2)

- **O que já existe**: Slack, webhooks, dashboard apps (extensões JS no painel), OpenSearch, import Intercom, integração Leadsquared (ERP/CRM).
- **Lacuna BR**: apps p/ ERPs e ferramentas BR (Omie, Bling, Tiny, ClickSign, Asaas/AbacatePay). Caminho recomendado: **dashboard apps + webhooks** (sem tocar o backend); incentivar um SDK de app exemplo em PT-BR.

---

## 10. Monetização e planos em BRL (P1 — decisão de negócio)

- **O que já existe**: planos/features premium via `enterprise/config/premium_features.yml` e marcas `premium`, `disable_branding`, `audit_logs`, `sla`, `custom_roles`, `captain_*`, `csat_review_notes`.
- **Lacuna**: cobrança em BRL (PIX/cartão). Na base não há gateway; a régua de cobrança + AbacatePay aparece como skill externa pronta para integrar na camada de contas (jobs de billing) — como adendo de instalação, não alterando fluxos do Chatwoot.

---

## Riscos técnicos herdados (working tree não commitado)

- O rebrand automático `chatwoot → woodesk` (1735 arquivos) renomeou **identificadores técnicos**, contra o princípio do projeto. Itens críticos a revisar antes de merge:
  - `window.woodeskConfig` / `WOODESK_INBOX_TOKEN` (contrato do SDK/widget) → deve voltar a `chatwootConfig`/`CHATWOOT_INBOX_TOKEN`.
  - `db/migrate/20260702000001|2` + `schema.rb`: colunas `woodesk_record_*` → devem permanecer `chatwoot_record_*` (tabelas já criadas em produção).
  - `config/application.rb`: `module Woodesk` → manter `module Chatwoot` (módulo Rails + constantes).
  - Classes `WoodeskCaptcha/App/Hub/ExceptionTracker/MarkdownRenderer` → manter nomes originais.
  - URLs falsas (`github.com/woodesk/woodesk`, `accounts@woodesk.com`) e keys de env.
- Recomendação: restaurar esses pontos à base antes de seguir; o branding legítimo fica em UI/i18n/config/assets (32 arquivos da camada de rebrand), não no código.

---

## Próximos passos sugeridos (fila)

1. [P0] Fixes de identificadores técnicos herdados (risco de quebra em produção).
2. [P0] Onboarding WhatsApp Cloud API em PT-BR + checklist (validação normalizador BR).
3. [P0] LGPD: export completo por contato (DSR) + política de retenção configurável.
4. [P1] Captain AI: prompts de QA em PT-BR + transcrição PT-BR; FAQ a partir da central PT-BR.
5. [P1] Máscaras/validação CPF/CNPJ/CEP/telefone nos atributos; template de contato BR.
6. [P1] SLA com feriados BR + business hours.
7. [P2] Cobrança via dashboard app/webhook (AbacatePay) e apps de integrações BR como exemplos.