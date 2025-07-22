module arkimg.webp;

import arkimg.bmp;
import arkimg._internal.base;
import arkimg._internal.crypto;
import arkimg._internal.misc;
import std.exception;

/*******************************************************************************
 * ArkImg for WebP
 */
class ArkWebp: ArkImgBase
{
private:
	enum ubyte[4] _fileSignatureRIFF = ['R', 'I', 'F', 'F'];
	enum ubyte[4] _fileFourCcWEBP    = ['W', 'E', 'B', 'P'];
	enum ubyte[4] _chunkFourCcEMDT   = ['E', 'M', 'D', 'T'];
	enum ubyte[4] _chunkFourCcEDAT   = ['E', 'D', 'A', 'T'];
	//--------------------------------------------------------------------------
	// TYPES
	//--------------------------------------------------------------------------
	static struct FileHeader
	{
		ubyte[4] fileSignature;
		uint     fileSize;
		ubyte[4] format;
	}
	static struct ChunkHeader
	{
		ubyte[4] chunkFourCc;
		uint     chunkSize;
	}
	static struct ChunkData
	{
		ChunkHeader        header;
		immutable(ubyte)[] data;
	}
	
	static struct WebpData
	{
		FileHeader fileHeader;
		ChunkData[] chunks;
	}
	
	//--------------------------------------------------------------------------
	// DATA
	//--------------------------------------------------------------------------
	WebpData _webp;
	
	//--------------------------------------------------------------------------
	// PRIVATE FUNCIONS
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * Webp画像入力
	 */
	void _importWebp(in ubyte[] binary, bool loadSecretData = true) @safe
	{
		enforce(binary.length >= FileHeader.sizeof, "Invalid WebP file format.");
		enforce(binary[0..4] == _fileSignatureRIFF[], "Invalid WebP file format.");
		enforce(binary[8..12] == _fileFourCcWEBP[], "Invalid WebP file format.");
		const(ubyte)[] src = binary[];
		(() @trusted => _webp.fileHeader = *cast(FileHeader*)src.ptr)();
		enforce(binary.length == 8 + _webp.fileHeader.fileSize, "Invalid WebP file format.");
		src = src[FileHeader.sizeof..$];
		while (src.length > 0)
		{
			enforce(src.length >= ChunkHeader.sizeof, "Invalid WebP file format.");
			ChunkData chunk;
			(() @trusted => chunk.header = *cast(ChunkHeader*)src.ptr)();
			src = src[ChunkHeader.sizeof..$];
			enforce(chunk.header.chunkSize <= src.length, "Invalid WebP file format.");
			chunk.data = src[0..chunk.header.chunkSize].idup;
			src = src[chunk.header.chunkSize..$];
			if (chunk.header.chunkFourCc == _chunkFourCcEDAT)
			{
				// SecretItem
				if (loadSecretData)
					_secretItems ~= SecretItem(EncryptedBinary(chunk.data));
			}
			else if (chunk.header.chunkFourCc == _chunkFourCcEMDT)
			{
				// Metadata
				if (loadSecretData)
					(() @trusted => _metadata = EncryptedBinary(chunk.data))();
			}
			else
			{
				_webp.chunks ~= chunk;
			}
		}
	}
	
	/***************************************************************************
	 * PNG画像出力
	 */
	immutable(ubyte)[] _exportWebp(bool saveSecretData = true) const @safe
	{
		import std.algorithm: map, sum;
		import std.range: chain;
		import std.array;
		auto app = appender!(immutable(ubyte)[]);
		
		// 秘密情報のチャンクをsize算出のために事前計算
		ChunkData[] customChunks;
		if (saveSecretData)
		{
			if (auto md = _getEncryptedMetadata())
			{
				ChunkData chunk;
				chunk.header.chunkFourCc[] = _chunkFourCcEMDT[];
				chunk.header.chunkSize = cast(uint)md.length;
				chunk.data = md;
				customChunks ~= chunk;
			}
			foreach (item; _getEncryptedItems())
			{
				ChunkData chunk;
				chunk.header.chunkFourCc[] = _chunkFourCcEDAT[];
				chunk.header.chunkSize = cast(uint)item.length;
				chunk.data = item;
				customChunks ~= chunk;
			}
		}
		
		// ヘッダ出力
		auto header = FileHeader(_fileSignatureRIFF,
			cast(uint)(chain(_webp.chunks, customChunks).map!(chunk => ChunkHeader.sizeof + chunk.data.length).sum()
				+ _fileFourCcWEBP.length),
			_fileFourCcWEBP);
		app ~= (() @trusted => (cast(ubyte*)&header)[0..FileHeader.sizeof])();
		
		// 各チャンク出力
		foreach (chunk; chain(_webp.chunks, customChunks))
		{
			app ~= (() @trusted => (cast(ubyte*)&chunk.header)[0..ChunkHeader.sizeof])();
			app ~= chunk.data;
		}
		return app.data;
	}
	
	/***************************************************************************
	 * BMP読み込み
	 * 
	 * libwebpに依存している場合だけ実装
	 * BMPをWebP形式に圧縮率90で変換し、そのWebPを読み込む。
	 */
	version (Have_libwebp)
	void _importBmpBaseImage(in ubyte[] binary) @trusted
	{
		import webp.encode;
		import core.stdc.stdlib: WebPFree = free;
		auto bmpimg = createBitmap(binary.dup);
		auto bmpsize = bmpimg.size,
			h = bmpsize.height,
			w = bmpsize.width;
		if (h < 0)
			h = -h;
		else
			bmpimg.vflip();
		ubyte* webpoutbuf;
		auto webpbufsize = bmpimg.channels == 4
			? WebPEncodeBGRA(bmpimg.dib.ptr, w, h, bmpimg.stride, 75.0f, &webpoutbuf)
			: WebPEncodeBGR(bmpimg.dib.ptr, w, h, bmpimg.stride, 75.0f, &webpoutbuf);
		scope (exit)
			WebPFree(webpoutbuf);
		_importWebp(webpoutbuf[0..webpbufsize], false);
	}
	
	/***************************************************************************
	 * BMP出力
	 * 
	 * libjpeg-turboに依存している場合だけ実装
	 * BMPをJPEG形式に圧縮率90で変換し、そのJPEGを読み込む。
	 */
	version (Have_libwebp)
	immutable(ubyte)[] _exportBmpBaseImage() const @trusted
	{
		import webp.decode;
		import core.stdc.stdlib: WebPFree = free;
		auto webpbuf = _exportWebp(false);
		WebPBitstreamFeatures webpfeatures;
		auto resultStatusCode = WebPGetFeatures(webpbuf.ptr, webpbuf.length, &webpfeatures);
		enforce(resultStatusCode == VP8StatusCode.VP8_STATUS_OK);
		auto bmp = webpfeatures.has_alpha
			? createBitmap(BmpSize(webpfeatures.width, webpfeatures.height), 8, 4)
			: createBitmap(BmpSize(webpfeatures.width, webpfeatures.height), 8, 3);
		int w, h;
		auto bmpBuf = webpfeatures.has_alpha
			? WebPDecodeBGRA(webpbuf.ptr, webpbuf.length, &w, &h)
			: WebPDecodeBGR(webpbuf.ptr, webpbuf.length, &w, &h);
		scope (exit)
			WebPFree(bmpBuf);
		auto wBytesCount = w * (webpfeatures.has_alpha ? 4 : 3);
		auto currPtr = bmpBuf;
		foreach (r; 0 .. h)
		{
			auto dstBuf = bmp.row(h - r - 1);
			dstBuf[0..wBytesCount] = currPtr[0..wBytesCount];
			currPtr += wBytesCount;
		}
		return bmp.fileBuffer.idup;
	}
	
public:
	//--------------------------------------------------------------------------
	// PUBLIC FUNCIONS
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * コンストラクタ
	 */
	this(in ubyte[] binary = null, in ubyte[] commonKey = null, in ubyte[] iv = null)
	{
		if (binary !is null)
			this.load(binary);
		if (commonKey)
			this.setKey(commonKey, iv);
	}
	
	/***************************************************************************
	 * PRIMITIVES
	 */
	void load(in ubyte[] binary)
	{
		_importWebp(binary);
	}
	/// ditto
	immutable(ubyte)[] save() const
	{
		return _exportWebp();
	}
	/// ditto
	void baseImage(in ubyte[] binary, string mimeType = null)
	{
		if (mimeType is null || mimeType == "image/webp")
		{
			_importWebp(binary);
		}
		else
		{
			version (Have_libwebp)
				if (mimeType == "image/bmp")
					return _importBmpBaseImage(binary);
			// TODO
			enforce("Unsupported image type.");
		}
	}
	/// ditto
	immutable(ubyte)[] baseImage(string mimeType = null)
	{
		if (mimeType is null || mimeType == "image/webp")
		{
			return _exportWebp();
		}
		else
		{
			version (Have_libwebp)
				if (mimeType == "image/bmp")
					return _exportBmpBaseImage();
			enforce("Unsupported image type.");
		}
		assert(0);
	}
}

@system unittest
{
	import std.file, std.path, std.uuid, std.string;
	import arkimg.utils;
	auto testdir = buildPath("tests", randomUUID.toString());
	enum resdir  = buildPath("tests", ".resources");
	mkdirRecurse(testdir);
	scope (exit)
		rmdirRecurse(testdir);
	
	auto commonKey = createCommonKey();
	auto iv = createRandomIV();
	auto prvKey = createPrivateKey();
	auto pubKey = createPublicKey(prvKey);
	
	auto img1 = new ArkWebp(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.webp")), commonKey, iv);
	img1.addSecretItem("TESTTESTTEST".representation);
	img1.sign(prvKey);
	std.file.write(testdir.buildPath("test-out.webp"), img1.save);
	auto sec1 = img1.getDecryptedItem(0);
	assert(sec1 == "TESTTESTTEST".representation);
	
	auto img2 = new ArkWebp(cast(immutable(ubyte)[])std.file.read(testdir.buildPath("test-out.webp")), commonKey, iv);
	assert(img2.getSecretItemCount() == 1);
	assert(img2.getDecryptedItem(0) == "TESTTESTTEST".representation);
	assert(img2.hasSign());
	assert(img2.verify(pubKey));
}
