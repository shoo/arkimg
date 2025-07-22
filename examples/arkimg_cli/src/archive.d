module src.archive;

import std.logger;
import arkimg;
import src.help;
import src.misc;

/*******************************************************************************
 * 
 */
int archiveCommand(string[] args)
{
	import std.getopt;
	import std.path, std.file, std.process;
	import std.algorithm, std.range, std.array;
	import std.format, std.conv, std.ascii;
	import std.base64;
	string inputFileName;
	string outputFileName;
	string[] secrets;
	string hexCommonKey = environment.get("ARKIMG_CLI_KEY");
	string hexIV        = environment.get("ARKIMG_CLI_IV");
	string prvKeyArg    = environment.get("ARKIMG_CLI_PRIVATE_KEY");
	bool force;
	bool verbose;
	try
	{
		auto getoptres = args.getopt(
			std.getopt.config.passThrough,
			std.getopt.config.required, "in|i",
				"Input image file name.",
				&inputFileName,
			"out|o",
				"Output image file name including encrypted data.\n"
				~ "If not specified, the input image will be overwritten.\n"
				~ "In this case, the --force flag is required.",
				&outputFileName,
			std.getopt.config.required, "secret|s",
				"Directory path of the plaintext secret data.\n"
				~ "Alternatively, multiple files can also be specified.",
				&secrets,
			std.getopt.config.required, "key|k",
				"Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.",
				&hexCommonKey,
			"iv",
				"Specify the IV for encryption in 16-byte hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_IV` will be used.\n"
				~ "If neither is set, a random 16-byte sequence will be prepended to the data.\n"
				~ "It is recommended not to specify this for security reasons.",
				&hexIV,
			"prvkey",
				"Private key pem file for signing or 32-digit hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.\n"
				~ "If neither is set, signing will not be performed.",
				&prvKeyArg,
			"force|f",
				"Overwrite the output file if it already exists.",
				&force,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Archive files to arkimg.\n"
				~ "ex) %s %s -i input.png -o output.png -s=secret.txt -k=%s --prvkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PRIVATE_KEY", createPrivateKey.convertPrivateKeyToRaw().toHexString())));
	}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Archive files to arkimg.\n" ~ e.msg);
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	
	// パラメータチェック
	if (!inputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is not existing.", inputFileName);
		return -1;
	}
	
	if (outputFileName.length == 0)
		outputFileName = inputFileName;
	
	if (!force && outputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is existing.", outputFileName);
		return -1;
	}
	
	// 鍵情報読み込み
	auto commonKey = hexCommonKey.chunks(2).map!(a => a.to!ubyte(16)).array;
	auto iv = hexIV.length > 0 ? hexIV.chunks(2).map!(a => a.to!ubyte(16)).array : null;
	auto prvKeyDER = loadPrivateKey(prvKeyArg);
	if (prvKeyArg.length > 0 && prvKeyDER.length == 0)
	{
		(cast()sharedLog).errorf("Unsupported private key type.");
		return -1;
	}
	
	// メイン処理実行
	try
	{
		if (secrets.length == 1 && secrets[0].isDir)
			archive(inputFileName, secrets[0], outputFileName, commonKey, iv, prvKeyDER);
		else
			archive(inputFileName, secrets, outputFileName, commonKey, iv, prvKeyDER);
	}
	catch (Exception e)
	{
		debug { (cast()sharedLog).error(e.toString); }
		else (cast()sharedLog).error(e.msg);
		return -1;
	}
	return 0;
}

/*******************************************************************************
 * 
 */
immutable(ubyte)[] archive(string srcMainImage, string[] secretFileNames,
	string baseDir = null,
	in ubyte[] key = null, in ubyte[] iv = null, in ubyte[] prvKey = null)
{
	import std.file, std.path;
	import std.string;
	import std.exception;
	auto img = loadImage(srcMainImage, key, iv);
	foreach (idx, file; secretFileNames)
	{
		enforce(file.exists, format("%s is not existing.", file));
		if (file.isDir)
			continue;
		auto data = cast(immutable(ubyte)[])std.file.read(file);
		auto name = baseDir.length > 0 ? relativePath(file.absolutePath, baseDir.absolutePath) : file;
		version (Windows)
			name = name.buildNormalizedPath.pathSplitter.join("/");
		auto mime = file.mimeType;
		infof("Add %s (%s)", name, mime);
		img.addSecretItem(data, name, mime, prvKey);
		img.addMetaInfo(idx, file.timeLastModified);
	}
	return img.save();
}
/// ditto
void archive(string srcMainImage, string[] secretFileNames, string dstArkimgFileName,
	string baseDir = null,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] prvKey = null)
{
	import std.file;
	auto buf = archive(srcMainImage, secretFileNames, baseDir, key, iv, prvKey);
	infof("Save %s", dstArkimgFileName);
	std.file.write(dstArkimgFileName, buf);
}

/// ditto
void archive(string srcMainImage, string secretDirName, string dstArkimgFileName,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] prvKey = null)
{
	import std.file, std.path;
	string[] secretFileNames;
	foreach (de; dirEntries(secretDirName, SpanMode.breadth))
	{
		if (de.isDir)
			continue;
		secretFileNames ~= de.name;
	}
	archive(srcMainImage, secretFileNames, dstArkimgFileName, secretDirName, key, iv, prvKey);
}
