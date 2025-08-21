import { describe, it, expect } from 'vitest';
import { shallowMount, type VueWrapper } from '@vue/test-utils';
import App from '@/App.vue';

describe('App.vue', () => {
	it('初期表示が正しく行われる', () => {
		const wrapper: VueWrapper = shallowMount(App);
		// MainView, Notification, Modalが存在するか
		expect(wrapper.findComponent({ name: 'MainView' }).exists()).toBe(true);
		expect(wrapper.findComponent({ name: 'Notification' }).exists()).toBe(true);
		expect(wrapper.findComponent({ name: 'Modal' }).exists()).toBe(true);
	});
	
	it('provideされたnotificationManagerで通知が追加される', async () => {
		const wrapper: VueWrapper = shallowMount(App);
		const notificationManager = (wrapper.vm.$ as any).provides['notificationManager'];
		notificationManager.notify('テストメッセージ', 'success', 'タイトル', 1000);
		await wrapper.vm.$nextTick();
		const notifications = (wrapper.vm as any).notifications;
		expect(notifications.length).toBe(1);
		expect(notifications[0].message).toBe('テストメッセージ');
		expect(notifications[0].type).toBe('success');
		expect(notifications[0].title).toBe('タイトル');
		expect(notifications[0].timeout).toBe(1000);
	});

	it('provideされたmodalControllerでモーダル表示・非表示が制御できる', async () => {
		const wrapper: VueWrapper = shallowMount(App);
		const modalController = (wrapper.vm.$ as any).provides['modalController'];
		const options = { title: 'テスト', message: '内容', confirmText: 'OK', calcelText: null };
		modalController.openModal(options);
		await wrapper.vm.$nextTick();
		expect((wrapper.vm as any).modalOptions).toEqual(options);
		modalController.closeModal();
		await wrapper.vm.$nextTick();
		expect((wrapper.vm as any).modalOptions).toBeNull();
	});
});
