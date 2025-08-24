<template>
  <Teleport to="body">
    <!-- オーバーレイ -->
    <Transition
      name="modal"
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isVisible && options"
        class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
        @click="handleOverlayClick"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="options.title ? 'modal-title' : undefined"
        :aria-describedby="options.message ? 'modal-description' : undefined"
      >
        <!-- モーダルダイアログ -->
        <Transition
          name="modal-dialog"
          enter-active-class="transition duration-200 ease-out"
          enter-from-class="opacity-0 scale-95 translate-y-4"
          enter-to-class="opacity-100 scale-100 translate-y-0"
          leave-active-class="transition duration-150 ease-in"
          leave-from-class="opacity-100 scale-100 translate-y-0"
          leave-to-class="opacity-0 scale-95 translate-y-4"
        >
          <div
            v-if="isVisible && options"
            ref="modalDialogRef"
            id="ModalDialog"
            class="bg-white rounded-lg shadow-xl max-w-lg w-full max-h-[90vh] overflow-auto"
            @click.stop
            tabindex="-1"
          >
            <!-- モーダル内容 -->
            <div class="p-6 sm:p-8">
              <!-- タイトル -->
              <h2
                v-if="options.title"
                id="modal-title"
                class="text-xl sm:text-2xl font-semibold text-gray-900 mb-4"
              >
                {{ options.title }}
              </h2>

              <!-- メッセージ -->
              <div
                v-if="options.message"
                id="modal-description"
                class="text-gray-700 mb-6"
                :class="{ 'mb-4': !options.title }"
              >
                {{ options.message }}
              </div>

              <!-- カスタムコンポーネント -->
              <component
                v-if="options.component"
                :is="options.component"
                v-bind="options.props"
                class="mb-6"
              />
            </div>

            <!-- ボタンエリア -->
            <div class="px-6 pb-6 sm:px-8 sm:pb-8">
              <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <!-- キャンセルボタン -->
                <button
                  v-if="options.cancelText !== null"
                  ref="cancelButtonRef"
                  type="button"
                  id="CancelButton"
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  :disabled="isProcessing"
                  @click="handleCancel"
                >
                  {{ options.cancelText || 'キャンセル' }}
                </button>

                <!-- 確認ボタン -->
                <button
                  v-if="options.confirmText !== null"
                  ref="confirmButtonRef"
                  type="button"
                  id="ConfirmButton"
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                  :disabled="isProcessing"
                  @click="handleConfirm"
                >
                  <!-- ローディングスピナー -->
                  <svg
                    v-if="isProcessing"
                    class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    />
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    />
                  </svg>
                  {{ options.confirmText || 'OK' }}
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch, nextTick, onMounted, onUnmounted, type Ref } from 'vue';
import type { ModalOptions } from '@/types/ui';

// Props
interface Props {
  options: ModalOptions | null;
}

const props = defineProps<Props>();

// Emits
const emit = defineEmits<{
  close: [];
}>();

// 内部状態
const isVisible: Ref<boolean> = ref(false);
const isProcessing: Ref<boolean> = ref(false);

// DOM参照
const modalDialogRef = ref<HTMLElement | null>(null);
const confirmButtonRef = ref<HTMLButtonElement | null>(null);
const cancelButtonRef = ref<HTMLButtonElement | null>(null);

// フォーカス可能な要素を取得
const getFocusableElements = (container: HTMLElement): HTMLElement[] => {
  const focusableSelectors = [
    'button',
    '[href]',
    'input',
    'select', 
    'textarea',
    '[tabindex]:not([tabindex="-1"])',
    '[contenteditable="true"]'
  ].join(', ');
  
  return Array.from(container.querySelectorAll(focusableSelectors))
    .filter((el): el is HTMLElement => {
      const element = el as HTMLElement;
      return element.tabIndex !== -1 && 
             element.offsetWidth > 0 && 
             element.offsetHeight > 0;
    });
};

// フォーカストラップの実装
let lastFocusedElement: HTMLElement | null = null;
let focusableElements: HTMLElement[] = [];

const trapFocus = (event: KeyboardEvent) => {
  if (!modalDialogRef.value || !isVisible.value) {
    return;
  }
  
  if (event.key === 'Tab') {
    focusableElements = getFocusableElements(modalDialogRef.value);
    
    if (focusableElements.length === 0) {
      return;
    }
    
    const firstFocusable = focusableElements[0];
    const lastFocusable = focusableElements[focusableElements.length - 1];
    
    if (event.shiftKey) {
      // Shift + Tab
      if (document.activeElement === firstFocusable) {
        event.preventDefault();
        lastFocusable.focus();
      }
    } else {
      // Tab
      if (document.activeElement === lastFocusable) {
        event.preventDefault();
        firstFocusable.focus();
      }
    }
  }
};

// Escキーでモーダルを閉じる
const handleEscKey = (event: KeyboardEvent) => {
  if (event.key === 'Escape' && isVisible.value && !isProcessing.value) {
    handleCancel();
  }
};

// オーバーレイクリック処理
const handleOverlayClick = () => {
  if (!isProcessing.value) {
    handleCancel();
  }
};

// 確認ボタン処理
const handleConfirm = async () => {
  if (!props.options?.onConfirm || isProcessing.value) return;
  
  try {
    isProcessing.value = true;
    await props.options.onConfirm();
    closeModal();
  } catch (error) {
    console.error('Modal confirm handler error:', error);
  } finally {
    isProcessing.value = false;
  }
};

// キャンセルボタン処理
const handleCancel = async () => {
  if (isProcessing.value) return;
  
  try {
    if (props.options?.onCancel) {
      props.options.onCancel();
    }
    closeModal();
  } catch (error) {
    console.error('Modal cancel handler error:', error);
    closeModal(); // エラーが発生してもモーダルは閉じる
  }
};

// モーダルを閉じる
const closeModal = () => {
  isVisible.value = false;
  isProcessing.value = false;
  
  // フォーカスを元の要素に戻す
  if (lastFocusedElement) {
    lastFocusedElement.focus();
    lastFocusedElement = null;
  }
  
  emit('close');
};

// モーダル表示時の処理
const showModal = async () => {
  // 現在のフォーカス要素を記録
  lastFocusedElement = document.activeElement as HTMLElement;
  
  isVisible.value = true;
  
  await nextTick();
  
  // フォーカスを設定
  if (modalDialogRef.value) {
    focusableElements = getFocusableElements(modalDialogRef.value);
    if (focusableElements.length > 0) {
      // 確認ボタンがあればそれに、なければ最初のフォーカス可能要素に
      const initialFocus = confirmButtonRef.value || focusableElements[0];
      initialFocus.focus();
    } else {
      // フォーカス可能要素がない場合はモーダル自体にフォーカス
      modalDialogRef.value.focus();
    }
  }
};

// optionsの変化を監視
watch(
  () => props.options,
  (newOptions) => {
    if (newOptions) {
      showModal();
    } else {
      closeModal();
    }
  },
  { immediate: true }
);

// ライフサイクル
onMounted(() => {
  document.addEventListener('keydown', trapFocus);
  document.addEventListener('keydown', handleEscKey);
  
  // 初期表示
  if (props.options) {
    showModal();
  }
});

onUnmounted(() => {
  document.removeEventListener('keydown', trapFocus);
  document.removeEventListener('keydown', handleEscKey);
  
  // フォーカスを復元
  if (lastFocusedElement) {
    lastFocusedElement.focus();
  }
});
</script>

<style scoped>
</style>
