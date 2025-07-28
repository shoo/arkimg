/*******************************************************************************
 * PNG拡張
 * 
 * PNG画像のArkPngクラスを定義します。
 * このクラスはlibpngに依存しており $(D baseImage) にBMP画像の読み書きをサポートしています。
 * - `ArkPng`: ArkImgのPNG用クラス。
 */
module arkimg.png;

import arkimg.bmp;
import arkimg._internal.base;
import arkimg._internal.misc;
import libpng.png;
import std.json;
import std.exception;
import std.sumtype;


/*******************************************************************************
 * ArkImg for PNG
 */
class ArkPng: ArkImgBase
{
private:
	//--------------------------------------------------------------------------
	// TYPES
	//--------------------------------------------------------------------------
	static struct MemoryReadStream
	{
		const(ubyte)[] buffer;
	}
	static struct MemoryWriteStream
	{
		import std.array;
		Appender!(ubyte[]) appender;
	}
	//--------------------------------------------------------------------------
	// DATA
	//--------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------
	// STATIC FUNCTIONS
	//--------------------------------------------------------------------------
	// PNG I/O メモリーリーダー
	static extern (C) void _fnReadMemory(png_structp pngPtr, png_bytep data, png_size_t length)
	{
		auto mem = cast(MemoryReadStream*) png_get_io_ptr(pngPtr);
		if (length <= mem.buffer.length)
		{
			data[0 .. length] = mem.buffer[0 .. length];
			mem.buffer = mem.buffer[length..$];
		}
		else
		{
			png_error(pngPtr, "Read Error in png_memory_read");
		}
	}
	// PNG I/O メモリーライター
	static extern (C) void _fnWriteMemory(png_structp pngPtr, png_bytep data, png_size_t length)
	{
		import core.memory;
		auto mem = cast(MemoryWriteStream*)png_get_io_ptr(pngPtr);
		mem.appender ~= data[0..length];
	}
	
	//--------------------------------------------------------------------------
	// PRIVATE FUNCTIONS
	//--------------------------------------------------------------------------
	
	// カスタムチャンクを挿入
	static void _insertCustomChunk(png_structp pngPtr, png_infop infoPtr, string chunkName, in ubyte[] data,
		png_byte location = PNG_AFTER_IDAT)
	{
		png_unknown_chunk customChunk;
		customChunk.name[0 .. 4] = cast(const(ubyte)[]) chunkName[0 .. 4];
		customChunk.data = cast(png_byte*) data.ptr;
		customChunk.size = cast(png_size_t) data.length;
		customChunk.location = location;
		png_set_unknown_chunks(pngPtr, infoPtr, &customChunk, 1);
	}
	// BMP画像読み込み
	void _loadImageBmp(in ubyte[] binary) @trusted
	{
		import std.math: abs;
		import arkimg._internal.refcnt;
		version (Posix) import core.sys.posix.setjmp;
		auto bmp = createBitmap(binary);
		// 入力, 出力
		auto ostrm = MemoryWriteStream();
		auto pngPtrWrite = png_create_write_struct(PNG_LIBPNG_VER_STRING.ptr, null, null, null)
			.enforce("Error: png_create_write_struct failed.");
		scope (success)
			_image = ostrm.appender.data.assumeUnique;
		auto infoPtrWrite = png_create_info_struct(pngPtrWrite);
		if (!infoPtrWrite)
		{
			png_destroy_write_struct(&pngPtrWrite, null);
			throw new Exception("Error: png_create_info_struct failed.");
		}
		scope (exit)
			png_destroy_write_struct(&pngPtrWrite, &infoPtrWrite);
		
		//version (Posix)
		//	if (setjmp(png_jmpbuf(pngPtr)))
		//		return;
		// PNGヘッダ出力
		png_set_write_fn(pngPtrWrite, &ostrm, &_fnWriteMemory, null);
		auto w = bmp.size.width;
		auto h = abs(bmp.size.height);
		auto ch = bmp.channels;
		png_set_IHDR(
			pngPtrWrite, infoPtrWrite,
			w, h, 8, ch == 3 ? PNG_COLOR_TYPE_RGB : ch == 4 ? PNG_COLOR_TYPE_RGB_ALPHA : PNG_COLOR_TYPE_GRAY,
			PNG_INTERLACE_NONE,
			PNG_COMPRESSION_TYPE_DEFAULT,
			PNG_FILTER_TYPE_DEFAULT
		);
		// 情報チャンクの書き込み
		png_write_info(pngPtrWrite, infoPtrWrite);
		// BMPのピクセルデータをPNGに書き込む（左上から左下に走査）
		scope bmpRow = new ubyte[w * ch];
		switch (ch)
		{
		case 1:
			foreach (y; 0 .. h)
				png_write_row(pngPtrWrite, bmp.row(h - y - 1).ptr);
			break;
		case 3:
			foreach (y; 0 .. h)
			{
				auto row = bmp.row(h - y - 1);
				foreach (x; 0 .. w)
				{
					bmpRow[x * 3 + 0] = row[x * 3 + 2]; // R→B
					bmpRow[x * 3 + 1] = row[x * 3 + 1]; // G→G
					bmpRow[x * 3 + 2] = row[x * 3 + 0]; // B→R
				}
				png_write_row(pngPtrWrite, bmpRow.ptr);
			}
			break;
		case 4:
			foreach (y; 0 .. h)
			{
				auto row = bmp.row(h - y - 1);
				foreach (x; 0 .. w)
				{
					bmpRow[x * 3 + 0] = row[x * 3 + 2]; // R→B
					bmpRow[x * 3 + 1] = row[x * 3 + 1]; // G→G
					bmpRow[x * 3 + 2] = row[x * 3 + 0]; // B→R
					bmpRow[x * 4 + 3] = row[x * 4 + 0]; // A→A
				}
				png_write_row(pngPtrWrite, bmpRow.ptr);
			}
			break;
		default:
			enforce(0, "Unknown pixel format");
		}
		// IENDチャンクの書き込み
		png_write_end(pngPtrWrite, infoPtrWrite);
	}
	
	/***************************************************************************
	 * PNG画像読み込み
	 */
	void _loadImagePng(in ubyte[] binary) @trusted
	{
		version (Posix) import core.sys.posix.setjmp;
		_image = binary.dup;
		
		// 入力
		auto istrm = MemoryReadStream(binary);
		auto pngPtr = png_create_read_struct(PNG_LIBPNG_VER_STRING.ptr, null, null, null)
			.enforce("Error: png_create_read_struct failed.");
		auto infoPtr = png_create_info_struct(pngPtr);
		if (!infoPtr)
		{
			png_destroy_read_struct(&pngPtr, null, null);
			throw new Exception("Error: png_create_info_struct failed.");
		}
		scope (exit)
			png_destroy_read_struct(&pngPtr, &infoPtr, null);
		
		//version (Posix)
		//	if (setjmp(png_jmpbuf(pngPtr)))
		//		return;
		
		// メモリから読み込むためのリード関数
		png_set_read_fn(pngPtr, &istrm, &_fnReadMemory);
		png_set_keep_unknown_chunks(pngPtr, PNG_HANDLE_CHUNK_ALWAYS, cast(immutable(ubyte)*)"eDAt\0eMDt\0"c.ptr, 0);
		png_read_info(pngPtr, infoPtr);
		// IDATを読みとばす
		scope row = new ubyte[png_get_rowbytes(pngPtr, infoPtr)];
		foreach (y; 0..png_get_image_height(pngPtr, infoPtr))
			png_read_row(pngPtr, row.ptr, null);
		png_read_end(pngPtr, infoPtr);
		png_unknown_chunkp unknownChunks;
		auto numUnknownChunks = png_get_unknown_chunks(pngPtr, infoPtr, &unknownChunks);
		foreach (ref chunk; unknownChunks[0..numUnknownChunks])
		{
			if (chunk.name[0..4] == "eDAt")
			{
				_secretItems ~= SecretItem(EncryptedBinary(chunk.data[0..chunk.size].idup));
			}
			else if (chunk.name[0..4] == "eMDt")
			{
				_metadata = EncryptedBinary(chunk.data[0..chunk.size].idup);
			}
			else
			{
				// 何もしない
			}
		}
	}
	
	/***************************************************************************
	 * PNG画像出力
	 */
	immutable(ubyte)[] _exportPng() const @trusted
	{
		version (Posix) import core.sys.posix.setjmp;
		// 入力, 出力
		auto istrm = MemoryReadStream(_image);
		auto ostrm = MemoryWriteStream();
		
		// 読み込み用にpng構造体を再初期化
		auto pngPtr = png_create_read_struct(PNG_LIBPNG_VER_STRING.ptr, null, null, null)
			.enforce("Error: png_create_read_struct failed.");
		auto infoPtr = png_create_info_struct(pngPtr);
		if (!infoPtr)
		{
			png_destroy_read_struct(&pngPtr, null, null);
			throw new Exception("Error: png_create_info_struct failed.");
		}
		scope (exit)
			png_destroy_read_struct(&pngPtr, &infoPtr, null);
		//version (Posix)
		//	if (setjmp(png_jmpbuf(pngPtr)))
		//		return;
	
		// 書き込み用にpng構造体を再初期化
		auto pngPtrWrite = png_create_write_struct(PNG_LIBPNG_VER_STRING.ptr, null, null, null)
			.enforce("Error: png_create_write_struct failed.");
		auto infoPtrWrite = png_create_info_struct(pngPtr);
		if (!infoPtrWrite)
		{
			png_destroy_write_struct(&pngPtrWrite, null);
			throw new Exception("Error: png_create_info_struct failed.");
		}
		scope (exit)
			png_destroy_write_struct(&pngPtrWrite, &infoPtrWrite);
		//version (Posix)
		//	if (setjmp(png_jmpbuf(pngWritePtr)))
		//		return;
		
		// IDATまで読み込み
		png_set_keep_unknown_chunks(pngPtr, PNG_HANDLE_CHUNK_ALWAYS, null, -1);
		png_set_keep_unknown_chunks(pngPtr, PNG_HANDLE_CHUNK_NEVER, cast(immutable(ubyte)*)"eMDt\0eDAt\0"c.ptr, 2);
		png_set_read_fn(pngPtr, &istrm, &_fnReadMemory);
		png_read_info(pngPtr, infoPtr);
		
		// PNGヘッダ出力
		png_set_write_fn(pngPtrWrite, &ostrm, &_fnWriteMemory, null);
		png_set_IHDR(
			pngPtrWrite, infoPtrWrite,
			png_get_image_width(pngPtr, infoPtr),
			png_get_image_height(pngPtr, infoPtr),
			png_get_bit_depth(pngPtr, infoPtr),
			png_get_color_type(pngPtr, infoPtr),
			png_get_interlace_type(pngPtr, infoPtr),
			png_get_compression_type(pngPtr, infoPtr),
			png_get_filter_type(pngPtr, infoPtr)
		);
		
		// IHDR～IDATまでのカスタムチャンク転送
		png_unknown_chunkp unknownChunks;
		auto numUnknownChunks = png_get_unknown_chunks(pngPtr, infoPtr, &unknownChunks);
		if (numUnknownChunks > 0)
			png_set_unknown_chunks(pngPtrWrite, infoPtrWrite, unknownChunks, numUnknownChunks);
		png_write_info(pngPtrWrite, infoPtrWrite);
		
		// IDATデータの書き込み
		ubyte[] row = new ubyte[png_get_rowbytes(pngPtr, infoPtr)];
		for (int y = 0; y < png_get_image_height(pngPtr, infoPtr); y++)
		{
			png_read_row(pngPtr, row.ptr, null);
			png_write_row(pngPtrWrite, row.ptr);
		}
		
		// IDAT～IENDまでの情報を読み取る
		png_read_end(pngPtr, infoPtr);
		numUnknownChunks = png_get_unknown_chunks(pngPtr, infoPtr, &unknownChunks);
		if (numUnknownChunks > 0)
			png_set_unknown_chunks(pngPtrWrite, infoPtrWrite, unknownChunks, numUnknownChunks);
		
		// `eMDt`チャンクと`eDAt`チャンクを追加
		import std.string;
		auto emtd = _getEncryptedMetadata();
		if (emtd.length != 0)
			_insertCustomChunk(pngPtrWrite, infoPtrWrite, "eMDt", emtd);
		foreach (edat; _getEncryptedItems)
			_insertCustomChunk(pngPtrWrite, infoPtrWrite, "eDAt", edat);
		
		// IENDチャンクの書き込み
		png_write_end(pngPtrWrite, infoPtrWrite);
		
		return ostrm.appender.data.assumeUnique;
	}
	
public:
	//--------------------------------------------------------------------------
	// PUBLIC FUNCTIONS
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * コンストラクタ
	 */
	this(in ubyte[] binary = null, in ubyte[] commonKey = null, in ubyte[] iv = null)
	{
		if (binary !is null)
			this.load(binary);
		if (commonKey.length > 0)
			this.setKey(commonKey, iv);
	}
	/***************************************************************************
	 * ArkImg primitives
	 */
	void load(in ubyte[] binary) @safe
	{
		_loadImagePng(binary);
	}
	/// ditto
	immutable(ubyte)[] save() const @safe
	{
		return _exportPng();
	}
	/// ditto
	void baseImage(in ubyte[] binary, string mimeType = null) @safe
	{
		if (mimeType is null || mimeType == "image/png")
		{
			_loadImagePng(binary);
		}
		else if (mimeType == "image/bmp")
		{
			_loadImageBmp(binary);
		}
		else
		{
			enforce(0, "Unsupported image type: " ~ mimeType);
		}
	}
	/// ditto
	immutable(ubyte)[] baseImage(string mimeType = null) const @safe
	{
		if (mimeType is null || mimeType == "image/png")
		{
			return _image;
		}
		else if (mimeType == "image/bmp")
		{
			return null;
		}
		else
		{
			enforce(0, "Unsupported image type.");
		}
		assert(0);
	}
}

@system unittest
{
	import std;
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
	
	auto img1 = new ArkPng;
	img1.setKey(commonKey, iv);
	img1.baseImage(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.bmp")), "image/bmp");
	img1.clearSecretItems();
	img1.addSecretItem("TESTTESTTEST".representation);
	assert(!img1.hasSign);
	img1.sign(prvKey);
	assert(img1.hasSign);
	
	std.file.write(testdir.buildPath("test-out.png"), img1.save());
	
	auto img2 = new ArkPng;
	img2.load(cast(immutable(ubyte)[])std.file.read(testdir.buildPath("test-out.png")));
	img2.setKey(commonKey, iv);
	assert(img2.hasSign);
	assert(img2.verify(pubKey));
	assert(img2.getSecretItemCount() == 1);
	assert(img2.getDecryptedItem(0) == "TESTTESTTEST".representation);
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
	auto prvKey    = createPrivateKey();
	auto pubKey    = createPublicKey(prvKey);
	
	auto img1 = new ArkPng;
	img1.setKey(commonKey);
	img1.baseImage(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.bmp")), "image/bmp");
	img1.clearSecretItems();
	img1.addSecretItem(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.png")));
	assert(!img1.hasSign);
	img1.sign(prvKey);
	assert(img1.hasSign);
	
	std.file.write(testdir.buildPath("test-out.png"), img1.save());
}
