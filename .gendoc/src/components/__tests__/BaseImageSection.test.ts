import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import BaseImageSection from '@/components/BaseImageSection.vue';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { ResponsiveContext, NotificationManager } from '@/types/ui';
import type { CryptoContext } from '@/types/crypto';
import * as arkimgUtils from '@/arkimg/utils';
import * as miscUtils from '@/utils/misc';

// モックの設定
vi.mock('@/arkimg/utils', () => ({
	loadParameter: vi.fn(),
	loadImage: vi.fn()
}));

vi.mock('@/utils/misc', () => ({
	getMimeTypeFromExtension: vi.fn()
}));

vi.mock('@/components/SettingsSection.vue', () => ({
	default: {
		name: 'SettingsSection',
		template: '<div>Settings Section</div>'
	}
}));

// グローバルのfetchをモック
global.fetch = vi.fn();
global.URL.createObjectURL = vi.fn();
global.URL.revokeObjectURL = vi.fn();

describe('BaseImageSection.vue', () => {
	let arkImgState: ArkImgState;
	let responsiveContext: ResponsiveContext;
	let notificationManager: NotificationManager;
	let cryptoContext: CryptoContext;
	let mockArkImg: any;

	beforeEach(() => {
	
		// テスト用のステート作成
		arkImgState = {
			baseImage: ref(null),
			baseImageFileName: ref(null),
			baseImageMIME: ref(null),
			secretItems: ref([]),
			selectedItem: ref(null),
			addItem: (item: SecretItem) => {item},
			removeItem: (index: number) => {index},
			updateItem: (index: number, item: SecretItem) => {index; item;}
		} as ArkImgState;

		responsiveContext = {
			isMobile: ref(false)
		} as ResponsiveContext;

		notificationManager = {
			notify: vi.fn()
		} as NotificationManager;

		cryptoContext = {
			key: ref(null),
			iv: ref(null),
			pubkey: ref(null)
		} as CryptoContext;

		// arkimgのモックオブジェクト
		mockArkImg = {
			getSecretItemCount: vi.fn(() => 0),
			getMetadataItem: vi.fn(),
			getSecretItem: vi.fn(),
			getBaseImage: vi.fn(() => ({
				buffer: new ArrayBuffer(8)
			}))
		};

		// モック関数の初期化
		vi.mocked(arkimgUtils.loadImage).mockResolvedValue(mockArkImg);
		vi.mocked(miscUtils.getMimeTypeFromExtension).mockReturnValue('image/jpeg');
		vi.mocked(global.URL.createObjectURL).mockReturnValue('blob:mock-url');
		vi.mocked(global.fetch).mockResolvedValue({
			ok: true,
			blob: () => Promise.resolve(new Blob())
		} as Response);
		
		// DragEventのモック
		global.DragEvent = class DragEvent extends Event {
			dataTransfer: any;
			constructor(type: string, eventInitDict?: any) {
				super(type, eventInitDict);
				this.dataTransfer = eventInitDict?.dataTransfer || null;
			}
		} as any;
	});

	afterEach(() => {
		vi.clearAllMocks();
	});

	const createWrapper = (props = {}) => {
		return shallowMount(BaseImageSection, {
			props,
			global: {
				provide: {
					arkImgState,
					responsiveContext,
					notificationManager,
					cryptoContext
				}
			}
		});
	};

	describe('初期表示', () => {
		it('ベース画像がない場合、ファイル入力エリアを表示する', () => {
			const wrapper = createWrapper();
			
			expect(wrapper.find('[data-testid="file-input-area"]').exists() || 
				   wrapper.find('label[for="image-input"]').exists()).toBe(true);
			expect(wrapper.find('input[type="file"]').exists()).toBe(true);
			expect(wrapper.text()).toContain('画像をドラッグ＆ドロップ');
		});

		it('モバイルでない場合、SettingsSectionを表示する', () => {
			responsiveContext.isMobile.value = false;
			const wrapper = createWrapper();
			
			expect(wrapper.findComponent({ name: 'SettingsSection' }).exists()).toBe(true);
		});

		it('モバイルの場合、SettingsSectionを表示しない', () => {
			responsiveContext.isMobile.value = true;
			const wrapper = createWrapper();
			
			expect(wrapper.findComponent({ name: 'SettingsSection' }).exists()).toBe(false);
		});
	});

	describe('ファイル選択', () => {
		it('ファイル入力で画像ファイルを選択できる', async () => {
			const wrapper = createWrapper();
			const fileInput = wrapper.find('input[type="file"]');
			
			const file = new File(['image content'], 'test.jpg', { type: 'image/jpeg' });
			
			// FileReaderのモック
			const mockFileReader = {
				onload: null as any,
				onerror: null as any,
				readAsArrayBuffer: vi.fn(function() {
					if (mockFileReader.onload) {
						mockFileReader.onload({
							target: { result: new ArrayBuffer(8) }
						});
					}
				})
			};
			global.FileReader = vi.fn(() => mockFileReader) as any;
			
			// ファイル選択をシミュレート
			Object.defineProperty(fileInput.element, 'files', {
				value: [file],
				writable: false
			});
			
			await fileInput.trigger('change');
			
			expect(mockFileReader.readAsArrayBuffer).toHaveBeenCalledWith(file);
		});

		it('画像以外のファイルを選択した場合、エラー通知を表示する', async () => {
			const wrapper = createWrapper();
			const fileInput = wrapper.find('input[type="file"]');
			
			const file = new File(['text content'], 'test.txt', { type: 'text/plain' });
			
			// ファイル選択をシミュレート
			Object.defineProperty(fileInput.element, 'files', {
				value: [file],
				writable: false
			});
			
			await fileInput.trigger('change');
			
			expect(notificationManager.notify).toHaveBeenCalledWith(
				'画像ファイルを選択してください',
				'error'
			);
		});
	});

	describe('ドラッグ&ドロップ', () => {
		it('ドラッグオーバー時にisDraggingがtrueになる', async () => {
			const wrapper = createWrapper();
			const dropZone = wrapper.find('[class*="border-dashed"]');
			
			await dropZone.trigger('dragover');
			
			// isDraggingの状態変化を確認（実装に応じて調整）
			expect((wrapper.vm as any).isDragging).toBe(true);
		});

		it('ドラッグリーブ時にisDraggingがfalseになる', async () => {
			const wrapper = createWrapper();
			const dropZone = wrapper.find('[class*="border-dashed"]');
			
			await dropZone.trigger('dragover');
			await dropZone.trigger('dragleave');
			
			expect((wrapper.vm as any).isDragging).toBe(false);
		});
		
		it('画像ファイルドロップ時に画像を読み込む', async () => {
			const wrapper = createWrapper();
			const dropZone = wrapper.find('[class*="border-dashed"]');
			
			const file = new File(['image content'], 'test.jpg', { type: 'image/jpeg' });
			
			// FileReaderのモック
			const mockFileReader = {
				onload: null as any,
				onerror: null as any,
				readAsArrayBuffer: vi.fn(function() {
					if (mockFileReader.onload) {
						mockFileReader.onload({
							target: { result: new ArrayBuffer(8) }
						});
					}
				})
			};
			global.FileReader = vi.fn(() => mockFileReader) as any;
			
			// dropイベントを直接呼び出し
			const mockEvent = {
				dataTransfer: { files: [file] },
				preventDefault: vi.fn()
			};
			
			await dropZone.trigger('drop', mockEvent);
			
			expect(mockFileReader.readAsArrayBuffer).toHaveBeenCalledWith(file);
		});
	});

	describe('URL入力', () => {
		it('URLから画像をダウンロードできる', async () => {
			const wrapper = createWrapper();
			const urlInput = wrapper.find('input[type="url"]');
			const downloadButton = wrapper.find('button');
			
			await urlInput.setValue('https://example.com/image.jpg');
			
			// FileReaderのモック
			const mockFileReader = {
				onload: null as any,
				onerror: null as any,
				readAsArrayBuffer: vi.fn(function() {
					if (mockFileReader.onload) {
						mockFileReader.onload({
							target: { result: new ArrayBuffer(8) }
						});
					}
				})
			};
			global.FileReader = vi.fn(() => mockFileReader) as any;
			
			await downloadButton.trigger('click');
			
			expect(global.fetch).toHaveBeenCalledWith('https://example.com/image.jpg');
			expect(notificationManager.notify).toHaveBeenCalledWith(
				'ダウンロードを開始します...',
				'info'
			);
		});

		it('URLハッシュからパラメータを読み込む', async () => {
			const wrapper = createWrapper();
			const urlInput = wrapper.find('input[type="url"]');
			const downloadButton = wrapper.find('button');
			
			vi.mocked(arkimgUtils.loadParameter).mockReturnValue({
				key: new Uint8Array([1, 2, 3]),
				iv: new Uint8Array([4, 5, 6]),
				pubkey: new Uint8Array([7, 8, 9])
			});
			
			await urlInput.setValue('https://example.com/image.jpg#key=abc&iv=def');
			
			const mockFileReader = {
				onload: null as any,
				onerror: null as any,
				readAsArrayBuffer: vi.fn(function() {
					if (mockFileReader.onload) {
						mockFileReader.onload({
							target: { result: new ArrayBuffer(8) }
						});
					}
				})
			};
			global.FileReader = vi.fn(() => mockFileReader) as any;
			
			await downloadButton.trigger('click');
			
			expect(arkimgUtils.loadParameter).toHaveBeenCalledWith('key=abc&iv=def');
		});

		it('ダウンロードに失敗した場合、エラー通知を表示する', async () => {
			const wrapper = createWrapper();
			const urlInput = wrapper.find('input[type="url"]');
			const downloadButton = wrapper.find('button');
			
			vi.mocked(global.fetch).mockRejectedValue(new Error('Network error'));
			
			await urlInput.setValue('https://example.com/invalid.jpg');
			await downloadButton.trigger('click');
			
			expect(notificationManager.notify).toHaveBeenCalledWith(
				'画像のダウンロードに失敗しました',
				'error'
			);
		});
	});

	describe('画像表示', () => {
		it('ベース画像がある場合、画像を表示する', async () => {
			arkImgState.baseImage.value = new Uint8Array([1, 2, 3, 4]);
			arkImgState.baseImageFileName.value = 'test.jpg';
			arkImgState.baseImageMIME.value = 'image/jpeg';
			
			const wrapper = createWrapper();
			
			// コンポーネントが画像を処理するまで待機
			await wrapper.vm.$nextTick();
			
			expect(arkimgUtils.loadImage).toHaveBeenCalled();
		});

		it('画像読み込み中はローディング表示をする', async () => {
			const wrapper = createWrapper();
			
			// ローディング状態を設定
			(wrapper.vm as any).isLoading = true;
			await wrapper.vm.$nextTick();
			
			expect(wrapper.find('.animate-spin').exists()).toBe(true);
			expect(wrapper.text()).toContain('読み込み中...');
		});

		it('画像読み込みエラー時はエラー表示と再試行ボタンを表示する', async () => {
			const wrapper = createWrapper();
			
			// エラー状態を設定
			(wrapper.vm as any).isImageLoadingError = true;
			await wrapper.vm.$nextTick();
			
			expect(wrapper.text()).toContain('画像の読み込みに失敗しました');
			expect(wrapper.find('button').text()).toContain('再試行');
		});
	});

	describe('画像アンロード', () => {
		it('×ボタンクリックで画像をアンロードする', async () => {
			// 画像を設定してマウント
			arkImgState.baseImage.value = new Uint8Array([1, 2, 3, 4]);
			arkImgState.baseImageFileName.value = 'test.jpg';
			arkImgState.baseImageMIME.value = 'image/jpeg';
			const wrapper = createWrapper();
			
			(wrapper.vm as any).imageUrl = 'blob:mock-url'; // 画像URLを直接設定
			
			// 画像が読み込まれるまで待機
			await wrapper.vm.$nextTick();
			await flushPromises();
			
			// ×ボタンを探して クリック
			// テンプレート構造に基づいて適切なセレクターを使用
			const closeButton = wrapper.find('#UnloadButton');
			await closeButton.trigger('click');
			
			expect(arkImgState.baseImage.value).toBeNull();
			expect(arkImgState.baseImageFileName.value).toBeNull();
			expect(arkImgState.baseImageMIME.value).toBeNull();
		});
	});

	describe('再試行機能', () => {
		it('再試行ボタンクリックで画像読み込みを再実行する', async () => {
			arkImgState.baseImage.value = new Uint8Array([1, 2, 3, 4]);
			const wrapper = createWrapper();
			
			// エラー状態を設定
			(wrapper.vm as any).isLoading = false;
			(wrapper.vm as any).isImageLoadingError = true;
			await wrapper.vm.$nextTick();
			
			// 再試行ボタンを正確に特定
			const retryButton = wrapper.find('#RetryButton');
			await retryButton.trigger('click');
			
			expect(arkimgUtils.loadImage).toHaveBeenCalled();
		});
	});

	describe('コンポーネントライフサイクル', () => {
		it('アンマウント時にURL.revokeObjectURLを呼び出す', () => {
			const wrapper = createWrapper();
			(wrapper.vm as any).imageUrl = 'blob:mock-url';
			
			wrapper.unmount();
			
			expect(global.URL.revokeObjectURL).toHaveBeenCalledWith('blob:mock-url');
		});
	});
});
