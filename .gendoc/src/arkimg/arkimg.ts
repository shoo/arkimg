
import { decodeBase64URLNoPadding, encodeBase64URLNoPadding } from "@/utils/misc";

export interface ArkImgMetadataItem {
	name?: string;
	mime?: string;
	sign?: string;
	comment?: string;
	modified?: string;
}

export interface ArkImg {
	// 署名を持っているか確認
	hasSign(idx?: number): boolean;
	// 検証されているか確認
	isVerified(idx?: number): boolean | undefined;
	// メタデータを設定
	setMetadata(metadata: any): void;
	// メタデータを取得
	getMetadata(): any;
	// ベース画像設定
	setBaseImage(binary: Uint8Array, mimeType?: string): void;
	// ベース画像取得
	getBaseImage(mimeType?: string): Uint8Array;
	// 添付する秘密データを追加(平文で指定)
	addSecretItem(binary: Uint8Array, name?: string, mimeType?: string, modified?: Date, comment?: string, prvKey?: Uint8Array): void;
	// 添付する秘密データを全削除
	clearSecretItems(): void;
	// 添付されている暗号化された秘密データの数
	getSecretItemCount(): number;
	// 添付されている復号された秘密データ
	getSecretItem(idx: number): Uint8Array;
	// 秘密データのメタデータを設定
	setMetadataItem(idx: number, mditm: ArkImgMetadataItem | undefined): void;
	// 秘密データのメタデータを取得
	getMetadataItem(idx: number): ArkImgMetadataItem | undefined;
}


export async function encryptAES(data: Uint8Array, key: Uint8Array, iv?: Uint8Array): Promise<Uint8Array> {
	const aesType: number = key.length * 8;
	const aesAlgo: string = iv?.length === 12 ? "AES-GCM" : "AES-CBC";
	// Web Crypto API を使用して AES-CBC で暗号化
	const encIv = iv || crypto.getRandomValues(new Uint8Array(16));
	const result = await crypto.subtle.encrypt(
		{
			name: aesAlgo,
			iv: encIv as BufferSource
		},
		await crypto.subtle.importKey(
			"raw",
			key as BufferSource,
			{ name: aesAlgo, length: aesType },
			false,
			["encrypt"]
		),
		data as BufferSource
	);
	if (iv)
		return new Uint8Array(result);
	const encryptedData = new Uint8Array(encIv.length + result.byteLength);
	encryptedData.set(encIv, 0);
	encryptedData.set(new Uint8Array(result), encIv.length);
	return encryptedData;
}


export async function decryptAES(data: Uint8Array, key: Uint8Array, iv?: Uint8Array | null): Promise<Uint8Array> {
	const aesType: number = key.length * 8;
	const aesAlgo: string = iv?.length === 12 ? "AES-GCM" : "AES-CBC";
	// Web Crypto API を使用して AES-CBC で復号
	return new Uint8Array(await crypto.subtle.decrypt(
		{
			name: aesAlgo,
			iv: (iv || data.slice(0, 16)) as BufferSource
		},
		await crypto.subtle.importKey(
			"raw",
			key as BufferSource,
			{ name: aesAlgo, length: aesType },
			false,
			["decrypt"]
		),
		(iv ? data : data.slice(16)) as BufferSource
	));
}

export async function singEd25519(data: Uint8Array, prvkey: Uint8Array): Promise<Uint8Array> {
	// 32バイトの生鍵からPKCS#8形式に変換する関数
	function createEd25519PKCS8PrivateKey(privateKeyBytes: Uint8Array) {
		// Ed25519 PKCS#8 DER形式のヘッダー
		const pkcs8Header = new Uint8Array([
			0x30, 0x2e, // SEQUENCE (46 bytes)
			0x02, 0x01, 0x00, // INTEGER 0 (version)
			0x30, 0x05, // SEQUENCE (5 bytes) - AlgorithmIdentifier
			0x06, 0x03, 0x2b, 0x65, 0x70, // OID 1.3.101.112 (Ed25519)
			0x04, 0x22, // OCTET STRING (34 bytes)
			0x04, 0x20 // OCTET STRING (32 bytes) - private key
		]);
	
		const result = new Uint8Array(pkcs8Header.length + privateKeyBytes.length);
		result.set(pkcs8Header);
		result.set(privateKeyBytes, pkcs8Header.length);
		
		return result;
	}
	return new Uint8Array(await crypto.subtle.sign(
		{ name: "Ed25519" },
		await crypto.subtle.importKey(
			"pkcs8",
			createEd25519PKCS8PrivateKey(prvkey),
			{ name: "Ed25519", namedCurve: "Ed25519" },
			true,
			["sign"]
		),
		data as BufferSource
	));
}


export async function verifyEd25519(data: Uint8Array, signature: Uint8Array, pubkey: Uint8Array): Promise<boolean> {
	return await crypto.subtle.verify(
		{ name: "Ed25519" },
		await crypto.subtle.importKey(
			"raw",
			pubkey as BufferSource,
			{ name: "Ed25519", namedCurve: "Ed25519" },
			false,
			["verify"]
		),
		signature as BufferSource,
		data as BufferSource
	);
}

export class EncryptedData {
	data: Uint8Array;    // データ本体の暗号文
	verified?: boolean;  // 暗号文の署名を検証した場合は true(検証済み)/false(検証失敗) が入る
	prvkey?: Uint8Array; // 秘密鍵を指定できる
	constructor(data: Uint8Array) {
		this.data = data;
	}
}
export class DecryptedData {
	data: Uint8Array;    // データ本体の平文
	verified?: boolean;  // 復号前に暗号文が検証された場合は true(検証済み)/false(検証失敗) が入る
	prvkey?: Uint8Array; // 暗号化する際に個別に秘密鍵を指定できる
	constructor(data: Uint8Array) {
		this.data = data;
	}
}

export class ArkImgBase implements ArkImg {
	protected baseImageData!: Uint8Array;
	protected secretItems: (EncryptedData | DecryptedData)[] = [];
	protected metadata?: {items: ArkImgMetadataItem[]};
	
	protected async getEncryptedMetadata(): Promise<Uint8Array | null> {
		if (this.metadata && this._key && this._key.length > 0) {
			return await encryptAES(new TextEncoder().encode(JSON.stringify(this.metadata)), this._key!, this._iv);
		}
		return null;
	}
	protected async setEncryptedMetadata(metadata: Uint8Array): Promise<void> {
		if (this._key && this._key.length > 0) {
			this.metadata = JSON.parse(new TextDecoder().decode(await decryptAES(metadata, this._key!, this._iv)));
		}
	}
	
	protected async addEncryptedSecretItem(data: Uint8Array): Promise<void> {
		if (this._key && this._key.length > 0) {
			this.secretItems.push(new EncryptedData(data));
		}
	}
	
	protected async exportImage(): Promise<Uint8Array> {
		throw new Error("Not implement.")
	}
	protected async importImage(buffer: Uint8Array): Promise<void> {
		this.baseImageData = buffer;
		throw new Error("Not implement.")
	}
	
	private _key!: Uint8Array | null;
	private _iv?: Uint8Array;
	private _prvkey?: Uint8Array;
	private _pubkey?: Uint8Array;
	
	private _getMetadataItemValue(i: number, name: string): string | Date | Uint8Array | undefined {
		if (!this.metadata || this.metadata instanceof Uint8Array) {
			return undefined;
		}
		if (i >= this.metadata.items.length) {
			return undefined;
		}
		const data = this.metadata.items[i];
		switch (name) {
		case "name":
			return data.name;
		case "mime":
			return data.mime;
		case "sign":
			if (data.sign === undefined) {
				return undefined;
			}
			// Base64デコードしてUint8Arrayに変換
			return decodeBase64URLNoPadding(data.sign);
		case "comment":
			return data.comment;
		case "modified":
			if (data.modified === undefined) {
				return undefined;
			}
			return new Date(data.modified);
		default:
			const dic = data as any;
			return dic[name];
		}
	}
	
	private _setMetadataItemValue(i: number, name: string, data: string | Date | Uint8Array | any): void {
		if (!this.metadata) {
			this.metadata = { items: [] };
		}
		while (this.metadata.items.length <= i) {
			this.metadata.items.push({});
		}
		switch (name) {
		case "name":
			if (typeof data !== 'string') {
				throw new Error("Unknown type of metadata");
			}
			this.metadata.items[i].name = data;
			break;
		case "mime":
			if (typeof data !== 'string') {
				throw new Error("Unknown type of metadata");
			}
			this.metadata.items[i].mime = data;
			break;
		case "sign":
			if (data instanceof Uint8Array) {
				this.metadata.items[i].sign = encodeBase64URLNoPadding(data);
				break;
			}
			if (typeof data === 'string') {
				this.metadata.items[i].sign = data;
				break;
			}
			throw new Error("Unknown type of metadata");
		case "comment":
			if (typeof data !== 'string') {
				throw new Error("Unknown type of metadata");
			}
			this.metadata.items[i].comment = data;
			break;
		case "modified":
			if (!(data instanceof Date)) {
				throw new Error("Unknown type of metadata");
			}
			this.metadata.items[i].modified = data.toISOString();
			break;
		default:
			const dic = this.metadata.items[i] as any;
			dic[name] = data;
		}
	}
	
	private async _encrypt(): Promise<void> {
		if (this._key === null) {
			throw new Error("key is null.");
		}
		for (const i in this.secretItems) {
			const item = this.secretItems[i];
			if (item instanceof DecryptedData) {
				// DecryptedDataのみ暗号化
				const encryptedItem = await encryptAES(item.data, this._key!, this._iv);
				this.secretItems[i] = new EncryptedData(encryptedItem);
				this.secretItems[i].prvkey = item.prvkey;
			}
		}
	}
	
	private async _decrypt(): Promise<void> {
		if (!this._key) {
			throw new Error("key is null.");
		}
		
		for (let i =0; i < this.secretItems.length; ++i) {
			const item = this.secretItems[i];
			if (item instanceof EncryptedData && this._key && this._key.length > 0) {
				// EncryptedDataのみ復号
				const decryptedItem = await decryptAES(item.data, this._key!, this._iv);
				this.secretItems[i] = new DecryptedData(decryptedItem);
				this.secretItems[i].verified = item.verified;
			}
		}
	}
	
	
	private async _sign(): Promise<void> {
		for (let i =0; i < this.secretItems.length; ++i) {
			const item = this.secretItems[i];
			if (item instanceof EncryptedData) {
				// EncryptedDataのみ復号, 鍵が指定されている場合だけ署名
				const prvkey = item.prvkey || this._prvkey;
				if (prvkey) {
					const signature = await singEd25519(item.data, prvkey);
					this._setMetadataItemValue(i, "sign", signature);
				}
			}
		}
	}
	
	private async _verify(): Promise<boolean | null> {
		if (!this._pubkey) {
			throw new Error("public key is not specified.");
		}
		
		let ret: boolean | null = true;
		for (let i = 0; i < this.secretItems.length; ++i) {
			const item = this.secretItems[i];
			const sign = this._getMetadataItemValue(i, "sign");
			if (item instanceof EncryptedData && sign instanceof Uint8Array && this._pubkey !== undefined) {
				const verifyResult = await verifyEd25519(item.data, sign as Uint8Array, this._pubkey);
				this.secretItems[i].verified = verifyResult;
				if (!verifyResult) {
					ret = ret === null ? null : false;
				}
			} else {
				ret = null;
			}
		}
		return ret;
	}
	
	private async _exportImage(): Promise<Uint8Array> {
		if (!(this._key instanceof Uint8Array)) {
			throw new Error("Key is not specified.");
		}
		await this._encrypt();
		await this._sign();
		return await this.exportImage();
	}
	
	private async _importImage(buffer: Uint8Array): Promise<void> {
		await this.importImage(buffer);
		if (this._pubkey instanceof Uint8Array) {
			await this._verify();
		}
		if (this._key && this._key instanceof Uint8Array) {
			await this._decrypt();
		}
	}
	
	private _keydecode(keyinfo: Uint8Array | string): Uint8Array {
		if (keyinfo instanceof Uint8Array) {
			return keyinfo;
		}
		if (keyinfo.match(/^(:?[0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})$/)) {
			// Hexdecimal(Base16)デコードしてUint8Arrayに変換
			return Uint8Array.from(keyinfo.match(/.{2}/g)!.map(byte => parseInt(byte, 16)));
		} else {
			// Base64デコードしてUint8Arrayに変換
			return decodeBase64URLNoPadding(keyinfo);
		}
	}
	
	// コンストラクタ
	constructor(key?: Uint8Array | string, iv?: Uint8Array | string, prvkey?: Uint8Array | string, pubkey?: Uint8Array | string) {
		if (key) {
			this._key = this._keydecode(key);
		}
		if (iv) {
			this._iv = this._keydecode(iv);
		}
		if (prvkey) {
			this._prvkey = this._keydecode(prvkey);
		}
		if (pubkey) {
			this._pubkey = this._keydecode(pubkey);
		}
	}
	
	// 画像ファイルのデータ読み込み
	load(binary: Uint8Array, key?: Uint8Array | string, iv?: Uint8Array | string, pubkey?: Uint8Array | string): Promise<void> {
		if (key) {
			this._key = this._keydecode(key);
		}
		if (iv) {
			this._iv = this._keydecode(iv);
		}
		if (pubkey) {
			this._pubkey = this._keydecode(pubkey);
		}
		return this._importImage(binary);
	}
	// 画像ファイルへのデータ保存
	save(key?: Uint8Array, iv?: Uint8Array | string, prvkey?: Uint8Array | string): Promise<Uint8Array> {
		if (key) {
			this._key = this._keydecode(key);
		}
		if (iv) {
			this._iv = this._keydecode(iv);
		}
		if (prvkey) {
			this._prvkey = this._keydecode(prvkey);
		}
		return this._exportImage();
	}
	// 署名を持っているか確認
	hasSign(idx?: number): boolean {
		if (idx !== undefined) {
			return this._getMetadataItemValue(idx, "sign") instanceof Uint8Array;
		}
		for (let i = 0; i < this.secretItems.length; ++i) {
			if (!(this._getMetadataItemValue(i, "sign") instanceof Uint8Array)) {
				return false;
			}
		}
		return true;
	}
	// 全データの署名をまとめて検証
	isVerified(idx?: number): boolean | undefined
	{
		if (idx !== undefined) {
			return this.secretItems[idx].verified;
		}
		for (let i = 0; i < this.secretItems.length; ++i) {
			if (!this.secretItems[i].verified)
				return false;
		}
		return true;
	}
	// メタデータを設定
	setMetadata(metadata: any): void {
		this.metadata = metadata;
	}
	// メタデータを取得
	getMetadata(): any {
		return this.metadata;
	}
	// ベース画像設定
	setBaseImage(binary: Uint8Array, mimeType?: string): void {
		binary;
		mimeType;
		throw new Error("Not implement.");
	}
	// ベース画像取得
	getBaseImage(mimeType?: string): Uint8Array {
		mimeType;
		if (this.baseImageData && this.baseImageData.length > 0) {
			return this.baseImageData;
		}
		throw new Error("Not implement.");
	}
	// 添付する秘密データを追加(平文で指定)
	addSecretItem(binary: Uint8Array, name?: string, mimeType?: string, modified?: Date, comment?: string, prvKey?: Uint8Array): void {
		const sdat = new DecryptedData(binary);
		sdat.prvkey = prvKey;
		const idx = this.secretItems.length;
		this.secretItems.push(sdat);
		if (name) {
			this._setMetadataItemValue(idx, "name", name);
		}
		if (mimeType) {
			this._setMetadataItemValue(idx, "mime", mimeType);
		}
		if (comment) {
			this._setMetadataItemValue(idx, "comment", comment);
		}
		if (modified) {
			this._setMetadataItemValue(idx, "modified", modified);
		}
		if (prvKey) {
			this.secretItems[idx].prvkey = prvKey;
		}
	}
	// 添付する秘密データを全削除
	clearSecretItems(): void {
		this.secretItems.length = 0;
		this.metadata = undefined;
	}
	// 添付されている暗号化された秘密データの数
	getSecretItemCount(): number {
		return this.secretItems.length;
	}
	// 添付されている復号された秘密データ
	getSecretItem(idx: number): Uint8Array {
		return this.secretItems[idx].data;
	}
	// 秘密データのメタデータを設定
	setMetadataItem(idx: number, mditm: ArkImgMetadataItem | undefined): void {
		// メタデータがないのにundefinedにする場合は、なにもしない
		if (mditm === undefined && (!this.metadata || this.metadata.items.length <= idx)) {
			return;
		}
		// メタデータがない場合は作る
		if (!this.metadata) {
			this.metadata = { items: [] };
		}
		// 末尾をundefinedにする場合は、長さを一つ減らす
		if (mditm === undefined && idx == this.metadata.items.length - 1) {
			this.metadata.items.length = this.metadata.items.length - 1;
			return;
		}
		// メタデータがすでにある場合は変更
		if (idx < this.metadata.items.length) {
			this.metadata.items[idx] = mditm ? mditm : {};
			return;
		}
		// メタデータが足りない場合は追加
		while (this.metadata.items.length < idx) {
			this.metadata.items.push({});
		}
		// メタデータを変更
		this.metadata.items.push(mditm ? mditm : {});
	}
	// 秘密データのメタデータを取得
	getMetadataItem(idx: number): ArkImgMetadataItem | undefined{
		if (!this.metadata || idx >= this.metadata.items.length) {
			return undefined;
		}
		return this.metadata.items[idx];
	}
}
