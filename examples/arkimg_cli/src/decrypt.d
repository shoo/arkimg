module src.decrypt;

import std.logger;
import arkimg;
import src.help;
import src.misc;

/*******************************************************************************
 * 
 */
int decryptCommand(string[] args)
{
	import std.getopt;
	import std.path, std.file, std.process;
	import std.algorithm, std.range, std.array;
	import std.format, std.conv, std.ascii, std.string;
	string inputFileName;
	string outputFileName;
	string secretFileName;
	string commonKeyArg = environment.get("ARKIMG_CLI_KEY");
	string ivArg        = environment.get("ARKIMG_CLI_IV");
	string pubKeyArg    = environment.get("ARKIMG_CLI_PUBLIC_KEY");
	string parameterArg;
	bool force;
	bool verbose;
	try
	{
		auto getoptres = args.getopt(
			std.getopt.config.passThrough,
			std.getopt.config.required, "in|i",
				"Input arkimg file name.",
				&inputFileName,
			"out|o",
				"Output file name of secret data including arkimg.\n"
				~ "If not specified, the file name of the meta information will be used.\n"
				~ "And if there is no meta information, the default name will be used.",
				&outputFileName,
			std.getopt.config.required, "secret|s",
				"Secret data file name or index includeing arkimg.",
				&secretFileName,
			"key|k",
				"Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.",
				&commonKeyArg,
			"iv",
				"Specify the IV for encryption in 16-byte hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_IV` will be used.\n"
				~ "If neither is set, a random 16-byte sequence will be prepended to the data.\n"
				~ "It is recommended not to specify this for security reasons.",
				&ivArg,
			"pubkey",
				"Public key pem file for signing or 32-byte hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_PUBLIC_KEY` will be used.\n"
				~ "If neither is set, signing will not be performed.",
				&pubKeyArg,
			"parameter|p",
				"Specify cryptographic information in parameter spec format instead of --key and --pubkey.",
				&parameterArg,
			"force|f",
				"Overwrite the output file if it already exists.",
				&force,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Decrypt files to arkimg.\n"
				~ "ex) %s %s -i input.png -o output.png -s=secret.txt -k=%s --pubkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PUBLIC_KEY",
					createPrivateKey.createPublicKey.convertPublicKeyToRaw().toHexString())));
	}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Decrypt files from arkimg.\n" ~ e.msg);
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	
	// パラメータチェック
	if (!inputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is not existing.", inputFileName);
		return -1;
	}
	
	if (!force && outputFileName.length > 0 && outputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is existing.", outputFileName);
		return -1;
	}
	
	// 鍵情報読み込み
	immutable(ubyte)[] commonKey = null;
	immutable(ubyte)[] iv        = null;
	immutable(ubyte)[] pubKeyDER = null;
	
	if (parameterArg.length > 0)
	{
		parameterArg.loadParameter(commonKey, iv, pubKeyDER);
	}
	else
	{
		commonKey = loadCommonKey(commonKeyArg);
		iv        = loadIV(ivArg);
		pubKeyDER = loadPublicKey(pubKeyArg);
	}
	
	if (commonKey.length == 0)
	{
		errorf("Required option key|k or parameter|p was not supplied.");
		return -1;
	}
	
	if (pubKeyArg.length > 0 && pubKeyDER.length == 0)
	{
		(cast()sharedLog).errorf("Unsupported public key type.");
		return -1;
	}
	
	// メイン処理実行
	try decrypt(inputFileName, secretFileName, outputFileName, commonKey, iv, pubKeyDER, force);
	catch (Exception e)
	{
		debug { (cast()sharedLog).error(e.toString); }
		else (cast()sharedLog).error(e.msg);
		return -1;
	}
	return 0;
}

/*******************************************************************************
 * 復号する
 * 
 * Params:
 *      secretFileName = ArkImg内に存在するメタデータのnameを指定する。ただし、<N>とした場合はデータ番号N番目とする。
 *      dstFileName    = 出力ファイル名。nullを指定した場合、secretFileNameで選択したArkImg内に存在するメタデータのnameが使用される。
 */
immutable(ubyte)[] decrypt(ArkImg img, size_t secretFileIdx, in ubyte[] pubKey = null)
{
	import std.exception;
	if (pubKey.length > 0)
		enforce(img.verify(pubKey), "Cannot verify signature of data");
	return img.getDecryptedItem(secretFileIdx);
}
/// ditto
immutable(ubyte)[] decrypt(in ubyte[] arkimgData, string mimeType, size_t secretFileIdx,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null)
{
	return loadImage(arkimgData.idup, mimeType, key, iv).decrypt(secretFileIdx, pubKey);
}
/// ditto
immutable(ubyte)[] decrypt(string arkimgFile, size_t secretFileIdx,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null)
{
	return loadImage(arkimgFile, key, iv).decrypt(secretFileIdx, pubKey);
}
/// ditto
immutable(ubyte)[] decrypt(string arkimgFile, string secretFileName,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null)
{
	import std.exception;
	auto img             = loadImage(arkimgFile, key, iv);
	auto metadata        = Metadata(img.metadata);
	size_t idx           = metadata.findSecretItem(secretFileName);
	enforce(idx != -1, "Cannot find secret file.");
	enforce(idx < img.getSecretItemCount(), "Cannot find secret file.");
	infof("Found %s", secretFileName);
	return img.decrypt(idx, pubKey);
}
/// ditto
void decrypt(string arkimgFile, string secretFileName, string dstFileName,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null, bool force = false)
{
	import std.file, std.conv;
	import std.exception;
	infof("Load %s", arkimgFile);
	auto img           = loadImage(arkimgFile, key, iv);
	auto metadata      = Metadata(img.metadata);
	string outFileName = dstFileName;
	size_t idx         = findSecretItem(metadata, secretFileName);
	enforce(idx != -1, "Cannot find secret file.");
	enforce(idx < img.getSecretItemCount(), "Cannot find secret file.");
	infof("Found %s", secretFileName);
	if (outFileName.length == 0)
		outFileName = metadata[idx].name;
	enforce(outFileName.length > 0, "Cannot estimate distination file name.");
	enforce(force || !outFileName.exists, text("Cannot overwrite a file, ", outFileName, " is existing."));
	std.file.write(outFileName, img.decrypt(idx, pubKey));
	infof("Save %s", outFileName);
}
