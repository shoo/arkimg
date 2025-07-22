module src.extract;

import std.logger;
import arkimg;
import src.help;
import src.misc;

/*******************************************************************************
 * 
 */
int extractCommand(string[] args)
{
	import std.getopt;
	import std.file, std.path, std.process;
	import std.format, std.conv;
	import std.range, std.algorithm, std.array;
	
	string inputFileName;
	string outputDirName;
	string commonKeyArg = environment.get("ARKIMG_CLI_KEY");
	string ivArg        = environment.get("ARKIMG_CLI_IV");
	string pubKeyArg    = environment.get("ARKIMG_CLI_PUBLIC_KEY");
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
				&outputDirName,
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
			"pubkey",
				"Public key pem file for signing or 32-byte hexadecimal format.\n"
				~ "If not specified, the environment variable `ARKIMG_CLI_PUBLIC_KEY` will be used.\n"
				~ "If neither is set, signing will not be performed.",
				&pubKeyArg,
			"force|f",
				"Overwrite the output file if it already exists.",
				&force,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Extract and decrypt files from arkimg.\n"
				~ "ex) %s %s -i input.png -o output.png -s=secret.txt -k=%s --pubkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PUBLIC_KEY",
					createPrivateKey.createPublicKey.convertPublicKeyToRaw().toHexString())));
	}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Extract and decrypt files from arkimg.\n" ~ e.msg);
	
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	
	// パラメータチェック
	if (!inputFileName.exists)
	{
		warningf("%s is not existing.", inputFileName);
		return -1;
	}
	if (!force && outputDirName.exists && !outputDirName.isDir)
	{
		warningf("%s is existing.", outputDirName);
		return -1;
	}
	
	// 鍵情報読み込み
	auto commonKey = loadCommonKey(commonKeyArg);
	auto iv = ivArg.length > 0 ? ivArg.chunks(2).map!(a => a.to!ubyte(16)).array : null;
	auto pubKeyDER = loadPublicKey(pubKeyArg);
	if (pubKeyArg.length > 0 && pubKeyDER.length == 0)
	{
		errorf("Unsupported public key type.");
		return -1;
	}
	
	// メイン処理実行
	try extract(inputFileName, outputDirName, commonKey, iv, pubKeyDER, force);
	catch (Exception e)
	{
		debug { error(e.toString); }
		else error(e.msg);
		return -1;
	}
	return 0;
}

/*******************************************************************************
 * 
 */
void extract(string arkimgFile, string dstDirName,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null, bool force = false)
{
	import std.file, std.path;
	import std.datetime;
	import std.format;
	infof("Load %s", arkimgFile);
	auto img             = loadImage(arkimgFile, key, iv);
	auto metadata        = Metadata(img.metadata);
	if (!dstDirName.exists)
		mkdirRecurse(dstDirName);
	foreach (idx; 0..img.getSecretItemCount)
	{
		auto itm = metadata[idx];
		auto name = !itm.isInit ? itm.name : format("%d", idx);
		infof("Found %s", name);
		auto dstFileName = dstDirName.buildPath(name);
		if (itm.isInit)
		{
			if (!force && dstFileName.exists)
			{
				warningf("%s already exists and was not extracted.", name);
				continue;
			}
			infof("Save %s", dstFileName);
			std.file.write(dstFileName, img.getDecryptedItem(idx));
			continue;
		}
		else
		{
			if (itm.sign.length > 0 && pubKey.length > 0)
			{
				if (!itm.verify(img.getEncryptedItem(idx), pubKey))
				{
					warningf("%s could not be verified with the specified public key.");
					continue;
				}
			}
			if (!force && dstFileName.exists)
			{
				warningf("%s already exists and was not extracted.", name);
				continue;
			}
			infof("Save %s", dstFileName);
			std.file.write(dstFileName, img.getDecryptedItem(idx));
			if (itm.modified !is SysTime.init)
				dstFileName.timeLastModified(itm.modified.toLocalTime);
		}
	}
}
