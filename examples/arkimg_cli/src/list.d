module src.list;

import std.logger;
import arkimg;
import src.help;
import src.misc;


struct DetailModeInfo
{
	bool enabled = false;
	bool digest = true;
	bool sign = true;
	bool mime = true;
	bool modified = true;
	bool comment = true;
	bool extra = false;
}
enum detailModeJSON = DetailModeInfo(true, false, false, false, false, false, false);

/*******************************************************************************
 * 
 * 
 * Simple mode display Examples:
 * ```
 * path/to/file1.txt
 * path/to/file2.txt
 * path/to/file3.txt
 * ```
 * 
 * Detail mode display Examples:
 * ```
 * path/to/file1.txt
 *     MimeType:  text/plain
 *     SHA256:    000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F
 *     Signature: 040102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F
 *     Modified:  2025-05-01T12:13:14
 *     Comment:   hogehoge
 *     Extra:     {
 *       "hoge": "fuga",
 *       "foo": "bar"
 *     }
 * ```
 */
int listCommand(string[] args)
{
	import std.getopt;
	import std.file, std.path, std.process;
	import std.format, std.conv;
	import std.range, std.algorithm, std.array;
	
	string inputFileName;
	string secretPattern;
	string commonKeyArg = environment.get("ARKIMG_CLI_KEY");
	string ivArg        = environment.get("ARKIMG_CLI_IV");
	string pubKeyArg    = environment.get("ARKIMG_CLI_PUBLIC_KEY");
	DetailModeInfo detail;
	bool verbose;
	try
	{
		auto getoptres = args.getopt(
			std.getopt.config.passThrough,
			std.getopt.config.required, "in|i",
				"Input image file name.",
				&inputFileName,
			"path|p",
				"Directory path of the secret data for list base.",
				&secretPattern,
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
			"detail|d",
				"Enable detailed mode. Default: false",
				&detail.enabled,
			"disp-json",
				"Enable detailed mode. Default: false",
				() { detail = detailModeJSON; },
			"disp-digest",
				"Display the digest(SHA-256) of the secret data in detail mode. Default: true",
				&detail.digest,
			"disp-sign",
				"Display the  signature of the secret data in detail mode. Default: true",
				&detail.sign,
			"disp-mime",
				"Display the mime type of the secret data in detail mode. Default: true Default: true",
				&detail.mime,
			"disp-modified",
				"Display the last modified timestamp of the secret data in detail mode. Default: true",
				&detail.modified,
			"disp-comment",
				"Display the comment of the secret data in detail mode. Default: true",
				&detail.mime,
			"disp-extra",
				"Display the extra of the secret data in detail mode. Default: false",
				&detail.extra,
			"verbose|v",
				"Display verbose messages.",
				&verbose);
		if (getoptres.helpWanted)
			return dispHelp(thisExePath.baseName.stripExtension, args[0], getoptres, "List files arkimg including.\n"
				~ format("ex) %s %s -i input.png -k=%s --pubkey=%s",
				thisExePath.baseName.stripExtension, args[0],
				environment.get("ARKIMG_CLI_KEY", createCommonKey.toHexString()),
				environment.get("ARKIMG_CLI_PUBLIC_KEY",
					createPrivateKey.createPublicKey.convertPublicKeyToRaw().toHexString())));
	}
	catch (Exception e)
		return dispHelp(thisExePath.baseName.stripExtension, args[0], GetoptResult.init,
			"Encrypt and add file into arkimg.\n" ~ e.msg);
	// ログレベル設定
	(cast()sharedLog).logLevel = cast(LogLevel)(verbose ? LogLevel.all : LogLevel.error | LogLevel.fatal);
	
	if (!inputFileName.exists)
	{
		(cast()sharedLog).warningf("%s is not existing.", inputFileName);
		return -1;
	}
	auto commonKey = loadCommonKey(commonKeyArg);
	auto iv = ivArg.length > 0 ? ivArg.chunks(2).map!(a => a.to!ubyte(16)).array : null;
	auto pubKeyDER = loadPublicKey(pubKeyArg);
	
	// メイン処理実行
	try list(inputFileName, secretPattern, detail, commonKey, iv, pubKeyDER);
	catch (Exception e)
	{
		debug { (cast()sharedLog).error(e.toString); }
		else (cast()sharedLog).error(e.msg);
		return -1;
	}
	
	return 0;
}

void list(string arkimgFile, string secretPattern, DetailModeInfo detail,
	in ubyte[] key, in ubyte[] iv = null, in ubyte[] pubKey = null)
{
	import std.format;
	import std.algorithm, std.range, std.array;
	import std.regex;
	import std.file, std.path;
	import std.digest, std.digest.sha;
	import std.stdio;
	import std.datetime;
	import std.json;
	import std.base64;
	auto img           = loadImage(arkimgFile, key, iv);
	auto metadata      = Metadata(img.metadata);
	auto pattern       = secretPattern.length == 0 ? string.init
		: secretPattern.buildNormalizedPath.split(regex(r"[/\\]")).filter!(a => a.length > 0 && a != ".").join("/");
	if (detail == detailModeJSON)
	{
		writeln(img.metadata.toPrettyString(JSONOptions.doNotEscapeSlashes));
		return;
	}
	foreach (idx; 0..img.getSecretItemCount())
	{
		auto itm = metadata[idx];
		auto name = itm.name;
		if (name.length == 0)
			name = format("<%d>", idx);
		if (pattern.length > 0)
		{
			auto path = name.buildNormalizedPath.split(regex(r"[/\\]"))
				.filter!(a => a.length > 0 && a != ".").join("/");
			if (!globMatch(path, pattern))
				continue;
		}
		writeln(name);
		if (!detail.enabled)
			continue;
		void disp(bool enabled, string title, lazy string info)
		{
			if (enabled)
				writefln("    %-10s %s", title ~ ":", info);
		}
		disp(detail.mime && itm.mime.length,
			"Mime", itm.mime);
		disp(detail.digest,
			"Digest", img.getDecryptedItem(idx).sha256Of.toHexString().dup);
		disp(detail.sign && itm.sign.length > 0,
			"Signature", Base64URLNoPadding.encode(itm.sign));
		disp(detail.sign && itm.modified !is SysTime.init,
			"Modified", itm.modified.toISOExtString());
		disp(detail.sign && itm.comment.length > 0,
			"Comment", itm.comment);
		disp(detail.sign && itm.extra !is JSONValue.init,
			"Extra", itm.extra.toPrettyString(JSONOptions.doNotEscapeSlashes));
	}
}
