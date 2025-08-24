import type { Ref } from 'vue';

export interface CryptoContext {
	key: Ref<Uint8Array | null>        // AES共通鍵（バイト列）
	iv: Ref<Uint8Array | null>         // AES初期化ベクトル（バイト列、null可）
	prvkey: Ref<Uint8Array | null>     // 秘密鍵（バイト列）
	pubkey: Ref<Uint8Array | null>     // 公開鍵（バイト列）
	isKeyValid: () => boolean          // 鍵の整合性チェック（AES鍵と必要な鍵が揃っているか）
}
