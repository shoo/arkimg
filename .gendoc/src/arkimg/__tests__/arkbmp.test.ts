import { ArkBmp } from "../arkbmp";
import { describe, it, beforeAll, expect } from "vitest";
import * as fs from "fs";
import * as path from "path";

describe("ArkBmpの基本動作テスト", () => {
	const commonKey = new Uint8Array([0xB3,0x36,0xC0,0x17,0x12,0xB2,0xE9,0x04,0x06,0x7A,0x99,0x74,0xD1,0xD5,0x7F,0x1C]);
	const prvKey = new Uint8Array([0x78,0x7A,0xCB,0xBD,0x04,0x0C,0x72,0x9B,0xAB,0x54,0x47,0x76,0xDD,0x26,
		0xBB,0xAA,0x9D,0x23,0xC7,0x21,0xC8,0xAE,0x64,0x3E,0x4D,0x89,0xED,0xAD,0xC2,0x2E,0x87,0x8F]);
	const pubKey = new Uint8Array([0xBF,0x56,0xFF,0x79,0x15,0xE3,0xF6,0xDF,0x0A,0x51,0x0E,0x42,0x66,0xB6,
		0xAA,0x5C,0x12,0xFB,0x35,0x37,0x24,0x75,0x8D,0x85,0x75,0x08,0xAB,0x40,0x82,0xEA,0xAC,0x3B]);
	
	const bmpPath: string = path.resolve(__dirname, "../__resources__/d-man.bmp");
	let bmpData: Uint8Array;
	
	beforeAll(() => {
		bmpData = new Uint8Array(fs.readFileSync(bmpPath));
	});
	
	it("BMP画像のインポート(load)・エクスポート(save)", async () => {
		const arkBmp: ArkBmp = new ArkBmp();
		await arkBmp.load(bmpData);
		const exported: Uint8Array = await arkBmp.save(commonKey);
		expect(exported.length).toBeGreaterThanOrEqual(bmpData.length);
		expect(arkBmp.getBaseImage("image/bmp").length).toBe(bmpData.length);
	});
	
	it("setBaseImage/getBaseImageの動作", () => {
		const arkBmp: ArkBmp = new ArkBmp();
		arkBmp.setBaseImage(bmpData, "image/bmp");
		const out: Uint8Array = arkBmp.getBaseImage("image/bmp");
		expect(out).toBeInstanceOf(Uint8Array);
		expect(out.length).toBe(bmpData.length);
	});
	
	it("BMP以外のMIME指定時の挙動", () => {
		const arkBmp: ArkBmp = new ArkBmp();
		arkBmp.setBaseImage(bmpData);
		expect(() => arkBmp.getBaseImage("image/png")).toThrow();
	});
	
	it("loadでEMDT/EDATチャンクなしでも正常動作", async () => {
		const arkBmp: ArkBmp = new ArkBmp();
		await expect(arkBmp.load(bmpData)).resolves.toBeUndefined();
	});
	
	it("save/loadで秘密データ・メタデータ追加して復元", async () => {
		const arkBmp1: ArkBmp = new ArkBmp();
		arkBmp1.setBaseImage(bmpData);
		arkBmp1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkBmp1.save(commonKey);
		expect(temp.length).toBeGreaterThan(bmpData.length);
		const arkBmp2: ArkBmp = new ArkBmp();
		await arkBmp2.load(temp, commonKey);
		expect(arkBmp2.getSecretItem(0)).toStrictEqual(new Uint8Array([1,2,3,4]));
		expect(arkBmp2.getMetadataItem(0)?.name).toBe("test.txt");
		expect(arkBmp2.isVerified()).toBe(false);
		expect(arkBmp2.isVerified(0)).toBeUndefined();
	});
	
	it("save/loadで署名・検証確認", async () => {
		const arkBmp1: ArkBmp = new ArkBmp();
		arkBmp1.setBaseImage(bmpData);
		arkBmp1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkBmp1.save(commonKey, undefined, prvKey);
		expect(temp.length).toBeGreaterThan(bmpData.length);
		const arkBmp2: ArkBmp = new ArkBmp();
		await arkBmp2.load(temp, commonKey, undefined, pubKey);
		expect(arkBmp2.isVerified()).toBe(true);
		expect(arkBmp2.isVerified(0)).toBe(true);
	});
	
	it("save/loadで署名・検証確認-失敗ケース", async () => {
		const arkBmp1: ArkBmp = new ArkBmp();
		arkBmp1.setBaseImage(bmpData);
		arkBmp1.addSecretItem(new Uint8Array([1,2,3,4]), "test.txt", "application/octet-stream");
		const temp: Uint8Array = await arkBmp1.save(commonKey, undefined, prvKey);
		expect(temp.length).toBeGreaterThan(bmpData.length);
		const arkBmp2: ArkBmp = new ArkBmp();
		await arkBmp2.load(temp, commonKey, undefined, new Uint8Array(32));
		expect(arkBmp2.isVerified()).toBe(false);
		expect(arkBmp2.isVerified(0)).toBe(false);
	});
	
	it("parseBmpHeader: BITMAPCOREHEADERのパース", () => {
		const bmp = new ArkBmp();
		// BITMAPCOREHEADER (12 bytes) + FileHeader (14 bytes)
		const buf = new Uint8Array(26);
		const dv = new DataView(buf.buffer);
		buf[0] = 0x42; // 'B'
		buf[1] = 0x4D; // 'M'
		dv.setUint32(2, 26, true); // fileSize
		dv.setUint32(10, 26, true); // pixelDataOffset
		dv.setUint32(14, 12, true); // infoHeaderSize
		dv.setUint16(18, 7, true); // width
		dv.setUint16(20, 5, true); // height
		dv.setUint16(22, 1, true); // planes
		dv.setUint16(24, 24, true); // bitsPerPixel
		const info = bmp["parseBmpHeader"](buf);
		expect(info.width).toBe(7);
		expect(info.height).toBe(5);
		expect(info.pixelDataOffset).toBe(26);
		expect(info.pixelDataSize).toBe(Math.floor((24*7+31)/32)*4*5);
	});
	
	it("parseBmpHeader: BITMAPV5HEADERのパース", () => {
		const bmp = new ArkBmp();
		// BITMAPV5HEADER (124 bytes) + FileHeader (14 bytes)
		const buf = new Uint8Array(138);
		const dv = new DataView(buf.buffer);
		buf[0] = 0x42; // 'B'
		buf[1] = 0x4D; // 'M'
		dv.setUint32(2, 138, true); // fileSize
		dv.setUint32(10, 138, true); // pixelDataOffset
		dv.setUint32(14, 124, true); // infoHeaderSize
		dv.setInt32(18, 11, true); // width
		dv.setInt32(22, 9, true); // height
		dv.setUint16(26, 1, true); // planes
		dv.setUint16(28, 32, true); // bitsPerPixel
		dv.setUint32(30, 0, true); // compression
		dv.setUint32(34, 0, true); // imageSize
		const info = bmp["parseBmpHeader"](buf);
		expect(info.width).toBe(11);
		expect(info.height).toBe(9);
		expect(info.pixelDataOffset).toBe(138);
		expect(info.pixelDataSize).toBe(Math.floor((32*11+31)/32)*4*9);
	});
});
