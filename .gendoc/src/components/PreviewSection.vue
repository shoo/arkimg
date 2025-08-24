<template>
  <div class="flex-1 flex flex-col p-4 bg-white rounded-lg shadow-md overflow-hidden relative">
    <!-- Header: File Name & Signature Status -->
    <div class="mb-4 pb-2 border-b border-gray-200 flex items-center justify-between">
      <h2 class="text-xl font-bold text-gray-800 truncate mr-4" :title="displayFileName">
        {{ displayFileName }}
      </h2>
      <span
        v-if="signatureStatus === 'verified'"
        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
      >
        <svg
          class="-ml-0.5 mr-1.5 h-2 w-2 text-green-400"
          fill="currentColor"
          viewBox="0 0 8 8"
        >
          <circle cx="4" cy="4" r="3" />
        </svg>
        署名検証済み
      </span>
      <span
        v-else-if="signatureStatus === 'failed'"
        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
      >
        <svg
          class="-ml-0.5 mr-1.5 h-2 w-2 text-red-400"
          fill="currentColor"
          viewBox="0 0 8 8"
        >
          <circle cx="4" cy="4" r="3" />
        </svg>
        署名検証失敗
      </span>
      <span
        v-else-if="signatureStatus === 'not_signed'"
        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
      >
        <svg
          class="-ml-0.5 mr-1.5 h-2 w-2 text-gray-400"
          fill="currentColor"
          viewBox="0 0 8 8"
        >
          <circle cx="4" cy="4" r="3" />
        </svg>
        署名なし
      </span>
      <span
        v-else-if="signatureStatus === 'key_missing'"
        class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
      >
        <svg
          class="-ml-0.5 mr-1.5 h-2 w-2 text-yellow-400"
          fill="currentColor"
          viewBox="0 0 8 8"
        >
          <circle cx="4" cy="4" r="3" />
        </svg>
        検証鍵なし
      </span>
    </div>

    <!-- Preview Area -->
    <div class="flex-1 overflow-auto bg-gray-50 rounded-md p-2 mb-4 flex items-center justify-center text-gray-500">
      <ImagePreview
        v-if="isImageContent()"
        :decryptedImageData="(decryptedContent as Uint8Array)"
        :fileName="displayFileName"
      />
      <TextPreview
        v-else-if="isTextContent()"
        :decryptedText="(decryptedContent as string)"
        :fileName="displayFileName"
      />
      <div
        v-else-if="previewType === 'unsupported'"
        class="text-center p-4"
      >
        <p class="text-red-500 font-semibold mb-2">
          このデータの復号またはプレビューに失敗しました。
        </p>
        <p class="text-sm">
          正しい共通鍵が設定されているか、またはファイル形式がサポートされているかご確認ください。
        </p>
      </div>
      <div v-else class="text-center p-4">
        <p>プレビューするデータを選択してください。</p>
      </div>
    </div>

    <!-- Metadata Editor (Accordion) -->
    <div v-if="selectedSecretItem !== null" class="mt-4 border border-gray-200 rounded-md">
      <div
        class="flex items-center justify-between p-3 bg-gray-100 cursor-pointer"
        @click="isMetadataEditorOpen = !isMetadataEditorOpen"
      >
        <h3 class="text-lg font-semibold text-gray-700">メタデータ</h3>
        <svg
          :class="{ 'rotate-180': isMetadataEditorOpen }"
          class="w-5 h-5 text-gray-600 transform transition-transform duration-200"
          fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
      </div>
      <div v-show="isMetadataEditorOpen" class="p-3">
        <MetadataEditor />
      </div>
    </div>

    <div
      v-else-if="selectedSecretItem === null"
      class="flex-1 flex items-center justify-center text-gray-500"
    >
      <p>プレビューするデータを選択してください。</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, inject } from 'vue';
import ImagePreview from '@/components/ImagePreview.vue';
import TextPreview from '@/components/TextPreview.vue';
import MetadataEditor from '@/components/MetadataEditor.vue';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { CryptoContext } from '@/types/crypto';
import type { NotificationManager } from '@/types/ui';
import { getMimeTypeFromExtension } from '@/utils/misc';

function isImageMimeType(mime: string): boolean {
  return mime.startsWith('image/');
}

function isTextMimeType(mime: string): boolean {
  return mime.startsWith('text/')
    || mime === 'application/json'
    || mime === 'application/x-shellscript'
    || mime === 'application/x-bat'
    || mime === 'application/x-powershell'
    || mime === 'application/xml';
}

// Injects
const arkImgState = inject<ArkImgState>('arkImgState')!;
const cryptoContext = inject<CryptoContext>('cryptoContext')!;
const notificationManager = inject<NotificationManager>('notificationManager')!;
// Internal State
const previewType = ref<'image' | 'text' | 'unsupported' | null>(null);
const decryptedContent = ref<Uint8Array | string | null>(null);
const isMetadataEditorOpen = ref(false);


function isImageContent(): boolean {
  return previewType.value === 'image' && decryptedContent.value instanceof Uint8Array;
}

function isTextContent(): boolean {
  return previewType.value === 'text' && typeof decryptedContent.value === 'string';
}

// Computed Properties
const selectedSecretItem = computed<SecretItem | null>(() => {
  if (arkImgState.selectedItem.value !== null && arkImgState.secretItems.value[arkImgState.selectedItem.value]) {
    return arkImgState.secretItems.value[arkImgState.selectedItem.value];
  }
  return null;
});

const displayFileName = computed(() => {
  return selectedSecretItem.value?.name || '不明なファイル';
});

const signatureStatus = computed<
  'verified' | 'failed' | 'not_signed' | 'key_missing' | 'unknown'
>(() => {
  const item = selectedSecretItem.value;
  if (!item || !item.data) {
    return 'unknown'; // Data not available or selected
  }

  if (!item.isSignVerified) {
    return 'not_signed'; // No signature present on the item
  }

  if (!cryptoContext.pubkey.value) {
    return 'key_missing'; // Public key for verification is not provided
  }

  return item.isSignVerified ? 'verified' : 'failed';
});

// Functions
const decryptAndPreparePreview = async (item: SecretItem | null) => {
  if (!item) {
    decryptedContent.value = null;
    previewType.value = null;
    return;
  }

  decryptedContent.value = null;
  previewType.value = null;

  try {
    // Attempt decryption
    const decryptedData = item.data;
    // Determine preview type based on MIME or data content
    let mime = item.mime || item.name ? getMimeTypeFromExtension(item.name as string) : 'application/octet-stream';

    if (isImageMimeType(mime)) {
      decryptedContent.value = decryptedData;
      previewType.value = 'image';
    } else if (isTextMimeType(mime) && decryptedData !== null) {
      // Try to decode as text
      try {
        const textDecoder = new TextDecoder('utf-8');
        decryptedContent.value = textDecoder.decode(decryptedData);
        previewType.value = 'text';
      } catch (decodeError) {
        console.warn('Failed to decode as UTF-8 text, treating as unsupported:', decodeError);
        decryptedContent.value = null;
        previewType.value = 'unsupported';
      }
    } else {
      decryptedContent.value = null;
      previewType.value = 'unsupported';
    }
  } catch (e: any) {
    decryptedContent.value = null;
    previewType.value = 'unsupported';
    notificationManager.notify(`データのプレビューに失敗しました: ${e.message}`, 'error');
  }
};

// Watchers
watch(selectedSecretItem, (newItem) => {
  decryptAndPreparePreview(newItem);
}, { immediate: true }); // Run immediately on component mount
</script>

<style scoped>
/* Add specific styles for PreviewSection if needed */
</style>
