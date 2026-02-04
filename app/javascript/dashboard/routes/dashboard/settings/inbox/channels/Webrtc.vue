<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import PageHeader from '../../SettingsSubPageHeader.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const state = reactive({
  channelName: '',
  websiteUrl: '',
  widgetColor: '#1f93ff',
  welcomeTitle: '',
  welcomeTagline: '',
  livekitUrl: '',
  livekitApiKey: '',
  livekitApiSecret: '',
});

const uiFlags = useMapGetter('inboxes/getUIFlags');

const validationRules = {
  channelName: { required },
};

const v$ = useVuelidate(validationRules, state);
const isSubmitDisabled = computed(() => v$.value.$invalid);

const formErrors = computed(() => ({
  channelName: v$.value.channelName?.$error
    ? t('INBOX_MGMT.ADD.WEBRTC.CHANNEL_NAME.ERROR')
    : '',
}));

async function createChannel() {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  const providerConfig = {};
  if (state.livekitUrl) providerConfig.livekit_url = state.livekitUrl;
  if (state.livekitApiKey) providerConfig.livekit_api_key = state.livekitApiKey;
  if (state.livekitApiSecret)
    providerConfig.livekit_api_secret = state.livekitApiSecret;

  try {
    const channel = await store.dispatch('inboxes/createWebrtcChannel', {
      name: state.channelName,
      webrtc: {
        website_url: state.websiteUrl,
        widget_color: state.widgetColor,
        welcome_title: state.welcomeTitle,
        welcome_tagline: state.welcomeTagline,
        provider_config: providerConfig,
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: channel.id },
    });
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        t('INBOX_MGMT.ADD.WEBRTC.API.ERROR_MESSAGE')
    );
  }
}
</script>

<template>
  <div class="overflow-auto col-span-6 p-6 w-full h-full">
    <PageHeader
      :header-title="t('INBOX_MGMT.ADD.WEBRTC.TITLE')"
      :header-content="t('INBOX_MGMT.ADD.WEBRTC.DESC')"
    />

    <form
      class="flex flex-col gap-4 flex-wrap mx-0"
      @submit.prevent="createChannel"
    >
      <Input
        v-model="state.channelName"
        :label="t('INBOX_MGMT.ADD.WEBRTC.CHANNEL_NAME.LABEL')"
        :placeholder="t('INBOX_MGMT.ADD.WEBRTC.CHANNEL_NAME.PLACEHOLDER')"
        :message="formErrors.channelName"
        :message-type="formErrors.channelName ? 'error' : 'info'"
        @blur="v$.channelName?.$touch"
      />

      <Input
        v-model="state.websiteUrl"
        :label="t('INBOX_MGMT.ADD.WEBRTC.WEBSITE_URL.LABEL')"
        :placeholder="t('INBOX_MGMT.ADD.WEBRTC.WEBSITE_URL.PLACEHOLDER')"
      />

      <Input
        v-model="state.livekitUrl"
        :label="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.URL.LABEL')"
        :placeholder="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.URL.PLACEHOLDER')"
        :message="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.URL.HINT')"
        message-type="info"
      />

      <Input
        v-model="state.livekitApiKey"
        :label="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_KEY.LABEL')"
        :placeholder="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_KEY.PLACEHOLDER')"
        :message="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_KEY.HINT')"
        message-type="info"
      />

      <Input
        v-model="state.livekitApiSecret"
        type="password"
        :label="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_SECRET.LABEL')"
        :placeholder="
          t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_SECRET.PLACEHOLDER')
        "
        :message="t('INBOX_MGMT.ADD.WEBRTC.LIVEKIT.API_SECRET.HINT')"
        message-type="info"
      />

      <div>
        <NextButton
          :is-loading="uiFlags.isCreating"
          :disabled="isSubmitDisabled"
          :label="t('INBOX_MGMT.ADD.WEBRTC.SUBMIT_BUTTON')"
          type="submit"
        />
      </div>
    </form>
  </div>
</template>
