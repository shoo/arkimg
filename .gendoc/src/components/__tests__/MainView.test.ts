import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { shallowMount, type VueWrapper } from '@vue/test-utils';
import MainView from '@/components/MainView.vue';
import BaseImageSection from '@/components/BaseImageSection.vue';
import SecretDataListSection from '@/components/SecretDataListSection.vue';
import PreviewSection from '@/components/PreviewSection.vue';
import SettingsSection from '@/components/SettingsSection.vue';

// Mock components
vi.mock('@/components/BaseImageSection.vue', () => ({
	default: { name: 'BaseImageSection', template: '<div data-testid="base-image-section"></div>' }
}));
vi.mock('@/components/SecretDataListSection.vue', () => ({
	default: { name: 'SecretDataListSection', template: '<div data-testid="secret-data-list-section"></div>' }
}));
vi.mock('@/components/PreviewSection.vue', () => ({
	default: { name: 'PreviewSection', template: '<div data-testid="preview-section"></div>' }
}));
vi.mock('@/components/SettingsSection.vue', () => ({
	default: { name: 'SettingsSection', template: '<div data-testid="settings-section"></div>' }
}));

describe('MainView', () => {
	let wrapper: VueWrapper<any>;
	let mockAddEventListener: any;
	let mockRemoveEventListener: any;
	let originalInnerWidth: number;

	beforeEach(() => {
		originalInnerWidth = window.innerWidth;
		mockAddEventListener = vi.spyOn(window, 'addEventListener');
		mockRemoveEventListener = vi.spyOn(window, 'removeEventListener');
	});

	afterEach(() => {
		wrapper?.unmount();
		vi.restoreAllMocks();
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: originalInnerWidth
		});
	});

	describe('レスポンシブレイアウト', () => {
		it('モバイルレイアウトが正しく適用される', async () => {
			Object.defineProperty(window, 'innerWidth', { 
				value: 600, 
				writable: true, 
				configurable: true 
			});
			wrapper = shallowMount(MainView);
			await wrapper.vm.$nextTick();

			const rootDiv = wrapper.find('div');
			expect(rootDiv.classes()).toContain('flex');
			expect(rootDiv.classes()).toContain('flex-col');
			expect(rootDiv.classes()).toContain('min-h-max');
		});

		it('PCレイアウトが正しく適用される', () => {
			Object.defineProperty(window, 'innerWidth', { value: 1024 });
			wrapper = shallowMount(MainView);

			const rootDiv = wrapper.find('div');
			expect(rootDiv.classes()).toContain('flex');
			expect(rootDiv.classes()).toContain('flex-row');
			expect(rootDiv.classes()).toContain('h-svh');
		});

		it('リサイズイベントリスナーが登録される', () => {
			wrapper = shallowMount(MainView);
			expect(mockAddEventListener).toHaveBeenCalledWith('resize', expect.any(Function));
		});

		it('アンマウント時にリサイズイベントリスナーが削除される', () => {
			wrapper = shallowMount(MainView);
			wrapper.unmount();
			expect(mockRemoveEventListener).toHaveBeenCalledWith('resize', expect.any(Function));
		});
	});

	describe('コンポーネントレンダリング', () => {
		beforeEach(() => {
			wrapper = shallowMount(MainView);
		});

		it('必要なコンポーネントが全て存在する', () => {
			expect(wrapper.findComponent(BaseImageSection).exists()).toBe(true);
			expect(wrapper.findComponent(SecretDataListSection).exists()).toBe(true);
			expect(wrapper.findComponent(PreviewSection).exists()).toBe(true);
			expect(wrapper.findComponent(SettingsSection).exists()).toBe(true);
		});
	});

	describe('プロバイダー機能', () => {
		beforeEach(() => {
			wrapper = shallowMount(MainView);
		});

		it('cryptoContextが提供される', () => {
			const vm = wrapper.vm as any;
			expect(vm.$.provides.cryptoContext).toBeDefined();
			expect(vm.$.provides.cryptoContext.key).toBeDefined();
			expect(vm.$.provides.cryptoContext.iv).toBeDefined();
			expect(vm.$.provides.cryptoContext.prvkey).toBeDefined();
			expect(vm.$.provides.cryptoContext.pubkey).toBeDefined();
			expect(typeof vm.$.provides.cryptoContext.isKeyValid).toBe('function');
		});

		it('arkImgStateが提供される', () => {
			const vm = wrapper.vm as any;
			expect(vm.$.provides.arkImgState).toBeDefined();
			expect(vm.$.provides.arkImgState.baseImage).toBeDefined();
			expect(vm.$.provides.arkImgState.baseImageFileName).toBeDefined();
			expect(vm.$.provides.arkImgState.baseImageMIME).toBeDefined();
			expect(vm.$.provides.arkImgState.secretItems).toBeDefined();
			expect(vm.$.provides.arkImgState.selectedItem).toBeDefined();
			expect(typeof vm.$.provides.arkImgState.addItem).toBe('function');
			expect(typeof vm.$.provides.arkImgState.updateItem).toBe('function');
			expect(typeof vm.$.provides.arkImgState.removeItem).toBe('function');
		});

		it('responsiveContextが提供される', () => {
			const vm = wrapper.vm as any;
			expect(vm.$.provides.responsiveContext).toBeDefined();
			expect(vm.$.provides.responsiveContext.isMobile).toBeDefined();
		});
	});

	describe('状態管理機能', () => {
		beforeEach(() => {
			wrapper = shallowMount(MainView);
		});

		it('アイテムが正しく追加される', () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;
			const testItem = { id: '1', name: 'test', data: new Uint8Array([1, 2, 3]) };

			arkImgState.addItem(testItem);
			expect(arkImgState.secretItems.value).toHaveLength(1);
			expect(arkImgState.secretItems.value[0]).toEqual(testItem);
		});

		it('アイテムが正しく更新される', () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;
			const initialItem = { data: new Uint8Array([1, 2, 3]), name: 'test1.png', mime: 'image/png' };
			const updateData = { name: 'test2.png' };

			arkImgState.addItem(initialItem);
			arkImgState.updateItem(0, updateData);

			expect(arkImgState.secretItems.value[0].name).toBe('test2.png');
			expect(arkImgState.secretItems.value[0].mime).toBe('image/png');
		});

		it('アイテムが正しく削除される', () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;
			const testItem1 = { data: new Uint8Array([1, 2, 3]), name: 'test1.png', mime: 'image/png' };
			const testItem2 = { data: new Uint8Array([4, 5, 6]), name: 'test2.png', mime: 'image/png' };

			arkImgState.addItem(testItem1);
			arkImgState.addItem(testItem2);
			arkImgState.selectedItem.value = 1;
			
			arkImgState.removeItem(0);
			
			expect(arkImgState.secretItems.value).toHaveLength(1);
			expect(arkImgState.secretItems.value[0].name).toBe('test2.png');
			expect(arkImgState.selectedItem.value).toBe(0); // インデックスが調整される
		});

		it('選択されたアイテムを削除すると選択が解除される', () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;
			const testItem = { data: new Uint8Array([1, 2, 3]), name: 'test1.png', mime: 'image/png' };
			
			arkImgState.addItem(testItem);
			arkImgState.selectedItem.value = 0;
			arkImgState.removeItem(0);
			
			expect(arkImgState.selectedItem.value).toBeNull();
		});
	});

	describe('暗号化コンテキスト', () => {
		beforeEach(() => {
			wrapper = shallowMount(MainView);
		});

		it('isKeyValid関数が正しく動作する', () => {
			const vm = wrapper.vm as any;
			const cryptoContext = vm.$.provides.cryptoContext;

			// キーが未設定の場合
			expect(cryptoContext.isKeyValid()).toBe(false);

			// キーが設定されている場合
			cryptoContext.key.value = new Uint8Array([1, 2, 3, 4]);
			expect(cryptoContext.isKeyValid()).toBe(true);

			// 空のキーの場合
			cryptoContext.key.value = new Uint8Array([]);
			expect(cryptoContext.isKeyValid()).toBe(false);
		});
	});

	describe('ウォッチャー機能', () => {
		beforeEach(() => {
			wrapper = shallowMount(MainView);
		});

		it('baseImageが変更されると関連状態がリセットされる', async () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;
			const testItem = { data: new Uint8Array([1, 2, 3]), name: 'test1.png', mime: 'image/png' };
			
			// 初期状態を設定
			arkImgState.addItem(testItem);
			arkImgState.selectedItem.value = 0;
			arkImgState.baseImage.value = new Uint8Array([1, 2, 3]);
			await wrapper.vm.$nextTick();
			
			// baseImageをnullに変更
			arkImgState.baseImage.value = null;
			await wrapper.vm.$nextTick();
			
			expect(arkImgState.secretItems.value).toHaveLength(0);
			expect(arkImgState.selectedItem.value).toBeNull();
		});

		it('secretItemsが空になると選択が解除される', async () => {
			const vm = wrapper.vm as any;
			const arkImgState = vm.$.provides.arkImgState;

			// 初期状態を設定
			arkImgState.addItem({ id: '1', name: 'test', data: new Uint8Array([1, 2, 3]) });
			arkImgState.selectedItem.value = 0;

			// アイテムを削除
			arkImgState.removeItem(0);
			await wrapper.vm.$nextTick();

			expect(arkImgState.selectedItem.value).toBeNull();
		});
	});
});
