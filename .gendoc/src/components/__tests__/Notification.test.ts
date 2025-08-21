import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, VueWrapper } from '@vue/test-utils';
import { nextTick } from 'vue';
import Notification from '@/components/Notification.vue';
import type { NotificationMessage } from '@/types/ui';

// タイマーのモック
vi.useFakeTimers();

describe('Notification.vue', () => {
	let wrapper: VueWrapper;

	beforeEach(() => {
		// DOMにbody要素を確保（Teleportのため）
		document.body.innerHTML = '<div id="app"></div>';
	});

	afterEach(() => {
		if (wrapper) {
			wrapper.unmount();
		}
		vi.clearAllTimers();
		document.body.innerHTML = '';
	});

	const createWrapper = (notifications: NotificationMessage[] = []) => {
		return mount(Notification, {
			props: { notifications },
			attachTo: document.getElementById('app')!
		})
	}

	describe('基本的な表示', () => {
		it('通知が表示される', async () => {
			const notifications: NotificationMessage[] = [
				{
					id: 1,
					type: 'success',
					message: 'テスト成功メッセージ',
					title: '成功'
				}
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElement = document.querySelector('[role="alert"]');
			expect(notificationElement).toBeTruthy();
			expect(notificationElement?.textContent).toContain('成功');
			expect(notificationElement?.textContent).toContain('テスト成功メッセージ');
		})

		it('複数の通知が表示される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'success', message: 'メッセージ1' },
				{ id: 2, type: 'error', message: 'メッセージ2' },
				{ id: 3, type: 'info', message: 'メッセージ3' }
			]

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElements = document.querySelectorAll('[role="alert"]');
			expect(notificationElements).toHaveLength(3);
		})

		it('最大5件まで表示される', async () => {
			const notifications: NotificationMessage[] = Array.from({ length: 7 }, (_, i) => ({
				id: i + 1,
				type: 'info' as const,
				message: `メッセージ${i + 1}`
			}))

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElements = document.querySelectorAll('[role="alert"]');
			expect(notificationElements).toHaveLength(5);
		})
	})

	describe('通知タイプ別のスタイル', () => {
		it.each([
			['success', 'border-l-green-500 bg-green-50'],
			['error', 'border-l-red-500 bg-red-50'],
			['info', 'border-l-blue-500 bg-blue-50']
		])('%s タイプの通知に正しいスタイルが適用される', async (type, expectedClasses) => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: type as any, message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElement = document.querySelector('[role="alert"]');
			expectedClasses.split(' ').forEach(className => {
				expect(notificationElement?.classList.contains(className)).toBe(true);
			})
		})
	})

	describe('アイコン表示', () => {
		it('成功通知にチェックアイコンが表示される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'success', message: 'テスト' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const icon = document.querySelector('.text-green-600');
			expect(icon).toBeTruthy();
		})

		it('エラー通知にXアイコンが表示される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'error', message: 'テスト' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const icon = document.querySelector('.text-red-600');
			expect(icon).toBeTruthy();
		})

		it('情報通知にiアイコンが表示される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テスト' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const icon = document.querySelector('.text-blue-600');
			expect(icon).toBeTruthy();
		})
	})

	describe('手動削除', () => {
		it('閉じるボタンをクリックすると通知が削除される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			const closeButton = document.querySelector('button[aria-label*="通知を閉じる"]');
			expect(closeButton).toBeTruthy();

			closeButton?.dispatchEvent(new Event('click'));
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);
		})
	})

	describe('自動削除タイマー', () => {
		it('デフォルトのタイムアウト後に通知が自動削除される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			// 5秒後（infoのデフォルト）
			vi.advanceTimersByTime(5000);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);
		})

		it('エラー通知は7秒後に自動削除される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'error', message: 'エラーメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			// 5秒後はまだ残っている
			vi.advanceTimersByTime(5000);
			await nextTick();
			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			// 7秒後に削除される
			vi.advanceTimersByTime(2000);
			await nextTick();
			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);
		});

		it('カスタムタイムアウトが正しく動作する', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テスト', timeout: 10 }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			// 5秒後はまだ残っている
			vi.advanceTimersByTime(5000);
			await nextTick();
			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);

			// 10秒後に削除される
			vi.advanceTimersByTime(5000);
			await nextTick();
			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);
		})
	})

	describe('タイマーの一時停止・再開', () => {
		it('マウスホバー時にタイマーが一時停止される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElement = document.querySelector('[role="alert"]') as HTMLElement;
			
			// 3秒経過
			vi.advanceTimersByTime(3000);
			
			// マウスエンター
			notificationElement.dispatchEvent(new Event('mouseenter'));
			await nextTick();

			// さらに5秒経過（本来なら削除されているはず）
			vi.advanceTimersByTime(5000);
			await nextTick();

			// まだ残っている
			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);
		});

		it('マウスリーブ時にタイマーが再開される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElement = document.querySelector('[role="alert"]') as HTMLElement;
			
			// 3秒経過
			vi.advanceTimersByTime(3000);
			
			// マウスエンター（一時停止）
			notificationElement.dispatchEvent(new Event('mouseenter'));
			await nextTick();
			
			// 2秒経過
			vi.advanceTimersByTime(2000);
			
			// マウスリーブ（再開）
			notificationElement.dispatchEvent(new Event('mouseleave'));
			await nextTick();

			// 残り2秒後に削除される
			vi.advanceTimersByTime(2000);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);
		})
	})

	describe('動的な通知追加', () => {
		it('新しい通知が追加されると表示される', async () => {
			wrapper = createWrapper([]);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(0);

			// 新しい通知を追加
			await wrapper.setProps({
				notifications: [
					{ id: 1, type: 'info', message: '新しい通知' }
				]
			});

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);
		})

		it('同じIDの通知は重複して追加されない', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			// 同じIDの通知を追加
			await wrapper.setProps({
				notifications: [
					...notifications,
					{ id: 1, type: 'success', message: '重複通知' }
				]
			});

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);
		});
	});

	describe('アクセシビリティ', () => {
		it('エラー通知にaria-live="assertive"が設定される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'error', message: 'エラーメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElement = document.querySelector('[role="alert"]');
			expect(notificationElement?.getAttribute('aria-live')).toBe('assertive');
		})

		it('成功・情報通知にaria-live="polite"が設定される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'success', message: '成功メッセージ' },
				{ id: 2, type: 'info', message: '情報メッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const notificationElements = document.querySelectorAll('[role="alert"]');
			notificationElements.forEach(element => {
				expect(element.getAttribute('aria-live')).toBe('polite');
			});
		});

		it('閉じるボタンに適切なaria-labelが設定される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'テストメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const closeButton = document.querySelector('button');
			expect(closeButton?.getAttribute('aria-label')).toContain('通知を閉じる');
			expect(closeButton?.getAttribute('aria-label')).toContain('テストメッセージ');
		});
	});

	describe('エッジケース', () => {
		it('空のメッセージの通知は表示されない', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: '' },
				{ id: 2, type: 'info', message: '   ' }, // 空白のみ
				{ id: 3, type: 'info', message: '正常なメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			expect(document.querySelectorAll('[role="alert"]')).toHaveLength(1);
		})

		it('タイトルがない場合でもメッセージが表示される', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'タイトルなしメッセージ' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const titleElement = document.querySelector('h3');
			expect(titleElement).toBeNull();

			const messageElement = document.querySelector('p');
			expect(messageElement?.textContent).toBe('タイトルなしメッセージ');
			expect(messageElement?.classList.contains('text-gray-900')).toBe(true);
		})

		it('タイトルがある場合はメッセージのスタイルが変わる', async () => {
			const notifications: NotificationMessage[] = [
				{ id: 1, type: 'info', message: 'メッセージ', title: 'タイトル' }
			];

			wrapper = createWrapper(notifications);
			await nextTick();

			const titleElement = document.querySelector('h3');
			expect(titleElement?.textContent).toBe('タイトル');

			const messageElement = document.querySelector('p');
			expect(messageElement?.classList.contains('text-gray-600')).toBe(true);
			expect(messageElement?.classList.contains('mt-1')).toBe(true);
		});
	});
});
