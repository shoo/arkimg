module src.encrypt;

import std.logger;
import std.json;
import std.datetime;
import arkimg;
import src.help;
import src.misc;

int encryptCommand(string[] args)
{
	import std.getopt;
	import std.file, std.path, std.process;
	import std.format, std.conv;
	import std.range, std.algorithm, std.array;
	
	string inputFileName;
	string outputFileName;
	string secretFileName;
	string commonKeyArg = environment.get("ARKIMG_CLI_KEY");
	string ivArg        = environment.get("ARKIMG_CLI_IV");
	string prvKeyArg    = environment.get("ARKIMG_CLI_PRIVATE_KEY");
	string comment;
	string exDatArg;
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
				~ "If not specified, the input image will be overwritten. In this case, the -f flag is required.",
				&outputFileName,
			std.getopt.config.required, "secret|s",
				"Directory path of the plaintext secret data. Alternatively, multi-files can also be specified.",
				&secretFileName,
			std.getopt.config.required, "key|k",
				"Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.",
				&commonKeyArg,
			"iv",
				"Specify the IV for encryption in 16-byte hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_IV` will be used.\n"
				~ "If neither is set, a random 16-byte sequence will be prepended to the data.\n"
				~ "It is recommended not to specify this for security reasons.",
				&ivArg,
			"prvkey",
				"Private key pem file for signing or 32-digit hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.\n"
				~ "If neither is set, signing will not be performed.",
				&prvKeyArg,
			"comment",
				"Specify comment messages of secret data.",
				&comment,
			"extra",
				"Specify JSON file of additional values of secret data.",
				&exDatArg,
			"force|f",
				"Overwrite the output file if it already exists.",
				&force,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Encrypt and add file into arkimg.\n"
				~ "ex) %s %s -i input.png -o output.png -s=secret.txt -k=%s --prvkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PRIVATE_KEY", createPrivateKey.convertPrivateKeyToRaw().toHexString())));
		}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Encrypt and add file into arkimg.\n" ~ e.msg);
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	
	// パラメータチェック
	if (!inputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is not existing.", inputFileName);
		return -1;
	}
	
	if (!secretFileName.exists)
	{
		(cast()sharedLog).warningf("%s is not existing.", secretFileName);
		return -1;
	}
	
	if (outputFileName.length == 0)
		outputFileName = inputFileName;
	
	if (!force && outputFileName.length > 0 && outputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is existing.", outputFileName);
		return -1;
	}
	
	JSONValue exDat;
	if (exDatArg.length > 0 && exDatArg.exists)
		exDat = std.file.readText(exDatArg).parseJSON();
	
	// 鍵情報読み込み
	auto commonKey = loadCommonKey(commonKeyArg);
	auto iv = ivArg.length > 0 ? ivArg.chunks(2).map!(a => a.to!ubyte(16)).array : null;
	auto prvKeyDER = loadPublicKey(prvKeyArg);
	if (prvKeyArg.length > 0 && prvKeyDER.length == 0)
	{
		(cast()sharedLog).errorf("Unsupported public key type.");
		return -1;
	}
	
	// メイン処理実行
	auto tim = std.file.timeLastModified(secretFileName);
	try encrypt(inputFileName, secretFileName, outputFileName, tim, comment, exDat, commonKey, iv, prvKeyDER, force);
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
immutable(ubyte)[] encrypt(ArkImg img, in ubyte[] srcFileData, string srcFileName, string srcMimeType,
	SysTime modified = SysTime.init, string comment = null, JSONValue exData = JSONValue.init,
	in ubyte[] prvKey = null)
{
	import std.path;
	auto idx = img.getSecretItemCount();
	infof("Add %s (%s) at %d", srcFileName, srcMimeType, idx);
	img.addSecretItem(srcFileData, srcFileName, srcMimeType, prvKey);
	img.addMetaInfo(idx, modified, comment, exData);
	return img.save();
}
/// ditto
void encrypt(string arkimgFile, string srcFilePath, string dstFileName,
	SysTime modified = SysTime.init, string comment = null, JSONValue exData = JSONValue.init,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] prvKey = null, bool force = false)
{
	import std.file, std.path;
	auto img = loadImage(arkimgFile, key, iv);
	infof("Load %s", arkimgFile);
	auto secdat = cast(immutable(ubyte)[])std.file.read(srcFilePath);
	auto dat = img.encrypt(secdat, srcFilePath.baseName, srcFilePath.mimeType, modified, comment, exData, prvKey);
	infof("Save %s", dstFileName);
	std.file.write(dstFileName, dat);
}
