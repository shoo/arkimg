import type { Ref } from 'vue';

export interface SecretItem {
	data: Uint8Array;                           // 平文のデータ
	name?: string;                              // ファイル名
	mime?: string;                              // MIMEタイプ
	comment?: string;                           // コメント
	modified?: Date;                            // 作成日時
	isSignVerified?: boolean;                   // 署名検証状態
	prvkey?: Uint8Array;                        // 秘密鍵
}

export interface ArkImgState {
	baseImage: Ref<Uint8Array | null>;
	baseImageFileName: Ref<string | null>;
	baseImageMIME: Ref<string | null>;
	secretItems: Ref<SecretItem[]>;
	selectedItem: Ref<number | null>;
	addItem: (item: SecretItem) => void;
	updateItem: (index: number, item: SecretItem) => void;
	removeItem: (index: number) => void;
}
