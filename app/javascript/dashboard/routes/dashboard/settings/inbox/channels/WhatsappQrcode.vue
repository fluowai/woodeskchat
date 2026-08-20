<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: 'WhatsApp Alternativo',
      webhookUrl: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.channelName?.trim(),
          channel: {
            type: 'api',
            webhook_url: this.webhookUrl,
          },
        });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            'Erro ao criar o canal de WhatsApp Alternativo.'
        );
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      header-title="WhatsApp Alternativo (QR Code / Baileys)"
      header-content="Crie uma caixa de entrada que funcionará como ponte para a Evolution API ou outras APIs não oficiais baseadas em Baileys."
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          Nome da Caixa de Entrada
          <input
            v-model="channelName"
            type="text"
            placeholder="Ex: Suporte WhatsApp"
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">
            O nome é obrigatório.
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label>
          URL do Webhook (Evolution API) - Opcional neste momento
          <input
            v-model="webhookUrl"
            type="text"
            placeholder="https://sua-evolution.api.com/webhook/..."
          />
        </label>
        <p class="help-text">
          Se você estiver usando a Evolution API, ela configurará o webhook automaticamente usando os tokens fornecidos na próxima tela, você pode deixar este campo em branco.
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          label="Criar Caixa de Entrada e Gerar Tokens"
        />
      </div>
    </form>
  </div>
</template>
