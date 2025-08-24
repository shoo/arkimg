<template>
  <div class="flex justify-center items-center w-full h-full border border-gray-300">
    <div v-if="isLoading" class="text-base text-gray-600">
      Loading...
    </div>
    <div v-else-if="isError" class="text-base text-red-500">
      Failed to display image.
    </div>
    <img v-else-if="imageUrl" :src="imageUrl" :alt="fileName" class="max-w-full max-h-full object-contain" />
    <div v-else class="text-base text-gray-400">
      No Image Data
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onUnmounted } from 'vue';

const props = defineProps<{
  decryptedImageData: Uint8Array;
  fileName?: string;
}>();

const imageUrl = ref<string | null>(null);
const isLoading = ref<boolean>(false);
const isError = ref<boolean>(false);

const createImageURL = () => {
  if (!props.decryptedImageData) {
    if (imageUrl.value !== null) {
      URL.revokeObjectURL(imageUrl.value);
      imageUrl.value = null;
    }
    return;
  }
  isLoading.value = true;
  isError.value = false;

  try {
    if (!(props.decryptedImageData instanceof Uint8Array)) {
      throw Error();
    }
    const blob = new Blob([props.decryptedImageData.slice(0)]);
    if (imageUrl.value !== null) {
      URL.revokeObjectURL(imageUrl.value);
    }
    imageUrl.value = URL.createObjectURL(blob);
  } catch (error) {
    console.error("Error creating image URL:", error);
    if (imageUrl.value !== null) {
      URL.revokeObjectURL(imageUrl.value);
      imageUrl.value = null;
    }
    isError.value = true;
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.decryptedImageData,
  (_) => {
    if (imageUrl.value) {
      URL.revokeObjectURL(imageUrl.value);
      imageUrl.value = null;
    }
    createImageURL();
  },
  { immediate: true }
);

onUnmounted(() => {
  if (imageUrl.value) {
    URL.revokeObjectURL(imageUrl.value);
    imageUrl.value = null;
  }
});
</script>

<style scoped>
</style>
