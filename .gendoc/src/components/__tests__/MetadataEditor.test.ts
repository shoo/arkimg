import { describe, it, expect, beforeEach, vi } from 'vitest';
import { DOMWrapper, shallowMount, VueWrapper } from '@vue/test-utils';
import { ref } from 'vue';
import MetadataEditor from '@/components/MetadataEditor.vue';

describe('MetadataEditor.vue', () => {
	let mockArkImgState: any;
	let mockNotificationManager: any;
	let wrapper: VueWrapper;

	beforeEach(() => {
		mockArkImgState = {
			selectedItem: ref(null),
			secretItems: ref([
				{
					name: 'test.jpg',
					comment: 'テストコメント',
					modified: new Date('2025-01-01T10:00:00Z'),
					mime: 'image/jpeg',
					data: new Uint8Array([1, 2, 3, 4, 5])
				}
			]),
			updateItem: vi.fn()
		};

		mockNotificationManager = {
			notify: vi.fn()
		};

		wrapper = shallowMount(MetadataEditor, {
			global: {
				provide: {
					arkImgState: mockArkImgState,
					notificationManager: mockNotificationManager
				}
			}
		});
	});

	describe('初期状態', () => {
		it('アイテムが選択されていない時にメッセージを表示する', () => {
			expect(wrapper.find('.text-center').text()).toBe('データを選択してください');
		});

		it('編集モードが無効になっている', () => {
			expect((wrapper.vm as any).isEditing).toBe(false);
		});
	});

	describe('アイテム選択時', () => {
		beforeEach(() => {
			mockArkImgState.selectedItem.value = 0;
		});

		it('ファイル情報を正しく表示する', () => {
			expect((wrapper.find('#filename').element as HTMLInputElement).value).toBe('test.jpg');
			expect((wrapper.find('#comment').element as HTMLTextAreaElement).value).toBe('テストコメント');
		});

		it('ファイルサイズを正しくフォーマットして表示する', () => {
			const sizeElement = wrapper.findAll('span').find((span: DOMWrapper<Node>) => span.text().includes('B'));
			expect(sizeElement?.text()).toBe('5 B');
		});

		it('編集ボタンが表示される', () => {
			const editButton = wrapper.find('button');
			expect(editButton.text()).toBe('編集');
		});

		it('署名検証ステータスが未検証として表示される', () => {
			const statusElement = wrapper.find('.text-gray-500 span');
			expect(statusElement.text()).toBe('未検証');
		});
	});

	describe('編集モード', () => {
		beforeEach(async () => {
			mockArkImgState.selectedItem.value = 0;
			await wrapper.vm.$nextTick();
			// 編集ボタンをクリックして編集モードに切り替え
			await wrapper.find('button').trigger('click');
			await wrapper.vm.$nextTick();
		});

		it('編集モードに切り替わる', () => {
			expect((wrapper.vm as any).isEditing).toBe(true);
		});

		it('保存とキャンセルボタンが表示される', () => {
			const buttons = wrapper.findAll('button');
			expect(buttons[0].text()).toBe('保存');
			expect(buttons[1].text()).toBe('キャンセル');
		});

		it('入力フィールドが有効になる', () => {
			expect(wrapper.find('#filename').attributes('disabled')).toBeUndefined();
			expect(wrapper.find('#comment').attributes('disabled')).toBeUndefined();
		});
	});

	describe('バリデーション', () => {
		beforeEach(async () => {
			mockArkImgState.selectedItem.value = 0;
			await wrapper.vm.$nextTick();
			await wrapper.find('button').trigger('click');
			await wrapper.vm.$nextTick();
		});

		it('ファイル名が空の場合エラーメッセージを表示する', async () => {
			(wrapper.vm as any).editingMetadata.name = '';
			await (wrapper.vm as any).saveMetadata();
			await wrapper.vm.$nextTick();
			
			expect((wrapper.vm as any).validationErrors.filename).toBe('ファイル名を入力してください');
		});

		it('バリデーションエラー時に保存されない', async () => {
			(wrapper.vm as any).editingMetadata.name = '';
			await (wrapper.vm as any).saveMetadata();
			
			expect(mockArkImgState.updateItem).not.toHaveBeenCalled();
		});
	});

	describe('データ保存', () => {
		beforeEach(async () => {
			mockArkImgState.selectedItem.value = 0;
			await (wrapper.vm as any).startEditing();
		});

		it('有効なデータの場合保存処理を実行する', async () => {
			(wrapper.vm as any).editingMetadata.name = 'updated.jpg';
			(wrapper.vm as any).editingMetadata.comment = '更新されたコメント';
			
			await (wrapper.vm as any).saveMetadata();
			
			expect(mockArkImgState.updateItem).toHaveBeenCalledWith(0, expect.objectContaining({
				name: 'updated.jpg',
				comment: '更新されたコメント'
			}));
		});

		it('保存成功時に成功通知を表示する', async () => {
			(wrapper.vm as any).editingMetadata.name = 'valid.jpg';
			
			await (wrapper.vm as any).saveMetadata();
			
			expect(mockNotificationManager.notify).toHaveBeenCalledWith('メタデータを保存しました', 'success');
		});

		it('保存後に編集モードを終了する', async () => {
			(wrapper.vm as any).editingMetadata.name = 'valid.jpg';
			
			await (wrapper.vm as any).saveMetadata();
			
			expect((wrapper.vm as any).isEditing).toBe(false);
		});
	});

	describe('編集キャンセル', () => {
		beforeEach(async () => {
			mockArkImgState.selectedItem.value = 0;
			await wrapper.vm.$nextTick();
			await wrapper.find('button').trigger('click');
			await wrapper.vm.$nextTick();
		});

		it('変更をキャンセルして編集モードを終了する', async () => {
			// データを変更
			(wrapper.vm as any).editingMetadata.name = 'changed.jpg';
			await wrapper.vm.$nextTick();
			
			// キャンセルボタンをクリック
			await wrapper.findAll('button')[1].trigger('click');
			await wrapper.vm.$nextTick();
			
			expect((wrapper.vm as any).isEditing).toBe(false);
			// cancelEditingはresetEditingStateを呼び出すため、元の値に戻る
			expect((wrapper.vm as any).editingMetadata.name).toBe('test.jpg');
		});
	});

	describe('変更検知', () => {
		beforeEach(async () => {
			mockArkImgState.selectedItem.value = 0;
			await wrapper.vm.$nextTick();
			await wrapper.find('button').trigger('click');
			await wrapper.vm.$nextTick();
		});

		it('ファイル名変更時に変更フラグが立つ', async () => {
			(wrapper.vm as any).editingMetadata.name = 'changed.jpg';
			await wrapper.vm.$nextTick();
			
			expect((wrapper.vm as any).hasChanges).toBe(true);
		});

		it('コメント変更時に変更フラグが立つ', async () => {
			(wrapper.vm as any).editingMetadata.comment = '変更されたコメント';
			await wrapper.vm.$nextTick();
			
			expect((wrapper.vm as any).hasChanges).toBe(true);
		});

		it('変更がない場合は変更フラグが立たない', () => {
			expect((wrapper.vm as any).hasChanges).toBe(false);
		});
	});

	describe('ファイルサイズフォーマット', () => {
		const testCases = [
			{ size: 500, expected: '500 B' },
			{ size: 1536, expected: '1.50 KB' },
			{ size: 1572864, expected: '1.50 MB' },
			{ size: 1610612736, expected: '1.50 GB' }
		];

		testCases.forEach(({ size, expected }) => {
			it(`${size}バイトを${expected}にフォーマットする`, () => {
				expect((wrapper.vm as any).formatFileSize(size)).toBe(expected);
			});
		});
	});
});
