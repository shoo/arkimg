module arkimg.utils;

import arkimg.api;
private import crypto = arkimg._internal.crypto;


/*******************************************************************************
 * ファイル名からMIMEタイプの取得 / Get MIME type from filename
 */
string mimeType(string filename) @safe
{
	import std.path, std.string, std.algorithm, std.array, std.range;
	struct ExtMap
	{
		string ext;
		string mime;
	}
	static immutable ExtMap[] maplut = [
		// 画像
		ExtMap("png", "image/png"),
		ExtMap("jpg", "image/jpeg"),
		ExtMap("webp", "image/webp"),
		ExtMap("bmp", "image/bmp"),
		ExtMap("avif", "image/avif"),
		ExtMap("tif", "image/tiff"),
		ExtMap("tiff", "image/tiff"),
		ExtMap("svg", "image/svg+xml"),
		ExtMap("gif", "image/gif"),
		ExtMap("ico", "image/vnd.microsoft.icon"),
		// 圧縮ファイル
		ExtMap("zip", "application/zip"),
		ExtMap("tar", "application/x-tar"),
		ExtMap("bz", "application/x-bzip"),
		ExtMap("bz2", "application/x-bzip2"),
		ExtMap("gz", "application/gzip"),
		ExtMap("7z", "application/x-7z-compressed"),
		ExtMap("rar", "application/vnd.rar"),
		ExtMap("pdf", "application/pdf"),
		// テキスト
		ExtMap("txt", "text/plain"),
		ExtMap("html", "text/html"),
		ExtMap("htm", "text/html"),
		ExtMap("xml", "text/xml"),
		ExtMap("css", "text/css"),
		ExtMap("js", "text/javascript"),
		ExtMap("jsx", "text/javascript"),
		ExtMap("json", "application/json"),
		ExtMap("c", "text/x-csrc"),
		ExtMap("h", "text/x-chdr"),
		ExtMap("cpp", "text/x-c++src"),
		ExtMap("hpp", "text/x-c++hdr"),
		ExtMap("py", "text/x-python"),
		ExtMap("d", "text/x-dsrc"),
		ExtMap("di", "text/x-dsrc"),
		ExtMap("rs", "text/x-rustsrc"),
		ExtMap("ts", "text/typescript"),
		ExtMap("tsx", "text/typescript"),
		ExtMap("sh", "application/x-shellscript"),
		ExtMap("bat", "application/x-bat"),
		ExtMap("ps1", "application/x-powershell"),
		ExtMap("md", "text/markdown"),
		ExtMap("markdown", "text/markdown"),
		ExtMap("yml", "text/yaml"),
		ExtMap("yaml", "text/yaml"),
		ExtMap("toml", "text/toml"),
		ExtMap("csv", "text/csv"),
		ExtMap("tsv", "text/tab-separated-values"),
		// 音声
		ExtMap("aac", "audio/aac"),
		ExtMap("mp3", "audio/mpeg"),
		ExtMap("ogg", "audio/ogg"),
		ExtMap("oga", "audio/ogg"),
		ExtMap("mka", "audio/x-matroska"),
		ExtMap("flac", "audio/x-flac"),
		ExtMap("wav", "audio/x-wav"),
		// 動画
		ExtMap("avi", "video/x-msvideo"),
		ExtMap("ogv", "video/ogg"),
		ExtMap("mp4", "video/mp4"),
		ExtMap("mpg", "video/mpeg"),
		ExtMap("mpeg", "video/mpeg"),
		ExtMap("webm", "video/webm"),
		//ExtMap("ts", "video/mp2t"), // TypeScript is prioritized
		ExtMap("mkv", "video/x-matroska"),
		// その他
		ExtMap("cbor", "application/cbor"),
		ExtMap("pt", "application/x-pytorch"),
		ExtMap("safetensors", "application/x-safetensors"),
		ExtMap("gguf", "application/x-gguf"),
		ExtMap("onnx", "application/x-onnx"),
		ExtMap("ppt", "application/vnd.ms-powerpoint"),
		ExtMap("pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
		ExtMap("doc", "application/msword"),
		ExtMap("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
		ExtMap("xls", "application/vnd.ms-excel"),
		ExtMap("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
	].sort!((a, b) => a.ext < b.ext).array.idup;
	static immutable extmap = maplut.map!(a => a.ext).array;
	static immutable mimemap = maplut.map!(a => a.mime).array;
	auto fext = filename.extension.toLower();
	if (fext.length == 0 || fext[0] != '.')
		return "application/octet-stream";
	auto found = find(extmap.assumeSorted(), fext[1..$]);
	if (found.empty)
		return "application/octet-stream";
	return mimemap[$ - found.length];
}

@safe unittest
{
	struct Dat
	{
		string file;
		string mime;
	}
	foreach (dat; [
		Dat("test.png",         "image/png"),
		Dat("test.jpg",         "image/jpeg"),
		Dat("test.webp",        "image/webp"),
		Dat("test.bmp",         "image/bmp"),
		Dat("test.avif",        "image/avif"),
		Dat("test.tif",         "image/tiff"),
		Dat("test.tiff",        "image/tiff"),
		Dat("test.svg",         "image/svg+xml"),
		Dat("test.gif",         "image/gif"),
		Dat("test.ico",         "image/vnd.microsoft.icon"),
		Dat("test.zip",         "application/zip"),
		Dat("test.tar",         "application/x-tar"),
		Dat("test.bz",          "application/x-bzip"),
		Dat("test.bz2",         "application/x-bzip2"),
		Dat("test.gz",          "application/gzip"),
		Dat("test.7z",          "application/x-7z-compressed"),
		Dat("test.rar",         "application/vnd.rar"),
		Dat("test.pdf",         "application/pdf"),
		Dat("test.txt",         "text/plain"),
		Dat("test.html",        "text/html"),
		Dat("test.htm",         "text/html"),
		Dat("test.xml",         "text/xml"),
		Dat("test.css",         "text/css"),
		Dat("test.js",          "text/javascript"),
		Dat("test.json",        "application/json"),
		Dat("test.cbor",        "application/cbor"),
		Dat("test.c",           "text/x-csrc"),
		Dat("test.h",           "text/x-chdr"),
		Dat("test.cpp",         "text/x-c++src"),
		Dat("test.hpp",         "text/x-c++hdr"),
		Dat("test.py",          "text/x-python"),
		Dat("test.d",           "text/x-dsrc"),
		Dat("test.di",          "text/x-dsrc"),
		Dat("test.rs",          "text/x-rustsrc"),
		Dat("test.ts",          "text/typescript"),
		Dat("test.sh",          "application/x-shellscript"),
		Dat("test.bat",         "application/x-bat"),
		Dat("test.ps1",         "application/x-powershell"),
		Dat("test.aac",         "audio/aac"),
		Dat("test.mp3",         "audio/mpeg"),
		Dat("test.ogg",         "audio/ogg"),
		Dat("test.oga",         "audio/ogg"),
		Dat("test.mka",         "audio/x-matroska"),
		Dat("test.flac",        "audio/x-flac"),
		Dat("test.wav",         "audio/x-wav"),
		Dat("test.avi",         "video/x-msvideo"),
		Dat("test.ogv",         "video/ogg"),
		Dat("test.mp4",         "video/mp4"),
		Dat("test.mpg",         "video/mpeg"),
		Dat("test.mpeg",        "video/mpeg"),
		Dat("test.webm",        "video/webm"),
		Dat("test.mkv",         "video/x-matroska"),
		Dat("test.pt",          "application/x-pytorch"),
		Dat("test.safetensors", "application/x-safetensors"),
		Dat("test.gguf",        "application/x-gguf"),
		Dat("test.onnx",        "application/x-onnx"),
		Dat("test.ppt",         "application/vnd.ms-powerpoint"),
		Dat("test.pptx",        "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
		Dat("test.doc",         "application/msword"),
		Dat("test.docx",        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
		Dat("test.xls",         "application/vnd.ms-excel"),
		Dat("test.xlsx",        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
		Dat("xxx",              "application/octet-stream"),
		Dat("xxx.aaa",          "application/octet-stream"),
	])
	{
		assert(dat.file.mimeType == dat.mime, dat.file ~ " and " ~ dat.file.mimeType ~ " is unmatched.");
	}
}

/*******************************************************************************
 * 共通鍵生成 / Generation of AES common key
 */
immutable(ubyte)[] createCommonKey(RandomGen = Random)(size_t keySize, RandomGen rng)
{
	return crypto.createCommonKey(keySize, rng);
}
/// ditto
immutable(ubyte)[] createCommonKey(size_t keySize = 16)
{
	import std.random: rndGen;
	return createCommonKey(keySize, rndGen);
}

/*******************************************************************************
 * 初期ベクトル / Generation of AES IV
 * 
 * 参考:
 *      通常は自動で作成して暗号データ内に埋め込むため、使用しません。
 *      以下のような用途を想定しています。
 *      - IVを秘匿したい(暗号データ毎に個別にIVを生成が推奨)
 *      - IVを共通化したい(セキュリティ上非推奨)
 *      - ファイルサイズを(16バイトだけ)減らしたい
 */
immutable(ubyte)[] createRandomIV(RandomGen = Random)(RandomGen rng)
{
	return crypto.createRandomIV(rng);
}
/// ditto
immutable(ubyte)[] createRandomIV()
{
	import std.random: rndGen;
	return createRandomIV(rndGen);
}

/*******************************************************************************
 * 秘密鍵作成(DER形式) / Generation of Ed25519 private key (DER format)
 */
immutable(ubyte)[] createPrivateKey()
{
	return crypto.createPrivateKeyEd25519();
}

/*******************************************************************************
 * 公開鍵作成(DER形式) / Generation of Ed25519 public key (DER format)
 */
immutable(ubyte)[] createPublicKey(in ubyte[] prvKey)
{
	return crypto.createPublicKeyEd25519(prvKey);
}

/*******************************************************************************
 * 鍵形式変換 / Convertion of Ed25519 public key format
 */
string convertPrivateKeyToPEM(in ubyte[] prvKey)
{
	return crypto.convertEd25519PrivateKeyDERToPEM(prvKey);
}
/// ditto
immutable(ubyte)[] convertPrivateKeyToDER(string prvKey)
{
	return crypto.convertEd25519PrivateKeyPEMToDER(prvKey);
}
/// ditto
immutable(ubyte)[] convertPrivateKeyToRaw(in ubyte[] prvKey)
{
	return crypto.convertEd25519PrivateKeyDERToRaw(prvKey);
}
/// ditto
immutable(ubyte)[] convertPrivateKeyToDER(immutable(ubyte)[] prvKey)
{
	return crypto.convertEd25519PrivateKeyRawToDER(prvKey);
}
/// ditto
string convertPublicKeyToPEM(in ubyte[] pubKey)
{
	return crypto.convertEd25519PublicKeyDERToPEM(pubKey);
}
/// ditto
immutable(ubyte)[] convertPublicKeyToDER(string pubKey)
{
	return crypto.convertEd25519PublicKeyPEMToDER(pubKey);
}
/// ditto
immutable(ubyte)[] convertPublicKeyToRaw(immutable(ubyte)[] pubKey)
{
	return crypto.convertEd25519PublicKeyDERToRaw(pubKey);
}
/// ditto
immutable(ubyte)[] convertPublicKeyToDER(immutable(ubyte)[] pubKey)
{
	return crypto.convertEd25519PublicKeyRawToDER(pubKey);
}

/*******************************************************************************
 * 画像のロード / Load any image to ArkImg
 */
ArkImg loadImage(immutable(ubyte)[] binary, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)
{
	switch (mimeType)
	{
	case "image/bmp":
		import arkimg.bmp;
		return new ArkBmp(binary, commonKey, iv);
	case "image/png":
		import arkimg.png;
		return new ArkPng(binary, commonKey, iv);
	case "image/jpeg":
		import arkimg.jpg;
		return new ArkJpeg(binary, commonKey, iv);
	case "image/webp":
		import arkimg.webp;
		return new ArkWebp(binary, commonKey, iv);
	default:
		throw new Exception("Unsupported image.");
	}
}
/// ditto
ArkImg loadImage(string filename, in ubyte[] commonKey = null, in ubyte[] iv = null)
{
	import std.file, std.exception;
	auto mime = filename.mimeType.enforce("Unsupported image.");
	return loadImage(cast(immutable(ubyte)[])std.file.read(filename), mime, commonKey, iv);
}

/*******************************************************************************
 * 画像の保存 / Save ArkImg to image file
 */
immutable(ubyte)[] saveImage(ArkImg img, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)
{
	ArkImg retimg;
	switch (mimeType)
	{
	case "image/png":
		import arkimg.png;
		if (cast(ArkPng)img)
			break;
		retimg = new ArkPng;
		break;
	case "image/jpeg":
		import arkimg.jpg;
		if (cast(ArkJpeg)img)
			break;
		retimg = new ArkJpeg;
		break;
	case "image/bmp":
		import arkimg.bmp;
		if (cast(ArkBmp)img)
			break;
		retimg = new ArkBmp;
		break;
	case "image/webp":
		import arkimg.webp;
		if (cast(ArkWebp)img)
			break;
		retimg = new ArkWebp;
		break;
	default:
		throw new Exception("Unsupported image.");
	}
	if (!retimg)
	{
		img.setKey(commonKey, iv);
		return img.save();
	}
	retimg.setKey(commonKey, iv);
	retimg.baseImage(img.baseImage("image/bmp"), "image/bmp");
	foreach (idx; 0..img.getSecretItemCount())
		retimg.addSecretItem(img.getDecryptedItem(idx));
	retimg.metadata = img.metadata;
	return retimg.save();
}

/*******************************************************************************
 * メタデータのヘルパ構造体 / Metadata helper
 */
struct Metadata
{
private:
	import std.json;
	import std.datetime;
	JSONValue _jv;
public:
	/***************************************************************************
	 * 
	 */
	struct Item
	{
	private:
		JSONValue _jv;
	public:
		/***********************************************************************
		 * 
		 */
		this(JSONValue jv)
		{
			_jv = jv;
		}
		/***********************************************************************
		 * 
		 */
		ref inout(JSONValue) value() inout
		{
			return _jv;
		}
		/***********************************************************************
		 * 
		 */
		bool isInit() const
		{
			return _jv is JSONValue.init;
		}
		/***********************************************************************
		 * 
		 */
		string name() const
		{
			if (_jv.type != JSONType.object)
				return null;
			if (auto v = "name" in _jv)
			{
				if (v.type != JSONType.string)
					return null;
				return v.str;
			}
			return null;
		}
		/***********************************************************************
		 * 
		 */
		string mime() const
		{
			if (_jv.type != JSONType.object)
				return null;
			if (auto v = "mime" in _jv)
			{
				if (v.type != JSONType.string)
					return null;
				return v.str;
			}
			return null;
		}
		/***********************************************************************
		 * 
		 */
		immutable(ubyte)[] sign() const
		{
			import std.base64;
			if (_jv.type != JSONType.object)
				return null;
			if (auto v = "sign" in _jv)
			{
				if (v.type != JSONType.string)
					return null;
				return Base64URLNoPadding.decode(v.str);
			}
			return null;
		}
		/***********************************************************************
		 * 
		 */
		SysTime modified() const
		{
			if (_jv.type != JSONType.object)
				return SysTime.init;
			if (auto v = "modified" in _jv)
			{
				if (v.type != JSONType.string)
					return SysTime.init;
				return SysTime.fromISOExtString(v.str).toLocalTime();
			}
			return SysTime.init;
		}
		/***********************************************************************
		 * 
		 */
		string comment() const
		{
			if (_jv.type != JSONType.object)
				return null;
			if (auto v = "comment" in _jv)
			{
				if (v.type != JSONType.string)
					return null;
				return v.str;
			}
			return null;
		}
		/***********************************************************************
		 * 
		 */
		bool verify(in ubyte[] data, in ubyte[] pubKey) const
		{
			if (auto s = sign())
				return crypto.verifyEd25519(s, data, pubKey);
			return false;
		}
		/***********************************************************************
		 * 
		 */
		JSONValue extra() const
		{
			JSONValue ret;
			if (_jv.type != JSONType.object)
				return ret;
			foreach (k, v; _jv.object)
			{
				switch (k)
				{
				case "name":
				case "mime":
				case "sign":
				case "modified":
				case "comment":
					continue;
				default:
					ret[k] = v;
				}
			}
			return ret;
		}
	}
	/***************************************************************************
	 * 
	 */
	this(JSONValue jv)
	{
		_jv = jv;
	}
	/***************************************************************************
	 * 
	 */
	ref inout(JSONValue) value() inout
	{
		return _jv;
	}
	/***************************************************************************
	 * 
	 */
	bool isInit() const
	{
		return _jv is JSONValue.init;
	}
	/***************************************************************************
	 * 
	 */
	Item opIndex(size_t idx)
	{
		if (_jv.type != JSONType.object)
			return Item.init;
		if (auto jvItems = "items" in _jv)
		{
			if (jvItems.type != JSONType.array)
				return Item.init;
			if (idx >= jvItems.array.length)
				return Item.init;
			return Item(jvItems.array[idx]);
		}
		return Item.init;
	}
	/***************************************************************************
	 * 
	 */
	auto opSlice()
	{
		static struct Range
		{
		private:
			JSONValue* jv;
			size_t     idx;
		public:
			inout(Item) front() inout
			{
				return Item(jv.array[idx]);
			}
			void popFront()
			{
				++idx;
			}
			bool empty() const
			{
				return jv is null
					|| idx >= jv.array.length;
			}
		}
		if (auto items = "items" in _jv)
			return items.type == JSONType.array ? Range(items) : Range.init;
		return Range.init;
	}
	
}
