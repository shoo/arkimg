import { ArkImgBase } from "./arkimg";

export class ArkWebp extends ArkImgBase {

	protected override async exportImage(): Promise<Uint8Array> {
		// WebPのチャンク構造に則り、既存チャンクの後にメタデータと秘密データを追加します。
		const baseImage = this.baseImageData;
		const encoder = new TextEncoder();
		
		// メタデータチャンク (EMDT) を作成
		const encryptedMetadata = await this.getEncryptedMetadata();
		
		// 秘密データチャンク (EDAT) の長さを計算
		let secretDataChunkSize = 0;
		for (let i = 0; i < this.secretItems.length; i++) {
			const chunkSize = this.secretItems[i].data.length;
			// パディングを含む（WebPチャンクは偶数バイトでパディング）
			const paddedSize = (chunkSize % 2 === 0) ? chunkSize : chunkSize + 1;
			secretDataChunkSize += 4 + 4 + paddedSize; // FourCC + Size + Data(with padding)
		}
		
		// メタデータチャンクのサイズ計算
		let metadataChunkSize = 0;
		if (encryptedMetadata !== null) {
			const metadataSize = encryptedMetadata.length;
			const paddedSize = (metadataSize % 2 === 0) ? metadataSize : metadataSize + 1;
			metadataChunkSize = 4 + 4 + paddedSize; // FourCC + Size + Data(with padding)
		}
		
		// 新しいファイルサイズを計算してRIFFヘッダーを更新
		const newFileSize = baseImage.length + metadataChunkSize + secretDataChunkSize;
		const result = new Uint8Array(newFileSize);
		
		// 元の画像データをコピー
		result.set(baseImage, 0);
		let offset = baseImage.length;
		
		// RIFFヘッダーのファイルサイズを更新 (8バイト目から4バイト)
		const dv = new DataView(result.buffer);
		dv.setUint32(4, newFileSize - 8, true); // Little-endian
		
		// EMDT チャンク (メタデータ)
		if (encryptedMetadata !== null) {
			const eMDtFourCC = encoder.encode("EMDT");
			const metadataSize = encryptedMetadata.length;
			const paddedSize = (metadataSize % 2 === 0) ? metadataSize : metadataSize + 1;
			
			// FourCC
			result.set(eMDtFourCC, offset);
			offset += 4;
			
			// Chunk Size (Little-endian)
			dv.setUint32(offset, metadataSize, true);
			offset += 4;
			
			// Data
			result.set(encryptedMetadata, offset);
			offset += metadataSize;
			
			// Padding (if needed)
			if (paddedSize > metadataSize) {
				result[offset] = 0;
				offset += 1;
			}
		}
		
		// EDAT チャンク (秘密データ)
		const eDAtFourCC = encoder.encode("EDAT");
		for (const itm of this.secretItems) {
			const dataSize = itm.data.length;
			const paddedSize = (dataSize % 2 === 0) ? dataSize : dataSize + 1;
			
			// FourCC
			result.set(eDAtFourCC, offset);
			offset += 4;
			
			// Chunk Size (Little-endian)
			dv.setUint32(offset, dataSize, true);
			offset += 4;
			
			// Data
			result.set(itm.data, offset);
			offset += dataSize;
			
			// Padding (if needed)
			if (paddedSize > dataSize) {
				result[offset] = 0;
				offset += 1;
			}
		}
		
		return result;
	}

	protected override async importImage(buffer: Uint8Array): Promise<void> {
		// WebPのチャンクを解析し、EMDTとEDATチャンクを抽出して秘密データとメタデータを復号します。
		const decoder = new TextDecoder();
		let offset = 0;
		
		// RIFF ヘッダーの確認
		if (buffer.length < 12) {
			throw new Error("Invalid WebP format: too short");
		}
		
		const riffSignature = decoder.decode(buffer.slice(0, 4));
		if (riffSignature !== "RIFF") {
			throw new Error("Invalid WebP format: not a RIFF file");
		}
		
		const webpSignature = decoder.decode(buffer.slice(8, 12));
		if (webpSignature !== "WEBP") {
			throw new Error("Invalid WebP format: not a WEBP file");
		}
		
		offset = 12; // RIFF header + file size + WEBP signature
		
		// ベース画像のデータを保存するための配列
		const baseImageBufferSlices: Uint8Array[] = [];
		let totalLength = 12; // RIFF header size
		
		// RIFF header を追加
		baseImageBufferSlices.push(buffer.slice(0, 12));
		
		while (offset < buffer.length) {
			const chunkOffset = offset;
			
			if (offset + 8 > buffer.length) {
				break; // 不完全なチャンクヘッダー
			}
			
			// FourCC (4 bytes)
			const fourCC = decoder.decode(buffer.slice(offset, offset + 4));
			offset += 4;
			
			// Chunk Size (4 bytes, Little-endian)
			const chunkSize = new DataView(buffer.buffer, buffer.byteOffset + offset).getUint32(0, true);
			offset += 4;
			
			if (offset + chunkSize > buffer.length) {
				break; // 不完全なチャンクデータ
			}
			
			const chunkData = buffer.slice(offset, offset + chunkSize);
			offset += chunkSize;
			
			// WebPチャンクは偶数バイトでパディング
			if (chunkSize % 2 === 1 && offset < buffer.length) {
				offset += 1; // パディングバイトをスキップ
			}
			
			switch (fourCC) {
			case 'EMDT':
				// メタデータチャンク
				await this.setEncryptedMetadata(new Uint8Array(chunkData));
				break;
			case 'EDAT':
				// 秘密データチャンク
				await this.addEncryptedSecretItem(new Uint8Array(chunkData));
				break;
			default:
				// それ以外はベースイメージのチャンク
				const chunkEnd = chunkOffset + 8 + chunkSize + (chunkSize % 2);
				const actualChunkEnd = Math.min(chunkEnd, buffer.length);
				baseImageBufferSlices.push(buffer.slice(chunkOffset, actualChunkEnd));
				totalLength += actualChunkEnd - chunkOffset;
				break;
			}
		}
		
		// 新しいUint8Arrayを作成（RIFFファイルサイズを更新）
		const combinedBuffer = new Uint8Array(totalLength);
		let offsetCombinedBuffer = 0;
		
		// 各スライスを新しいバッファにコピー
		for (const slice of baseImageBufferSlices) {
			combinedBuffer.set(slice, offsetCombinedBuffer);
			offsetCombinedBuffer += slice.length;
		}
		
		// RIFFファイルサイズを更新
		const dv = new DataView(combinedBuffer.buffer);
		dv.setUint32(4, totalLength - 8, true); // Little-endian
		
		this.baseImageData = combinedBuffer;
	}
	
	override setBaseImage(binary: Uint8Array, mimeType?: string): void {
		// WEBPの場合、そのまま設定
		if (!mimeType || mimeType === 'image/webp') {
			this.baseImageData = binary;
		}
	}
	
	override getBaseImage(mimeType?: string): Uint8Array {
		// WEBPの場合、そのまま返す
		if ((!mimeType || mimeType === 'image/webp') && this.baseImageData && this.baseImageData.length > 0) {
			return this.baseImageData;
		}
		throw new Error("Base image not set");
	}
}
