import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises, shallowMount, type VueWrapper } from '@vue/test-utils';
import { ref } from 'vue';
import SettingsSection from '@/components/SettingsSection.vue';
import CryptoKeyInput from '@/components/CryptoKeyInput.vue';
import type { CryptoContext } from '@/types/crypto';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { NotificationManager } from '@/types/ui';

// Mock modules
vi.mock('@/arkimg/utils', () => ({
	createArkImg: vi.fn().mockResolvedValue(new Uint8Array([1, 2, 3, 4])),
}));

vi.mock('@/utils/misc', () => ({
	getMimeTypeFromExtension: vi.fn().mockReturnValue('image/png'),
}));

// Mock DOM APIs
Object.defineProperty(URL, 'createObjectURL', {
	writable: true,
	value: vi.fn().mockReturnValue('mock-object-url'),
});

Object.defineProperty(URL, 'revokeObjectURL', {
	writable: true,
	value: vi.fn(),
});

describe('SettingsSection.vue', () => {
	let wrapper: VueWrapper<any>;
	let mockCryptoContext: CryptoContext;
	let mockArkImgState: ArkImgState;
	let mockNotificationManager: NotificationManager;
	
	function createWrapper() {
		return shallowMount(SettingsSection, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					arkImgState: mockArkImgState,
					notificationManager: mockNotificationManager,
				},
				stubs: {
					CryptoKeyInput: true,
				},
			},
		}); 
	}
	beforeEach(() => {

		// Mock injection dependencies
		mockCryptoContext = {
			key: ref(new Uint8Array([1, 2, 3])),
			iv: ref(new Uint8Array([4, 5, 6])),
			prvkey: ref(new Uint8Array([7, 8, 9])),
			pubkey: ref(new Uint8Array([10, 11, 12])),
			isKeyValid: vi.fn().mockReturnValue(true),
		};
		
		// Mock injection dependencies
		mockCryptoContext = {
			key: ref(new Uint8Array([1, 2, 3])),
			iv: ref(new Uint8Array([4, 5, 6])),
			prvkey: ref(new Uint8Array([7, 8, 9])),
			pubkey: ref(new Uint8Array([10, 11, 12])),
			isKeyValid: vi.fn().mockReturnValue(true),
		} as CryptoContext;

		mockArkImgState = {
			baseImage: ref(new Uint8Array([13, 14, 15])),
			baseImageFileName: ref('test.png'),
			baseImageMIME: ref('image/png'),
			secretItems: ref([
				{
					data: new Uint8Array([16, 17, 18]),
					name: 'secret1.txt',
					mime: 'text/plain',
					comment: 'test comment',
					modified: new Date('2023-01-01'),
				},
			]),
			selectedItem: ref(null),
			addItem: (item: SecretItem) => {item},
			removeItem: (index: number) => {index},
			updateItem: (index: number, item: SecretItem) => {index; item;}
		};

		mockNotificationManager = {
			notify: vi.fn(),
		};
		
		wrapper = createWrapper();
	});

	it('正しくレンダリングされることを確認', () => {
		expect(wrapper.find('h2').text()).toBe('設定');
		expect(wrapper.findComponent(CryptoKeyInput).exists()).toBe(true);
		expect(wrapper.find('button').text()).toBe('作成');
		expect(wrapper.findAll('button')).toHaveLength(2);
	});

	it('作成ボタンが条件を満たす場合に有効になることを確認', () => {
		const createButton = wrapper.findAll('button')[0];
		expect(createButton.attributes('disabled')).toBeUndefined();
	});

	it('ベース画像がない場合に作成ボタンが無効になることを確認', async () => {
		mockArkImgState.baseImage.value = null;
		await wrapper.vm.$nextTick();
		
		const createButton = wrapper.findAll('button')[0];
		expect(createButton.attributes('disabled')).toBeDefined();
	});

	it('暗号鍵が無効な場合に作成ボタンを無効にする', async () => {
		(mockCryptoContext.isKeyValid as any).mockReturnValue(false);
		wrapper = createWrapper();
		
		await wrapper.vm.$nextTick();
		
		expect((wrapper.vm as any).isProcessing).toBe(false);
		expect((wrapper.vm as any).canCreateArkImg).toBe(false);
		const createButton = wrapper.find('#CreateArkImgButton');
		expect(createButton.attributes('disabled')).toBeDefined();
	});
	it('ArkImg作成中に処理状態を表示する', async () => {
		const { createArkImg } = await import('@/arkimg/utils');
		// 長時間の処理をシミュレート
		vi.mocked(createArkImg).mockImplementation(() => new Promise(resolve => setTimeout(() => resolve(new Uint8Array([1, 2, 3, 4])), 100)));
	
		const createButton = wrapper.findAll('button')[0];
		
		// 処理開始
		const clickPromise = createButton.trigger('click');
		await wrapper.vm.$nextTick();
		
		expect(createButton.text()).toBe('作成中...');
		expect(createButton.attributes('disabled')).toBeDefined();
		
		// 処理完了まで待機
		await clickPromise;
		vi.mocked(createArkImg).mockRestore();
	});

	it('ArkImgを正常に作成してダウンロードする', async () => {
		const { createArkImg } = await import('@/arkimg/utils');
		const originalCreateElement = document.createElement;
		let lastCreatedElement: HTMLAnchorElement = undefined as any as HTMLAnchorElement;
		const createElementSpy = vi
			.spyOn(document, 'createElement')
			.mockImplementation((tagName: string) => {
				if (tagName === 'a') {
					const el = originalCreateElement.call(document, 'a'); // ← 本物を呼ぶ
					vi.spyOn(el, 'click').mockImplementation(() => {});
					lastCreatedElement = el as HTMLAnchorElement;
					return el;
				}
				return originalCreateElement.call(document, tagName);
			});
		const appendChildSpy = vi.spyOn(document.body, 'appendChild').mockImplementation((node) => node);
		const removeChildSpy = vi.spyOn(document.body, 'removeChild').mockImplementation((node) => node);
		vi.mock('@/arkimg/utils', () => ({
			createArkImg: vi.fn(() => ({
				buffer: new ArrayBuffer(8) // 適当なバイト配列
			}))
		}));
		
		const createButton = wrapper.find('#CreateArkImgButton');
		await createButton.trigger('click');
		// Wait for async operation
		await flushPromises();

		expect(createArkImg).toHaveBeenCalledWith(
			mockArkImgState.baseImage.value,
			'image/png',
			[{
				data: mockArkImgState.secretItems.value[0].data,
				metadata: {
					name: 'secret1.txt',
					mime: 'text/plain',
					comment: 'test comment',
					modified: '2023-01-01T00:00:00.000Z',
				},
				prvkey: mockCryptoContext.prvkey.value,
			}],
			mockCryptoContext.key.value,
			mockCryptoContext.iv.value,
			mockCryptoContext.prvkey.value
		);

		expect(mockNotificationManager.notify).toHaveBeenCalledWith('ArkImgファイルを作成中...', 'info');
		expect(mockNotificationManager.notify).toHaveBeenCalledWith('ArkImgファイルが作成され、ダウンロードされました。', 'success');
		expect(lastCreatedElement?.download).toBe('test.png');
		expect(lastCreatedElement?.click).toHaveBeenCalled();
		expect(appendChildSpy).toHaveBeenCalled();
		expect(removeChildSpy).toHaveBeenCalled();
		expect(URL.revokeObjectURL).toHaveBeenCalledWith('mock-object-url');

		createElementSpy.mockRestore();
		appendChildSpy.mockRestore();
		removeChildSpy.mockRestore();
	});

	it('ArkImg作成エラーを処理する', async () => {
		const { createArkImg } = await import('@/arkimg/utils');
		vi.mocked(createArkImg).mockRejectedValueOnce(new Error('Creation failed'));

		const createButton = wrapper.findAll('button')[0];
		await createButton.trigger('click');

		// Wait for async operation
		await new Promise(resolve => setTimeout(resolve, 0));

		expect(mockNotificationManager.notify).toHaveBeenCalledWith('ArkImgファイルを作成中...', 'info');
		expect(mockNotificationManager.notify).toHaveBeenCalledWith('ArkImgファイルの作成に失敗しました: Creation failed', 'error');
	});

	it('リセットボタンがクリックされたときに状態をリセット', async () => {
		const resetButton = wrapper.findAll('button')[1];
		await resetButton.trigger('click');

		expect(mockArkImgState.baseImage.value).toBe(null);
		expect(mockArkImgState.secretItems.value).toEqual([]);
		expect(mockArkImgState.selectedItem.value).toBe(null);
		expect(mockCryptoContext.key.value).toBe(null);
		expect(mockCryptoContext.iv.value).toBe(null);
		expect(mockCryptoContext.prvkey.value).toBe(null);
		expect(mockCryptoContext.pubkey.value).toBe(null);
		expect(mockNotificationManager.notify).toHaveBeenCalledWith('状態をリセットしました。', 'info');
	});

	it('処理中にボタンを無効にすることをテストする', async () => {
		// Mock createArkImg to simulate long processing
		const { createArkImg } = await import('@/arkimg/utils');
		vi.mocked(createArkImg).mockImplementation(() => new Promise(resolve => setTimeout(resolve, 100)));

		const [createButton, resetButton] = wrapper.findAll('button');
		
		// Start processing
		createButton.trigger('click');
		await wrapper.vm.$nextTick();

		expect(createButton.attributes('disabled')).toBeDefined();
		expect(resetButton.attributes('disabled')).toBeDefined();
	});

	it('オプションの暗号値が欠落していても正常に処理できることを確認', async () => {
		// Clear optional crypto values
		mockCryptoContext.key.value = null;
		mockCryptoContext.prvkey.value = null;
		mockCryptoContext.iv.value = null;
		mockCryptoContext.prvkey.value = null;

		const createButton = wrapper.findAll('button')[0];
		await createButton.trigger('click');

		// Wait for async operation
		await new Promise(resolve => setTimeout(resolve, 0));

		const { createArkImg } = await import('@/arkimg/utils');
		expect(createArkImg).toHaveBeenCalledWith(
			mockArkImgState.baseImage.value,
			'image/png',
			[{
				data: mockArkImgState.secretItems.value[0].data,
				metadata: {
					name: 'secret1.txt',
					mime: 'text/plain',
					comment: 'test comment',
					modified: '2023-01-01T00:00:00.000Z',
				},
				prvkey: undefined,
			}],
			mockCryptoContext.key.value,
			undefined,
			undefined
		);
	});
});
