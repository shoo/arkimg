/*******************************************************************************
 * BMP拡張
 * 
 * ビットマップ画像の基礎的な利用のためのAPIとArkBmpクラスを定義します。
 * - `Bitmap`: ビットマップを取り扱うためのデータクラス。
 * - `createBitmap`: Bitmap を適切に初期化します。
 * - `ArkBmp`: ArkImgのBMP用クラス。
 */
module arkimg.bmp;

import arkimg._internal.base;
import arkimg._internal.refcnt;
import arkimg._internal.crypto;
import arkimg._internal.misc;

/*******************************************************************************
 * 
 */
struct BmpSize
{
	///
	int width;
	///
	int height;
}

/*******************************************************************************
 * ビットマップフォーマットのファイルヘッダ
 */
struct BitmapFileHeader
{
align (1):
	union
	{
	align (1):
		struct
		{
		align (1):
			///
			ubyte typeH = 0x42;
			///
			ubyte typeL = 0x4d;
		}
		/***********************************************************************
		 * "BM"
		 */
		ushort type;
	}
	/***************************************************************************
	 * ファイルサイズ
	 * 
	 * 要変更
	 */
	uint size = 0;
	/***************************************************************************
	 * 予約
	 * 
	 * 常に0
	 */
	ushort reserved1 = 0;
	/***************************************************************************
	 * 予約
	 * 
	 * 常に0
	 */
	ushort reserved2 = 0;
	/***************************************************************************
	 * データの開始位置のオフセット
	 * 
	 * BitmapInformationHeader以外であれば要変更
	 * BitmapFileHeader.sizeof + BitmapInformationHeader.sizeof
	 */
	uint offset = 54;
}
static assert(BitmapFileHeader.sizeof == 14);


/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダの中身
 */
mixin template BitmapCoreHeaderImpl()
{
	/***************************************************************************
	 * 画像の横幅
	 * 
	 * 要変更
	 */
	short width = 0;
	/***************************************************************************
	 * 画像の縦幅
	 * 
	 * 要変更
	 */
	short height = 0;
	/***************************************************************************
	 * プレーン数
	 * 
	 * 常に1
	 */
	short planes = 1;
	/***************************************************************************
	 * 1ピクセル当たりのビット数
	 * 
	 * 24bit以外であれば要変更
	 */
	short bitCount = 24;
}

/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダの中身
 */
mixin template BitmapInformationHeaderImpl()
{
	/***************************************************************************
	 * 画像の横幅
	 * 
	 * 要変更
	 */
	int width = 0;
	/***************************************************************************
	 * 画像の縦幅
	 * 
	 * 要変更
	 */
	int height = 0;
	/***************************************************************************
	 * プレーン数
	 * 
	 * 常に1
	 */
	ushort planes = 1;
	/***************************************************************************
	 * 1ピクセル当たりのビット数
	 * 
	 * 32bit以外であれば要変更
	 */
	ushort bitCount = 32;
	/***************************************************************************
	 * 圧縮
	 * 
	 * 0であれば無圧縮
	 * それ以外であれば要変更
	 */
	uint compression = 0;
	/***************************************************************************
	 * 画像のバイトサイズ
	 * 
	 * 要変更
	 */
	uint sizeImage = 0;
	/***************************************************************************
	 * 横方向解像度[pixel/m]
	 * 
	 * 96dpiで3780
	 */
	int xPixPerMeter = 3780;
	/***************************************************************************
	 * 縦方向解像度[pixel/m]
	 * 
	 * 96dpiで3780
	 */
	int yPixPerMeter = 3780;
	/***************************************************************************
	 * 色パレット数
	 * 
	 * パレットを使用する場合は要変更
	 */
	uint clrUsed = 0;
	/***************************************************************************
	 * 重要色数
	 */
	uint cirImportant = 0;
}


/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダ
 */
mixin template BitmapInformationHeaderV5Impl()
{
align (1):
	///
	mixin BitmapInformationHeaderImpl;
	/***************************************************************************
	 * 赤マスク
	 */
	uint         redMask = 0;
	/***************************************************************************
	 * 緑マスク
	 */
	uint         greenMask = 0;
	/***************************************************************************
	 * 青マスク
	 */
	uint         blueMask = 0;
	/***************************************************************************
	 * アルファマスク
	 */
	uint         alphaMask = 0;
	/***************************************************************************
	 * カラースペースタイプ
	 */
	uint         csType = 0;
	/***************************************************************************
	 * XYZ
	 */
	struct CieXyzTriple
	{
	align (1):
		struct CieXyz
		{
		align (1):
			///
			int x = 0;
			///
			int y = 0;
			///
			int z = 0;
		}
		///
		CieXyz red;
		///
		CieXyz green;
		///
		CieXyz blue;
	}
	/// ditto
	CieXyzTriple endpoints;
	/***************************************************************************
	 * 赤ガンマ値
	 */
	uint         gammaRed = 0;
	/***************************************************************************
	 * 緑ガンマ値
	 */
	uint         gammaGreen = 0;
	/***************************************************************************
	 * 青ガンマ値
	 */
	uint         gammaBlue = 0;
	/***************************************************************************
	 * 展開意図
	 */
	uint         intent = 0;
	/***************************************************************************
	 * プロファイルデータ
	 */
	uint         profileData = 0;
	/***************************************************************************
	 * プロファイルサイズ
	 */
	uint         profileSize = 0;
	/***************************************************************************
	 * 予約
	 */
	uint         reserved = 0;
}




/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダ(V1)
 */
struct BitmapCoreHeader
{
align (1):
	/***************************************************************************
	 * この構造体のサイズ
	 * 
	 * 常に40
	 */
	uint size = BitmapCoreHeader.sizeof;
	///
	mixin BitmapCoreHeaderImpl;
}
static assert(BitmapCoreHeader.sizeof == 12);


/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダ(V1)
 */
struct BitmapInformationHeader
{
align (1):
	/***************************************************************************
	 * この構造体のサイズ
	 * 
	 * 常に40
	 */
	uint size = BitmapInformationHeader.sizeof;
	///
	mixin BitmapInformationHeaderImpl;
}
static assert(BitmapInformationHeader.sizeof == 40);


/*******************************************************************************
 * ビットマップフォーマットの情報ヘッダ(V5)
 */
struct BitmapInformationHeaderV5
{
align (1):
	/***************************************************************************
	 * この構造体のサイズ
	 * 
	 * 常に124
	 */
	uint size = BitmapInformationHeaderV5.sizeof;
	
	///
	mixin BitmapInformationHeaderV5Impl;
}
static assert(BitmapInformationHeaderV5.sizeof == 124);

/*******************************************************************************
 * ビットマップファイルの構造
 * 
 * 必ずメモリ上にビット列を含めた十分なサイズを設けること。
 * Example:
 * -----------------------------------------------------------------------------
 * auto bmp = cast(BmpImage*)new ubyte[bmpsz];
 * -----------------------------------------------------------------------------
 * 等とすること。
 */
struct BmpImage
{
package(arkimg):
	struct ImageHeaderData
	{
	align (1):
		///
		BitmapFileHeader file;
		union
		{
			///
			BitmapCoreHeader coreInfo;
			///
			BitmapInformationHeader info;
			///
			BitmapInformationHeaderV5 infoV5;
		}
		// infoとinfoV5は、infoによってアクセス可能
		static foreach (m; __traits(allMembers, BitmapInformationHeader))
		{
			static assert(__traits(getMember, info, m).offsetof == __traits(getMember, infoV5, m).offsetof);
			static assert(__traits(getMember, info, m).sizeof   == __traits(getMember, infoV5, m).sizeof);
			static assert(is(typeof(__traits(getMember, info, m)) == typeof(__traits(getMember, infoV5, m))));
		}
	}
	mixin CountedImpl!ImageHeaderData counted;
	
	alias _imgData = counted.buffer;
	alias _header  = counted.data;
public:
	
	
	/***************************************************************************
	 * ファイルヘッダ
	 */
	ref inout(BitmapFileHeader) fileHeader() @system @nogc pure nothrow inout @property
	{
		return _header.file;
	}
	
	/***************************************************************************
	 * ファイル全体のバッファ
	 */
	inout(ubyte)[] fileBuffer() @system @nogc pure nothrow inout @property
	in (_imgData.length >= ImageHeaderData.sizeof)
	{
		return _imgData;
	}
	
	/***************************************************************************
	 * 情報ヘッダーサイズ
	 */
	size_t infoSize() @system @nogc pure nothrow inout @property
	{
		return _header.info.size;
	}
	
	/***************************************************************************
	 * 情報ヘッダー
	 */
	ref inout(BitmapInformationHeader) info() @system @nogc pure nothrow inout @property
	in (infoSize == BitmapInformationHeader.sizeof
	 || infoSize == BitmapInformationHeaderV5.sizeof)
	{
		return _header.info;
	}
	
	/***************************************************************************
	 * Coreヘッダー
	 */
	ref inout(BitmapCoreHeader) coreInfo() @system @nogc pure nothrow inout @property
	in (infoSize == BitmapCoreHeader.sizeof)
	{
		return _header.coreInfo;
	}
	
	/***************************************************************************
	 * V5情報ヘッダー
	 */
	ref inout(BitmapInformationHeaderV5) infoV5() @system @nogc pure nothrow inout @property
	in (_header.infoV5.size == BitmapInformationHeaderV5.sizeof)
	{
		return _header.infoV5;
	}
	
	/***************************************************************************
	 * 画像のバッファサイズ
	 */
	size_t imageBufferSize() @nogc pure nothrow const @property
	{
		if (infoSize == BitmapCoreHeader.sizeof)
		{
			immutable widthStep = ((ulong(coreInfo.bitCount) * coreInfo.width + 32 - 1) / 32) * 4;
			return cast(size_t)(ulong(coreInfo.height) * widthStep);
		}
		return info.sizeImage;
	}
	
	/***************************************************************************
	 * 画像のサイズ
	 */
	BmpSize size() @nogc pure nothrow const @property
	{
		if (infoSize == BitmapCoreHeader.sizeof)
			return BmpSize(coreInfo.width, coreInfo.height);
		return BmpSize(info.width, info.height);
	}
	
	/***************************************************************************
	 * 画像のチャンネル数
	 */
	uint channels() @nogc pure nothrow const @property
	{
		if (infoSize == BitmapCoreHeader.sizeof)
			return coreInfo.bitCount / 8;
		return info.bitCount / 8;
	}
	
	/***************************************************************************
	 * 画像のストライド(一行のバイト数)
	 */
	uint stride() @nogc pure nothrow const @property
	{
		if (_header.info.size == BitmapCoreHeader.sizeof)
			return cast(uint)((_header.coreInfo.bitCount * _header.coreInfo.width + 32 - 1) / 32) * 4;
		return cast(uint)((_header.info.bitCount * _header.info.width + 32 - 1) / 32) * 4;
	}
	
	/***************************************************************************
	 * パレットのバッファ
	 */
	inout(uint)[] palette() @system @nogc pure nothrow inout @property
	in (_imgData.length >= fileHeader.offset + info.sizeImage)
	{
		auto ptr = cast(inout uint*)&_imgData[fileHeader.sizeof + info.size];
		return ptr[0..info.clrUsed];
	}
	
	/***************************************************************************
	 * 画像のバッファ
	 */
	inout(ubyte)[] dib() @system @nogc pure nothrow inout @property
	{
		return _imgData[fileHeader.offset .. fileHeader.offset + imageBufferSize];
	}
	
	/***************************************************************************
	 * 画像の行バッファ
	 * 
	 * yは画像の下端(0)から上端へ向かって正方向に進む。
	 */
	inout(ubyte)[] row(size_t y) @system @nogc pure nothrow inout @property
	{
		immutable BmpSize bmpsize = size;
		immutable size_t bitCount = _header.info.size == BitmapCoreHeader.sizeof
			? _header.coreInfo.bitCount : _header.info.bitCount;
		immutable widthStep = ((bitCount * bmpsize.width + 32 - 1) / 32) * 4;
		immutable r = (bmpsize.height < 0 ? (bmpsize.height - y - 1) : y);
		immutable st = r * widthStep;
		immutable ed = (r + 1) * widthStep;
		return dib[st..ed];
	}
	
	/***************************************************************************
	 * 画像の上下逆転
	 * 
	 * 
	 */
	void vflip() @system @nogc pure nothrow
	{
		import core.stdc.stdlib;
		immutable BmpSize bmpsize = size;
		immutable int w = bmpsize.width;
		immutable int h = bmpsize.height < 0 ? -bmpsize.height : bmpsize.height;
		immutable size_t bitCount = _header.info.size == BitmapCoreHeader.sizeof
			? _header.coreInfo.bitCount : _header.info.bitCount;
		immutable widthStep = ((bitCount * w + 32 - 1) / 32) * 4;
		
		import arkimg._internal.misc: assumePure;
		ubyte* buf = cast(ubyte*)assumePure(&malloc)(widthStep);
		scope (exit)
			assumePure(&free)(buf);
		auto bufRow = buf[0..widthStep];
		auto bufDib = dib;
		foreach (r; 0..h/2)
		{
			immutable st1 = r * widthStep;
			immutable ed1 = st1 + widthStep;
			immutable st2 = (h - r - 1) * widthStep;
			immutable ed2 = st2 + widthStep;
			bufRow[] = bufDib[st1..ed1];
			bufDib[st1..ed1] = bufDib[st2..ed2];
			bufDib[st2..ed2] = bufRow[];
		}
		if (infoSize == BitmapCoreHeader.sizeof)
			coreInfo.height = cast(short)-coreInfo.height;
		else
			info.height = -info.height;
	}
	
	/***************************************************************************
	 * 初期化
	 */
	void initialize(size_t fileHeaderSize, size_t infoHeaderSize, ushort colorPalleteCnt, BmpSize size,
		uint dep = 8, uint channels = 4) @trusted pure @nogc
	{
		import core.stdc.stdlib;
		import std.algorithm;
		
		ImageHeaderData tmp;
		
		immutable dpp  = cast(ushort)(dep * channels);
		uint widthStep = ((dpp * size.width + dpp - 1) / 32) * 4;
		uint imgSize   = widthStep*abs(size.height);
		
		auto headSize = fileHeaderSize + infoHeaderSize;
		auto newSize = headSize + colorPalleteCnt*4 + imgSize;
		
		tmp.file.size      = cast(uint)newSize;
		tmp.file.offset    = cast(uint)(headSize + colorPalleteCnt*4);
		tmp.info.size      = cast(uint)infoHeaderSize;
		tmp.info.width     = size.width;
		tmp.info.height    = size.height;
		tmp.info.bitCount  = dpp;
		tmp.info.clrUsed   = colorPalleteCnt;
		tmp.info.sizeImage = imgSize;
		
		counted.initializeCountedInstance(newSize);
		auto initBuf = cast(ubyte*)&tmp;
		buffer[0..headSize] = initBuf[0..headSize];
	}
	
	/// ditto
	void initialize(BmpSize size, uint dep = 8, uint channels = 4) @safe pure @nogc
	{
		initialize(BitmapFileHeader.sizeof,
			channels == 4 ? BitmapInformationHeaderV5.sizeof : BitmapInformationHeader.sizeof,
			0, size, dep, channels);
	}
	
	/// ditto
	void initialize(ubyte[] fileBuffer) @trusted pure @nogc
	{
		counted.initializeCountedInstance(fileBuffer);
	}
	
	///
	int addRef()()
	{
		 return counted.addRef();
	}
	///
	int release()() @trusted @nogc
	{
		return (() @trusted => cast(int delegate() @nogc @safe)&counted.release)()();
	}
}

static assert(isCountedData!BmpImage);
alias Bitmap = RefCounted!BmpImage;

/*******************************************************************************
 * 
 */
Bitmap createBitmap(BmpSize size, uint dep = 8, uint channels = 4) pure @nogc
{
	BmpImage ret;
	ret.initialize(size, dep, channels);
	return attachRefCounted!BmpImage(ret);
}

/*******************************************************************************
 * 
 */
inout(Bitmap) createBitmap(inout(ubyte)[] fileBuffer = null) pure @nogc
{
	BmpImage ret;
	ret.initialize(cast(ubyte[])fileBuffer);
	return cast(inout)attachRefCounted!BmpImage(ret);
}


/*******************************************************************************
 * ArkImg for Bitmap
 */
class ArkBmp: ArkImgBase
{
private:
	//--------------------------------------------------------------------------
	// TYPES
	//--------------------------------------------------------------------------
	enum ubyte[4] _chunkFourCcEMDT   = ['E', 'M', 'D', 'T'];
	enum ubyte[4] _chunkFourCcEDAT   = ['E', 'D', 'A', 'T'];
	struct CustomChunkHeader
	{
		ubyte[4] signature;
		uint size;
	}
	struct CustomChunkData
	{
		CustomChunkHeader header;
		immutable(ubyte)[] data;
	}
	
	//--------------------------------------------------------------------------
	// DATA
	//--------------------------------------------------------------------------
	Bitmap _bmp;
	
	//--------------------------------------------------------------------------
	// PRIVATE FUNCIONS
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * BMP画像入力
	 */
	void _importBmp(in ubyte[] binary) @safe
	{
		import std.exception;
		(() @trusted => _bmp = createBitmap(binary.dup))();
		enforce((() @trusted => _bmp.fileHeader.typeH == 0x42 && _bmp.fileHeader.typeL == 0x4d)());
		auto bmpsize = (() @trusted => _bmp.fileHeader.offset + _bmp.imageBufferSize)();
		enforce(bmpsize <= binary.length);
		auto src = binary[bmpsize..$];
		while (src.length > 0)
		{
			enforce(src.length >= CustomChunkHeader.sizeof, "Unsupported bmp format.");
			CustomChunkData dat;
			dat.header = (() @trusted => *cast(CustomChunkHeader*)src.ptr)();
			src = src[CustomChunkHeader.sizeof..$];
			enforce(src.length >= dat.header.size, "Unsupported bmp format.");
			dat.data = src[0..dat.header.size].idup;
			src = src[dat.header.size..$];
			if (dat.header.signature == _chunkFourCcEDAT)
			{
				// SecretItem
				_secretItems ~= SecretItem(EncryptedBinary(dat.data));
			}
			else if (dat.header.signature == _chunkFourCcEMDT)
			{
				// Metadata
				(() @trusted => _metadata = EncryptedBinary(dat.data))();
			}
			else
			{
				// 何もしない
			}
		}
	}
	
	/***************************************************************************
	 * BMP画像出力
	 */
	immutable(ubyte)[] _exportBmp() const @safe
	{
		import std.algorithm: map, sum;
		import std.array: appender;
		// 秘密情報のチャンクをsize算出のために事前計算
		auto app = appender!(immutable(ubyte)[]);
		
		CustomChunkData[] customChunks;
		if (auto md = _getEncryptedMetadata())
		{
			CustomChunkData chunk;
			chunk.header.signature[] = _chunkFourCcEMDT[];
			chunk.header.size = cast(uint)md.length;
			chunk.data = md;
			customChunks ~= chunk;
		}
		foreach (item; _getEncryptedItems())
		{
			CustomChunkData chunk;
			chunk.header.signature[] = _chunkFourCcEDAT[];
			chunk.header.size = cast(uint)item.length;
			chunk.data = item;
			customChunks ~= chunk;
		}
		auto bmpsize = (() @trusted => _bmp.fileHeader.offset + _bmp.imageBufferSize)();
		auto chunksize = customChunks.map!(chunk => CustomChunkHeader.sizeof + chunk.data.length).sum();
		app.reserve(bmpsize + chunksize);
		BitmapFileHeader hdr = (() @trusted => _bmp.fileHeader)();
		hdr.size = cast(uint)(bmpsize + chunksize);
		app ~= (() @trusted => (cast(ubyte*)&hdr)[0..BitmapFileHeader.sizeof])();
		app ~= (() @trusted => _bmp.fileBuffer[BitmapFileHeader.sizeof..bmpsize])();
		foreach (chunk; customChunks)
		{
			app ~= (() @trusted => (cast(ubyte*)&chunk.header)[0..CustomChunkHeader.sizeof])();
			app ~= chunk.data;
		}
		return app.data;
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
		_importBmp(binary);
	}
	/// ditto
	immutable(ubyte)[] save() const
	{
		return _exportBmp();
	}
	/// ditto
	void baseImage(in ubyte[] binary, string mimeType = null)
	{
		import std.exception;
		if (mimeType is null || mimeType == "image/bmp")
		{
			_importBmp(binary);
		}
		else
		{
			// TODO
			enforce("Unsupported image type.");
		}
	}
	/// ditto
	immutable(ubyte)[] baseImage(string mimeType = null)
	{
		import std.exception;
		if (mimeType is null || mimeType == "image/bmp")
		{
			return _exportBmp();
		}
		else
		{
			// TODO
			enforce("Unsupported image type.");
			assert(0);
		}
	}
}

@system unittest
{
	import std;
	auto testdir = buildPath("tests", randomUUID.toString());
	enum resdir  = buildPath("tests", ".resources");
	mkdirRecurse(testdir);
	scope (exit)
		rmdirRecurse(testdir);
	
	auto commonKey = createCommonKey();
	auto iv = createRandomIV();
	auto prvKey = createPrivateKeyEd25519();
	auto pubKey = createPublicKeyEd25519(prvKey);
	auto img1 = new ArkBmp(cast(immutable(ubyte)[])std.file.read(resdir.buildPath("d-man.bmp")), commonKey, iv);
	img1.addSecretItem("TESTTESTTEST".representation);
	img1.sign(prvKey);
	std.file.write(testdir.buildPath("test-out.bmp"), img1.save);
	
	auto img2 = new ArkBmp(cast(immutable(ubyte)[])std.file.read(testdir.buildPath("test-out.bmp")), commonKey, iv);
	assert(img2.getSecretItemCount() == 1);
	assert(img2.getDecryptedItem(0) == "TESTTESTTEST".representation);
	assert(img2.hasSign());
	assert(img2.verify(pubKey));
}
