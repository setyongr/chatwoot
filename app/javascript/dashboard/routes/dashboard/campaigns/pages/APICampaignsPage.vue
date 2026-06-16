<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import APICampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/APICampaign/APICampaignDialog.vue';
import APICampaignReportDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/APICampaign/APICampaignReportDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import APICampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/APICampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showAPICampaignDialog, toggleAPICampaignDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);
const reportDialogRef = ref(null);

const APICampaigns = computed(() => getters['campaigns/getAPICampaigns'].value);

const hasNoAPICampaigns = computed(
  () => APICampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};

const handleReport = campaign => {
  selectedCampaign.value = campaign;
  reportDialogRef.value?.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.API_CHANNEL.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.API_CHANNEL.NEW_CAMPAIGN')"
    @click="toggleAPICampaignDialog()"
    @close="toggleAPICampaignDialog(false)"
  >
    <template #action>
      <APICampaignDialog
        v-if="showAPICampaignDialog"
        @close="toggleAPICampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoAPICampaigns"
      :campaigns="APICampaigns"
      :is-api-type="true"
      @delete="handleDelete"
      @report="handleReport"
    />
    <APICampaignEmptyState
      v-else
      :title="t('CAMPAIGN.API_CHANNEL.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.API_CHANNEL.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
    <APICampaignReportDialog
      ref="reportDialogRef"
      :campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
