import { ArkImgBase } from "./arkimg";

interface BmpHeaderInfo {
	pixelDataOffset: number;
	pixelDataSize: number;
	width: number;
	height: number;
}

export class ArkBmp extends ArkImgBase {

	private parseBmpHeader(buffer: Uint8Array): BmpHeaderInfo {
		const decoder = new TextDecoder();
		const dv = new DataView(buffer.buffer, buffer.byteOffset);
		
		// BMPファイルシグネチャの確認 ("BM")
		const signature = decoder.decode(buffer.slice(0, 2));
		if (signature !== "BM") {
			throw new Error("Invalid BMP format: not a BMP file");
		}
		
		// Bitmap File Header (14 bytes)
		//const fileSize = dv.getUint32(2, true); // Little-endian
		const pixelDataOffset = dv.getUint32(10, true); // Little-endian
		
		// Info Header Size
		const infoHeaderSize = dv.getUint32(14, true); // Little-endian
		
		let width: number, height: number, bitsPerPixel: number, compression: number, imageSize: number;
		
		switch (infoHeaderSize) {
		case 12: // BITMAPCOREHEADER
			{
				if (buffer.length < 26) { // 14 (file header) + 12 (core header)
					throw new Error("Invalid BMP format: BITMAPCOREHEADER too small");
				}
				
				width = dv.getUint16(18, true); // Little-endian, unsigned 16-bit
				height = dv.getUint16(20, true); // Little-endian, unsigned 16-bit
				const planes = dv.getUint16(22, true); // Little-endian
				bitsPerPixel = dv.getUint16(24, true); // Little-endian
				
				if (planes !== 1) {
					throw new Error("Invalid BMP format: unsupported planes count");
				}
				
				compression = 0; // BITMAPCOREHEADER は常に無圧縮
				imageSize = 0; // 計算が必要
			}
			break;
			
		case 40: // BITMAPINFOHEADER
			{
				if (buffer.length < 54) { // 14 (file header) + 40 (info header)
					throw new Error("Invalid BMP format: BITMAPINFOHEADER too small");
				}
				
				width = dv.getInt32(18, true); // Little-endian, signed 32-bit
				height = dv.getInt32(22, true); // Little-endian, signed 32-bit
				const planes = dv.getUint16(26, true); // Little-endian
				bitsPerPixel = dv.getUint16(28, true); // Little-endian
				compression = dv.getUint32(30, true); // Little-endian
				imageSize = dv.getUint32(34, true); // Little-endian
				
				if (planes !== 1) {
					throw new Error("Invalid BMP format: unsupported planes count");
				}
			}
			break;
			
		case 108: // BITMAPV4HEADER
		case 124: // BITMAPV5HEADER
			{
				const minSize = infoHeaderSize === 108 ? 122 : 138; // 14 + 108 or 14 + 124
				if (buffer.length < minSize) {
					throw new Error(`Invalid BMP format: BITMAPV${infoHeaderSize === 108 ? '4' : '5'}HEADER too small`);
				}
				
				width = dv.getInt32(18, true); // Little-endian, signed 32-bit
				height = dv.getInt32(22, true); // Little-endian, signed 32-bit
				const planes = dv.getUint16(26, true); // Little-endian
				bitsPerPixel = dv.getUint16(28, true); // Little-endian
				compression = dv.getUint32(30, true); // Little-endian
				imageSize = dv.getUint32(34, true); // Little-endian
				
				if (planes !== 1) {
					throw new Error("Invalid BMP format: unsupported planes count");
				}
				
				// V4/V5ヘッダーには追加のフィールドがありますが、
				// ピクセルデータサイズの計算には基本的な情報のみ使用
			}
			break;
			
		default:
			throw new Error(`Invalid BMP format: unsupported info header size ${infoHeaderSize}`);
		}
		
		// 画像サイズが0の場合は計算
		let pixelDataSize = imageSize;
		if (pixelDataSize === 0 && compression === 0) { // 無圧縮の場合のみ計算
			// 行サイズの計算（4バイト境界でパディング）
			const rowSize = Math.floor((bitsPerPixel * Math.abs(width) + 31) / 32) * 4;
			pixelDataSize = rowSize * Math.abs(height);
		} else if (pixelDataSize === 0) {
			throw new Error("Invalid BMP format: compressed image without size information");
		}
		
		return {
			pixelDataOffset,
			pixelDataSize,
			width: Math.abs(width),
			height: Math.abs(height)
		};
	}

	protected override async exportImage(): Promise<Uint8Array> {
		// BMPのピクセルデータ後にメタデータと秘密データを追加します。
		const baseImage = this.baseImageData;
		const encoder = new TextEncoder();
		
		// メタデータチャンク (EMDT) を作成
		const encryptedMetadata = await this.getEncryptedMetadata();
		
		// 秘密データチャンク (EDAT) の長さを計算
		let secretDataChunkSize = 0;
		for (let i = 0; i < this.secretItems.length; i++) {
			secretDataChunkSize += 4 + 4 + this.secretItems[i].data.length; // Signature + Length + Data
		}
		
		// メタデータチャンクのサイズ計算
		let metadataChunkSize = 0;
		if (encryptedMetadata !== null) {
			metadataChunkSize = 4 + 4 + encryptedMetadata.length; // Signature + Length + Data
		}
		
		// 新しいファイルサイズ
		const newFileSize = baseImage.length + metadataChunkSize + secretDataChunkSize;
		const result = new Uint8Array(newFileSize);
		
		// 元のBMP画像データをコピー
		result.set(baseImage, 0);
		let offset = baseImage.length;
		
		// EMDT チャンク (メタデータ)
		if (encryptedMetadata !== null) {
			const eMDtSignature = encoder.encode("EMDT");
			const dv = new DataView(result.buffer);
			
			// Signature (4 bytes)
			result.set(eMDtSignature, offset);
			offset += 4;
			
			// Data Length (4 bytes, Little-endian)
			dv.setUint32(offset, encryptedMetadata.length, true);
			offset += 4;
			
			// Data
			result.set(encryptedMetadata, offset);
			offset += encryptedMetadata.length;
		}
		
		// EDAT チャンク (秘密データ)
		const eDAtSignature = encoder.encode("EDAT");
		for (const itm of this.secretItems) {
			const dv = new DataView(result.buffer);
			
			// Signature (4 bytes)
			result.set(eDAtSignature, offset);
			offset += 4;
			
			// Data Length (4 bytes, Little-endian)
			dv.setUint32(offset, itm.data.length, true); // Lower 32 bits
			offset += 4;
			
			// Data
			result.set(itm.data, offset);
			offset += itm.data.length;
		}
		
		return result;
	}

	protected override async importImage(buffer: Uint8Array): Promise<void> {
		// BMPのピクセルデータ終了位置を計算し、その後のEMDTとEDATチャンクを抽出します。
		const decoder = new TextDecoder();
		
		// BMPヘッダーを解析
		const headerInfo = this.parseBmpHeader(buffer);
		
		// ピクセルデータの終了位置を計算
		const pixelDataEnd = headerInfo.pixelDataOffset + headerInfo.pixelDataSize;
		
		// ベース画像データを抽出（ピクセルデータの終了まで）
		this.baseImageData = buffer.slice(0, pixelDataEnd);
		
		// ピクセルデータ後のencrypted chunkを解析
		let offset = pixelDataEnd;
		const dv = new DataView(buffer.buffer, buffer.byteOffset);
		
		while (offset < buffer.length) {
			// 最低限のチャンクヘッダーサイズをチェック
			if (offset + 12 > buffer.length) {
				break; // 不完全なチャンクヘッダー
			}
			
			// Signature (4 bytes)
			const chunkSignature = decoder.decode(buffer.slice(offset, offset + 4));
			offset += 4;
			
			// Data Length (4 bytes, Little-endian)
			const dataLength = dv.getUint32(offset, true);
			offset += 4;
			
			// データ長の妥当性チェック
			if (offset + dataLength > buffer.length) {
				break; // 不完全なチャンクデータ
			}
			
			const chunkData = buffer.slice(offset, offset + dataLength);
			offset += dataLength;
			
			switch (chunkSignature) {
			case 'EMDT':
				// メタデータチャンク
				await this.setEncryptedMetadata(new Uint8Array(chunkData));
				break;
			case 'EDAT':
				// 秘密データチャンク
				await this.addEncryptedSecretItem(new Uint8Array(chunkData));
				break;
			default:
				// 未知のシグネチャは無視
				console.warn(`Unknown chunk signature: ${chunkSignature}`);
				break;
			}
		}
	}
	
	override setBaseImage(binary: Uint8Array, mimeType?: string): void {
		// BMPの場合、そのまま設定
		if (!mimeType || mimeType === 'image/bmp') {
			this.baseImageData = binary;
		}
	}
	
	override getBaseImage(mimeType?: string): Uint8Array {
		// BMPの場合、そのまま返す
		if ((!mimeType || mimeType === 'image/bmp') && this.baseImageData && this.baseImageData.length > 0) {
			return this.baseImageData;
		}
		throw new Error("Base image not set");
	}
}
