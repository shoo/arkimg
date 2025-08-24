import { describe, it, expect } from "vitest";
import { ArkImgBase, DecryptedData, EncryptedData,
	encryptAES, decryptAES, singEd25519, verifyEd25519,
	type ArkImgMetadataItem } from "../arkimg";

describe("ArkImgBaseの基本動作", () => {
	const commonKey = new Uint8Array([0xB3,0x36,0xC0,0x17,0x12,0xB2,0xE9,0x04,0x06,0x7A,0x99,0x74,0xD1,0xD5,0x7F,0x1C]);
	const prvKey = new Uint8Array([0x78,0x7A,0xCB,0xBD,0x04,0x0C,0x72,0x9B,0xAB,0x54,0x47,0x76,0xDD,0x26,
		0xBB,0xAA,0x9D,0x23,0xC7,0x21,0xC8,0xAE,0x64,0x3E,0x4D,0x89,0xED,0xAD,0xC2,0x2E,0x87,0x8F]);
	const pubKey = new Uint8Array([0xBF,0x56,0xFF,0x79,0x15,0xE3,0xF6,0xDF,0x0A,0x51,0x0E,0x42,0x66,0xB6,
		0xAA,0x5C,0x12,0xFB,0x35,0x37,0x24,0x75,0x8D,0x85,0x75,0x08,0xAB,0x40,0x82,0xEA,0xAC,0x3B]);
	
	describe("encryptAES/decryptAES", () => {
		it("AES-CBCで暗号化・復号できる", async () => {
			// 16byte key, 16byte iv
			const key = new Uint8Array(16).map((_,i)=>i+1);
			const iv = new Uint8Array(16).map((_,i)=>16-i);
			const plain = new Uint8Array([1,2,3,4,5,6,7,8]);
			const encrypted = await encryptAES(plain, key, iv);
			expect(encrypted).toBeInstanceOf(Uint8Array);
			expect(encrypted.length).toBeGreaterThan(0);
			const decrypted = await decryptAES(encrypted, key, iv);
			expect(decrypted).toEqual(plain);
		});

		it("AES-CBC: iv省略時は先頭にivが付与される", async () => {
			const key = new Uint8Array(16).map((_,i)=>i+1);
			const plain = new Uint8Array([1,2,3,4,5,6,7,8]);
			const encrypted = await encryptAES(plain, key);
			expect(encrypted.length).toBeGreaterThan(16);
			// 先頭16byteがiv
			const iv = encrypted.slice(0,16);
			const decrypted = await decryptAES(encrypted, key);
			expect(decrypted).toEqual(plain);
			const decrypted2 = await decryptAES(encrypted.slice(16), key, iv);
			expect(decrypted2).toEqual(plain);
		});
		
		it("AES-GCMで暗号化・復号できる", async () => {
			// 16byte key, 12byte iv
			const key = new Uint8Array(16).map((_,i)=>i+1);
			const iv = new Uint8Array(12).map((_,i)=>i+1);
			const plain = new Uint8Array([1,2,3,4,5,6,7,8]);
			const encrypted = await encryptAES(plain, key, iv);
			expect(encrypted).toBeInstanceOf(Uint8Array);
			expect(encrypted.length).toBeGreaterThan(0);
			const decrypted = await decryptAES(encrypted, key, iv);
			expect(decrypted).toEqual(plain);
		});
		
		it("decryptAES: key不一致で例外", async () => {
			const key = new Uint8Array(16).map((_,i)=>i+1);
			const wrongKey = new Uint8Array(16).map((_,i)=>i+2);
			const iv = new Uint8Array(16).map((_,i)=>16-i);
			const plain = new Uint8Array([1,2,3,4,5,6,7,8]);
			const encrypted = await encryptAES(plain, key, iv);
			await expect(decryptAES(encrypted, wrongKey, iv)).rejects.toThrow();
		});
	});
	
	describe("singEd25519/verifyEd25519", () => {
		it("Ed25519署名と検証が成功する", async () => {
			const data = new Uint8Array([1,2,3,4,5]);
			const signature = await singEd25519(data, prvKey);
			expect(signature).toBeInstanceOf(Uint8Array);
			expect(signature.length).toBe(64);
			const verified = await verifyEd25519(data, signature, pubKey);
			expect(verified).toBe(true);
		});
		
		it("Ed25519: 検証失敗ケース", async () => {
			const data = new Uint8Array([1,2,3,4,5]);
			const signature = await singEd25519(data, prvKey);
			// データ改ざん
			const tampered = new Uint8Array([9,9,9,9,9]);
			const verified = await verifyEd25519(tampered, signature, pubKey);
			expect(verified).toBe(false);
		});
	});
	
	it("インスタンス生成ができる", () => {
		const ark = new ArkImgBase();
		expect(ark).toBeInstanceOf(ArkImgBase);
	});
	
	it("秘密データ追加・取得ができる", () => {
		const ark = new ArkImgBase();
		const data = new Uint8Array([1,2,3]);
		ark.addSecretItem(data, "test", "application/octet-stream");
		expect(ark.getSecretItemCount()).toBe(1);
		expect(ark.getSecretItem(0)).toEqual(data);
	});
	
	it("メタデータの設定・取得ができる", () => {
		const ark = new ArkImgBase();
		const meta = { items: [{ name: "a", mime: "b" }] };
		ark.setMetadata(meta);
		expect(ark.getMetadata()).toEqual(meta);
	});
	
	it("メタデータアイテムの設定・取得ができる", () => {
		const ark = new ArkImgBase();
		const mditm: ArkImgMetadataItem = { name: "n", mime: "m" };
		ark.setMetadataItem(0, mditm);
		expect(ark.getMetadataItem(0)).toEqual(mditm);
	});
	
	it("秘密データ全削除ができる", () => {
		const ark = new ArkImgBase();
		ark.addSecretItem(new Uint8Array([1]));
		ark.clearSecretItems();
		expect(ark.getSecretItemCount()).toBe(0);
	});
	
	it("hasSign: 署名がない場合はfalseを返す", () => {
		const ark = new ArkImgBase();
		ark.addSecretItem(new Uint8Array([1]), "n");
		expect(ark.hasSign()).toBe(false);
		expect(ark.hasSign(0)).toBe(false);
	});
	
	it("hasSign: 署名がある場合はtrueを返す", () => {
		const ark = new ArkImgBase();
		ark.addSecretItem(new Uint8Array([1]));
		// signはBase64URLデコード可能な文字列
		ark.setMetadata({ items: [{ sign: "AA" }] });
		// signがUint8Arrayとして認識される
		expect(ark.hasSign(0)).toBe(true);
	});
	
	it("isVerified: verifiedがfalseの場合はfalseを返す", () => {
		const ark = new ArkImgBase();
		ark.addSecretItem(new Uint8Array([1]));
		(ark as any).secretItems[0].verified = false;
		expect(ark.isVerified()).toBe(false);
		expect(ark.isVerified(0)).toBe(false);
	});
	
	it("isVerified: verifiedがtrueの場合はtrueを返す", () => {
		const ark = new ArkImgBase();
		ark.addSecretItem(new Uint8Array([1]));
		(ark as any).secretItems[0].verified = true;
		expect(ark.isVerified()).toBe(true);
		expect(ark.isVerified(0)).toBe(true);
	});
	
	it("setBaseImage/getBaseImage: 未実装例外を投げる", () => {
		const ark = new ArkImgBase();
		expect(() => ark.setBaseImage(new Uint8Array([1,2,3]), "image/png")).toThrow("Not implement.");
		expect(() => ark.getBaseImage("image/png")).toThrow("Not implement.");
	});
	
	it("getBaseImage: baseImageDataがあれば返す", () => {
		const ark = new ArkImgBase();
		(ark as any).baseImageData = new Uint8Array([9,8,7]);
		expect(ark.getBaseImage()).toEqual(new Uint8Array([9,8,7]));
	});
	
	it("addSecretItem: 全引数分岐", () => {
		const ark = new ArkImgBase();
		const data = new Uint8Array([1]);
		ark.addSecretItem(data, "n", "m", new Date("2020-01-01"), "c", new Uint8Array([2]));
		expect(ark.getSecretItemCount()).toBe(1);
		expect(ark.getSecretItem(0)).toEqual(data);
		expect(ark.getMetadataItem(0)?.name).toBe("n");
		expect(ark.getMetadataItem(0)?.mime).toBe("m");
		expect(ark.getMetadataItem(0)?.comment).toBe("c");
		expect((ark as any).secretItems[0].prvkey).toBeDefined();
	});
	
	it("setMetadataItem: undefinedで末尾削除", () => {
		const ark = new ArkImgBase();
		ark.setMetadata({ items: [{ name: "a" }, { name: "b" }] });
		ark.setMetadataItem(1, undefined);
		expect(ark.getMetadata()?.items.length).toBe(1);
	});
	
	it("setMetadataItem: undefinedで何もしない", () => {
		const ark = new ArkImgBase();
		ark.setMetadata({ items: [] });
		ark.setMetadataItem(0, undefined);
		expect(ark.getMetadata()?.items.length).toBe(0);
	});
	
	it("setMetadataItem: 境界値で追加", () => {
		const ark = new ArkImgBase();
		ark.setMetadata({ items: [] });
		ark.setMetadataItem(2, { name: "x" });
		expect(ark.getMetadata()?.items.length).toBe(3);
		expect(ark.getMetadataItem(2)?.name).toBe("x");
	});
	
	it("getMetadataItem: 範囲外はundefined", () => {
		const ark = new ArkImgBase();
		ark.setMetadata({ items: [{ name: "a" }] });
		expect(ark.getMetadataItem(1)).toBeUndefined();
	});
	
	it("clearSecretItems: 副作用でmetadataも消える", () => {
		const ark = new ArkImgBase();
		ark.setMetadata({ items: [{ name: "a" }] });
		ark.addSecretItem(new Uint8Array([1]));
		ark.clearSecretItems();
		expect(ark.getMetadata()).toBeUndefined();
	});
	
	it("コンストラクタ引数分岐", () => {
		const key = new Uint8Array([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
		const ark = new ArkImgBase(key, key, key, key);
		expect(ark).toBeInstanceOf(ArkImgBase);
	});
	
	describe("ArkImgBaseのプライベートメソッド", () => {
		it("_getMetadataItemValue: name/mime/sign/comment/modified/その他", () => {
			const ark = new ArkImgBase();
			ark.setMetadata({ items: [{ name: "n", mime: "m", sign: "AA", comment: "c", modified: "2020-01-01", extra: "ex" }] });
			expect((ark as any)._getMetadataItemValue(0, "name")).toBe("n");
			expect((ark as any)._getMetadataItemValue(0, "mime")).toBe("m");
			expect((ark as any)._getMetadataItemValue(0, "sign")).toBeInstanceOf(Uint8Array);
			expect((ark as any)._getMetadataItemValue(0, "comment")).toBe("c");
			expect((ark as any)._getMetadataItemValue(0, "modified")).toEqual(new Date("2020-01-01"));
			expect((ark as any)._getMetadataItemValue(0, "extra")).toBe("ex");
			expect((ark as any)._getMetadataItemValue(1, "name")).toBeUndefined();
		});
		
		it("_setMetadataItemValue: 各種分岐", () => {
			const ark = new ArkImgBase();
			// name
			(ark as any)._setMetadataItemValue(0, "name", "n");
			expect(ark.getMetadataItem(0)?.name).toBe("n");
			// mime
			(ark as any)._setMetadataItemValue(0, "mime", "m");
			expect(ark.getMetadataItem(0)?.mime).toBe("m");
			// sign (Uint8Array)
			(ark as any)._setMetadataItemValue(0, "sign", new Uint8Array([1,2]));
			expect(typeof ark.getMetadataItem(0)?.sign).toBe("string");
			// sign (string)
			(ark as any)._setMetadataItemValue(0, "sign", "AA");
			expect(ark.getMetadataItem(0)?.sign).toBe("AA");
			// comment
			(ark as any)._setMetadataItemValue(0, "comment", "c");
			expect(ark.getMetadataItem(0)?.comment).toBe("c");
			// extra
			(ark as any)._setMetadataItemValue(0, "extra", "ex");
			expect((ark.getMetadataItem(0) as any).extra).toBe("ex");
			// 型不正
			expect(() => (ark as any)._setMetadataItemValue(0, "name", 123)).toThrow();
			expect(() => (ark as any)._setMetadataItemValue(0, "mime", 123)).toThrow();
			expect(() => (ark as any)._setMetadataItemValue(0, "sign", {})).toThrow();
			expect(() => (ark as any)._setMetadataItemValue(0, "comment", 123)).toThrow();
		});
		
		it("_keydecode: Uint8Array, hex, base64", () => {
			const ark = new ArkImgBase();
			// Uint8Array
			const arr = new Uint8Array([1,2,3]);
			expect((ark as any)._keydecode(arr)).toEqual(arr);
			// hex
			expect((ark as any)._keydecode("0102030401020304010203040102030401020304010203040102030401020304"))
				.toEqual(new Uint8Array([1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4]));
			// base64 (AA==)
			expect((ark as any)._keydecode("AA"))
				.toBeInstanceOf(Uint8Array);
		});
		
		it("_encrypt/_decrypt: DecryptedDataがEncryptedDataに変換され、復号で元に戻る", async () => {
			const ark = new ArkImgBase(commonKey);
			// DecryptedData追加
			ark.addSecretItem(new Uint8Array([1,2,3,4,5]));
			await (ark as any)._encrypt();
			expect((ark as any).secretItems[0]).toBeInstanceOf(EncryptedData);
			// 復号
			await (ark as any)._decrypt();
			expect((ark as any).secretItems[0]).toBeInstanceOf(DecryptedData);
			expect((ark as any).secretItems[0].data).toEqual(new Uint8Array([1,2,3,4,5]));
		});
		
		it("_encrypt: key=nullで例外", async () => {
			const ark = new ArkImgBase();
			(ark as any)._key = null;
			await expect((ark as any)._encrypt()).rejects.toThrow("key is null.");
		});
		
		it("_decrypt: key=undefinedで例外", async () => {
			const ark = new ArkImgBase();
			(ark as any)._key = undefined;
			await expect((ark as any)._decrypt()).rejects.toThrow("key is null.");
		});
		
		it("_sign: EncryptedDataに署名が付与される", async () => {
			const ark = new ArkImgBase(commonKey, undefined, prvKey);
			// 事前に暗号化済みデータを追加
			const encrypted = await encryptAES(new Uint8Array([1,2,3,4,5]), commonKey);
			(ark as any).secretItems.push(new EncryptedData(encrypted));
			await (ark as any)._sign();
			// メタデータに署名が追加されている
			expect(ark.getMetadataItem(0)?.sign).toBeDefined();
		});
		
		it("_verify: 署名検証が成功しverified=trueになる", async () => {
			const ark = new ArkImgBase(commonKey, undefined, prvKey, pubKey);
			// 暗号化+署名
			const encrypted = await encryptAES(new Uint8Array([1,2,3,4,5]), commonKey);
			(ark as any).secretItems.push(new EncryptedData(encrypted));
			await (ark as any)._sign();
			// 検証
			(ark as any)._pubkey = pubKey;
			const result = await (ark as any)._verify();
			expect(result).toBe(true);
			expect((ark as any).secretItems[0].verified).toBe(true);
		});
		
		it("_verify: 署名不一致でverified=falseになる", async () => {
			const ark = new ArkImgBase(commonKey, undefined, prvKey, pubKey);
			// 暗号化+署名
			const encrypted = await encryptAES(new Uint8Array([1,2,3,4,5]), commonKey);
			(ark as any).secretItems.push(new EncryptedData(encrypted));
			await (ark as any)._sign();
			// 署名を改ざん
			ark.setMetadataItem(0, { sign: "AA" });
			(ark as any)._pubkey = pubKey;
			const result = await (ark as any)._verify();
			expect(result).toBe(false);
			expect((ark as any).secretItems[0].verified).toBe(false);
		});
		
		it("_exportImage: key未指定で例外", async () => {
			const ark = new ArkImgBase();
			(ark as any)._key = undefined;
			await expect((ark as any)._exportImage()).rejects.toThrow("Key is not specified.");
		});
		
		it("_importImage: importImage例外を伝播", async () => {
			const ark = new ArkImgBase();
			await expect((ark as any)._importImage(new Uint8Array([1,2,3]))).rejects.toThrow("Not implement.");
		});
	});
});

describe("DecryptedData/EncryptedDataの型", () => {
	it("DecryptedDataのdataが設定される", () => {
		const d = new DecryptedData(new Uint8Array([1,2]));
		expect(d.data).toEqual(new Uint8Array([1,2]));
	});
	it("EncryptedDataのdataが設定される", () => {
		const e = new EncryptedData(new Uint8Array([3,4]));
		expect(e.data).toEqual(new Uint8Array([3,4]));
	});
});
