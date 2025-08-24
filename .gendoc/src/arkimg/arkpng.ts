import { ArkImgBase } from "./arkimg";
import { calcCRC32 } from "./utils";

export class ArkPng extends ArkImgBase {

	protected override async exportImage(): Promise<Uint8Array> {
		// PNGのチャンク構造に則り、IDATチャンクの後にメタデータと秘密データを追加します。
		const baseImage = this.baseImageData;
		const encoder = new TextEncoder();
		
		// メタデータチャンク (eMDt) を作成
		const encryptedMetadata = await this.getEncryptedMetadata();
		
		// 秘密データチャンク (eDAt) の長さを計算
		let secretDataChunkSize = 0;
		for (let i = 0; i < this.secretItems.length; i++) {
			secretDataChunkSize += 4 + 4 + this.secretItems[i].data.length + 4;
		}
		
		// すべてのチャンクを結合
		let result = new Uint8Array(baseImage.length + (encryptedMetadata !== null ? 4 + 4 + encryptedMetadata.length + 4: 0) + secretDataChunkSize);
		// IENDまで
		result.set(baseImage.slice(0, baseImage.length - 12), 0);
		let offset = baseImage.length - 12;
		// eMDt
		if (encryptedMetadata !== null) {
			const eMDtChunkType = encoder.encode("eMDt");
			const eMDtChunkCRCInit = calcCRC32(eMDtChunkType);
			const dv = new DataView(result.buffer);
			dv.setUint32(offset + 0, encryptedMetadata.length, false);
			result.set(eMDtChunkType, offset + 4);
			result.set(encryptedMetadata, offset + 4 + 4);
			dv.setUint32(offset + 4 + 4 + encryptedMetadata.length, calcCRC32(encryptedMetadata, eMDtChunkCRCInit), false);
			offset += 4 + 4 + encryptedMetadata.length + 4;
		}
		// eDAt
		const eDAtChunkType = encoder.encode("eDAt");
		const eDAtChunkCRCInit = calcCRC32(eDAtChunkType);
		for (const itm of this.secretItems) {
			const dv = new DataView(result.buffer);
			dv.setUint32(offset + 0, itm.data.length, false);
			result.set(eDAtChunkType, offset + 4);
			result.set(itm.data, offset + 4 + 4);
			dv.setUint32(offset + 4 + 4 + itm.data.length, calcCRC32(itm.data, eDAtChunkCRCInit), false);
			offset += 4 + 4 + itm.data.length + 4;
		}
		// IEND
		result.set(baseImage.slice(baseImage.length - 12), offset);
		
		return result;
	}

	protected override async importImage(buffer: Uint8Array): Promise<void> {
		// PNGのチャンクを解析し、eMDtとeDatチャンクを抽出して秘密データとメタデータを復号します。
		const baseImageBufferSlices : Uint8Array[] = [];
		let totalLength = 0;
		const decoder = new TextDecoder();
		let offset = 0;
		const pngHeader = buffer.slice(0, 8);
		baseImageBufferSlices.push(pngHeader);
		totalLength += pngHeader.length;
		offset += 8;
		
		let foundIEND: boolean = false;
		while (offset < buffer.length && !foundIEND) {
			const chunkOffset = offset;
			// Chunk Length (4 bytes)
			const chunkLength = new DataView(buffer.slice(offset, offset + 4).buffer).getUint32(0, false); // Big-endian
			offset += 4;
			
			// Chunk Type (4 bytes)
			const chunkType = decoder.decode(buffer.slice(offset, offset + 4));
			offset += 4;
			
			const chunkData = buffer.slice(offset, offset + chunkLength);
			offset += chunkLength;
			
			// CRC (4 bytes) - 今回は使用しません
			offset += 4;
			
			switch (chunkType)
			{
			case 'eMDt':
				// メタデータチャンク
				await this.setEncryptedMetadata(new Uint8Array(chunkData));
				break;
			case 'eDAt':
				// 秘密データチャンク
				await this.addEncryptedSecretItem(new Uint8Array(chunkData));
				break;
			case 'IEND':
				// IEND
				baseImageBufferSlices.push(buffer.slice(chunkOffset, offset));
				totalLength += offset - chunkOffset;
				foundIEND = true;
				break;
			default:
				// それ以外はベースイメージのチャンク
				baseImageBufferSlices.push(buffer.slice(chunkOffset, offset));
				totalLength += offset - chunkOffset;
				break;
			}
		}
		if (!foundIEND) {
			throw new Error("Invalid PNG format.");
		}
		// 新しいUint8Arrayを作成
		const combinedBuffer = new Uint8Array(totalLength);
		let offsetCombinedBuffer = 0;
		// 各スライスを新しいバッファにコピー
		for (const slice of baseImageBufferSlices) {
			combinedBuffer.set(slice, offsetCombinedBuffer);
			offsetCombinedBuffer += slice.length;
		}
		this.baseImageData = combinedBuffer;
	}
	
	override setBaseImage(binary: Uint8Array, mimeType?: string): void {
		// PNGの場合、そのまま設定
		if (!mimeType || mimeType === 'image/png') {
			this.baseImageData = binary;
		}
	}
	
	override getBaseImage(mimeType?: string): Uint8Array {
		// PNGの場合、そのまま返す
		if ((!mimeType || mimeType === 'image/png') && this.baseImageData && this.baseImageData.length > 0) {
			return this.baseImageData;
		}
		throw new Error("Base image not set");
	}
}
