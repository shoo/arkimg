module arkimg.utils;

import arkimg.api;
private import crypto = arkimg._internal.crypto;


/*******************************************************************************
 * ファイル名からMIMEタイプの取得
 */
string mimeType(string filename)
{
	import std.path, std.string;
	switch (filename.extension.toLower)
	{
	// 画像
	case ".png":
		return "image/png";
	case ".jpg":
		return "image/jpeg";
	case ".webp":
		return "image/webp";
	case ".bmp":
		return "image/bmp";
	case ".avif":
		return "image/avif";
	case ".tif":
		return "image/tiff";
	case ".tiff":
		return "image/tiff";
	case ".svg":
		return "image/svg+xml";
	case ".gif":
		return "image/gif";
	case ".ico":
		return "image/vnd.microsoft.icon";
	// 圧縮ファイル
	case ".zip":
		return "application/zip";
	case ".tar":
		return "application/x-tar";
	case ".bz":
		return "application/x-bzip";
	case ".bz2":
		return "application/x-bzip2";
	case ".gz":
		return "application/gzip";
	case ".7z":
		return "application/x-7z-compressed";
	case ".rar":
		return "application/vnd.rar";
	case ".pdf":
		return "application/pdf";
	// テキスト
	case ".txt":
		return "text/plain";
	case ".html":
		return "text/html";
	case ".htm":
		return "text/html";
	case ".xml":
		return "text/xml";
	case ".css":
		return "text/css";
	case ".js":
		return "text/javascript";
	case ".json":
		return "application/json";
	case ".cbor":
		return "application/cbor";
	case ".c":
		return "text/x-csrc";
	case ".h":
		return "text/x-chdr";
	case ".cpp":
		return "text/x-c++src";
	case ".hpp":
		return "text/x-c++hdr";
	case ".py":
		return "text/x-python";
	case ".d":
		return "text/x-dsrc";
	case ".di":
		return "text/x-dsrc";
	case ".rs":
		return "text/x-rustsrc";
	case ".sh":
		return "application/x-shellscript";
	case ".bat":
		return "application/x-bat";
	case ".ps1":
		return "application/x-powershell";
	// 音声
	case ".aac":
		return "audio/aac";
	case ".mp3":
		return "audio/mpeg";
	case ".ogg":
		return "audio/ogg";
	case ".oga":
		return "audio/ogg";
	case ".mka":
		return "audio/x-matroska";
	case ".flac":
		return "audio/x-flac";
	case ".wav":
		return "audio/x-wav";
	// 動画
	case ".avi":
		return "video/x-msvideo";
	case ".ogv":
		return "video/ogg";
	case ".mp4":
		return "video/mp4";
	case ".mpg":
		return "video/mpeg";
	case ".mpeg":
		return "video/mpeg";
	case ".webm":
		return "video/webm";
	case ".ts":
		return "video/mp2t";
	case ".mkv":
		return "video/x-matroska";
	// その他
	case ".pt":
		return "application/x-pytorch";
	case ".safetensors":
		return "application/x-safetensors";
	case ".gguf":
		return "application/x-gguf";
	case ".onnx":
		return "application/x-onnx";
	case ".ppt":
		return "application/vnd.ms-powerpoint";
	case ".pptx":
		return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
	case ".doc":
		return "application/msword";
	case ".docx":
		return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
	case ".xls":
		return "application/vnd.ms-excel";
	case ".xlsx":
		return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
	default:
		return null;
	}
}


/*******************************************************************************
 * 共通鍵生成
 */
immutable(ubyte)[] createCommonKey(RandomGen = Random)(size_t keySize, RandomGen rng)
{
	return crypto.createCommonKey(keySize, rng);
}
/// ditto
immutable(ubyte)[] createCommonKey(size_t keySize = 32)
{
	return crypto.createCommonKey(keySize);
}

/*******************************************************************************
 * 初期ベクトル
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
	return crypto.createRandomIV();
}

/*******************************************************************************
 * 秘密鍵作成
 */
immutable(ubyte)[] createPrivateKey()
{
	return crypto.createPrivateKeyEd25519();
}

/*******************************************************************************
 * 公開鍵作成
 */
immutable(ubyte)[] createPublicKey(in ubyte[] prvKey)
{
	return crypto.createPublicKeyEd25519(prvKey);
}

/*******************************************************************************
 * 鍵形式変換
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
 * 画像のロード
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
 * 画像の保存
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
	retimg.baseImage = img.baseImage("image/bmp");
	foreach (idx; 0..img.getSecretItemCount())
		retimg.addSecretItem(img.getDecryptedItem(idx));
	retimg.metadata = img.metadata;
	return retimg.save();
}

/*******************************************************************************
 * 
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
