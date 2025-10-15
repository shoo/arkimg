<template>
  <div :class="{'flex flex-col min-h-max w-max max-w-full mx-auto': isMobile, 'flex flex-row h-svh w-svw py-10 justify-center': !isMobile}">
    <!-- PC-Left/Mobile-Top: BaseImageSection (and CryptoKeyInput for PC) -->
    <BaseImageSection
      :class="{
        'w-full': isMobile || (!arkImgState.baseImage.value),
        'w-1/2': !isMobile && (arkImgState.baseImage.value && arkImgState.selectedItem.value === null),
        'w-1/4': !isMobile && (arkImgState.baseImage.value && arkImgState.selectedItem.value !== null),
        'p-4 bg-gray-50 flex-shrink-0 max-w-xl': true,
        'overflow-y-auto': !isMobile
      }"
    />

    <!-- PC-Center/Mobile-Middle: SecretDataListSection -->
    <SecretDataListSection
      :class="{
        'w-full': isMobile,
        'w-1/2': !isMobile && arkImgState.selectedItem.value === null,
        'w-1/4': !isMobile && arkImgState.selectedItem.value !== null,
        'p-4 bg-gray-50 overflow-y-auto max-w-xl': true,
        'flex-shrink-0': !isMobile,
        'flex-grow': isMobile,
        'hidden': !arkImgState.baseImage.value
      }"
    />

    <!-- PC-Right/Mobile-Hidden: PreviewSection -->
    <PreviewSection
      :class="{
        'w-1/2': true,
        'p-4 bg-gray-50 flex-shrink-0 overflow-y-auto': true,
        'hidden': !arkImgState.baseImage.value || arkImgState.selectedItem.value === null || isMobile
      }"
    />

    <!-- PC-Hidden/Mobile-Bottom: SettingsSection (CryptoKeyInput for Mobile) -->
    <SettingsSection
      :class="{
        'w-full': true,
        'p-4 bg-gray-50 flex-shrink-0': true,
        'hidden': !isMobile || !arkImgState.baseImage.value
      }"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, provide, watch } from 'vue';
import type { Ref } from 'vue';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { ResponsiveContext } from '@/types/ui';
import type { CryptoContext } from '@/types/crypto';

// Components
import BaseImageSection from '@/components/BaseImageSection.vue';
import SecretDataListSection from '@/components/SecretDataListSection.vue';
import PreviewSection from '@/components/PreviewSection.vue';
import SettingsSection from '@/components/SettingsSection.vue';

// --- Crypto Context ---
const key: Ref<Uint8Array | null> = ref(null);
const iv: Ref<Uint8Array | null> = ref(null);
const prvkey: Ref<Uint8Array | null> = ref(null);
const pubkey: Ref<Uint8Array | null> = ref(null);

const isKeyValid = () => {
  // Basic validation: AES key must be present for most operations
  return key.value !== null && key.value.length > 0;
};

const cryptoContext: CryptoContext = {
  key,
  iv,
  prvkey,
  pubkey,
  isKeyValid,
};
provide('cryptoContext', cryptoContext);

// --- ArkImg State ---
const baseImage: Ref<Uint8Array | null> = ref(null);
const baseImageFileName: Ref<string | null> = ref(null);
const baseImageMIME: Ref<string | null> = ref(null);
const secretItems: Ref<SecretItem[]> = ref([]);
const selectedItem: Ref<number | null> = ref(null);

const updateItem = (index: number, item: SecretItem) => {
  if (index >= 0 && index < secretItems.value.length) {
    secretItems.value[index] = { ...secretItems.value[index], ...item };
  }
};

const addItem = (item: SecretItem) => {
  secretItems.value.push(item);
};

const removeItem = (index: number) => {
  if (index >= 0 && index < secretItems.value.length) {
    secretItems.value.splice(index, 1);
    if (selectedItem.value === index) {
      selectedItem.value = null; // Deselect if removed
    } else if (selectedItem.value !== null && selectedItem.value > index) {
      selectedItem.value--; // Adjust selected index if an item before it was removed
    }
  }
};

const arkImgState: ArkImgState = {
  baseImage,
  baseImageFileName,
  baseImageMIME,
  secretItems,
  selectedItem,
  addItem,
  updateItem,
  removeItem,
};
provide('arkImgState', arkImgState);

// --- Responsive Context ---
const isMobile: Ref<boolean> = ref(false);

const checkMobile = () => {
  isMobile.value = window.innerWidth <= 768; // Tailwind's 'md' breakpoint
};

onMounted(() => {
  checkMobile();
  window.addEventListener('resize', checkMobile);
});

onUnmounted(() => {
  window.removeEventListener('resize', checkMobile);
});

const responsiveContext: ResponsiveContext = {
  isMobile,
};
provide('responsiveContext', responsiveContext);

// Watch for changes in baseImage to reset selected item
watch(baseImage, (newVal) => {
  if (!newVal) {
    secretItems.value = [];
    selectedItem.value = null;
  }
});

// Watch for changes in secretItems to deselect if empty or out of bounds
watch(secretItems, (newVal) => {
  if (selectedItem.value !== null && (selectedItem.value >= newVal.length || newVal.length === 0)) {
    selectedItem.value = null;
  }
}, { deep: true });
</script>

<style scoped>
</style>
