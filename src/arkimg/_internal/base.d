module arkimg._internal.base;

import arkimg.api;
import arkimg._internal.crypto;
import arkimg._internal.misc;
import std.sumtype;
import std.json;
import std.exception;

abstract class ArkImgBase: ArkImg
{
protected:
	//--------------------------------------------------------------------------
	// TYPES
	//--------------------------------------------------------------------------
	static struct EncryptedBinary
	{
		immutable(ubyte)[] data;
	}
	static struct DecryptedBinary
	{
		immutable(ubyte)[] data;
	}
	alias Metadata = SumType!(JSONValue, EncryptedBinary);
	alias SecretItem = SumType!(EncryptedBinary, DecryptedBinary);
	
	//--------------------------------------------------------------------------
	// DATA
	//--------------------------------------------------------------------------
	immutable(ubyte)[]   _image;
	SecretItem[]         _secretItems;
	immutable(ubyte)[]   _commonKey;
	immutable(ubyte)[]   _iv;
	Metadata             _metadata;
	
	//--------------------------------------------------------------------------
	// PROTECTED FUNCTION
	//--------------------------------------------------------------------------
	
	/***************************************************************************
	 * メタデータ取得
	 */
	immutable(ubyte)[] _getEncryptedMetadata() const @safe
	{
		import std.string: representation;
		return _metadata.match!(
			(JSONValue dat) => 
				dat is JSONValue.init || dat is JSONValue.emptyObject || dat is JSONValue.emptyArray
				? null : _enc(dat.toString(JSONOptions.doNotEscapeSlashes).representation),
			(EncryptedBinary dat) => dat.data);
	}
	/// ditto
	JSONValue _getDecryptedMetadata() const @safe
	{
		return _metadata.match!(
			(JSONValue dat) => dat,
			(EncryptedBinary dat)
			{
				auto bin = _dec(dat.data);
				if (bin.length == 0)
					return JSONValue.emptyObject;
				return parseJSON(cast(string)bin);
			});
	}
	/***************************************************************************
	 * 秘匿データ取得
	 */
	immutable(ubyte)[] _getDecryptedItem(SecretItem itm) const @safe
	{
		return itm.match!(
			(EncryptedBinary dat) => _dec(dat.data),
			(DecryptedBinary dat) => dat.data);
	}
	/// ditto
	immutable(ubyte)[] _getEncryptedItem(SecretItem itm) const @safe
	{
		return itm.match!(
			(EncryptedBinary dat) => dat.data,
			(DecryptedBinary dat) => _enc(dat.data));
	}
	/// ditto
	auto _getDecryptedItems() const @safe
	{
		import std.algorithm;
		return _secretItems.map!(itm => _getDecryptedItem(itm));
	}
	/// ditto
	auto _getEncryptedItems() const @safe
	{
		import std.algorithm;
		return _secretItems.map!(itm => _getEncryptedItem(itm));
	}
	
	/***************************************************************************
	 * 暗号化
	 */
	void _encryptAllItems() @trusted
	{
		foreach (ref dat; _secretItems)
			dat = dat.match!(
				(EncryptedBinary dat) => dat,
				(DecryptedBinary dat) => EncryptedBinary(_enc(dat.data)));
	}
private:
	immutable(ubyte)[] _enc(in ubyte[] dat) const @safe
	{
		if (_iv is null)
		{
			auto iv = createRandomIV();
			return iv ~ encryptAES(dat, _commonKey, iv);
		}
		else
		{
			return encryptAES(dat, _commonKey, _iv);
		}
	}
	immutable(ubyte)[] _dec(in ubyte[] dat) const @safe
	{
		if (_iv is null)
		{
			auto iv = dat[0..16];
			return decryptAES(dat[16..$], _commonKey, iv);
		}
		else
		{
			return decryptAES(dat, _commonKey, _iv);
		}
	}
public:
	/// ArkImg primitive
	override void setKey(in ubyte[] commonKey, in ubyte[] iv = null) @safe
	{
		_commonKey = commonKey.idup;
		_iv = iv is null ? null : iv.idup;
	}
	/// ditto
	override void sign(in ubyte[] prvKey) @safe
	in (_commonKey !is null)
	{
		import std.base64, std.range;
		import arkimg._internal.misc;
		// 暗号データに署名するので、すべてのデータを暗号化
		_encryptAllItems();
		
		auto md = metadata();
		scope (success)
			metadata = md;
		if (md.type != JSONType.object)
			md = JSONValue.emptyObject;
		
		auto items = &(md.reqa("items"));
		foreach (idx, dat; _getEncryptedItems.enumerate)
			reqo(*items, idx).req!string("sign").str = Base64URLNoPadding.encode(signEd25519(dat, prvKey));
	}
	/// ditto
	override bool verify(in ubyte[] pubKey) const @safe
	{
		import std.base64, std.range;
		auto md = metadata;
		if (md.type != JSONType.object)
			return false;
		auto items = "items" in md;
		if (items is null)
			return false;
		foreach (idx, dat; _getEncryptedItems.enumerate)
		{
			if (items.type != JSONType.array || idx >= (() @trusted => items.array)().length)
				return false;
			auto signJv = "sign" in (() @trusted => items.array)()[idx];
			if (signJv is null || signJv.type != JSONType.string || signJv.str.length == 0)
				return false;
			auto signBin = Base64URLNoPadding.decode(signJv.str);
			if (signBin.length == 0)
				return false;
			if (!verifyEd25519(signBin, dat, pubKey))
				return false;
		}
		return true;
	}
	/// ditto
	override bool hasSign() const @safe
	{
		import std.algorithm;
		auto md = metadata;
		if (md.type != JSONType.object)
			return false;
		auto items = "items" in md;
		if (items is null)
			return false;
		if (items.type != JSONType.array || (() @trusted => items.array)().length != _secretItems.length)
			return false;
		return (() @trusted => items.array)().all!(item => "sign" in item);
	}
	/// ditto
	override void metadata(in JSONValue metadata) @trusted
	{
		_metadata = metadata;
	}
	/// ditto
	override JSONValue metadata() const @safe
	{
		return _getDecryptedMetadata();
	}
	/// ditto
	override void addSecretItem(in ubyte[] binary,
		string name = null, string mimeType = null, in ubyte[] prvKey = null) @safe
	{
		import std.base64;
		immutable(ubyte)[] encBin;
		auto idx = _secretItems.length;
		if (prvKey !is null)
		{
			enforce(_commonKey !is null, "A common key must be preconfigured for signing");
			encBin = _enc(binary);
			_secretItems ~= SecretItem(EncryptedBinary(encBin));
		}
		else
		{
			_secretItems ~= SecretItem(DecryptedBinary(binary.idup));
		}
		if (name !is null || mimeType !is null || prvKey !is null)
		{
			auto md = metadata;
			scope (success)
				metadata = md;
			auto item = &(md.reqa("items").reqo(idx));
			if (name !is null)
				req!string(*item, "name").str = name;
			if (mimeType !is null)
				req!string(*item, "mime").str = mimeType;
			if (prvKey !is null)
				req!string(*item, "sign").str = Base64URLNoPadding.encode(signEd25519(encBin, prvKey));
		}
	}
	/// ditto
	override void clearSecretItems() @safe
	{
		_secretItems = null;
	}
	/// ditto
	override size_t getSecretItemCount() const @safe
	{
		return _secretItems.length;
	}
	/// ditto
	override immutable(ubyte)[] getDecryptedItem(size_t idx) const @safe
	{
		return _getDecryptedItem(_secretItems[idx]);
	}
	/// ditto
	override immutable(ubyte)[] getEncryptedItem(size_t idx) const @safe
	{
		return _getEncryptedItem(_secretItems[idx]);
	}
}
