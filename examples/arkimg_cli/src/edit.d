module src.edit;

import std.logger;
import std.datetime;
import std.json;
import arkimg;
import src.help;
import src.misc;

/*******************************************************************************
 * 
 */
int editCommand(string[] args)
{
	import std.getopt;
	import std.path, std.file, std.process;
	import std.algorithm, std.range, std.array;
	import std.format, std.conv, std.ascii, std.string;
	string inputFileName;
	string outputFileName;
	string secretFileName;
	string newSecretFileName;
	string commonKeyArg = environment.get("ARKIMG_CLI_KEY");
	string ivArg        = environment.get("ARKIMG_CLI_IV");
	string prvKeyArg    = environment.get("ARKIMG_CLI_PRIVATE_KEY");
	string content;
	string name;
	string mime;
	string timArg;
	string comment;
	string exDatArg;
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
				"Specify secret data file name or index includeing arkimg to edit.",
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
			"content",
				"Specify the file name containing the new content of the secret data.\n"
				~ "Specify only if you want to modify it.",
				&content,
			"name",
				"Specify the new name of the secret data. Specify only if you want to modify it.",
				&name,
			"mimetype",
				"Specify the mime type of the secret data. Specify only if you want to modify it.",
				&mime,
			"timestamp",
				"Specify the time stamp of the secret data. Specify only if you want to modify it.",
				&timArg,
			"comment",
				"Specify the comment messages of the secret data. Specify only if you want to modify it.",
				&comment,
			"extra",
				"Specify JSON file of extra values of secret data. Specify only if you want to modify it.",
				&exDatArg,
			"force|f",
				"Overwrite the output file if it already exists.",
				&force,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, format(
				"Edit files of arkimg.\n"
				~ "%s %s -i input.png -o output.png -s=secret.txt -k=%s --prvkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PRIVATE_KEY", createPrivateKey.convertPrivateKeyToRaw().toHexString())));
	}
	catch (Exception e)
		return dispFallbackHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Edit files of arkimg.\n" ~ e.msg);
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
	
	if (!force && outputFileName.length > 0 && outputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is existing.", outputFileName);
		return -1;
	}
	
	JSONValue exDat;
	if (exDatArg.length > 0 && exDatArg.exists)
		exDat = std.file.readText(exDatArg).parseJSON();
	
	SysTime tim;
	if (timArg.length > 0)
		tim = SysTime.fromISOExtString(timArg);
	
	// 鍵情報読み込み
	auto commonKey = loadCommonKey(commonKeyArg);
	auto iv = ivArg.length > 0 ? ivArg.chunks(2).map!(a => a.to!ubyte(16)).array : null;
	auto prvKeyDER = loadPrivateKey(prvKeyArg);
	if (prvKeyArg.length > 0 && prvKeyDER.length == 0)
	{
		(cast()sharedLog).errorf("Unsupported public key type.");
		return -1;
	}
	
	// メイン処理実行
	try edit(inputFileName, secretFileName, content, outputFileName, commonKey, iv, prvKeyDER,
		mime, newSecretFileName, tim, comment, exDat);
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
void edit(ArkImg img, size_t secretFileIdx,
	in ubyte[] newFileData = null, string mimeType = null, string newFileName = null,
	SysTime modified = SysTime.init, string comment = null, JSONValue exData = JSONValue.init,
	in ubyte[] prvKey = null)
{
	import std.path;
	import std.exception;
	import std.array;
	enforce(secretFileIdx != -1, "Cannot find file in arkimg.");
	auto oldMetadata = img.metadata;
	immutable(ubyte)[][] oldSecrets;
	auto pubKey = prvKey is null ? null : createPublicKey(prvKey);
	enforce(pubKey is null || img.verify(pubKey), "Cannot verify signature of arkimg.");
	if (newFileData.length > 0)
	{
		foreach (idx; 0..img.getSecretItemCount)
			oldSecrets ~= img.getDecryptedItem(idx);
		img.clearSecretItems();
		foreach (idx; 0..secretFileIdx)
			img.addSecretItem(oldSecrets[idx]);
		img.addSecretItem(newFileData, newFileName, mimeType, prvKey);
		foreach (idx; secretFileIdx + 1 .. oldSecrets.length)
			img.addSecretItem(oldSecrets[idx]);
	}
	img.metadata = oldMetadata.setMetaInfo(secretFileIdx, newFileName, mimeType, modified, comment, exData);
	infof("Edit at %s", secretFileIdx);
}
/// ditto
void edit(string arkimgFile, string secretFileName, string replaceFile, string outFileName,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] prvKey = null,
	string mimeType = null, string newSecretFileName = null, SysTime modified = SysTime.init,
	string comment = null, JSONValue exData = JSONValue.init)
{
	import std.exception;
	import std.file;
	infof("Load %s", arkimgFile);
	auto img      = loadImage(arkimgFile, key, iv);
	enforce(prvKey is null || img.verify(prvKey.createPublicKey()));
	auto metadata = Metadata(img.metadata);
	size_t idx    = metadata.findSecretItem(secretFileName);
	enforce(idx != -1, "Cannot find secret data.");
	auto tim     = modified !is SysTime.init ? modified : replaceFile.length > 0
			? replaceFile.timeLastModified : SysTime.init;
	auto fileDat = replaceFile.length > 0       ? cast(ubyte[])std.file.read(replaceFile) : null;
	auto name    = newSecretFileName.length > 0 ? newSecretFileName : secretFileName;
	auto mime    = mimeType.length > 0          ? mimeType : name.mimeType;
	img.edit(idx, fileDat, mime, name, tim, comment, exData, prvKey);
	infof("Save %s", outFileName);
	std.file.write(outFileName, img.save());
}
