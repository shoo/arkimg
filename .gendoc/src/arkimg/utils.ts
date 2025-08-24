import { ArkImgBase, type ArkImg, type ArkImgMetadataItem } from "./arkimg";
import { decodeBase64URLNoPadding } from "@/utils/misc";
import { ArkPng } from "./arkpng";
import { ArkWebp } from "./arkwebp";
import { ArkJpeg } from "./arkjpg";
import { ArkBmp } from "./arkbmp";

export async function loadImage(binary: Uint8Array, mimeType: string, key?: Uint8Array | string, iv?: Uint8Array | string, pubkey?: Uint8Array | string): Promise<ArkImg> {
	let arkimg: ArkImgBase;
	switch (mimeType) {
	case 'image/bmp':
		arkimg = new ArkBmp();
		await arkimg.load(binary, key, iv, pubkey);
		return arkimg;
	case 'image/png':
		arkimg = new ArkPng();
		await arkimg.load(binary, key, iv, pubkey);
		return arkimg;
	case 'image/jpeg':
		arkimg = new ArkJpeg();
		await arkimg.load(binary, key, iv, pubkey);
		return arkimg;
	case 'image/webp':
		arkimg = new ArkWebp();
		await arkimg.load(binary, key, iv, pubkey);
		return arkimg;
	default:
		throw new Error("Not implement.");
	}
}
export async function createRandomKey(keysize?: number): Promise<Uint8Array> {
	return crypto.getRandomValues(new Uint8Array(keysize ? keysize : 16));
}
export async function createRandomIV(): Promise<Uint8Array> {
	return crypto.getRandomValues(new Uint8Array(16));
}
export async function createKeyPair(): Promise<{prvkey: Uint8Array, pubkey: Uint8Array}> {
	// Web Crypto API を使用して Ed25519 の秘密鍵/公開鍵を生成
	const keyPair = await crypto.subtle.generateKey(
		{
			name: "Ed25519",
		},
		true,
		["sign", "verify"]
	);
	const jwk = await crypto.subtle.exportKey('jwk', keyPair.privateKey);
	if (!jwk.d) {
		throw new Error("Cannot create private key");
	}
	if (!jwk.x) {
		throw new Error("Cannot create public key");
	}
	const ret = {
		prvkey: decodeBase64URLNoPadding(jwk.d),
		pubkey: decodeBase64URLNoPadding(jwk.x),
	};
	if (ret.prvkey.length !== 32) {
		throw new Error("Cannot create private key");
	}
	if (ret.pubkey.length !== 32) {
		throw new Error("Cannot create public key");
	}
	return ret;
}
export async function createPrivateKey(): Promise<Uint8Array> {
	// Web Crypto API を使用して Ed25519 の秘密鍵を生成
	return (await createKeyPair()).prvkey;
}
export async function createPublicKey(prvkey: Uint8Array | string): Promise<Uint8Array> {
	prvkey;
	throw new Error("Unsupported");
}
export function loadParameter(parameter: string): { key: Uint8Array, iv?: Uint8Array, pubkey?: Uint8Array } {
	let key: Uint8Array;
	let iv: Uint8Array | undefined;
	let pubkey: Uint8Array | undefined;

	// 共通鍵のみBase64URL形式 (22, 32, or 43 characters)
	const base64Match = parameter.match(/^([0-9a-zA-Z-_]{22}|[0-9a-zA-Z-_]{32}|[0-9a-zA-Z-_]{43})$/);
	if (base64Match) {
		key = decodeBase64URLNoPadding(base64Match[1]);
		return { key };
	}
	
	// 共通鍵/IV/公開鍵の組み合わせ (e.g., k16i16p32-base64string)
	const encodedKeyInfoMatch = parameter.match(/^(?:k(16|24|32))(?:i(16))?(?:p(32))?-([0-9a-zA-Z-_+])$/);
	if (encodedKeyInfoMatch) {
		const bin = decodeBase64URLNoPadding(encodedKeyInfoMatch[4]);
		const keyLen = encodedKeyInfoMatch[1] ? parseInt(encodedKeyInfoMatch[1], 10) : 0;
		const ivLen = encodedKeyInfoMatch[2] ? parseInt(encodedKeyInfoMatch[2], 10) : 0;
		const pubKeyLen = encodedKeyInfoMatch[3] ? parseInt(encodedKeyInfoMatch[3], 10) : 0;
		
		key = bin.slice(0, keyLen);
		if (ivLen > 0) {
			iv = bin.slice(keyLen, keyLen + ivLen);
		}
		if (pubKeyLen > 0) {
			pubkey = bin.slice(keyLen + ivLen);
		}
		return { key, iv, pubkey };
	}
	
	// Hexadecimal format (key, optional iv, optional pubkey)
	function hexToBytes(hex: string): Uint8Array {
		const bytes = new Uint8Array(hex.length / 2);
		for (let i = 0; i < hex.length; i += 2) {
			bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
		}
		return bytes;
	}
	const hexMatch = parameter.match(/^([0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})(?:-([0-9a-fA-F]{32}))?(?:-([0-9a-fA-F]{64}))?$/);
	if (hexMatch) {
		key = hexToBytes(hexMatch[1]);
		if (hexMatch[2]) {
			iv = hexToBytes(hexMatch[2]);
		}
		if (hexMatch[3]) {
			// Similar to the above, assuming raw public key bytes if provided in hex.
			pubkey = hexToBytes(hexMatch[3]);
		}
		return { key, iv, pubkey };
	}
	
	throw new Error("Invalid parameter format");
}

export interface ArkImgSecretItem
{
	data: Uint8Array;
	metadata?: ArkImgMetadataItem;
	prvkey?: Uint8Array;
}

export async function createArkImg(baseImage: Uint8Array, mimeType: string, secrets: ArkImgSecretItem[],
	key: Uint8Array, iv?: Uint8Array, prvkey?: Uint8Array): Promise<Uint8Array>
{
	const arkimg = await loadImage(baseImage, mimeType, key, iv) as ArkImgBase;
	for (const itm of secrets) {
		arkimg.addSecretItem(itm.data,
			itm.metadata?.name,
			itm.metadata?.mime,
			itm.metadata?.modified !== undefined ? new Date(itm.metadata!.modified) : undefined,
			itm.metadata?.comment,
			itm.prvkey ?? prvkey);
	}
	return await arkimg.save(key, iv, prvkey);
}



// CRC32計算用テーブルを作成
const crc32Table: Uint32Array = new Uint32Array(256);

export function calcCRC32(data: Uint8Array, initial: number = 0): number {
	let crc: number = initial ^ 0xFFFFFFFF;
	if (crc32Table[0] === 0) {
		for (let i: number = 0; i < 256; i++) {
			let c = i;
			for (let j = 0; j < 8; j++) {
				c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
			}
			crc32Table[i] = c >>> 0;
		}
	}
	for (let i = 0; i < data.length; i++) {
		crc = (crc >>> 8) ^ crc32Table[(crc ^ data[i]) & 0xff];
	}
	return (crc ^ 0xFFFFFFFF) >>> 0;
}
