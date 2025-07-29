/*******************************************************************************
 * JPEG拡張
 * 
 * JPEG画像のArkJpegクラスを定義します。
 * このクラスはlibjpeg-turboに依存させることで $(D baseImage) にBMP画像の読み書きをサポートさせることができます。
 * `dub.selection.json` に依存を追加するか、このライブラリを継承したプロジェクトで依存を追加します。
 * - `ArkJpeg`: ArkImgのJPEG用クラス。
 */
module arkimg.jpg;

import arkimg._internal.base;
import arkimg.bmp;
import arkimg._internal.crypto;
import arkimg._internal.misc;
import std.exception;
import std.sumtype;
import std.json;

/*******************************************************************************
 * ArkImg for Jpeg
 */
class ArkJpeg: ArkImgBase
{
private:
	enum ubyte[4] _chunkFourCcEMDT   = ['E', 'M', 'D', 'T'];
	enum ubyte[4] _chunkFourCcEDAT   = ['E', 'D', 'A', 'T'];
	//--------------------------------------------------------------------------
	// TYPES
	//--------------------------------------------------------------------------
	static struct JpegData
	{
		size_t startSegment;
		static struct Segment
		{
			size_t start;
			immutable(ubyte)[] marker;
			immutable(ubyte)[] data;
		}
		Segment[] segments;
		immutable(ubyte)[] imageData;
		size_t endOfImage;
	}
	//--------------------------------------------------------------------------
	// DATA
	//--------------------------------------------------------------------------
	JpegData _jpeg;
	
	//--------------------------------------------------------------------------
	// PRIVATE FUNCIONS
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * Jpeg画像入力
	 */
	void _importJpeg(in ubyte[] binary, bool loadSecretData = true) @safe
	{
		import std.algorithm;
		_image = binary.idup;
		enforce(_image[0 .. 2] == [0xFF, 0xD8], "Unsupported image type.");
		_jpeg.startSegment = 2;
		size_t parsePos = 2;
		// JPEG画像の構造解析
		while (parsePos < _image.length)
		{
			auto buffer = _image[parsePos .. $];
			enforce(buffer.length >= 2, "Unsupported image type.");
			if (buffer[0 .. 2] == [0xFF, 0xD9])
			{
				// Found EOI
				_jpeg.endOfImage = parsePos;
				parsePos += 2;
				break;
			}
			enforce(buffer.length >= 4, "Unsupported image type.");
			auto segLen = size_t(buffer[2]) << 8 | size_t(buffer[3]);
			enforce(segLen >= 2 && segLen < segLen + 2 && segLen <= buffer.length, "Unsupported image type.");
			JpegData.Segment seg;
			seg.start  = parsePos;
			seg.marker = buffer[0..2];
			seg.data   = buffer[4..2 + segLen];
			_jpeg.segments ~= seg;
			parsePos += 2 + segLen;
			if (seg.marker == [0xFF, 0xDA])
			{
				// Found SOS
				buffer = _image[parsePos .. $];
				auto imgSize = buffer.countUntil([0xFF, 0xD9]);
				enforce(imgSize != -1, "Unsupported image type.");
				_jpeg.imageData = buffer[0 .. imgSize];
				parsePos += imgSize;
			}
		}
		if (!loadSecretData)
			return;
		// ArkImg拡張情報の構造解析
		while (parsePos < _image.length)
		{
			auto buf = _image[parsePos .. $];
			if (buf.length < 8)
				break;
			uint len  = (uint(buf[4]) << 0) | (uint(buf[5]) << 8) | (uint(buf[6]) << 16) | (uint(buf[7]) << 24);
			if (!(len >= 4 && len < len + 4 && len + 4 <= buf.length))
				break;
			if (buf[0..4] == _chunkFourCcEDAT)
			{
				// SecretItem
				_secretItems ~= SecretItem(EncryptedBinary(buf[8 .. len + 4]));
			}
			else if (buf[0..4] == _chunkFourCcEMDT)
			{
				// Metadata
				() @trusted { _metadata = EncryptedBinary(buf[8 .. len + 4]); }();
			}
			else
			{
				// 何もしない
			}
			parsePos += 4 + len;
		}
	}
	
	/***************************************************************************
	 * Jpeg画像出力
	 */
	immutable(ubyte)[] _exportJpeg(bool saveSecretData = true) const @safe
	{
		import std.array;
		enforce(_image.length >= 2);
		assert(_jpeg.endOfImage <= cast()_image.length - 2);
		auto app = appender!(ubyte[]);
		app ~= _image[0 .. _jpeg.endOfImage + 2];
		
		if (!saveSecretData)
			return (() @trusted => app.data.assumeUnique)();
		
		if (auto md = _getEncryptedMetadata())
		{
			enforce(md.length < uint.max - 4, "A metadata is too long.");
			uint len = cast(uint)(md.length + 4);
			app ~= _chunkFourCcEMDT[];
			app ~= [ubyte((len & 0x000000FF) >> 0),
				ubyte((len & 0x000000FF) >> 8),
				ubyte((len & 0x00FF0000) >> 16),
				ubyte((len & 0xFF000000) >> 24)];
			app ~= md;
		}
		foreach (item; _getEncryptedItems())
		{
			enforce(item.length < uint.max - 4, "A secret item is too long.");
			uint len = cast(uint)(item.length + 4);
			app ~= _chunkFourCcEDAT[];
			app ~= [ubyte((len & 0x000000FF) >> 0),
				ubyte((len & 0x0000FF00) >> 8),
				ubyte((len & 0x00FF0000) >> 16),
				ubyte((len & 0xFF000000) >> 24)];
			app ~= item;
		}
		return (() @trusted => app.data.assumeUnique)();
	}
	
	/***************************************************************************
	 * BMP読み込み
	 * 
	 * libjpeg-turboに依存している場合だけ実装
	 * BMPをJPEG形式に圧縮率90で変換し、そのJPEGを読み込む。
	 */
	version (Have_jpeg_turbo)
	void _importBmpBaseImage(in ubyte[] binary) @trusted
	{
		import libjpeg.turbojpeg;
		auto bmpimgSrc = createBitmap(binary);
		auto bmpimg = bmpimgSrc.channels == 4 ? bmpimgSrc.alphaBrend(0xFFFFFF) : bmpimgSrc;
		auto bmpsize = bmpimg.size;
		auto h = bmpsize.height < 0 ? -bmpsize.height : bmpsize.height;
		auto w = bmpsize.width;
		// TODO: カラーパレット、モノクロビットマップ等に対応
		auto compressor = tjInitCompress();
		scope (exit)
			tjDestroy(compressor);
		ubyte* jpegoutbuf;
		size_t jpegbufsize;
		int flags = TJFLAG_FASTDCT;
		if (bmpsize.height >= 0)
			flags |= TJFLAG_BOTTOMUP;
		enforce(tjCompress2(compressor, cast(ubyte*)bmpimg.dib.ptr, w, 0, h, TJPF.TJPF_BGR,
			&jpegoutbuf, cast(c_ulong*)&jpegbufsize,
			TJSAMP.TJSAMP_444, 90, flags) >= 0, "Unsupported image type.");
		scope (exit)
			tjFree(jpegoutbuf);
		_importJpeg(jpegoutbuf[0..jpegbufsize], false);
	}
	
	/***************************************************************************
	 * BMP出力
	 * 
	 * libjpeg-turboに依存している場合だけ実装
	 * BMPをJPEG形式に圧縮率90で変換し、そのJPEGを読み込む。
	 */
	version (Have_jpeg_turbo)
	immutable(ubyte)[] _exportBmpBaseImage() const @trusted
	{
		import libjpeg.turbojpeg;
		auto tjInstance = tjInitDecompress();
		scope (exit)
			tjDestroy(tjInstance);
		
		int width, height, jpegSubsamp;
		enforce(tjDecompressHeader2(tjInstance, cast(ubyte*)_image.ptr, cast(uint)_image.length,
			&width, &height, &jpegSubsamp) >= 0, "Failed to export JPEG");
		
		auto bmp = createBitmap(BmpSize(width, height), 8, 3);
		enforce(tjDecompress2(tjInstance, cast(ubyte*)_image.ptr, cast(uint)_image.length, bmp.dib.ptr,
			width, 0, height, TJPF.TJPF_BGR, TJFLAG_BOTTOMUP) >= 0, "Failed to decompress JPEG");
		
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
	 * ArkImg primitives
	 */
	void load(in ubyte[] binary) @safe
	{
		_importJpeg(binary);
	}
	/// ditto
	immutable(ubyte)[] save() const @safe
	{
		return _exportJpeg();
	}
	/// ditto
	void baseImage(in ubyte[] binary, string mimeType = null) @safe
	{
		if (mimeType is null || mimeType == "image/jpeg")
		{
			_importJpeg(binary, false);
		}
		else
		{
			version (Have_jpeg_turbo)
				if (mimeType == "image/bmp")
					return _importBmpBaseImage(binary);
			enforce("Unsupported image type.");
		}
	}
	/// ditto
	immutable(ubyte)[] baseImage(string mimeType = null) @safe
	{
		if (mimeType is null || mimeType == "image/jpeg")
		{
			return _exportJpeg();
		}
		else
		{
			version (Have_jpeg_turbo)
				if (mimeType == "image/bmp")
					return _exportBmpBaseImage();
			enforce("Unsupported image type.");
			assert(0);
		}
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
	
	auto img1 = new ArkJpeg(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.jpg")), commonKey, iv);
	img1.addSecretItem("TESTTESTTEST".representation);
	img1.sign(prvKey);
	std.file.write(testdir.buildPath("test-out.jpg"), img1.save);
	
	auto img2 = new ArkJpeg(cast(immutable(ubyte)[])std.file.read(testdir.buildPath("test-out.jpg")), commonKey, iv);
	assert(img2.getSecretItemCount() == 1);
	assert(img2.getDecryptedItem(0) == "TESTTESTTEST".representation);
	assert(img2.hasSign());
	assert(img2.verify(pubKey));
}
