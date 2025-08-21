import { ArkJpeg } from "../arkjpg";
import { describe, it, beforeAll, expect } from "vitest";
import * as fs from "fs";
import * as path from "path";

describe("ArkJpegの基本動作テスト", () => {
	const commonKey = new Uint8Array([0xB3,0x36,0xC0,0x17,0x12,0xB2,0xE9,0x04,0x06,0x7A,0x99,0x74,0xD1,0xD5,0x7F,0x1C]);
	const prvKey = new Uint8Array([0x78,0x7A,0xCB,0xBD,0x04,0x0C,0x72,0x9B,0xAB,0x54,0x47,0x76,0xDD,0x26,
		0xBB,0xAA,0x9D,0x23,0xC7,0x21,0xC8,0xAE,0x64,0x3E,0x4D,0x89,0xED,0xAD,0xC2,0x2E,0x87,0x8F]);
	const pubKey = new Uint8Array([0xBF,0x56,0xFF,0x79,0x15,0xE3,0xF6,0xDF,0x0A,0x51,0x0E,0x42,0x66,0xB6,
		0xAA,0x5C,0x12,0xFB,0x35,0x37,0x24,0x75,0x8D,0x85,0x75,0x08,0xAB,0x40,0x82,0xEA,0xAC,0x3B]);
	
	const jpegPath: string = path.resolve(__dirname, "../__resources__/d-man.jpg");
	let jpegData: Uint8Array;
	
	beforeAll(() => {
		jpegData = new Uint8Array(fs.readFileSync(jpegPath));
	});
	
	it("JPEG画像のインポート(load)・エクスポート(save)", async () => {
		const arkJpeg: ArkJpeg = new ArkJpeg();
		await arkJpeg.load(jpegData);
		const exported: Uint8Array = await arkJpeg.save(commonKey);
		expect(exported.length).toBeGreaterThanOrEqual(jpegData.length);
		expect(arkJpeg.getBaseImage("image/jpeg").length).toBe(jpegData.length);
	});
	
	it("setBaseImage/getBaseImageの動作", () => {
		const arkJpeg: ArkJpeg = new ArkJpeg();
		arkJpeg.setBaseImage(jpegData, "image/jpeg");
		const out: Uint8Array = arkJpeg.getBaseImage("image/jpeg");
		expect(out).toBeInstanceOf(Uint8Array);
		expect(out.length).toBe(jpegData.length);
	});
	
	it("JPEG以外のMIME指定時の挙動", () => {
		const arkJpeg: ArkJpeg = new ArkJpeg();
		arkJpeg.setBaseImage(jpegData);
		expect(() => arkJpeg.getBaseImage("image/png")).toThrow();
	});
	
	it("loadでEXIF/APP0チャンクなしでも正常動作", async () => {
		const arkJpeg: ArkJpeg = new ArkJpeg();
		await expect(arkJpeg.load(jpegData)).resolves.toBeUndefined();
	});
	
	it("save/loadで秘密データ・メタデータ追加して復元", async () => {
		const arkJpeg1: ArkJpeg = new ArkJpeg();
		arkJpeg1.setBaseImage(jpegData);
		arkJpeg1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkJpeg1.save(commonKey);
		expect(temp.length).toBeGreaterThan(jpegData.length);
		const arkJpeg2: ArkJpeg = new ArkJpeg();
		await arkJpeg2.load(temp, commonKey);
		expect(arkJpeg2.getSecretItem(0)).toStrictEqual(new Uint8Array([1,2,3,4]));
		expect(arkJpeg2.getMetadataItem(0)?.name).toBe("test.txt");
		expect(arkJpeg2.isVerified()).toBe(false);
		expect(arkJpeg2.isVerified(0)).toBeUndefined();
	});
	
	it("save/loadで署名・検証確認", async () => {
		const arkJpeg1: ArkJpeg = new ArkJpeg();
		arkJpeg1.setBaseImage(jpegData);
		arkJpeg1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkJpeg1.save(commonKey, undefined, prvKey);
		expect(temp.length).toBeGreaterThan(jpegData.length);
		const arkJpeg2: ArkJpeg = new ArkJpeg();
		await arkJpeg2.load(temp, commonKey, undefined, pubKey);
		expect(arkJpeg2.isVerified()).toBe(true);
		expect(arkJpeg2.isVerified(0)).toBe(true);
	});
	
	it("save/loadで署名・検証確認-失敗ケース", async () => {
		const arkJpeg1: ArkJpeg = new ArkJpeg();
		arkJpeg1.setBaseImage(jpegData);
		arkJpeg1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkJpeg1.save(commonKey, undefined, prvKey);
		expect(temp.length).toBeGreaterThan(jpegData.length);
		const arkJpeg2: ArkJpeg = new ArkJpeg();
		await arkJpeg2.load(temp, commonKey, undefined, new Uint8Array(32));
		expect(arkJpeg2.isVerified()).toBe(false);
		expect(arkJpeg2.isVerified(0)).toBe(false);
	});
});
