import { ArkImgBase } from "./arkimg";

export class ArkJpeg extends ArkImgBase {

	protected override async exportImage(): Promise<Uint8Array> {
		// JPEGのEOIマーカー後にメタデータと秘密データを追加します。
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
		
		// 元のJPEG画像データをコピー
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
			dv.setUint32(offset, itm.data.length, true);
			offset += 4;
			
			// Data
			result.set(itm.data, offset);
			offset += itm.data.length;
		}
		
		return result;
	}

	protected override async importImage(buffer: Uint8Array): Promise<void> {
		// JPEGのEOIマーカー後のEMDTとEDATチャンクを抽出して秘密データとメタデータを復号します。
		const decoder = new TextDecoder();
		
		// JPEGのEOIマーカー (0xFF 0xD9) を探す
		let eoiPosition = -1;
		for (let i = 0; i < buffer.length - 1; i++) {
			if (buffer[i] === 0xFF && buffer[i + 1] === 0xD9) {
				eoiPosition = i + 2; // EOIマーカーの次の位置
				break;
			}
		}
		
		if (eoiPosition === -1) {
			throw new Error("Invalid JPEG format: EOI marker not found");
		}
		
		// ベース画像はEOIマーカーまで
		this.baseImageData = buffer.slice(0, eoiPosition);
		
		// EOIマーカー後のデータを解析
		let offset = eoiPosition;
		
		while (offset < buffer.length) {
			// 最低限のチャンクヘッダーサイズ (Signature 4 bytes + Length 8 bytes = 12 bytes) をチェック
			if (offset + 12 > buffer.length) {
				break; // 不完全なチャンクヘッダー
			}
			
			// Signature (4 bytes)
			const signature = decoder.decode(buffer.slice(offset, offset + 4));
			offset += 4;
			
			// Data Length (4 bytes, Little-endian)
			const dv = new DataView(buffer.buffer, buffer.byteOffset + offset);
			const dataLength = dv.getUint32(0, true);
			offset += 4;
			
			// データ長の妥当性チェック
			if (offset + dataLength > buffer.length) {
				break; // 不完全なチャンクデータ
			}
			
			const chunkData = buffer.slice(offset, offset + dataLength);
			offset += dataLength;
			
			switch (signature) {
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
				console.warn(`Unknown chunk signature: ${signature}`);
				break;
			}
		}
	}
	
	override setBaseImage(binary: Uint8Array, mimeType?: string): void {
		// JPEGの場合、そのまま設定
		if (!mimeType || mimeType === 'image/jpeg') {
			this.baseImageData = binary;
		}
	}
	
	override getBaseImage(mimeType?: string): Uint8Array {
		// JPEGの場合、そのまま返す
		if ((!mimeType || mimeType === 'image/jpeg') && this.baseImageData && this.baseImageData.length > 0) {
			return this.baseImageData;
		}
		throw new Error("Base image not set");
	}
}
