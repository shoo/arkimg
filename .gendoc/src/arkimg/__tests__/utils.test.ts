import { createKeyPair, createRandomIV, createRandomKey, createPrivateKey,
	loadImage, loadParameter, createArkImg, type ArkImgSecretItem, calcCRC32 } from "../utils";
import { describe, it, beforeAll, expect } from "vitest";
import * as fs from "fs";
import * as path from "path";
import { ArkBmp } from "../arkbmp";
import { ArkPng } from "../arkpng";
import { ArkWebp } from "../arkwebp";
import { ArkJpeg } from "../arkjpg";
import type { ArkImgMetadataItem } from "../arkimg";

function readResource(name: string): Uint8Array
{
	const resourcesPath = path.resolve(__dirname, "../__resources__");
	return new Uint8Array(fs.readFileSync(path.join(resourcesPath, name)));
}

describe("loadParameterのテスト", () => {
	it("Base64URL形式キー", () => {
		// 22文字のBase64URL（Aで埋めるとデコード結果が0長になるので、実際に1バイト以上になる値を使う）
		const param = "QUFBQUFBQUFBQUFBQUFBQQ"; // "AAAAAAAAAAAAAAA"のBase64URL
		const res = loadParameter(param);
		expect(res.key).toBeInstanceOf(Uint8Array);
		expect(res.key.length).toBeGreaterThan(0);
	});
	it("Hex形式キー+IV+Pubkey", () => {
		const param = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef-0123456789abcdef0123456789abcdef-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
		const res = loadParameter(param);
		expect(res.key.length).toBe(32);
		expect(res.iv?.length).toBe(16);
		expect(res.pubkey?.length).toBe(32);
	});
	it("不正なパラメータ", () => {
		expect(() => loadParameter("invalid!param")).toThrow();
	});
});
describe("loadImageのテスト", () => {
	it("BMP形式の読み込み", async () => {
		const bmpData = readResource("d-man.bmp");
		const arkimg = await loadImage(bmpData, "image/bmp");
		expect(arkimg).toBeInstanceOf(ArkBmp);
	});
	
	it("PNG形式の読み込み", async () => {
		const pngData = readResource("d-man.png");
		const arkimg = await loadImage(pngData, "image/png");
		expect(arkimg).toBeInstanceOf(ArkPng);
	});
	
	it("WebP形式の読み込み", async () => {
		const webpData = readResource("d-man.webp");
		const arkimg = await loadImage(webpData, "image/webp");
		expect(arkimg).toBeInstanceOf(ArkWebp);
	});
	
	it("JPEG形式の読み込み", async () => {
		const jpegData = readResource("d-man.jpg");
		const arkimg = await loadImage(jpegData, "image/jpeg");
		expect(arkimg).toBeInstanceOf(ArkJpeg);
	});
	
	it("未対応のMIMEタイプ", async () => {
		await expect(loadImage(new Uint8Array(32), "image/gif")).rejects.toThrow("Not implement.");
	});
});

describe("鍵生成のテスト", () => {
	it("デフォルトサイズ", async () => {
		const key = await createRandomKey();
		expect(key).toBeInstanceOf(Uint8Array);
		expect(key.length).toBe(16);
	});
	it("指定サイズ", async () => {
		const key = await createRandomKey(32);
		expect(key).toBeInstanceOf(Uint8Array);
		expect(key.length).toBe(32);
	});
	it("IV生成", async () => {
		const iv = await createRandomIV();
		expect(iv).toBeInstanceOf(Uint8Array);
		expect(iv.length).toBe(16);
	});
	it("鍵ペア生成", async () => {
		const { prvkey, pubkey } = await createKeyPair();
		expect(prvkey).toBeInstanceOf(Uint8Array);
		expect(prvkey.length).toBe(32);
		expect(pubkey).toBeInstanceOf(Uint8Array);
		expect(pubkey.length).toBe(32);
	});
	it("秘密鍵生成", async () => {
		const prvkey = await createPrivateKey();
		expect(prvkey).toBeInstanceOf(Uint8Array);
		expect(prvkey.length).toBe(32);
	});
});

describe("createArkImgのテスト", () => {
	let pngData: Uint8Array = readResource("d-man.png");
	let key: Uint8Array;
	let iv: Uint8Array;

	beforeAll(async () => {
		key = await createRandomKey(32);
		iv = await createRandomIV();
	});
	
	it("画像と秘密情報追加", async () => {
		const secrets = [{
			data: new Uint8Array([1, 2, 3]),
			metadata: {
				name: "test.txt",
				mime: "text/plain",
				modified: new Date(Date.now()).toISOString(),
				comment: "test comment"
			} as ArkImgMetadataItem
		}] as ArkImgSecretItem[];
		const result = await createArkImg(pngData, "image/png", secrets, key, iv);
		expect(result).toBeInstanceOf(Uint8Array);
		expect(result.length).toBeGreaterThan(0);
		
		// 追加された秘密情報が正しく格納されているか確認
		const arkimg = await loadImage(result, "image/png", key, iv);
		const itemCnt = arkimg.getSecretItemCount();
		const item = arkimg.getSecretItem(0);
		const itemMetadata = arkimg.getMetadataItem(0);
		expect(itemCnt).toBe(1);
		expect(item).toEqual(new Uint8Array([1, 2, 3]));
		expect(itemMetadata?.name).toBe("test.txt");
		expect(itemMetadata?.mime).toBe("text/plain");
		expect(itemMetadata?.modified).toBeDefined();
		expect(itemMetadata?.comment).toBe("test comment");
	});
	
	it("秘密鍵付きで画像と秘密情報追加", async () => {
		const {prvkey, pubkey} = await createKeyPair();
		expect(pubkey.length).toBe(32);
		const secrets = [{
			data: new Uint8Array([4, 5, 6]),
			metadata: {
				name: "test.txt",
				mime: "text/plain",
				modified: new Date(Date.now()).toISOString(),
				comment: "test comment"
			} as ArkImgMetadataItem,
			prvkey: prvkey
		}];
		const result = await createArkImg(pngData, "image/png", secrets, key, iv);
		expect(result).toBeInstanceOf(Uint8Array);
		expect(result.length).toBeGreaterThan(0);
		
		// 追加された秘密情報が正しく格納されているか確認 (秘密鍵はデコードできないためデータのみ確認)
		const arkimg = await loadImage(result, "image/png", key, iv);
		const itemCnt = arkimg.getSecretItemCount();
		expect(itemCnt).toBe(1);
		expect(arkimg.hasSign(0)).toBe(true);
		expect(arkimg.hasSign()).toBe(true);
		expect(arkimg.isVerified(0)).toBeUndefined();
	});
	
	it("秘密情報なしで画像生成", async () => {
		const result = await createArkImg(pngData, "image/png", [], key, iv);
		expect(result).toBeInstanceOf(Uint8Array);
		expect(result.length).toBeGreaterThan(0);
	});
});

describe("calcCRC32のテスト", () => {
	it("空データ", () => {
		const data = new Uint8Array([]);
		expect(calcCRC32(data)).toBe(0);
	});
	it("文字列データ", () => {
		const data = new TextEncoder().encode("hello world");
		expect(calcCRC32(data)).toBe(0x0D4A1185);
	});
	it("初期値指定", () => {
		const data = new TextEncoder().encode("hello world");
		expect(calcCRC32(data, 0)).toBe(0x0D4A1185);
	});
	it("複数回計算", () => {
		const data1 = new TextEncoder().encode("hello");
		const data2 = new TextEncoder().encode(" world");
		const crc1 = calcCRC32(data1);
		const crc2 = calcCRC32(data2, crc1);
		expect(crc2).toBe(0x0D4A1185);
	});
});
