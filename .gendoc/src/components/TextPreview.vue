<template>
  <div class="bg-white rounded-lg shadow-sm h-full w-full flex flex-col">
    <div v-if="isLoading" class="flex-1 flex items-center justify-center text-gray-500 text-lg">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mr-2"></div>
      読み込み中...
    </div>
    <div v-else-if="isError" class="flex-1 flex items-center justify-center text-red-600 text-lg text-center">
      テキストの復号に失敗しました。
    </div>
    <div v-else-if="!decryptedText || decryptedText.length === 0" class="flex-1 flex items-center justify-center text-gray-500 text-lg text-center">
      表示できる内容がありません。
    </div>
    <pre v-else class="font-mono text-sm w-full h-full text-left bg-gray-50 p-1 text-gray-800 overflow-auto">{{ decryptedText }}</pre>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

const props = defineProps<{
  decryptedText: string
}>();

const isLoading = ref(false);
const isError = ref(false);

const processText = () => {
  isLoading.value = true;
  isError.value = false;

  setTimeout(() => {
    if (typeof props.decryptedText !== 'string') {
      isError.value = true;
    }
    isLoading.value = false;
  }, 0);
};

watch(
  () => props.decryptedText,
  () => {
    processText();
  },
  { immediate: true }
);
</script>

<style scoped>
</style>
