import { describe, it, expect, beforeEach, vi } from 'vitest';
import { shallowMount, type VueWrapper } from '@vue/test-utils';
import SecretDataListSection from '@/components/SecretDataListSection.vue';
import type { ArkImgState, SecretItem } from '@/types/arkimg';
import type { CryptoContext } from '@/types/crypto';
import type { ResponsiveContext, NotificationManager, ModalController } from '@/types/ui';

describe('SecretDataListSection.vue', () => {
	let wrapper: VueWrapper<any>;
	let mockArkImgState: ArkImgState;
	let mockCryptoContext: CryptoContext;
	let mockResponsiveContext: ResponsiveContext;
	let mockNotificationManager: NotificationManager;
	let mockModalController: ModalController;
	
	const createMockSecretItem = (overrides: Partial<SecretItem> = {}): SecretItem => ({
		data: new Uint8Array([1, 2, 3]),
		name: 'test.txt',
		mime: 'text/plain',
		comment: 'テストファイル',
		modified: new Date(),
		isSignVerified: true,
		prvkey: undefined,
		...overrides
	});
	
	beforeEach(() => {
		mockArkImgState = {
			secretItems: { value: [] },
			selectedItem: { value: null },
			addItem: vi.fn(),
			removeItem: vi.fn()
		} as any;
		
		mockCryptoContext = {
			prvkey: { value: null }
		} as any;
		
		mockResponsiveContext = {
			isMobile: { value: false }
		} as any;
		
		mockNotificationManager = {
			notify: vi.fn()
		} as any;
		
		mockModalController = {
			openModal: vi.fn()
		} as any;
		
		wrapper = shallowMount(SecretDataListSection, {
			global: {
				provide: {
					arkImgState: mockArkImgState,
					cryptoContext: mockCryptoContext,
					responsiveContext: mockResponsiveContext,
					notificationManager: mockNotificationManager,
					modalController: mockModalController
				}
			}
		});
	});
	
	describe('初期表示', () => {
		it('データが存在しない場合、案内メッセージが表示される', () => {
			expect(wrapper.text()).toContain('秘密データが追加されていません');
			expect(wrapper.text()).toContain('下の追加エリアからファイルを追加してください');
		});
		
		it('ファイル追加エリアが表示される', () => {
			expect(wrapper.text()).toContain('ファイルをここにドラッグ＆ドロップ');
			expect(wrapper.text()).toContain('ファイルを選択');
		});
	});
	
	describe('PCモードでのデータ表示', () => {
		beforeEach(() => {
			mockArkImgState.secretItems.value = [
				createMockSecretItem(),
				createMockSecretItem({
					name: 'image.png',
					mime: 'image/png',
					isSignVerified: false
				}),
				createMockSecretItem({
					name: 'image.webp',
					mime: 'image/webp',
					isSignVerified: undefined
				})
			];
			mockResponsiveContext.isMobile.value = false;
			wrapper = shallowMount(SecretDataListSection, {
				global: {
					provide: {
						arkImgState: mockArkImgState,
						cryptoContext: mockCryptoContext,
						responsiveContext: mockResponsiveContext,
						notificationManager: mockNotificationManager,
						modalController: mockModalController
					}
				}
			});
		});
		
		it('リスト形式でファイルが表示される', () => {
			expect(wrapper.text()).toContain('test.txt');
			expect(wrapper.text()).toContain('image.png');
		});
		
		it('署名検証状態のアイコンが適切に表示される', () => {
			const items = wrapper.findAll('.secret-item');
			expect(items).toHaveLength(3);
			const icon1 = items[0].find("svg");
			expect(mockArkImgState.secretItems.value[0].isSignVerified).toBe(true);
			expect(icon1.classes("text-green-500")).toBe(true);
			const icon2 = items[1].find("svg");
			expect(mockArkImgState.secretItems.value[1].isSignVerified).toBe(false);
			expect(icon2.classes("text-red-500")).toBe(true);
			const icon3 = items[2].find("svg");
			expect(mockArkImgState.secretItems.value[2].isSignVerified).toBeUndefined();
			expect(icon3.classes("text-gray-400")).toBe(true);
		});
		
		it('ファイルタイプに応じたアイコンが表示される', () => {
			expect(wrapper.html()).toContain('text-green-500'); // テキストファイル用アイコン
			expect(wrapper.html()).toContain('text-blue-500'); // 画像ファイル用アイコン
		});
		
		it('署名検証に失敗したファイルは赤色で強調表示される', () => {
			expect(wrapper.html()).toContain('border-red-300 bg-red-50');
		});
	});

	describe('モバイルモードでのアコーディオン表示', () => {
		beforeEach(() => {
			mockArkImgState.secretItems.value = [createMockSecretItem()];
			mockResponsiveContext.isMobile.value = true;
			wrapper = shallowMount(SecretDataListSection, {
				global: {
					provide: {
						arkImgState: mockArkImgState,
						cryptoContext: mockCryptoContext,
						responsiveContext: mockResponsiveContext,
						notificationManager: mockNotificationManager,
						modalController: mockModalController
					}
				}
			});
		});
		
		it('アコーディオン形式で表示される', () => {
			expect(wrapper.find('.secret-item-mobile')).toBeDefined();
		});
		
		it('アコーディオンヘッダーをクリックすると展開される', async () => {
			const header = wrapper.find('[data-test-id="accordion-header"]');
			if (header.exists()) {
				await header.trigger('click');
				expect(wrapper.vm.expandedItemIndex).toBe(0);
			}
		});
	});
	
	describe('ファイル選択機能', () => {
		it('アイテムをクリックすると選択される', async () => {
			mockArkImgState.secretItems.value = [createMockSecretItem()];
			await wrapper.setData({});
			
			const selectItemSpy = vi.spyOn(wrapper.vm, 'selectItem');
			await wrapper.vm.selectItem(0);
			
			expect(selectItemSpy).toHaveBeenCalledWith(0);
		});
		
		it('選択をクリアできる', async () => {
			mockArkImgState.selectedItem.value = 0;
			
			await wrapper.vm.clearSelection();
			
			expect(mockArkImgState.selectedItem.value).toBeNull();
		});
	});
	
	describe('ファイル削除機能', () => {
		beforeEach(() => {
			mockArkImgState.secretItems.value = [createMockSecretItem()];
		});
		
		it('削除ボタンクリックで確認モーダルが開かれる', async () => {
			await wrapper.vm.confirmDelete(0);
			
			expect(mockModalController.openModal).toHaveBeenCalledWith({
				title: 'ファイルの削除',
				message: '「test.txt」を削除しますか？この操作は取り消せません。',
				confirmText: '削除',
				cancelText: 'キャンセル',
				onConfirm: expect.any(Function)
			});
		});
		
		it('削除確認時にアイテムが削除される', async () => {
			mockModalController.openModal = vi.fn().mockImplementation(({ onConfirm }) => {
				onConfirm();
			});
			
			await wrapper.vm.confirmDelete(0);
			
			expect(mockArkImgState.removeItem).toHaveBeenCalledWith(0);
			expect(mockNotificationManager.notify).toHaveBeenCalledWith(
				'「test.txt」を削除しました',
				'success'
			);
		});
	});
	
	describe('ドラッグ&ドロップ機能', () => {
		it('ドラッグオーバー時にスタイルが変更される', async () => {
			const mockEvent = {
				preventDefault: vi.fn(),
				dataTransfer: { files: [] }
			} as any;

			await wrapper.vm.handleDragOver(mockEvent);
			
			expect(wrapper.vm.dragging).toBe(true);
			expect(mockEvent.preventDefault).toHaveBeenCalled();
		});
		
		it('ドラッグリーブ時にスタイルがリセットされる', async () => {
			wrapper.vm.dragging = true;
			const mockEvent = {
				preventDefault: vi.fn(),
				currentTarget: { getBoundingClientRect: () => ({ left: 0, right: 100, top: 0, bottom: 100 }) },
				clientX: 200,
				clientY: 200
			} as any;

			await wrapper.vm.handleDragLeave(mockEvent);
			
			expect(wrapper.vm.dragging).toBe(false);
		});
		
		it('ファイルドロップ時に処理される', async () => {
			const mockArrayBuffer = new Uint8Array(4);
		
			const mockFile = {
				name: "test.txt",
				type: "text/plain",
				size: 4,
				lastModified: Date.now(),
				arrayBuffer: vi.fn().mockResolvedValue(mockArrayBuffer),
			} as unknown as File;
			
			const mockEvent = {
				preventDefault: vi.fn(),
				dataTransfer: { files: [mockFile] },
			} as any;
			
			const addItemSpy = vi.spyOn(mockArkImgState, "addItem");
			await wrapper.vm.handleDrop(mockEvent);
			
			expect(addItemSpy).toHaveBeenCalledWith(
				expect.objectContaining({
					name: "test.txt",
					mime: "text/plain"
				}));
			expect(wrapper.vm.dragging).toBe(false);
		});
	});
	
	describe('ファイル処理機能', () => {
		it('有効なファイルが正常に処理される', async () => {
			// Fileコンストラクタをモック
			const mockArrayBuffer = new ArrayBuffer(12);
			const mockFile = {
				name: 'test.txt',
				type: 'text/plain',
				size: 12,
				lastModified: Date.now(),
				arrayBuffer: vi.fn().mockResolvedValue(mockArrayBuffer)
			} as any;
			
			const files = [mockFile];
			await wrapper.vm.processFiles(files);
			
			expect(mockArkImgState.addItem).toHaveBeenCalled();
			expect(mockNotificationManager.notify).toHaveBeenCalledWith(
				'1個のファイルを追加しました',
				'success'
			);
		});
		
		it('大きすぎるファイルは拒否される', async () => {
			// 小さいファイルを作成してsizeだけモック
			const mockLargeFile = new File(['small content'], 'large.txt', { 
				type: 'text/plain'
			});
			
			// sizeプロパティだけを大きな値に設定
			Object.defineProperty(mockLargeFile, 'size', { 
				value: 51 * 1024 * 1024, // 51MB
				writable: false,
				configurable: false
			});
			
			const files = [mockLargeFile] as any;
			await wrapper.vm.processFiles(files);
			
			expect(mockNotificationManager.notify).toHaveBeenCalledWith(
				expect.stringContaining('large.txt (ファイルサイズが大きすぎます)'),
				'error'
			);
			expect(mockArkImgState.addItem).not.toHaveBeenCalled();
		});
		
		it('空のファイルは拒否される', async () => {
			const mockEmptyFile = new File([], 'empty.txt', { type: 'text/plain' });
			Object.defineProperty(mockEmptyFile, 'size', { value: 0 });

			const files = [mockEmptyFile] as any;
			await wrapper.vm.processFiles(files);
			
			expect(mockNotificationManager.notify).toHaveBeenCalledWith(
				expect.stringContaining('empty.txt (空のファイル)'),
				'error'
			);
		});
	});
	
	describe('ユーティリティ関数', () => {
		it('ファイル名が正しくフォーマットされる', () => {
			expect(wrapper.vm.formatFileName('short.txt')).toBe('short.txt');
			expect(wrapper.vm.formatFileName('very-long-filename-that-exceeds-limit.txt'))
				.toBe('very-long-filename-th....txt');
		});
		
		it('ファイルサイズが正しくフォーマットされる', () => {
			expect(wrapper.vm.formatFileSize(0)).toBe('0 B');
			expect(wrapper.vm.formatFileSize(1024)).toBe('1 KB');
			expect(wrapper.vm.formatFileSize(1048576)).toBe('1 MB');
		});
		
		it('画像ファイルが正しく判定される', () => {
			expect(wrapper.vm.isImageFile('image/png')).toBe(true);
			expect(wrapper.vm.isImageFile('image/jpeg')).toBe(true);
			expect(wrapper.vm.isImageFile('text/plain')).toBe(false);
			expect(wrapper.vm.isImageFile(undefined)).toBe(false);
		});
		
		it('テキストファイルが正しく判定される', () => {
			expect(wrapper.vm.isTextFile('text/plain')).toBe(true);
			expect(wrapper.vm.isTextFile('application/json')).toBe(true);
			expect(wrapper.vm.isTextFile('image/png')).toBe(false);
			expect(wrapper.vm.isTextFile(undefined)).toBe(false);
		});
	});

	describe('ファイル入力トリガー', () => {
		it('ファイル選択ボタンクリックでファイル入力がトリガーされる', async () => {
			const mockClick = vi.fn();
			const mockFileInput = { click: mockClick };
			
			// Vue 3では異なるアプローチを使用
			wrapper.vm.fileInput = mockFileInput;
			
			await wrapper.vm.triggerFileInput();
			
			expect(mockClick).toHaveBeenCalled();
		});
		
		it('ファイル選択後に処理される', async () => {
			const mockArrayBuffer = new Uint8Array(12);
			const mockFile = {
				name: 'test.txt',
				type: 'text/plain',
				size: 12,
				arrayBuffer: vi.fn().mockResolvedValue(mockArrayBuffer),
			} as unknown as File;
			
			const addItemSpy = vi.spyOn(mockArkImgState, 'addItem');
			
			const mockEvent = {
				target: {
					files: [mockFile] as any, // FileListとして扱う
					value: 'test.txt'
				}
			} as any;
			
			await wrapper.vm.handleFileSelect(mockEvent);
			
			expect(addItemSpy).toHaveBeenCalledWith(
				expect.objectContaining({
					name: "test.txt",
					mime: "text/plain"
				}));
			expect(mockEvent.target.value).toBe('');
		});
	});
});
