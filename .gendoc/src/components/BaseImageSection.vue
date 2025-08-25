<template>
  <div class="bg-white shadow rounded-lg p-4 flex flex-col relative">
    <div v-if="isLoading" class="flex flex-col items-center justify-center h-48">
      <svg class="animate-spin h-10 w-10 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="mt-2 text-gray-500">読み込み中...</p>
    </div>
    <div v-else-if="isImageLoadingError" class="flex flex-col items-center justify-center h-48">
      <p class="text-red-500">画像の読み込みに失敗しました。</p>
      <button @click="retryLoadImage" class="mt-2 bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded" id="RetryButton">再試行</button>
    </div>
    <div v-else class="flex flex-col items-center justify-center">
      <div
        @dragover.prevent="handleDragOver"
        @dragleave.prevent="handleDragLeave"
        @drop.prevent="handleDrop"
        :class="{'w-full border-2 border-dashed border-gray-400 rounded-lg': !baseImage}"
      >
        <!-- ベースイメージ未選択の場合 ファイル入力欄を作成 -->
        <label v-if="!baseImage" for="image-input" class="cursor-pointer flex flex-col items-center justify-center">
          <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
          </svg>
          <p class="text-gray-500">画像をドラッグ＆ドロップ</p>
          <p class="text-gray-500">または</p>
          <span class="text-blue-500">ファイルを選択</span>
        </label>
        <input id="image-input" type="file" class="hidden" @change="handleFileSelect">
        <!-- ベースイメージ未選択の場合 URL入力欄を作成 -->
        <div v-if="!baseImage" class="w-full p-4 flex flex-col items-center justify-center mt-3 mb-3">
          <label for="url-input" class="text-lg font-semibold text-left w-full text-gray-500">またはURLを入力:</label>
          <div class="flex w-full">
            <input
              id="url-input"
              type="url"
              placeholder="Enter URL..."
              class="flex-grow p-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              v-model="urlInput"
            />
            <button @click="downloadImage" class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded-r-md">Download</button>
          </div>
        </div>
      </div>
      <img v-if="baseImage" :src="imageUrl" alt="Base Image" class="max-h-128 max-w-full object-contain" />
      <div v-if="baseImage" class="absolute top-6 right-6 z-10 cursor-pointer': true" @click="unloadBaseImage" id="UnloadButton">
        <svg class="w-6 h-6 text-gray-500 hover:text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </div>
    </div>
    <SettingsSection v-if="!responsiveContext?.isMobile?.value" />
  </div>
</template>

<script setup lang="ts">
import { ref, onUnmounted, inject, watch, onMounted } from 'vue';
import type { ArkImgState } from '@/types/arkimg';
import type { ResponsiveContext, NotificationManager } from '@/types/ui';
import { loadParameter, loadImage as loadArkImg } from '@/arkimg/utils';
import SettingsSection from '@/components/SettingsSection.vue';
import type { CryptoContext } from '@/types/crypto';
import { getMimeTypeFromExtension } from '@/utils/misc';

const arkImgState         = inject<ArkImgState>('arkImgState')!;
const responsiveContext   = inject<ResponsiveContext>('responsiveContext')!;
const notificationManager = inject<NotificationManager>('notificationManager')!;
const cryptoContext       = inject<CryptoContext>('cryptoContext')!;

const isLoading = ref(false);
const isDragging = ref(false);
const isImageLoadingError = ref(false);
const imageUrl = ref('');
const urlInput = ref('');
const baseImage = arkImgState.baseImage;

watch(baseImage, (newBaseImage: Uint8Array | null) => {
  if (newBaseImage) {
    loadImage(newBaseImage)
  } else {
    imageUrl.value = ''
  }
})

const loadImage = (imageSource: Uint8Array | null) => {
  if (!imageSource) {
    return;
  }
  isLoading.value = true;
  const baseImageFileName = arkImgState.baseImageFileName.value!;
  const baseImageMIME = arkImgState.baseImageMIME.value ?? getMimeTypeFromExtension(baseImageFileName);
  if (arkImgState.secretItems.value) {
    arkImgState.secretItems.value.length = 0;
  }
  (async () => {
    try {
      const arkimg = await loadArkImg(imageSource, baseImageMIME,
        cryptoContext.key.value || undefined,
        cryptoContext.iv.value || undefined,
        cryptoContext.pubkey.value || undefined);
      for (let i = 0; i < arkimg.getSecretItemCount(); ++i) {
        const md = arkimg.getMetadataItem(i);
        arkImgState.secretItems.value.push({
          data: arkimg.getSecretItem(i),
          name: md?.name,
          mime: md?.mime,
          comment: md?.comment,
          isSignVerified: md?.sign ? arkimg.isVerified(i) : undefined,
          modified: md?.modified ? new Date(md.modified) : undefined,
        });
      }
      const blob = new Blob([arkimg.getBaseImage(baseImageMIME).buffer as ArrayBuffer]);
      imageUrl.value = URL.createObjectURL(blob);
    } catch (e) {
      notificationManager.notify("ベース画像の読み込みに失敗しました。", 'error');
      unloadBaseImage();
    }
    isLoading.value = false;
  })();
}

const handleDragOver = () => {
  isDragging.value = true;
};

const handleDragLeave = () => {
  isDragging.value = false;
};

const handleDrop = (event: DragEvent) => {
  isDragging.value = false;
  if (!event.dataTransfer) return;

  const file = event.dataTransfer.files[0];
  if (file && file.type.startsWith('image/')) {
    const reader = new FileReader();
    reader.onload = (e) => {
      if (e.target?.result) {
        arkImgState.baseImage.value = new Uint8Array(e.target.result as ArrayBuffer);
        arkImgState.baseImageFileName.value = file.name;
        arkImgState.baseImageMIME.value = file.type;
        notificationManager.notify('ファイルの読み込みに成功しました', 'success');
      }
    };
    reader.onerror = () => {
      notificationManager.notify('ファイルの読み込みに失敗しました', 'error');
    };
    reader.readAsArrayBuffer(file);
  } else {
    notificationManager.notify('画像ファイルを選択してください', 'error');
  }
}

const handleFileSelect = (event: Event) => {
  const target = event.target as HTMLInputElement;
  if (!target.files) return;

  const file = target.files[0];
  if (file && file.type.startsWith('image/')) {
    const reader = new FileReader();
    reader.onload = (e) => {
      if (e.target?.result) {
        arkImgState.baseImage.value = new Uint8Array(e.target.result as ArrayBuffer);
        arkImgState.baseImageFileName.value = file.name;
        arkImgState.baseImageMIME.value = file.type;
        notificationManager.notify('ファイルの読み込みに成功しました', 'success');
      }
    };
    reader.onerror = () => {
      notificationManager.notify('ファイルの読み込みに失敗しました', 'error');
    };
    reader.readAsArrayBuffer(file);
  } else {
    notificationManager.notify('画像ファイルを選択してください', 'error');
  }
};

const downloadImage = async () => {

  notificationManager.notify('ダウンロードを開始します...', 'info');
  try {
    const urlToDownload = urlInput.value.trim();
    const urlHash = urlToDownload.split('#').length == 2 ? urlToDownload.split('#')[1] : undefined;
    if (urlHash && urlHash.length > 0) {
      const keyInfo = loadParameter(urlHash);
      if (keyInfo.key.length > 0) {
        cryptoContext.key.value = keyInfo.key;
      }
      if (keyInfo.iv && keyInfo.iv.length > 0) {
        cryptoContext.iv.value = keyInfo.iv;
      }
      if (keyInfo.pubkey && keyInfo.pubkey.length > 0) {
        cryptoContext.pubkey.value = keyInfo.pubkey;
      }
    }
    const response = await fetch(urlToDownload);
    if (!response.ok) {
      throw new Error('Network response was not ok');
    }
    const blob = await response.blob();
    const reader = new FileReader();
    reader.onload = (e) => {
      if (e.target?.result) {
        arkImgState.baseImage.value = new Uint8Array(e.target.result as ArrayBuffer);
        arkImgState.baseImageFileName.value = urlToDownload.split('/').pop() || 'downloaded_image';
        arkImgState.baseImageMIME.value = blob.type;
        notificationManager.notify('画像をダウンロードしました', 'success');
      }
    };
    reader.onerror = () => {
      notificationManager.notify('画像の読み込みに失敗しました', 'error');
    };
    reader.readAsArrayBuffer(blob);
  } catch (error) {
    notificationManager.notify('画像のダウンロードに失敗しました', 'error');
  }
};

const retryLoadImage = () => {
  if (arkImgState.baseImage && arkImgState.baseImage.value) {
    loadImage(arkImgState.baseImage.value);
  }
};

const unloadBaseImage = () => {
  if (arkImgState.baseImage?.value || arkImgState.baseImageFileName?.value) {
    arkImgState.baseImage.value = null;
    arkImgState.baseImageFileName.value = null;
    arkImgState.baseImageMIME.value = null;
    notificationManager.notify('ベース画像をアンロードしました', 'success')
  }
};

onMounted(() => {
  if (arkImgState.baseImage && arkImgState.baseImage.value && imageUrl.value == '') {
    loadImage(arkImgState.baseImage.value);
  } else {
    unloadBaseImage();
  }
});

onUnmounted(() => {
  if (imageUrl.value) {
    URL.revokeObjectURL(imageUrl.value);
    imageUrl.value = '';
  }
});
</script>

<style scoped>
</style>
