export function decodeBase64URLNoPadding(data: string): Uint8Array {
	const b64decoded = atob(data.replace(/-/g, '+').replace(/_/g, '/'));
	return Uint8Array.from(b64decoded, char => char.charCodeAt(0));
}
export function encodeBase64URLNoPadding(data: Uint8Array): string {
	const b64encoded = btoa(String.fromCharCode(...data));
	return b64encoded.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
// Uint8Array, Hexdecimal, Base64形式の鍵情報をUint8Array形式に変換
export function decodeKeyInfo(keyinfo: Uint8Array | string): Uint8Array {
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

// Get MIME type from file extension
export function getMimeTypeFromExtension(fileName: string): string{
	const ext = fileName.split('.').pop()?.toLowerCase()
	const mimeMap: Record<string, string> = {
		// 画像ファイル
		png: 'image/png',
		jpg: 'image/jpeg',
		jpeg: 'image/jpeg',
		webp: 'image/webp',
		bmp: 'image/bmp',
		avif: 'image/avif',
		tif: 'image/tiff',
		tiff: 'image/tiff',
		svg: 'image/svg+xml',
		gif: 'image/gif',
		ico: 'image/vnd.microsoft.icon',
		// 圧縮ファイル
		zip: 'application/zip',
		tar: 'application/x-tar',
		bz: 'application/x-bzip',
		bz2: 'application/x-bzip2',
		gz: 'application/gzip',
		'7z': 'application/x-7z-compressed',
		rar: 'application/vnd.rar',
		pdf: 'application/pdf',
		// テキストファイル
		txt: 'text/plain',
		html: 'text/html',
		htm: 'text/html',
		xml: 'text/xml',
		css: 'text/css',
		js: 'text/javascript',
		json: 'application/json',
		ts: 'text/typescript',
		tsx: 'text/typescript',
		c: 'text/x-csrc',
		h: 'text/x-chdr',
		cpp: 'text/x-c++src',
		hpp: 'text/x-c++hdr',
		py: 'text/x-python',
		d: 'text/x-dsrc',
		di: 'text/x-dsrc',
		rs: 'text/x-rustsrc',
		sh: 'application/x-shellscript',
		bat: 'application/x-bat',
		ps1: 'application/x-powershell',
		md: 'text/markdown',
		markdown: 'text/markdown',
		yml: 'text/yaml',
		yaml: 'text/yaml',
		toml: 'text/toml',
		csv: 'text/csv',
		tsv: 'text/tab-separated-values',
		// 音声
		aac: 'audio/aac',
		mp3: 'audio/mpeg',
		ogg: 'audio/ogg',
		oga: 'audio/ogg',
		mka: 'audio/x-matroska',
		flac: 'audio/x-flac',
		wav: 'audio/x-wav',
		// 動画
		avi: 'video/x-msvideo',
		ogv: 'video/ogg',
		mp4: 'video/mp4',
		mpg: 'video/mpeg',
		mpeg: 'video/mpeg',
		webm: 'video/webm',
		//ts: 'video/mp2t',
		mkv: 'video/x-matroska',
		// その他
		cbor: 'application/cbor',
		pt: 'application/x-pytorch',
		safetensors: 'application/x-safetensors',
		gguf: 'application/x-gguf',
		onnx: 'application/x-onnx',
		ppt: 'application/vnd.ms-powerpoint',
		pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
		doc: 'application/msword',
		docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
		xls: 'application/vnd.ms-excel',
		xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
		exe: 'application/x-msdownload',
		bin: 'application/octet-stream',
		dat: 'application/octet-stream',
	};
	return ext ? (mimeMap[ext] || 'application/octet-stream') : 'application/octet-stream';
}
