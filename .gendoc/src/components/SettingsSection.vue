<template>
  <div class="p-4 bg-white rounded-lg shadow-md space-y-4">
    <h2 class="text-xl font-bold text-gray-800 mb-4">設定</h2>

    <!-- 暗号鍵入力 -->
    <CryptoKeyInput />

    <!-- Action Buttons -->
    <div class="flex flex-row space-x-8 mt-8 justify-end">
      <button
        @click="downloadArkImg"
        id="CreateArkImgButton"
        :disabled="isProcessing || !canCreateArkImg"
        class="w-32 py-2 px-4 bg-blue-600 text-white font-semibold rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <span v-if="!isProcessing">作成</span>
        <span v-else>作成中...</span>
      </button>
      <!-- 他の操作ボタンはここに追加 -->
      <button
        @click="resetState"
        id="ResetButton"
        :disabled="isProcessing"
        class="w-32 py-2 px-4 bg-gray-300 text-gray-800 font-semibold rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        リセット
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, inject, computed, onMounted } from 'vue';
import CryptoKeyInput from '@/components/CryptoKeyInput.vue'; // CryptoKeyInputをインポート
import type { CryptoContext } from '@/types/crypto'; // 型定義をインポート
import type { NotificationManager } from '@/types/ui'; // 型定義をインポート
import type { ArkImgState } from '@/types/arkimg'; // 型定義をインポート
import { createArkImg, type ArkImgSecretItem } from '@/arkimg/utils';
import { getMimeTypeFromExtension } from '@/utils/misc';

// Inject Dependencies
const cryptoContext = inject<CryptoContext>('cryptoContext')!;
const arkImgState = inject<ArkImgState>('arkImgState')!;
const notificationManager = inject<NotificationManager>('notificationManager')!;

// Internal State
const urlInput = ref('');
const isProcessing = ref(false);
const validationErrors = ref<{ url?: string }>({});

// Computed Properties
const canCreateArkImg = computed(() => {
  // ArkImg作成に必要な条件をここに記述
  // 例: ベース画像が存在し、AES鍵と秘密鍵が有効であること
  return arkImgState.baseImage.value !== null && arkImgState.baseImageFileName.value !== null && cryptoContext.isKeyValid();
});

const downloadArkImg = async () => {
  isProcessing.value = true;
  notificationManager.notify('ArkImgファイルを作成中...', 'info');

  try {
    // ここにArkImgファイルを作成するロジックを実装
    // arkImgState.baseImage.value と arkImgState.encryptedItems.value を使用
    // cryptoContext.aesKey.value, cryptoContext.privateKey.value を使用して暗号化・署名
    const secrets: ArkImgSecretItem[] = [];
    for (const itm of arkImgState.secretItems.value) {
      secrets.push({
        data: itm.data,
        metadata: {
          name: itm.name,
          mime: itm.mime,
          comment: itm.comment,
          modified: itm.modified?.toISOString()
        },
        prvkey: cryptoContext.prvkey?.value || undefined
      });
    }
    const arkimgMimeType = arkImgState.baseImageMIME.value ?? getMimeTypeFromExtension(arkImgState.baseImageFileName.value!);
    const arkimgBinary = await createArkImg(
      arkImgState.baseImage.value!, arkimgMimeType, secrets,
      cryptoContext.key.value!, cryptoContext.iv?.value || undefined, cryptoContext.prvkey?.value || undefined
      );
    
    // 生成されたArkImgファイルをダウンロードする処理
    const dummyBlob = new Blob([arkimgBinary.buffer as ArrayBuffer], { type: arkimgMimeType });
    const url = URL.createObjectURL(dummyBlob);
    const a = document.createElement('a');
    a.href = url;
    a.download = arkImgState.baseImageFileName.value!;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    notificationManager.notify('ArkImgファイルが作成され、ダウンロードされました。', 'success');
  } catch (error: any) {
    notificationManager.notify('ArkImgファイルの作成に失敗しました: ' + error.message, 'error');
  } finally {
    isProcessing.value = false;
  }
};

const resetState = () => {
  urlInput.value = '';
  arkImgState.baseImage.value = null;
  arkImgState.secretItems.value = [];
  arkImgState.selectedItem.value = null;
  cryptoContext.key.value = null;
  cryptoContext.iv.value = null;
  cryptoContext.prvkey.value = null;
  cryptoContext.pubkey.value = null;
  validationErrors.value = {};
  notificationManager.notify('状態をリセットしました。', 'info');
};

onMounted(() => {
  // 初期ロード時にURL入力欄に何か設定したい場合はここに記述
  // if (!arkImgState.baseImage.value && !urlInput.value) {
  //   urlInput.value = 'https://example.com/default_image.png';
  //   handleUrlChange(); // デフォルト画像を自動ロードする例
  // }
});
</script>

<style scoped>
/* 必要に応じてTailwind以外のカスタムスタイルを追加 */
</style>
