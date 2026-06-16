<script setup>
import { reactive, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getAPIInboxes'),
};

const initialState = {
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
  rateLimit: '',
  minDelay: '',
  maxDelay: '',
};

const state = reactive({ ...initialState });

const rules = {
  title: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.API_CHANNEL.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.message,
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: state.selectedAudience?.map(id => ({
    id,
    type: 'Label',
  })),
  trigger_rules: {
    ...(state.rateLimit ? { rate_limit: parseInt(state.rateLimit, 10) } : {}),
    ...(state.minDelay ? { min_delay: parseInt(state.minDelay, 10) } : {}),
    ...(state.maxDelay ? { max_delay: parseInt(state.maxDelay, 10) } : {}),
  },
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

// Template variable chips
const TEMPLATE_VARIABLES = [
  { label: '{{contact.name}}', value: '{{contact.name}}' },
  { label: '{{contact.first_name}}', value: '{{contact.first_name}}' },
  { label: '{{contact.last_name}}', value: '{{contact.last_name}}' },
  { label: '{{contact.email}}', value: '{{contact.email}}' },
  { label: '{{contact.phone_number}}', value: '{{contact.phone_number}}' },
];

const messageTextareaRef = ref(null);

const insertVariable = variable => {
  const textarea = messageTextareaRef.value?.$el?.querySelector('textarea');
  if (!textarea) {
    state.message += variable;
    return;
  }
  const start = textarea.selectionStart ?? state.message.length;
  const end = textarea.selectionEnd ?? state.message.length;
  state.message =
    state.message.slice(0, start) + variable + state.message.slice(end);
  // Restore focus and move cursor after inserted variable
  textarea.focus();
  const newPos = start + variable.length;
  textarea.setSelectionRange(newPos, newPos);
};

// Live preview
const showPreview = ref(false);

const PREVIEW_CONTACT = {
  '{{contact.name}}': 'John Doe',
  '{{contact.first_name}}': 'John',
  '{{contact.last_name}}': 'Doe',
  '{{contact.email}}': 'john@example.com',
  '{{contact.phone_number}}': '+1 555-0100',
};

const previewMessage = computed(() => {
  if (!state.message) return '';
  return state.message.replace(
    /\{\{contact\.(name|first_name|last_name|email|phone_number)\}\}/g,
    (match) => PREVIEW_CONTACT[match] || match
  );
});
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-2">
      <TextArea
        ref="messageTextareaRef"
        v-model="state.message"
        :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MESSAGE.LABEL')"
        :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MESSAGE.PLACEHOLDER')"
        show-character-count
        :message="formErrors.message"
        :message-type="formErrors.message ? 'error' : 'info'"
      />

      <div class="flex flex-col gap-1.5">
        <p class="mb-0 text-xs font-medium text-n-slate-10">
          {{ t('CAMPAIGN.API_CHANNEL.CREATE.FORM.TEMPLATE_VARIABLES.LABEL') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="variable in TEMPLATE_VARIABLES"
            :key="variable.value"
            type="button"
            class="inline-flex items-center h-6 px-2 py-0.5 text-xs font-medium rounded-md bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3 cursor-pointer border-0 transition-colors"
            @click="insertVariable(variable.value)"
          >
            {{ variable.label }}
          </button>
        </div>
      </div>

      <div v-if="state.message" class="flex flex-col gap-1.5">
        <button
          type="button"
          class="flex items-center gap-1 text-xs font-medium text-n-slate-10 hover:text-n-slate-12 transition-colors border-0 bg-transparent cursor-pointer p-0 w-fit"
          @click="showPreview = !showPreview"
        >
          <span
            class="i-lucide-chevron-right size-3 transition-transform"
            :class="{ 'rotate-90': showPreview }"
          />
          {{ t('CAMPAIGN.API_CHANNEL.CREATE.FORM.TEMPLATE_VARIABLES.PREVIEW_LABEL') }}
        </button>
        <div
          v-if="showPreview"
          class="p-3 text-sm rounded-lg bg-n-alpha-2 text-n-slate-11 whitespace-pre-wrap"
        >
          {{ previewMessage }}
        </div>
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.API_CHANNEL.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.API_CHANNEL.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <Input
      v-model="state.rateLimit"
      :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.RATE_LIMIT.LABEL')"
      type="number"
      min="1"
      :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.RATE_LIMIT.PLACEHOLDER')"
      :message="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.RATE_LIMIT.HELP')"
      message-type="info"
    />

    <Input
      v-model="state.minDelay"
      :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MIN_DELAY.LABEL')"
      type="number"
      min="0"
      :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MIN_DELAY.PLACEHOLDER')"
      :message="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MIN_DELAY.HELP')"
      message-type="info"
    />

    <Input
      v-model="state.maxDelay"
      :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MAX_DELAY.LABEL')"
      type="number"
      min="0"
      :placeholder="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MAX_DELAY.PLACEHOLDER')"
      :message="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.MAX_DELAY.HELP')"
      message-type="info"
    />

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.API_CHANNEL.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
