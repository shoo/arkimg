<template>
  <div class="p-6 bg-white rounded-lg shadow-md">
    <h3 class="text-xl font-semibold mb-4">ファイル情報</h3>

    <div v-if="selectedItem !== null" class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
        <label for="filename" class="block text-sm font-medium text-gray-700">ファイル名:</label>
        <div class="flex flex-col">
          <input
          type="text"
          id="filename"
          v-model="editingMetadata.name"
          :disabled="!isEditing"
            class="block w-full rounded-md border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
            :class="{ 'border-red-500': validationErrors.filename }"
        />
          <div v-if="validationErrors.filename" class="text-sm text-red-600 mt-1">
            {{ validationErrors.filename }}
          </div>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
        <span class="text-sm font-medium text-gray-700">ファイルサイズ:</span>
        <span class="text-sm text-gray-900">{{ formatFileSize(arkImgState.secretItems.value[selectedItem!].data.length) }}</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
        <label for="comment" class="block text-sm font-medium text-gray-700">コメント:</label>
        <textarea
          id="comment"
          v-model="editingMetadata.comment"
          :disabled="!isEditing"
          class="block w-full rounded-md border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm resize-y"
          rows="3"
        ></textarea>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <span class="text-sm font-medium text-gray-700">作成日時:</span>
        <span class="text-sm text-gray-900">{{ editingMetadata.modified.toLocaleString() }}</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <span class="text-sm font-medium text-gray-700">MIMEタイプ:</span>
        <span class="text-sm text-gray-900">{{ editingMetadata.mime }}</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
        <span class="text-sm font-medium text-gray-700">署名検証:</span>
        <span class="flex items-center gap-2" :class="signatureStatusClass">
          <svg v-if="signatureStatus === 'verified'" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="green" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
          </svg>
          <svg v-else-if="signatureStatus === 'failed'" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="red" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M8 12h8M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          <span class="text-sm font-semibold">
            {{ signatureStatus === 'verified' ? '検証済み' : signatureStatus === 'failed' ? '検証失敗' : '未検証' }}
          </span>
        </span>
      </div>

      <div class="flex justify-start space-x-4" v-if="isEditing">
        <button @click="saveMetadata" :disabled="!hasChanges" class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:bg-indigo-400 disabled:cursor-not-allowed">
          保存
        </button>
        <button @click="cancelEditing" class="inline-flex justify-center rounded-md border border-gray-300 bg-white py-2 px-4 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
          キャンセル
        </button>
      </div>
      <button v-else @click="startEditing" class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
        編集
      </button>
    </div>
    <div v-else class="text-center py-8 text-gray-500 italic">
      データを選択してください
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, inject } from 'vue';
import type { ArkImgState } from '@/types/arkimg';
import type { NotificationManager } from '@/types/ui'
import { decodeKeyInfo } from '@/utils/misc';
const arkImgState = inject<ArkImgState>('arkImgState')!;
const notificationManager = inject<NotificationManager>('notificationManager')!;
const selectedItem = computed(() => arkImgState.selectedItem.value);

interface ArkImgItem {
  name: string;
  comment: string;
  modified: Date;
  mime: string;
  privkey?: string;
  isSignatureValid?: boolean;
}
const isEditing = ref(false);
const editingMetadata = ref<ArkImgItem>({
  name: '',
  comment: '',
  modified: new Date,
  mime: '',
  privkey: undefined,
  isSignatureValid: undefined,
});
const validationErrors = ref<{ filename?: string }>({});
const hasChanges = ref(false);

const signatureStatus = computed<'verified' | 'failed' | 'unverified'>(() => {
  if (!selectedItem.value) return 'unverified'; // 初期状態
  return 'unverified';
});

const signatureStatusClass = computed<string>(() => {
  switch (signatureStatus.value) {
    case 'verified':
      return 'text-green-600';
    case 'failed':
      return 'text-red-600';
    default:
      return 'text-gray-500';
  }
});

const cancelEditing = (): void => {
  if (hasChanges.value) {
    // TODO: モーダルを表示して確認する
    resetEditingState(selectedItem.value);
  }
  isEditing.value = false;
};

const saveMetadata = (): void => {
  if (validateMetadata()) {
    const index = arkImgState.selectedItem.value ?? -1;
    if (index !== -1) {
      arkImgState.updateItem(index, {
        data: arkImgState.secretItems.value[index].data,
        name: editingMetadata.value.name,
        mime: editingMetadata.value.mime,
        comment: editingMetadata.value.comment,
        modified: new Date(editingMetadata.value.modified),
        prvkey: editingMetadata.value.privkey ? decodeKeyInfo(editingMetadata.value.privkey) : undefined,
      });
      isEditing.value = false;
      hasChanges.value = false;
      notificationManager.notify('メタデータを保存しました', 'success');
    } else {
      notificationManager.notify('保存に失敗しました', 'error');
    }
  }
};

const validateMetadata = (): boolean => {
  validationErrors.value = {};
  let isValid = true;

  if (!editingMetadata.value.name) {
    validationErrors.value.filename = 'ファイル名を入力してください';
    isValid = false;
  }

  return isValid;
};

const resetEditingState = (idx: number | null): void => {
  isEditing.value = false;
  hasChanges.value = false;
  validationErrors.value = {};
  if (idx !== null) {
    const itm = arkImgState.secretItems.value[idx];
    editingMetadata.value = {
      name: itm.name || '',
      mime: itm.mime || '',
      modified: itm.modified ? itm.modified: new Date,
      comment: itm.comment || ''
    };
  } else {
    editingMetadata.value = { name: '', mime: '', modified: new Date, comment: '' };
  }
};

const formatFileSize = (size: number): string => {
  if (size < 1024) {
    return size + ' B';
  } else if (size < 1024 * 1024) {
    return (size / 1024).toFixed(2) + ' KB';
  } else if (size < 1024 * 1024 * 1024) {
    return (size / (1024 * 1024)).toFixed(2) + ' MB';
  } else {
    return (size / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
  }
};

watch(selectedItem, (newItem) => {
  if (newItem !== null) {
    resetEditingState(newItem);
  } else {
    resetEditingState(null);
  }
}, { immediate: true });
const startEditing = (): void => {
  isEditing.value = true;
};

watch(editingMetadata, () => {
  if (selectedItem.value !== null) {
    hasChanges.value =
      editingMetadata.value.name !== arkImgState.secretItems.value[selectedItem.value].name ||
      editingMetadata.value.comment !== arkImgState.secretItems.value[selectedItem.value].comment;
  } else {
    hasChanges.value = false;
  }
}, { deep: true });
</script>
