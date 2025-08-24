import { describe, test, expect } from 'vitest';
import { 
	decodeBase64URLNoPadding, 
	encodeBase64URLNoPadding, 
	decodeKeyInfo, 
	getMimeTypeFromExtension 
} from '../misc';

describe('Base64URL関数', () => {
	test('Base64URLデコードが正常に動作する', () => {
		const encoded = 'SGVsbG8gV29ybGQ';
		const result = decodeBase64URLNoPadding(encoded);
		const expected = new Uint8Array([72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100]);
		expect(result).toEqual(expected);
	});

	test('Base64URLエンコードが正常に動作する', () => {
		const data = new Uint8Array([72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100]);
		const result = encodeBase64URLNoPadding(data);
		expect(result).toBe('SGVsbG8gV29ybGQ');
	});

	test('エンコード・デコードの往復が一致する', () => {
		const original = new Uint8Array([1, 2, 3, 255, 0, 128]);
		const encoded = encodeBase64URLNoPadding(original);
		const decoded = decodeBase64URLNoPadding(encoded);
		expect(decoded).toEqual(original);
	});
});

describe('キー情報デコード', () => {
	test('Uint8Arrayをそのまま返す', () => {
		const key = new Uint8Array([1, 2, 3, 4]);
		expect(decodeKeyInfo(key)).toBe(key);
	});

	test('16進数文字列を正常にデコードする', () => {
		const hex32 = '0123456789abcdef0123456789abcdef';
		const result = decodeKeyInfo(hex32);
		expect(result).toEqual(new Uint8Array([1, 35, 69, 103, 137, 171, 205, 239, 1, 35, 69, 103, 137, 171, 205, 239]));
	});

	test('48文字の16進数文字列をデコードする', () => {
		const hex48 = '000102030405060708090a0b0c0d0e0f1011121314151617';
		const result = decodeKeyInfo(hex48);
		expect(result.length).toBe(24);
	});

	test('64文字の16進数文字列をデコードする', () => {
		const hex64 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
		const result = decodeKeyInfo(hex64);
		expect(result.length).toBe(32);
	});

	test('Base64URL文字列をデコードする', () => {
		const base64 = 'SGVsbG8';
		const result = decodeKeyInfo(base64);
		expect(result).toEqual(new Uint8Array([72, 101, 108, 108, 111]));
	});
});

describe('MIMEタイプ取得', () => {
	test('画像ファイルのMIMEタイプを正しく返す', () => {
		expect(getMimeTypeFromExtension('test.png')).toBe('image/png');
		expect(getMimeTypeFromExtension('image.JPG')).toBe('image/jpeg');
		expect(getMimeTypeFromExtension('photo.webp')).toBe('image/webp');
	});

	test('テキストファイルのMIMEタイプを正しく返す', () => {
		expect(getMimeTypeFromExtension('readme.txt')).toBe('text/plain');
		expect(getMimeTypeFromExtension('script.js')).toBe('text/javascript');
		expect(getMimeTypeFromExtension('style.css')).toBe('text/css');
		expect(getMimeTypeFromExtension('config.json')).toBe('application/json');
	});

	test('圧縮ファイルのMIMEタイプを正しく返す', () => {
		expect(getMimeTypeFromExtension('archive.zip')).toBe('application/zip');
		expect(getMimeTypeFromExtension('backup.tar')).toBe('application/x-tar');
		expect(getMimeTypeFromExtension('file.7z')).toBe('application/x-7z-compressed');
	});

	test('音声・動画ファイルのMIMEタイプを正しく返す', () => {
		expect(getMimeTypeFromExtension('song.mp3')).toBe('audio/mpeg');
		expect(getMimeTypeFromExtension('video.mp4')).toBe('video/mp4');
		expect(getMimeTypeFromExtension('movie.webm')).toBe('video/webm');
	});

	test('拡張子なしファイルはデフォルトMIMEタイプを返す', () => {
		expect(getMimeTypeFromExtension('filename')).toBe('application/octet-stream');
		expect(getMimeTypeFromExtension('')).toBe('application/octet-stream');
	});

	test('未知の拡張子はデフォルトMIMEタイプを返す', () => {
		expect(getMimeTypeFromExtension('file.unknown')).toBe('application/octet-stream');
		expect(getMimeTypeFromExtension('test.xyz')).toBe('application/octet-stream');
	});

	test('大文字小文字を区別しない', () => {
		expect(getMimeTypeFromExtension('FILE.PNG')).toBe('image/png');
		expect(getMimeTypeFromExtension('Document.PDF')).toBe('application/pdf');
	});
});
