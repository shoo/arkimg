<template>
  <div class="secret-data-list-section h-full flex flex-col">
    <!-- セクションヘッダー -->
    <div class="flex-shrink-0 p-4 border-b border-gray-200">
      <h2 class="text-lg font-semibold text-gray-900">秘密データ一覧</h2>
    </div>

    <!-- メインコンテンツエリア -->
    <div class="flex-1 overflow-hidden" @click.self="clearSelection">
      <!-- データが存在しない場合の案内 -->
      <div 
        v-if="arkImgState.secretItems.value.length === 0"
        class="h-full flex items-center justify-center p-8"
      >
        <div class="text-center text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <p class="text-sm">秘密データが追加されていません</p>
          <p class="text-xs mt-1">下の追加エリアからファイルを追加してください</p>
        </div>
      </div>

      <!-- PC表示時：縦スクロールリスト -->
      <div v-else-if="!responsiveContext.isMobile.value" class="h-full overflow-y-auto" @click.self="clearSelection">
        <div class="p-2 space-y-3">
          <div
            v-for="(item, index) in arkImgState.secretItems.value"
            :key="index"
            class="secret-item bg-white rounded-lg border border-gray-200 p-0 cursor-pointer transition-all duration-200 hover:shadow-md"
            :class="{
              'ring-2 ring-blue-500 bg-blue-50': arkImgState.selectedItem.value === index,
              'border-red-300 bg-red-50': item.isSignVerified === false
            }"
            @click="selectItem(index)"
          >
            <div class="flex">
              <!-- 左側：アイコン -->
              <div class="flex flex-col h-18 w-9 min-w-0">
                <!-- 署名検証状態アイコン -->
                <div class="h-6">
                  <svg v-if="item.isSignVerified === true" class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  <svg v-else-if="item.isSignVerified === false" class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  <svg v-else class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                  </svg>
                </div>
      
                <!-- ファイルタイプアイコン -->
                <div class="h-6 w-9 flex justify-center">
                  <svg v-if="isImageFile(item.mime)" class="h-6 w-6 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <svg v-else-if="isTextFile(item.mime)" class="h-6 w-6 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <svg v-else class="h-6 w-6 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                  </svg>
                </div>
              </div>
      
              <!-- ファイル -->
              <div class="flex flex-col flex-1 min-w-0">
                <p class="my-3 text-sm font-medium text-gray-900 truncate">
                  {{ formatFileName(item.name || 'unnamed') }}
                </p>
                <div class="flex w-full">
                  <div class="grow">
                    <p class="text-xs text-gray-500">
                      {{ item.mime || 'unknown' }} • {{ formatFileSize(item.data.length) }}
                    </p>
                    <p v-if="item.comment" class="mt-1 text-xs text-gray-600 truncate">
                      {{ item.comment }}
                    </p>
                  </div>
                  <div class="ml-4 flex-shrink-0">
                    <button
                      @click.stop="confirmDelete(index)"
                      class="p-2 text-gray-400 hover:text-red-500 transition-colors duration-200"
                      :title="`${item.name || 'ファイル'}を削除`"
                    >
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>


      <!-- モバイル表示時：アコーディオンリスト -->
      <div v-else class="h-full overflow-y-auto" @click.self="clearSelection">
        <div class="divide-y divide-gray-200">
          <div
            v-for="(item, index) in arkImgState.secretItems.value"
            :key="index"
            class="secret-item-mobile"
          >
            <!-- アコーディオンヘッダー -->
            <div
              class="p-4 cursor-pointer hover:bg-gray-50 transition-colors duration-200"
              :class="{
                'bg-blue-50': expandedItemIndex === index,
                'bg-red-50': item.isSignVerified === false
              }"
              @click="toggleAccordion(index)"
            >
              <div class="flex items-center justify-between">
                <!-- 左側：ファイル情報 -->
                <div class="flex items-center min-w-0 flex-1">
                  <!-- 署名検証状態 + ファイルタイプアイコン -->
                  <div class="flex items-center space-x-2 flex-shrink-0 mr-3">
                    <svg v-if="item.isSignVerified === true" class="h-4 w-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                    <svg v-else-if="item.isSignVerified === false" class="h-4 w-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                    <svg v-else class="h-4 w-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>

                    <svg v-if="isImageFile(item.mime)" class="h-5 w-5 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <svg v-else-if="isTextFile(item.mime)" class="h-5 w-5 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <svg v-else class="h-5 w-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                    </svg>
                  </div>

                  <div class="min-w-0 flex-1">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      {{ formatFileName(item.name || 'unnamed') }}
                    </p>
                    <p class="text-xs text-gray-500">
                      {{ item.mime || 'unknown' }} • {{ formatFileSize(item.data.length) }}
                    </p>
                  </div>
                </div>

                <!-- 右側：展開アイコンと削除ボタン -->
                <div class="flex items-center space-x-2 flex-shrink-0">
                  <button
                    @click.stop="confirmDelete(index)"
                    class="p-2 text-gray-400 hover:text-red-500 transition-colors duration-200"
                    :title="`${item.name || 'ファイル'}を削除`"
                  >
                    <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                  
                  <svg
                    class="h-5 w-5 text-gray-400 transition-transform duration-200"
                    :class="{ 'transform rotate-180': expandedItemIndex === index }"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
              </div>
            </div>

            <!-- アコーディオンコンテンツ（モバイル時のプレビュー） -->
            <div
              v-if="expandedItemIndex === index"
              class="border-t border-gray-200 bg-gray-50"
            >
              <div class="p-4">
                <!-- プレビューコンポーネントをモバイル用に埋め込み -->
                <PreviewSection />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ファイル追加エリア -->
    <div class="flex-shrink-0 border-t border-gray-200">
      <div
        class="p-4 m-4 border-2 border-dashed border-gray-300 rounded-lg text-center transition-all duration-200"
        :class="{
          'border-blue-500 bg-blue-50': dragging,
          'hover:border-gray-400': !dragging
        }"
        @dragover.prevent="handleDragOver"
        @dragleave.prevent="handleDragLeave"
        @drop.prevent="handleDrop"
      >
        <svg class="mx-auto h-8 w-8 text-gray-400 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
        </svg>
        <p class="text-sm text-gray-600 mb-2">
          ファイルをここにドラッグ＆ドロップ
        </p>
        <p class="text-xs text-gray-500 mb-3">
          または
        </p>
        <button
          @click="triggerFileInput"
          class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors duration-200"
        >
          <svg class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
          </svg>
          ファイルを選択
        </button>
        
        <!-- 隠しファイルインプット -->
        <input
          ref="fileInput"
          type="file"
          multiple
          class="hidden"
          @change="handleFileSelect"
        >
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, inject, onMounted, onUnmounted } from 'vue'
import type { ArkImgState, SecretItem } from '@/types/arkimg'
import type { CryptoContext } from '@/types/crypto'
import type { ResponsiveContext, NotificationManager, ModalController } from '@/types/ui'
import PreviewSection from '@/components/PreviewSection.vue'
import { getMimeTypeFromExtension } from '@/utils/misc'

// Inject dependencies
const arkImgState = inject<ArkImgState>('arkImgState')!
const cryptoContext = inject<CryptoContext>('cryptoContext')!
const responsiveContext = inject<ResponsiveContext>('responsiveContext')!
const notificationManager = inject<NotificationManager>('notificationManager')!
const modalController = inject<ModalController>('modalController')!

// Internal state
const dragging = ref(false)
const expandedItemIndex = ref<number | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)

// File type detection
const isImageFile = (mimeType?: string): boolean => {
 if (!mimeType) return false
 return mimeType.startsWith('image/')
}

const isTextFile = (mimeType?: string): boolean => {
 if (!mimeType) return false
 return mimeType.startsWith('text/') || 
        ['application/json', 'application/javascript', 'application/xml'].includes(mimeType)
}

// File name formatting with ellipsis for long names
const formatFileName = (fileName: string): string => {
  if (fileName.length <= 30) return fileName
  
  const dotIndex = fileName.lastIndexOf('.')
  if (dotIndex === -1) {
    return fileName.substring(0, 27) + '...'
  }
  
  const name = fileName.substring(0, dotIndex)
  const ext = fileName.substring(dotIndex)
  
  if (name.length > 24) {
    return name.substring(0, 21) + '...' + ext
  }
  
  return fileName
}

// File size formatting
const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 B'
  
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

// Item selection
const selectItem = (index: number): void => {
  arkImgState.selectedItem.value = index
}
// Clear selection
const clearSelection = (): void => {
  arkImgState.selectedItem.value = null
  expandedItemIndex.value = null // Also close accordion if open
}

// Accordion toggle for mobile
const toggleAccordion = (index: number): void => {
  if (expandedItemIndex.value === index) {
    expandedItemIndex.value = null
  } else {
    expandedItemIndex.value = index
    // Also select the item for consistency
    selectItem(index)
  }
}

// File deletion with confirmation
const confirmDelete = (index: number): void => {
  const item = arkImgState.secretItems.value[index]
  const fileName = item.name || 'unnamed'
  
  modalController.openModal({
    title: 'ファイルの削除',
    message: `「${fileName}」を削除しますか？この操作は取り消せません。`,
    confirmText: '削除',
    cancelText: 'キャンセル',
    onConfirm: () => {
      try {
        // If deleting the currently selected item, clear selection
        if (arkImgState.selectedItem.value === index) {
          arkImgState.selectedItem.value = null
        }
        // If deleting an item before the selected one, adjust selection index
        else if (arkImgState.selectedItem.value !== null && arkImgState.selectedItem.value > index) {
          arkImgState.selectedItem.value -= 1
        }
        
        // Close accordion if deleting the expanded item
        if (expandedItemIndex.value === index) {
          expandedItemIndex.value = null
        }
        // Adjust expanded index if needed
        else if (expandedItemIndex.value !== null && expandedItemIndex.value > index) {
          expandedItemIndex.value -= 1
        }
        
        arkImgState.removeItem(index)
        notificationManager.notify(`「${fileName}」を削除しました`, 'success')
      } catch (error) {
        console.error('Error deleting item:', error)
        notificationManager.notify('ファイルの削除に失敗しました', 'error')
      }
    }
  })
}

// Drag and drop handlers
const handleDragOver = (event: DragEvent): void => {
  event.preventDefault()
  dragging.value = true
}

const handleDragLeave = (event: DragEvent): void => {
  event.preventDefault()
  // Only set dragging to false if leaving the drop zone entirely
  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  const x = event.clientX
  const y = event.clientY
  
  if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
    dragging.value = false
  }
}

const handleDrop = (event: DragEvent): void => {
  event.preventDefault()
  dragging.value = false
  
  const files = event.dataTransfer?.files
  if (!files || files.length === 0) {
    notificationManager.notify('ドラッグされたファイルが見つかりません', 'error')
    return
  }
  processFiles(files)
}

// File input trigger
const triggerFileInput = (): void => {
  fileInput.value?.click()
}

// File input handler
const handleFileSelect = (event: Event): void => {
  const target = event.target as HTMLInputElement
  const files = target.files
  
  if (!files || files.length === 0) return
  
  processFiles(files)
  
  // Reset input value to allow selecting the same file again
  target.value = ''
}

// Process selected files
const processFiles = async (files: FileList): Promise<void> => {
  try {
    const validFiles: File[] = [];
    const invalidFiles: string[] = [];
    
    // Validate files
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      
      if (file.size === 0) {
        invalidFiles.push(`${file.name} (空のファイル)`);
        continue
      }
      
      if (file.size > 50 * 1024 * 1024) { // 50MB limit
        invalidFiles.push(`${file.name} (ファイルサイズが大きすぎます)`);
        continue
      }
      
      validFiles.push(file);
    }
    
    // Show warnings for invalid files
    if (invalidFiles.length > 0) {
      notificationManager.notify(
        `以下のファイルはスキップされました: ${invalidFiles.join(', ')}`,
        'error'
      );
    }
    
    if (validFiles.length === 0) {
      return
    }
    
    // Process valid files
    for (const file of validFiles) {
      try {
        const arrayBuffer = await file.arrayBuffer();
        const data = new Uint8Array(arrayBuffer);
        
        const secretItem: SecretItem = {
          data,
          name: file.name,
          mime: file.type || getMimeTypeFromExtension(file.name),
          comment: '',
          modified: new Date(file.lastModified),
          isSignVerified: undefined, // Will be set after encryption/signing
          prvkey: cryptoContext.prvkey.value || undefined
        };
        
        arkImgState.addItem(secretItem);
      } catch (error) {
        console.error(`Error processing file ${file.name}:`, error);
        notificationManager.notify(`「${file.name}」の処理に失敗しました`, 'error');
      }
    }
    
    if (validFiles.length > 0) {
      notificationManager.notify(
        `${validFiles.length}個のファイルを追加しました`,
        'success'
      );
    }
  } catch (error) {
    console.error('Error processing files:', error);
    notificationManager.notify('ファイルの処理中にエラーが発生しました', 'error');
  }
}


// Global drag and drop prevention
const preventGlobalDrop = (event: DragEvent): void => {
  event.preventDefault();
}

// Lifecycle hooks
onMounted(() => {
  // Prevent default drag and drop behavior on the entire document
  document.addEventListener('dragover', preventGlobalDrop);
  document.addEventListener('drop', preventGlobalDrop);
})

onUnmounted(() => {
  // Clean up event listeners
  document.removeEventListener('dragover', preventGlobalDrop);
  document.removeEventListener('drop', preventGlobalDrop);
})
</script>

<style scoped>
</style>
