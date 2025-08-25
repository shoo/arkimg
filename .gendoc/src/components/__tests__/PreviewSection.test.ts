import { describe, it, expect, beforeEach, vi } from 'vitest';
import { shallowMount, type VueWrapper } from '@vue/test-utils';
import { ref } from 'vue';
import PreviewSection from '@/components/PreviewSection.vue';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { CryptoContext } from '@/types/crypto';
import type { NotificationManager } from '@/types/ui';

// モックコンポーネント
const mockImagePreview = {
	name: 'ImagePreview',
	template: '<div data-testid="image-preview">Image Preview</div>'
};

const mockTextPreview = {
	name: 'TextPreview',
	template: '<div data-testid="text-preview">Text Preview</div>'
};

const mockMetadataEditor = {
	name: 'MetadataEditor',
	template: '<div data-testid="metadata-editor">Metadata Editor</div>'
};

describe('PreviewSection.vue', () => {
	let wrapper: VueWrapper<any>;
	let mockArkImgState: ArkImgState;
	let mockCryptoContext: CryptoContext;
	let mockNotificationManager: NotificationManager;
	
	const mockSecretItem: SecretItem = {
		name: 'test-file.txt',
		data: new Uint8Array([116, 101, 115, 116]), // "test" in UTF-8
		mime: 'text/plain',
		isSignVerified: true,
		prvkey: new Uint8Array()
	};

	beforeEach(() => {
		mockArkImgState = {
			baseImage: ref(new Uint8Array([1,2,3,4])),
			baseImageFileName: ref('test.png'),
			baseImageMIME: ref('image/png'),
			selectedItem: ref(0),
			secretItems: ref([mockSecretItem]),
			addItem: (item: SecretItem) => {item},
			removeItem: (index: number) => {index},
			updateItem: (index: number, item: SecretItem) => {index;item;},
		};
		
		mockCryptoContext = {
			key: ref(new Uint8Array([1,2,3,4])),
			iv: ref(null),
			prvkey: ref(new Uint8Array([1, 2, 3])),
			pubkey: ref(new Uint8Array([1, 2, 3])),
			isKeyValid: () => true,
		};
		
		mockNotificationManager = {
			notify: vi.fn()
		};
	});

	const createWrapper = (overrides: Partial<{ arkImgState: ArkImgState; cryptoContext: CryptoContext; notificationManager: NotificationManager }> = {}) => {
		return shallowMount(PreviewSection, {
			global: {
				provide: {
					arkImgState: overrides.arkImgState || mockArkImgState,
					cryptoContext: overrides.cryptoContext || mockCryptoContext,
					notificationManager: overrides.notificationManager || mockNotificationManager
				},
				stubs: {
					ImagePreview: mockImagePreview,
					TextPreview: mockTextPreview,
					MetadataEditor: mockMetadataEditor
				}
			}
		});
	};

	it('アイテム未選択時は選択プロンプトを表示する', async () => {
		const emptyArkImgState = {
			baseImage: ref(null),
			baseImageFileName: ref(null),
			baseImageMIME: ref(null),
			selectedItem: ref(null),
			secretItems: ref([]),
			addItem: (item: SecretItem) => {item},
			removeItem: (index: number) => {index},
			updateItem: (index: number, item: SecretItem) => {index;item;},
		};
		wrapper = createWrapper({ arkImgState: emptyArkImgState });
		await wrapper.vm.$nextTick();
		
		// 最下部のメッセージを確認
		const emptyMessage = wrapper.find('.flex-1.flex.items-center.justify-center.text-gray-500');
		expect(emptyMessage.exists()).toBe(true);
		expect(emptyMessage.text()).toContain('プレビューするデータを選択してください。');
	});

	it('選択されたアイテムのファイル名を表示する', () => {
		wrapper = createWrapper();
		
		const fileName = wrapper.find('h2');
		expect(fileName.text()).toBe('test-file.txt');
		expect(fileName.attributes('title')).toBe('test-file.txt');
	});

	it('署名検証済みステータスを正しく表示する', () => {
		wrapper = createWrapper();
		
		const statusBadge = wrapper.find('.bg-green-100');
		expect(statusBadge.exists()).toBe(true);
		expect(statusBadge.text()).toContain('署名検証済み');
	});

	it('署名なしステータスを正しく表示する', () => {
		const itemWithoutSign: SecretItem = {
			...mockSecretItem,
			isSignVerified: false
		};
		const stateWithoutSign = {
			...mockArkImgState,
			selectedItem: ref<number | null>(0),
			secretItems: ref<SecretItem[]>([itemWithoutSign])
		};
		wrapper = createWrapper({ arkImgState: stateWithoutSign });
		
		const statusBadge = wrapper.find('.bg-gray-100');
		expect(statusBadge.exists()).toBe(true);
		expect(statusBadge.text()).toContain('署名なし');
	});
	
	it('検証鍵なしステータスを正しく表示する', () => {
		const contextWithoutKey = {
			...mockCryptoContext,
			pubkey: ref<Uint8Array | null>(null)
		};
		wrapper = createWrapper({ cryptoContext: contextWithoutKey });
		
		const statusBadge = wrapper.find('.bg-yellow-100');
		expect(statusBadge.exists()).toBe(true);
		expect(statusBadge.text()).toContain('検証鍵なし');
	});
	
	it('テキストファイルの場合はTextPreviewを表示する', async () => {
		wrapper = createWrapper();
		await wrapper.vm.$nextTick();
		
		const textPreview = wrapper.findComponent(mockTextPreview);
		expect(textPreview.exists()).toBe(true);
	});
	
	it('画像ファイルの場合はImagePreviewを表示する', async () => {
		const imageItem: SecretItem = {
			...mockSecretItem,
			name: 'test-image.png',
			mime: 'image/png'
		};
		const stateWithImage = {
			...mockArkImgState,
			selectedItem: ref<number | null>(0),
			secretItems: ref<SecretItem[]>([imageItem])
		};
		wrapper = createWrapper({ arkImgState: stateWithImage });
		await wrapper.vm.$nextTick();
		
		const imagePreview = wrapper.findComponent(mockImagePreview);
		expect(imagePreview.exists()).toBe(true);
	});
	
	it('サポートされていないファイル形式の場合はエラーメッセージを表示する', async () => {
		const unsupportedItem: SecretItem = {
			...mockSecretItem,
			name: 'test-file.bin',
			mime: 'application/octet-stream'
		};
		const stateWithUnsupported = {
			...mockArkImgState,
			selectedItem: ref<number | null>(0),
			secretItems: ref<SecretItem[]>([unsupportedItem])
		};
		wrapper = createWrapper({ arkImgState: stateWithUnsupported });
		await wrapper.vm.$nextTick();
		
		expect(wrapper.text()).toContain('このデータの復号またはプレビューに失敗しました。');
	});

	it('メタデータアコーディオンをクリックすると開閉する', async () => {
		wrapper = createWrapper();
		await wrapper.vm.$nextTick();
		
		const accordionHeader = wrapper.find('.bg-gray-100.cursor-pointer');
		expect(accordionHeader.exists()).toBe(true);
		
		// v-showを使用しているため、要素の表示状態を確認
		const metadataContainer = wrapper.find('[data-testid="metadata-editor"]').element.parentElement as HTMLDivElement;
		
		// 初期状態では非表示
		expect(metadataContainer.style.display).toBe('none');
		
		// クリックして開く
		await accordionHeader.trigger('click');
		await wrapper.vm.$nextTick();
		
		expect(metadataContainer.style.display).not.toBe('none');
		
		// 再度クリックして閉じる
		await accordionHeader.trigger('click');
		await wrapper.vm.$nextTick();
		
		expect(metadataContainer.style.display).toBe('none');
	});

	it('メタデータアコーディオンのアイコンが正しく回転する', async () => {
		wrapper = createWrapper();
		
		const accordionIcon = wrapper.find('svg.transform.transition-transform');
		const accordionHeader = wrapper.find('.bg-gray-100.cursor-pointer');
		
		// 初期状態
		expect(accordionIcon.classes()).not.toContain('rotate-180');
		
		// クリックして開く
		await accordionHeader.trigger('click');
		await wrapper.vm.$nextTick();
		
		expect(accordionIcon.classes()).toContain('rotate-180');
	});

	it('ファイル名が未定義の場合は不明なファイルと表示する', () => {
		const itemWithoutName: SecretItem = {
			...mockSecretItem,
			name: undefined as any
		};
		const stateWithoutName = {
			...mockArkImgState,
			selectedItem: ref<number | null>(0),
			secretItems: ref<SecretItem[]>([itemWithoutName])
		};
		wrapper = createWrapper({ arkImgState: stateWithoutName });
		
		const fileName = wrapper.find('h2');
		expect(fileName.text()).toBe('不明なファイル');
	});

	it('JSONファイルはテキストプレビューで表示される', async () => {
		const jsonItem: SecretItem = {
			...mockSecretItem,
			name: 'test.json',
			mime: 'application/json'
		};
		const stateWithJson = {
			...mockArkImgState,
			selectedItem: ref<number | null>(0),
			secretItems: ref<SecretItem[]>([jsonItem])
		};
		wrapper = createWrapper({ arkImgState: stateWithJson });
		await wrapper.vm.$nextTick();
		
		const textPreview = wrapper.findComponent(mockTextPreview);
		expect(textPreview.exists()).toBe(true);
	});
});
