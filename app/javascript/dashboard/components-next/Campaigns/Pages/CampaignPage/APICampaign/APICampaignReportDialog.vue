<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  campaign: {
    type: Object,
    default: null,
  },
});

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const isLoading = ref(false);
const reportData = ref(null);

const statusLabel = computed(() => {
  const statusMap = {
    active: t('CAMPAIGN.API_CHANNEL.CARD.STATUS.SCHEDULED'),
    processing: t('CAMPAIGN.API_CHANNEL.CARD.STATUS.PROCESSING'),
    completed: t('CAMPAIGN.API_CHANNEL.CARD.STATUS.COMPLETED'),
  };
  return reportData.value ? statusMap[reportData.value.status] || reportData.value.status : '-';
});

const fetchReport = async () => {
  if (!props.campaign) return;
  isLoading.value = true;
  reportData.value = null;
  try {
    reportData.value = await store.dispatch(
      'campaigns/fetchCampaignReport',
      props.campaign.id
    );
  } catch {
    useAlert(t('CAMPAIGN.API_CHANNEL.REPORT.API.ERROR_MESSAGE'));
    dialogRef.value?.close();
  } finally {
    isLoading.value = false;
  }
};

const open = () => {
  dialogRef.value?.open();
  fetchReport();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CAMPAIGN.API_CHANNEL.REPORT.TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('CAMPAIGN.API_CHANNEL.REPORT.CLOSE')"
    width="md"
  >
    <div class="flex flex-col gap-4">
      <div
        v-if="isLoading"
        class="flex items-center justify-center py-6 text-n-slate-11"
      >
        <Spinner />
      </div>
      <template v-else-if="reportData">
        <div class="grid grid-cols-2 gap-3">
          <div class="flex flex-col gap-1 p-4 rounded-lg bg-n-alpha-2">
            <span class="text-xs font-medium text-n-slate-10">
              {{ t('CAMPAIGN.API_CHANNEL.REPORT.TOTAL_CONTACTS') }}
            </span>
            <span class="text-2xl font-semibold text-n-slate-12">
              {{ reportData.total_contacts }}
            </span>
          </div>
          <div class="flex flex-col gap-1 p-4 rounded-lg bg-n-alpha-2">
            <span class="text-xs font-medium text-n-slate-10">
              {{ t('CAMPAIGN.API_CHANNEL.REPORT.MESSAGES_SENT') }}
            </span>
            <span class="text-2xl font-semibold text-n-teal-11">
              {{ reportData.messages_sent }}
            </span>
          </div>
          <div class="flex flex-col gap-1 p-4 rounded-lg bg-n-alpha-2">
            <span class="text-xs font-medium text-n-slate-10">
              {{ t('CAMPAIGN.API_CHANNEL.REPORT.MESSAGES_FAILED') }}
            </span>
            <span class="text-2xl font-semibold text-n-ruby-11">
              {{ reportData.messages_failed }}
            </span>
          </div>
          <div class="flex flex-col gap-1 p-4 rounded-lg bg-n-alpha-2">
            <span class="text-xs font-medium text-n-slate-10">
              {{ t('CAMPAIGN.API_CHANNEL.REPORT.STATUS') }}
            </span>
            <span class="text-base font-semibold text-n-slate-12">
              {{ statusLabel }}
            </span>
          </div>
        </div>
      </template>
    </div>
  </Dialog>
</template>
