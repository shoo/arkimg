module src.misc;

import std.json;
import std.datetime;
import arkimg;

///
string toHexString(immutable(ubyte)[] binary)
{
	import std.string;
	return format("%(%02X%)", binary);
}

///
immutable(ubyte)[] loadCommonKey(string key)
{
	import std.file, std.algorithm, std.range, std.array, std.ascii, std.base64, std.conv;
	if (key.length == 0)
		return null;
	if (key.exists)
		return std.file.readText(key).convertPublicKeyToDER();
	if (key.all!isHexDigit)
		return cast(immutable(ubyte)[])key.chunks(2).map!(a => a.to!ubyte(16)).array;
	if (key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
		return Base64URLNoPadding.decode(key);
	return null;
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
	if (key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
	{
		auto der = cast(immutable(ubyte)[])Base64URLNoPadding.decode(key);
		if (der.length == 32)
			der = convertPrivateKeyToDER(der);
		return der;
	}
	return null;
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
	if (key.all!(c => c.isDigit || c.isAlpha || (c == '-' || c == '_')))
	{
		auto der = cast(immutable(ubyte)[])Base64URLNoPadding.decode(key);
		if (der.length == 32)
			der = convertPublicKeyToDER(der);
		return der;
	}
	return null;
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
