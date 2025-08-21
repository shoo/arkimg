<template>
  <div class="h-svh w-svw">
    <MainView />
    <Notification :notifications="notifications" />
    <Modal :options="modalOptions" @close="closeModal" />
  </div>
</template>

<script setup lang="ts">
import { provide, ref } from 'vue'
import MainView from '@/components/MainView.vue'
import Notification from '@/components/Notification.vue'
import Modal from '@/components/Modal.vue'
import type { NotificationMessage, NotificationManager, ModalController } from '@/types/ui' // Corrected based on design-api.md
import type { ModalOptions } from '@/types/ui'

const notifications = ref<NotificationMessage[]>([])
const modalOptions = ref<ModalOptions | null>(null)

const notify = (message: string, type: 'success' | 'error' | 'info', title?: string, timeout?: number) => {
  const id : number = Date.now();
  notifications.value.push({
    id: id,
    title: title,
    message: message,
    type: type,
    timeout: timeout
  });
};

const openModal = (options: ModalOptions) => {
  modalOptions.value = options
};

const closeModal = () => {
  modalOptions.value = null
};

provide<NotificationManager>('notificationManager', {
  notify,
} as NotificationManager);

provide<ModalController>('modalController', {
  openModal,
  closeModal,
} as ModalController);
</script>

<style scoped>
</style>
