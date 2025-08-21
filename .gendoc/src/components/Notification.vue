<template>
  <Teleport to="body">
    <div class="fixed top-4 right-4 sm:top-4 sm:right-4 left-4 right-4 sm:left-auto sm:right-auto">
      <TransitionGroup
        name="notification"
        tag="div"
        class="space-y-3"
        @enter="onEnter"
        @leave="onLeave"
      >
        <div
          v-for="notification in displayingNotifications"
          :key="notification.id"
          :class="notificationClasses(notification.type)"
          class="
            max-w-sm w-full bg-white rounded-lg shadow-lg border-l-4
            flex items-start space-x-3 p-4
            transform transition-all duration-300 ease-out
          "
          role="alert"
          :aria-live="notification.type === 'error' ? 'assertive' : 'polite'"
          @mouseenter="pauseTimer(notification.id)"
          @mouseleave="resumeTimer(notification.id)"
        >
          <!-- アイコン -->
          <div class="flex-shrink-0">
            <svg
              v-if="notification.type === 'success'"
              class="w-5 h-5 text-green-600"
              fill="currentColor"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clip-rule="evenodd"
              />
            </svg>
            <svg
              v-else-if="notification.type === 'error'"
              class="w-5 h-5 text-red-600"
              fill="currentColor"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                clip-rule="evenodd"
              />
            </svg>
            <svg
              v-else
              class="w-5 h-5 text-blue-600"
              fill="currentColor"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
          </div>

          <!-- メッセージ内容 -->
          <div class="flex-1 min-w-0">
            <h3
              v-if="notification.title"
              class="text-sm font-semibold text-gray-900 truncate"
            >
              {{ notification.title }}
            </h3>
            <p
              :class="[
                'text-sm',
                notification.title ? 'text-gray-600 mt-1' : 'text-gray-900'
              ]"
            >
              {{ notification.message }}
            </p>
          </div>

          <!-- 閉じるボタン -->
          <button
            type="button"
            class="
              flex-shrink-0 ml-2 p-1 rounded-md
              text-gray-400 hover:text-gray-600
              focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500
              transition-colors duration-200
            "
            :aria-label="`通知を閉じる: ${notification.message}`"
            @click="removeNotification(notification.id)"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch, nextTick, onUnmounted } from 'vue'
import type { NotificationMessage } from '@/types/ui'

interface Props {
  notifications: NotificationMessage[]
}

const props = defineProps<Props>()

// 内部状態
const displayingNotifications = ref<NotificationMessage[]>([])
const timers = ref<Map<number, number>>(new Map())
const pausedTimers = ref<Map<number, { remaining: number; startTime: number }>>(new Map())
const processedIds = ref<Set<number>>(new Set())

// 通知スタイルクラス
const notificationClasses = (type: 'success' | 'error' | 'info') => {
  const classes = {
    success: 'border-l-green-500 bg-green-50',
    error: 'border-l-red-500 bg-red-50',
    info: 'border-l-blue-500 bg-blue-50'
  }
  return classes[type] || classes.info
}

// 通知を追加
const addNotification = (notification: NotificationMessage) => {
  if (!notification.message || notification.message.trim() === '') {
    return
  }

  if (processedIds.value.has(notification.id)) {
    return
  }

  processedIds.value.add(notification.id)
  displayingNotifications.value.unshift(notification)

  // 最大5件まで表示
  if (displayingNotifications.value.length > 5) {
    const removed = displayingNotifications.value.pop()
    if (removed) {
      const timer = timers.value.get(removed.id)
      if (timer) {
        clearTimeout(timer)
        timers.value.delete(removed.id)
      }
      pausedTimers.value.delete(removed.id)
    }
  }

  // 自動削除タイマーを設定
  const timeout = notification.timeout || (notification.type === 'error' ? 7 : 5)
  const timer = setTimeout(() => {
    removeNotification(notification.id)
  }, timeout * 1000)

  timers.value.set(notification.id, timer as any)
}

// 通知を削除
const removeNotification = (id: number) => {
  const index = displayingNotifications.value.findIndex(n => n.id === id)
  if (index > -1) {
    displayingNotifications.value.splice(index, 1)
  }

  const timer = timers.value.get(id)
  if (timer) {
    clearTimeout(timer)
    timers.value.delete(id)
  }

  pausedTimers.value.delete(id)
}

// タイマーを一時停止
const pauseTimer = (id: number) => {
  const timer = timers.value.get(id)
  if (timer) {
    clearTimeout(timer)
    timers.value.delete(id)

    // 残り時間を計算
    const notification = displayingNotifications.value.find(n => n.id === id)
    if (notification) {
      const timeout = notification.timeout || (notification.type === 'error' ? 7 : 5)
      const elapsed = (Date.now() - (notification as any).startTime) / 1000
      const remaining = Math.max(0, timeout - elapsed)
      
      pausedTimers.value.set(id, {
        remaining,
        startTime: Date.now()
      })
    }
  }
}

// タイマーを再開
const resumeTimer = (id: number) => {
  const pausedTimer = pausedTimers.value.get(id)
  if (pausedTimer) {
    const timer = setTimeout(() => {
      removeNotification(id)
    }, pausedTimer.remaining * 1000)

    timers.value.set(id, timer as any)
    pausedTimers.value.delete(id)
  }
}

// アニメーション処理
const onEnter = (el: Element) => {
  const element = el as HTMLElement
  element.style.opacity = '0'
  element.style.transform = 'translateX(100%)'
  
  nextTick(() => {
    element.style.transition = 'all 0.3s ease-out'
    element.style.opacity = '1'
    element.style.transform = 'translateX(0)'
  })
}

const onLeave = (el: Element) => {
  const element = el as HTMLElement
  element.style.transition = 'all 0.3s ease-out'
  element.style.opacity = '0'
  element.style.transform = 'translateX(100%)'
}

// propsの変更を監視
watch(
  () => props.notifications,
  (newNotifications) => {
    newNotifications.forEach(notification => {
      if (!processedIds.value.has(notification.id)) {
        // 開始時刻を記録
        ;(notification as any).startTime = Date.now()
        addNotification(notification)
      }
    })
  },
  { immediate: true, deep: true }
)

// コンポーネントのクリーンアップ
const cleanup = () => {
  timers.value.forEach(timer => clearTimeout(timer))
  timers.value.clear()
  pausedTimers.value.clear()
}

// アンマウント時のクリーンアップ
onUnmounted(cleanup)
</script>

<style scoped>
/* 通知のアニメーション */
.notification-enter-active {
  transition: all 0.3s ease-out;
}

.notification-leave-active {
  transition: all 0.3s ease-out;
}

.notification-enter-from {
  opacity: 0;
  transform: translateX(100%);
}

.notification-leave-to {
  opacity: 0;
  transform: translateX(100%);
}

.notification-move {
  transition: transform 0.3s ease-out;
}

</style>
