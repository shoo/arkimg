module src.keyutil;

import std.logger;
import std.base64;
import std.stdio;
import arkimg;
import src.help;

int keyutilCommand(string[] args)
{
	import std.getopt;
	import std.path, std.file, std.process;
	import std.algorithm, std.range, std.array;
	import std.format, std.conv, std.ascii;
	bool genCommonKey;
	size_t keySize = 128;
	bool genIV;
	bool genPrvKey;
	bool genPubKey;
	string prvKey = environment.get("ARKIMG_CLI_KEY");
	bool verbose;
	bool base64;
	bool parameter;
	try
	{
		auto getoptres = args.getopt(
			std.getopt.config.passThrough,
			"genkey|k",
				"Generate a common key for encryption/decryption.",
				&genCommonKey,
			"keysize",
				"Specify size of the common key in bit length. (default=128 or 192 or 256)",
				&keySize,
			"geniv",
				"Specify the IV for encryption in 16-byte hexadecimal format.\n"
				~ "If not specified, a random 16-byte sequence will be prepended to the data.\n"
				~ "It is recommended not to specify this for security reasons.",
				&genIV,
			"genprvkey",
				"Generate a private key for sign.",
				&genPrvKey,
			"prvkey",
				"Specify the private key in 32 bytes hexadecimal format for generating the public key.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.",
				&prvKey,
			"genpubkey",
				"Generate a public key for verifing signature.",
				&genPubKey,
			"base64",
				"Generate keys with Base64 format (Base64 URL NoPadding).",
				&base64,
			"parameter",
				"Generate keys with parameter specs format.",
				&parameter,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Key utilities.\n"
				~ "ex) %s %s --genkey --geniv --genprvkey --genpubkey",
				thisExePath.baseName.stripExtension, args[0]));
	}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Key utilities.\n" ~ e.msg);
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	// パラメータチェック
	if (!genCommonKey && !genIV && !genPrvKey && !genPubKey)
	{
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init, "Key utilities.\n"
			~ "Specify at least one of the following arguments:\n"
			~ "    --genkey:    Generate common key for encryption/decryption.\n"
			~ "    --geniv:     Generate IV.\n"
			~ "    --genprvkey: Generate private key for signing.\n"
			~ "    --genpubkey: Generate public key for verification.");
	}
	if (genPubKey && (!genPrvKey && prvKey.length == 0))
	{
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init, "Key utilities.\n"
			~ "To generate a public key, you need to either generate or specify a private key:\n"
			~ "    --genprvkey: Generate private key for signing.\n"
			~ "    --prvkey:    Specify the private key.");
	}
	if (genPrvKey && prvKey.length != 0)
	{
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init, "Key utilities.\n"
			~ "There is a conflict between generating and specifying the private key:\n"
			~ "    --genprvkey: Generate private key for signing.\n"
			~ "    --prvkey:    Specify the private key.");
	}
	if (genPrvKey && (keySize != 128 && keySize != 192 && keySize != 256))
	{
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init, "Key utilities.\n"
			~ "The size of the common key is incorrect:\n"
			~ "    --keysize: 128 or 192 or 256");
	}
	if (parameter && !genCommonKey)
	{
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init, "Key utilities.\n"
			~ "A common key is required for parameters:\n"
			~ "    --genkey:    Generate common key for encryption/decryption.");
	}
	immutable(ubyte)[] prvKeyRaw;
	if (prvKey.length == 0)
	{
		prvKeyRaw = null;
	}
	else if (prvKey.exists)
	{
		auto pem = std.file.readText(prvKey);
		prvKeyRaw = pem.convertPrivateKeyToDER().convertPrivateKeyToRaw();
	}
	else if (prvKey.all!isHexDigit)
	{
		prvKeyRaw = prvKey.chunks(2).map!(a => a.to!ubyte(16)).array;
	}
	else if (prvKey.all!(a => a.isDigit || a.isAlpha || (a == '-' || a == '_')))
	{
		prvKeyRaw = Base64URLNoPadding.decode(prvKey);
	}
	else
	{
		prvKeyRaw = null;
	}
	
	immutable(ubyte)[] generatedCommonKey  = null;
	immutable(ubyte)[] generatedIV         = null;
	immutable(ubyte)[] generatedPrivateKey = prvKeyRaw;
	immutable(ubyte)[] generatedPublicKey  = null;
	
	if (genCommonKey)
		generatedCommonKey = createCommonKey(keySize / 8);
	if (genIV)
		generatedIV = createRandomIV();
	if (genPrvKey)
		generatedPrivateKey = createPrivateKey().convertPrivateKeyToRaw();
	if (genPubKey)
		generatedPublicKey = createPublicKey(generatedPrivateKey.convertPrivateKeyToDER()).convertPublicKeyToRaw();
	
	// メイン処理実行
	if (parameter)
	{
		writeln("Parameter: ", getParameter(generatedCommonKey, generatedIV, generatedPublicKey, base64));
		if (genPrvKey)
			writeln("PrivateKey: ", base64
				? Base64URLNoPadding.encode(generatedPrivateKey)
				: format("%(%02X%)", generatedPrivateKey));
	}
	else
	{
		if (generatedCommonKey.length > 0)
			writeln("CommonKey:  ", base64
				? Base64URLNoPadding.encode(generatedCommonKey)
				: format("%(%02X%)", generatedCommonKey));
		if (generatedIV.length > 0)
			writeln("IV:         ", base64
				? Base64URLNoPadding.encode(generatedIV)
				: format("%(%02X%)", generatedIV));
		if (genPrvKey)
			writeln("PrivateKey: ", base64
				? Base64URLNoPadding.encode(generatedPrivateKey)
				: format("%(%02X%)", generatedPrivateKey));
		if (genPubKey)
			writeln("PublicKey:  ", base64
				? Base64URLNoPadding.encode(generatedPublicKey)
				: format("%(%02X%)", generatedPublicKey));
	}
	return 0;
}

string getParameter(in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null, bool base64 = false)
{
	import std.format, std.base64;
	if (base64)
	{
		alias B64 = Base64URLNoPadding;
		if (iv.length == 0 && pubKey.length == 0)
			return format("k%d-%s", key.length, B64.encode(key));
		if (iv.length > 0 && pubKey.length == 0)
			return format("k%di%d-%s", key.length, iv.length, B64.encode(key ~ iv));
		if (iv.length == 0 && pubKey.length > 0)
			return format("k%dp%d-%s", key.length, pubKey.length, B64.encode(key ~ pubKey));
		return format("k%di%dp%d-%s", key.length, iv.length, pubKey.length, B64.encode(key ~ iv ~ pubKey));
	}
	if (iv.length == 0 && pubKey.length == 0)
		return format("%(%02X%)", key);
	if (iv.length > 0 && pubKey.length == 0)
		return format("%(%02X%)-%(%02X%)", key, iv);
	if (iv.length == 0 && pubKey.length > 0)
		return format("%(%02X%)-%(%02X%)", key, pubKey);
	return format("%(%02X%)-%(%02X%)-%(%02X%)", key, iv, pubKey);
}
