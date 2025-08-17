module src.misc;

import std.json;
import std.datetime;
import arkimg;
import std.string;

enum string versionInfo = import("version").chomp;

///
string toHexString(immutable(ubyte)[] binary)
{
	return format("%(%02X%)", binary);
}

///
void loadParameter(string parameter,
	out immutable(ubyte)[] key, out immutable(ubyte)[] iv, out immutable(ubyte)[] pubkey)
{
	import std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv, std.regex, std.exception;
	if (parameter.length == 0)
		return;
	if (auto m = parameter.matchFirst(regex(r"^([0-9a-zA-Z-_]{22}|[0-9a-zA-Z-_]{32}|[0-9a-zA-Z-_]{43})$")))
	{
		// Base64形式
		key = cast(immutable(ubyte)[])Base64URLNoPadding.decode(m.captures[1]);
		return;
	}
	if (auto m = parameter.matchFirst(regex(r"^(?:k(16|24|32))(?:i(16))?(?:p(32))?-([0-9a-zA-Z-_]+)$")))
	{
		// Base64形式
		auto bin = cast(immutable(ubyte)[])Base64URLNoPadding.decode(m.captures[4]);
		auto keyLen    = m.captures[1].length > 0 ? m.captures[1].to!size_t : 0;
		auto ivLen     = m.captures[2].length > 0 ? m.captures[2].to!size_t : 0;
		auto pubKeyLen = m.captures[3].length > 0 ? m.captures[3].to!size_t : 0;
		assert(keyLen == 16 || keyLen == 24 || keyLen == 32);
		assert(ivLen == 0 || ivLen == 16);
		assert(pubKeyLen == 0 || pubKeyLen == 32);
		enforce(keyLen + ivLen + pubKeyLen == bin.length);
		key    = bin[0..keyLen];
		iv     = bin[keyLen .. keyLen + ivLen];
		pubkey = pubKeyLen == 0 ? null : bin[keyLen + ivLen .. $].convertPublicKeyToDER();
		return;
	}
	if (auto m = parameter.matchFirst(regex(r"^([0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})"
		~ r"(?:-([0-9a-fA-F]{32}))?(?:-([0-9a-fA-F]{64}))?$")))
	{
		// 16進数形式
		assert(m.captures[1].length == 16 || m.captures[1].length == 24 || m.captures[1].length == 32);
		assert(m.captures[2].length == 0 || m.captures[2].length == 32);
		assert(m.captures[3].length == 0 || m.captures[3].length == 64);
		key    = cast(immutable(ubyte)[])m.captures[1].chunks(2).map!(a => a.to!ubyte(16)).array;
		iv     = cast(immutable(ubyte)[])m.captures[2].chunks(2).map!(a => a.to!ubyte(16)).array;
		pubkey = convertPublicKeyToDER(cast(immutable(ubyte)[])m.captures[3].chunks(2).map!(a => a.to!ubyte(16)).array);
	}
}

@system unittest
{
	immutable(ubyte)[] key;
	immutable(ubyte)[] iv;
	immutable(ubyte)[] pubkey;
	loadParameter("k16p32-nerNAaaqW9Q4ssfQi1t3kLNm98ZEZGcqntPw0mJYB9GEREpTUJTVDTExmh8GtE-i", key, iv, pubkey);
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	assert(iv == cast(immutable(ubyte)[])x"");
	auto pubkeyRaw = pubkey.convertPublicKeyToRaw();
	assert(pubkeyRaw == cast(immutable(ubyte)[])x"B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2");
	
	loadParameter("k99p32--i", key, iv, pubkey);
	assert(key == cast(immutable(ubyte)[])x"");
	assert(iv == cast(immutable(ubyte)[])x"");
	assert(pubkey == cast(immutable(ubyte)[])x"");
	
	loadParameter("9DEACD01A6AA5BD438B2C7D08B5B7790-B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2",
		key, iv, pubkey);
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	assert(iv == cast(immutable(ubyte)[])x"");
	pubkeyRaw = pubkey.convertPublicKeyToRaw();
	assert(pubkeyRaw == cast(immutable(ubyte)[])x"B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2");
	
	loadParameter("nerNAaaqW9Q4ssfQi1t3kA", key, iv, pubkey);
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	assert(iv == cast(immutable(ubyte)[])x"");
	assert(pubkey == cast(immutable(ubyte)[])x"");
}

///
immutable(ubyte)[] loadCommonKey(string key)
{
	import std.file, std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv;
	if (key.length == 0)
		return null;
	if (key.exists)
		return std.file.readText(key).chomp.loadCommonKey();
	if (key.all!isHexDigit)
		return cast(immutable(ubyte)[])key.chunks(2).map!(a => a.to!ubyte(16)).array;
	if ((key.length == 22 || key.length == 32 || key.length == 43)
		&& key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
		return Base64URLNoPadding.decode(key);
	return null;
}

@system unittest
{
	auto key = loadCommonKey("9DEACD01A6AA5BD438B2C7D08B5B7790");
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	
	key = loadCommonKey("nerNAaaqW9Q4ssfQi1t3kA");
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	
	key = loadCommonKey("");
	assert(key == cast(immutable(ubyte)[])x"");
	
	key = loadCommonKey("xxx");
	assert(key == cast(immutable(ubyte)[])x"");
	
	import std.file, std.uuid;
	auto keyFile = "." ~ randomUUID.toString() ~ ".key";
	scope (exit)
		remove(keyFile);
	std.file.write(keyFile, "9DEACD01A6AA5BD438B2C7D08B5B7790");
	key = loadCommonKey(keyFile);
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
	
	std.file.write(keyFile, "9DEACD01A6AA5BD438B2C7D08B5B7790\n");
	key = loadCommonKey(keyFile);
	assert(key == cast(immutable(ubyte)[])x"9DEACD01A6AA5BD438B2C7D08B5B7790");
}

///
immutable(ubyte)[] loadIV(string iv)
{
	import std.file, std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv;
	if (iv.length == 0)
		return null;
	if (iv.exists)
		return std.file.readText(iv).chomp.loadIV();
	if (iv.all!isHexDigit)
		return cast(immutable(ubyte)[])iv.chunks(2).map!(a => a.to!ubyte(16)).array;
	if (iv.length == 22 && iv.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
		return Base64URLNoPadding.decode(iv);
	return null;
}

@system unittest
{
	auto iv = loadIV("7015E8F3993846605479982491495DAF");
	assert(iv == cast(immutable(ubyte)[])x"7015E8F3993846605479982491495DAF");
	
	iv = loadIV("cBXo85k4RmBUeZgkkUldrw");
	assert(iv == cast(immutable(ubyte)[])x"7015E8F3993846605479982491495DAF");
	
	iv = loadIV("");
	assert(iv == cast(immutable(ubyte)[])x"");
	
	iv = loadIV("xxx");
	assert(iv == cast(immutable(ubyte)[])x"");
	
	import std.file, std.uuid;
	auto ivFile = "." ~ randomUUID.toString() ~ ".iv";
	scope (exit)
		remove(ivFile);
	std.file.write(ivFile, "7015E8F3993846605479982491495DAF");
	iv = loadIV(ivFile);
	assert(iv == cast(immutable(ubyte)[])x"7015E8F3993846605479982491495DAF");
	std.file.write(ivFile, "7015E8F3993846605479982491495DAF\n");
	iv = loadIV(ivFile);
	assert(iv == cast(immutable(ubyte)[])x"7015E8F3993846605479982491495DAF");
}

///
immutable(ubyte)[] loadPrivateKey(string key)
{
	import std.file, std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv;
	if (key.length == 0)
		return null;
	if (key.exists)
		return std.file.readText(key).convertPrivateKeyToDER();
	if (key.all!isHexDigit)
	{
		auto der = cast(immutable(ubyte)[])key.chunks(2).map!(a => a.to!ubyte(16)).array;
		if (der.length == 32)
			der = convertPrivateKeyToDER(der);
		return der;
	}
	if (key.length == 43 && key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
	{
		auto der = cast(immutable(ubyte)[])Base64URLNoPadding.decode(key);
		if (der.length == 32)
			der = convertPrivateKeyToDER(der);
		return der;
	}
	return null;
}

@system unittest
{
	enum testDER = cast(immutable(ubyte)[])
		x"302E020100300506032B657004220420CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919";
	auto prvKey = loadPrivateKey("CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919");
	assert(prvKey == testDER);
	
	prvKey = loadPrivateKey("z5rnqETxs80MzzciPEhYpuXUDmuk0UKbErazCGJh-Rk");
	assert(prvKey == testDER);
	
	prvKey = loadPrivateKey("");
	assert(prvKey == cast(immutable(ubyte)[])x"");
	
	prvKey = loadPrivateKey("xxx");
	assert(prvKey == cast(immutable(ubyte)[])x"");
	
	import std.file, std.uuid;
	auto prvKeyFile = "." ~ randomUUID.toString() ~ ".prvkey";
	scope (exit)
		remove(prvKeyFile);
	std.file.write(prvKeyFile, testDER.convertPrivateKeyToPEM());
	prvKey = loadPrivateKey(prvKeyFile);
	assert(prvKey == testDER);
}

///
immutable(ubyte)[] loadPublicKey(string key)
{
	import std.file, std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv;
	if (key.length == 0)
		return null;
	if (key.exists)
	{
		auto pem = std.file.readText(key);
		return convertPublicKeyToDER(pem);
	}
	if (key.all!isHexDigit)
	{
		auto der = cast(immutable(ubyte)[])key.chunks(2).map!(a => a.to!ubyte(16)).array;
		if (der.length == 32)
			der = convertPublicKeyToDER(der);
		return der;
	}
	if (key.length == 43 && key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
	{
		auto der = cast(immutable(ubyte)[])Base64URLNoPadding.decode(key);
		if (der.length == 32)
			der = convertPublicKeyToDER(der);
		return der;
	}
	return null;
}

@system unittest
{
	enum testDER = cast(immutable(ubyte)[])
		x"302A300506032B6570032100B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2";
	auto prvKey = loadPublicKey("B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2");
	assert(prvKey == testDER);
	
	prvKey = loadPublicKey("s2b3xkRkZyqe0_DSYlgH0YRESlNQlNUNMTGaHwa0T6I");
	assert(prvKey == testDER);
	
	prvKey = loadPublicKey("");
	assert(prvKey == cast(immutable(ubyte)[])x"");
	
	prvKey = loadPublicKey("xxx");
	assert(prvKey == cast(immutable(ubyte)[])x"");
	
	import std.file, std.uuid;
	auto pubKeyFile = "." ~ randomUUID.toString() ~ ".pubkey";
	scope (exit)
		remove(pubKeyFile);
	std.file.write(pubKeyFile, testDER.convertPublicKeyToPEM());
	prvKey = loadPublicKey(pubKeyFile);
	assert(prvKey == testDER);
}


JSONValue setMetaInfo(JSONValue metadata, size_t idx,
	string fileName = null, string mimeType = null,
	SysTime modified = SysTime.init, string comment = null, JSONValue exData = JSONValue.init)
{
	if (modified !is SysTime.init || comment.length > 0 || exData !is JSONValue.init)
	{
		if ("items" !in metadata)
			metadata["items"] = JSONValue.emptyArray;
		while (metadata["items"].array.length <= idx)
			metadata["items"].array ~= JSONValue.emptyObject;
		if (fileName.length > 0)
			metadata["items"][idx]["name"] = JSONValue(fileName);
		if (mimeType.length > 0)
			metadata["items"][idx]["mime"] = JSONValue(mimeType);
		if (modified !is SysTime.init)
			metadata["items"][idx]["modified"] = JSONValue(modified.toUTC.toISOExtString());
		if (comment.length > 0)
			metadata["items"][idx]["comment"] = JSONValue(comment);
		if (exData.type == JSONType.object)
		{
			foreach (k, v; exData.object)
				metadata["items"][idx][k] = v;
		}
	}
	return metadata;
}

void addMetaInfo(ArkImg img, size_t idx,
	SysTime modified = SysTime.init, string comment = null, JSONValue exData = JSONValue.init)
{
	auto metadata = img.metadata;
	if (modified !is SysTime.init || comment.length > 0 || exData !is JSONValue.init)
		img.metadata = metadata.setMetaInfo(idx, null, null, modified, comment, exData);
}

size_t findSecretItem(Metadata metadata, string secretFileName)
{
	import std.algorithm, std.range, std.ascii, std.conv, std.string;
	if (secretFileName.startsWith("<") && secretFileName.endsWith(">"))
	{
		auto stripped = secretFileName.chompPrefix("<").chomp(">");
		if (stripped.all!isDigit)
			return stripped.to!size_t();
	}
	else
	{
		foreach (idx, item; metadata[].enumerate)
		{
			if (item.name == secretFileName)
				return idx;
		}
	}
	return -1;
}
