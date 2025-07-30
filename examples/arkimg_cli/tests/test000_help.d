module tests.test000_help;

import std.process;
import std.exception;
import std.file;
import std.string;
import std.conv;
import std.path;
import std.regex;

void main()
{
	auto exeName = "arkimg";
	version (Windows)
		exeName = exeName.setExtension("exe");
	auto exeBaseName = exeName.stripExtension;
	enum key    = "2E99C5EC3DB63E1594BFC2E8A83386B64A390511FD05B29EC868D110D41CB835";
	enum prvkey = "D047E070E48DE4DC11E639E8F44ED393740AD95217750F1410896C2A6A639CBE";
	enum pubkey = "BEE58C62F18257EFDFEBD311832AD05B3F26706DB32ECF49F99CCDC0D130F110";
	auto env    = ["ARKIMG_CLI_KEY": key, "ARKIMG_CLI_PRIVATE_KEY": prvkey, "ARKIMG_CLI_PUBLIC_KEY": pubkey];
	// Version
	auto versionInfo = std.file.readText("../views/version").chomp;
	auto tagName = versionInfo.replaceFirst(regex(`-\d+-g[0-9a-f]+$`), "");
	auto myLicense = versionInfo.startsWith("v0.0.0")
		? "https://github.com/shoo/arkimg/blob/main/LICENSE"
		: "https://github.com/shoo/arkimg/blob/" ~ tagName ~ "/LICENSE";
	
	// 通常実行
	auto result = execArkimgCli(["-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) <CMD> <OPTIONS>
		
		<CMD>:
		      archive a | Archive secret files to arkimg.
		      extract x | Extract secret files from arkimg including.
		  encrypt enc e | Encrypt and add file to arkimg.
		  decrypt dec d | Decrypt and copy file from arkimg including.
		        list ls | List files arkimg including.
		      remove rm | Delete file from arkimg including.
		           edit | Edit file information of arkimg including.
		        keyutil | Make keys.
		  -h     --help | Help messages.
		      --license | Display license information.
		`));
	
	// 引数なしで実行→エラー
	result = execArkimgCliFail(env: env);
	version (Windows)
		enum errCode = "-1";
	else
		enum errCode = "255";
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) <CMD> <OPTIONS>
		
		<CMD>:
		      archive a | Archive secret files to arkimg.
		      extract x | Extract secret files from arkimg including.
		  encrypt enc e | Encrypt and add file to arkimg.
		  decrypt dec d | Decrypt and copy file from arkimg including.
		        list ls | List files arkimg including.
		      remove rm | Delete file from arkimg including.
		           edit | Edit file information of arkimg including.
		        keyutil | Make keys.
		  -h     --help | Help messages.
		      --license | Display license information.
		Error Program exited with code $(errCode)
		`));
	
	// archive のヘルプ
	result = execArkimgCli(["a", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) a <OPTIONS>
		
		Archive files to arkimg.
		ex) $(exeBaseName) a -i input.png -o output.png -s=secret.txt -k=$(key) --prvkey=$(prvkey)
		<OPTIONS> of a:
		 -i      --in | * Input image file name.
		 -o     --out |   Output image file name including encrypted data.
		                  If not specified, the input image will be overwritten.
		                  In this case, the --force flag is required.
		 -s  --secret | * Directory path of the plaintext secret data.
		                  Alternatively, multiple files can also be specified.
		 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                  If neither is set, a random 16-byte sequence will be prepended to the data.
		                  It is recommended not to specify this for security reasons.
		     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_PRIVATE_KEY`") will be used.
		                  If neither is set, signing will not be performed.
		 -f   --force |   Overwrite the output file if it already exists.
		 -v --verbose |   Display verbose messages.
		 -h    --help |   This help information.
		`));
	
	// extract のヘルプ
	result = execArkimgCli(["x", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) x <OPTIONS>
		
		Extract and decrypt files from arkimg.
		ex) $(exeBaseName) x -i input.png -o output.png -s=secret.txt -k=$(key) --pubkey=$(pubkey)
		<OPTIONS> of x:
		 -i        --in | * Input arkimg file name.
		 -o       --out |   Output file name of secret data including arkimg.
		                    If not specified, the file name of the meta information will be used.
		                    And if there is no meta information, the default name will be used.
		 -k       --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                    If neither is set, a random 16-byte sequence will be prepended to the data.
		                    It is recommended not to specify this for security reasons.
		       --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_PUBLIC_KEY`") will be used.
		                    If neither is set, signing will not be performed.
		 -p --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
		 -f     --force |   Overwrite the output file if it already exists.
		 -v   --verbose |   Display verbose messages.
		 -h      --help |   This help information.
		`));
	
	// encrypt のヘルプ
	result = execArkimgCli(["e", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) e <OPTIONS>
		
		Encrypt and add file into arkimg.
		ex) $(exeBaseName) e -i input.png -o output.png -s=secret.txt -k=$(key) --prvkey=$(prvkey)
		<OPTIONS> of e:
		 -i      --in | * Input image file name.
		 -o     --out |   Output image file name including encrypted data.
		                  If not specified, the input image will be overwritten. In this case, the -f flag is required.
		 -s  --secret | * Directory path of the plaintext secret data. Alternatively, multi-files can also be specified.
		 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                  If neither is set, a random 16-byte sequence will be prepended to the data.
		                  It is recommended not to specify this for security reasons.
		     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_PRIVATE_KEY`") will be used.
		                  If neither is set, signing will not be performed.
		    --comment |   Specify comment messages of secret data.
		      --extra |   Specify JSON file of additional values of secret data.
		 -f   --force |   Overwrite the output file if it already exists.
		 -v --verbose |   Display verbose messages.
		 -h    --help |   This help information.
		`));
	
	// decrypt のヘルプ
	result = execArkimgCli(["d", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) d <OPTIONS>
		
		Decrypt files to arkimg.
		ex) $(exeBaseName) d -i input.png -o output.png -s=secret.txt -k=$(key) --pubkey=$(pubkey)
		<OPTIONS> of d:
		 -i        --in | * Input arkimg file name.
		 -o       --out |   Output file name of secret data including arkimg.
		                    If not specified, the file name of the meta information will be used.
		                    And if there is no meta information, the default name will be used.
		 -s    --secret | * Secret data file name or index includeing arkimg.
		 -k       --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                    If neither is set, a random 16-byte sequence will be prepended to the data.
		                    It is recommended not to specify this for security reasons.
		       --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_PUBLIC_KEY`") will be used.
		                    If neither is set, signing will not be performed.
		 -p --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
		 -f     --force |   Overwrite the output file if it already exists.
		 -v   --verbose |   Display verbose messages.
		 -h      --help |   This help information.
		`));
	
	// list のヘルプ
	result = execArkimgCli(["ls", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) ls <OPTIONS>
		
		List files arkimg including.
		ex) $(exeBaseName) ls -i input.png -k=$(key) --pubkey=$(pubkey)
		<OPTIONS> of ls:
		 -i            --in | * Input image file name.
		 -l      --location |   Location of directory path of the secret data for list base.
		 -k           --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                        If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		               --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                        If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                        If neither is set, a random 16-byte sequence will be prepended to the data.
		                        It is recommended not to specify this for security reasons.
		           --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
		                        If not specified, the environment variable $("`ARKIMG_CLI_PUBLIC_KEY`") will be used.
		                        If neither is set, signing will not be performed.
		 -p     --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
		 -d        --detail |   Enable detailed mode. Default: false
		             --json |   JSON output mode. Default: false
		      --disp-digest |   Display the digest(SHA-256) of the secret data in detail mode. Default: true
		        --disp-sign |   Display the  signature of the secret data in detail mode. Default: true
		        --disp-mime |   Display the mime type of the secret data in detail mode. Default: true Default: true
		    --disp-modified |   Display the last modified timestamp of the secret data in detail mode. Default: true
		     --disp-comment |   Display the comment of the secret data in detail mode. Default: true
		       --disp-extra |   Display the extra of the secret data in detail mode. Default: false
		 -v       --verbose |   Display verbose messages.
		 -h          --help |   This help information.
		`));
	
	// remove のヘルプ
	result = execArkimgCli(["rm", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) rm <OPTIONS>
		
		Edit files of arkimg.
		$(exeBaseName) rm -i input.png -o output.png -s=secret.txt -k=$(key) --prvkey=$(prvkey)
		<OPTIONS> of rm:
		 -i      --in | * Input arkimg file name.
		 -o     --out |   Output file name of secret data including arkimg.
		                  If not specified, the file name of the meta information will be used.
		                  And if there is no meta information, the default name will be used.
		 -s  --secret | * Specify secret data file name or index includeing arkimg to remove.
		 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                  If neither is set, a random 16-byte sequence will be prepended to the data.
		                  It is recommended not to specify this for security reasons.
		     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
		                  If not specified, the environment variable $("`ARKIMG_CLI_PRIVATE_KEY`") will be used.
		                  If neither is set, signing will not be performed.
		 -f   --force |   Overwrite the output file if it already exists.
		 -v --verbose |   Display verbose messages.
		 -h    --help |   This help information.
		`));
	
	// edit のヘルプ
	result = execArkimgCli(["edit", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) edit <OPTIONS>
		
		Edit files of arkimg.
		$(exeBaseName) edit -i input.png -o output.png -s=secret.txt -k=$(key) --prvkey=$(prvkey)
		<OPTIONS> of edit:
		 -i        --in | * Input arkimg file name.
		 -o       --out |   Output file name of secret data including arkimg.
		                    If not specified, the file name of the meta information will be used.
		                    And if there is no meta information, the default name will be used.
		 -s    --secret | * Specify secret data file name or index includeing arkimg to edit.
		 -k       --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		                    If neither is set, a random 16-byte sequence will be prepended to the data.
		                    It is recommended not to specify this for security reasons.
		       --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
		                    If not specified, the environment variable $("`ARKIMG_CLI_PRIVATE_KEY`") will be used.
		                    If neither is set, signing will not be performed.
		      --content |   Specify the file name containing the new content of the secret data.
		                    Specify only if you want to modify it.
		         --name |   Specify the new name of the secret data. Specify only if you want to modify it.
		     --mimetype |   Specify the mime type of the secret data. Specify only if you want to modify it.
		    --timestamp |   Specify the time stamp of the secret data. Specify only if you want to modify it.
		      --comment |   Specify the comment messages of the secret data. Specify only if you want to modify it.
		        --extra |   Specify JSON file of extra values of secret data. Specify only if you want to modify it.
		 -f     --force |   Overwrite the output file if it already exists.
		 -v   --verbose |   Display verbose messages.
		 -h      --help |   This help information.
		`));
	
	// keyutil のヘルプ
	result = execArkimgCli(["keyutil", "-h"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		USAGE: $(exeBaseName) keyutil <OPTIONS>
		
		Key utilities.
		ex) $(exeBaseName) keyutil --genkey --geniv --genprvkey --genpubkey
		<OPTIONS> of keyutil:
		 -k    --genkey |   Generate a common key for encryption/decryption.
		      --keysize |   Specify size of the common key in bit length. (default=128 or 192 or 256)
		          --key |   Specify common key for parameter output. Cannot be used together with --genkey/--keysize.
		                    If not specified, the environment variable $("`ARKIMG_CLI_KEY`") will be used.
		        --geniv |   Specify the IV for encryption in 16-byte hexadecimal format.
		                    If not specified, a random 16-byte sequence will be prepended to the data.
		                    It is recommended not to specify this for security reasons.
		           --iv |   Specify IV for parameter output. Cannot be used together with --geniv.
		                    If not specified, the environment variable $("`ARKIMG_CLI_IV`") will be used.
		    --genprvkey |   Generate a private key for sign.
		       --prvkey |   Specify the private key in 32 bytes hexadecimal format for generating the public key.
		                    If not specified, the environment variable $("`ARKIMG_CLI_PRIVATE_KEY`") will be used.
		    --genpubkey |   Generate a public key for verifying signature.
		       --pubkey |   Specify public key for parameter output. Cannot be used together with --genpubkey.
		                    If not specified, the environment variable $("`ARKIMG_CLI_PUBLIC_KEY`") will be used.
		       --base64 |   Generate keys with Base64 format (Base64 URL NoPadding).
		    --parameter |   Generate keys with parameter specs format.
		 -v   --verbose |   Display verbose messages.
		 -h      --help |   This help information.
		`));
	
	// keyutil のヘルプ
	result = execArkimgCli(["--license"], env: env);
	assert(result.compareStrings(i`
		ArkImg, the secret data image archiver. $(versionInfo)
		Copyright 2025 SHOO
		
		ArkImg: BSL-1.0 - $(myLicense)
		libpng (Deimos): BSL-1.0 - https://github.com/D-Programming-Deimos/libpng/master/dub.json
		libpng: zlib/libpng - https://libpng.org/pub/png/src/libpng-LICENSE.txt
		openssl-static: Apache-2.0 - https://github.com/bildhuus/deimos-openssl-static/blob/master/dub.sdl
		openssl (Deimos): OpenSSL or SSLeay - https://github.com/D-Programming-Deimos/openssl/blob/master/dub.sdl
		OpenSSL: Apache-2.0 - https://github.com/openssl/openssl/blob/master/LICENSE.txt
		`));
}

string uniqueName(string parent, string extension, string prefix = "")
{
	import std.path, std.uuid;
	return parent.buildPath(prefix ~ randomUUID.toString().setExtension(extension));
}

string createUniqueDir(string parent)
{
	import std.path, std.uuid;
	auto dir = buildNormalizedPath(parent, randomUUID.toString()).absolutePath();
	mkdirRecurse(dir);
	return dir;
}

bool compareStrings(ITxt...)(string a, ITxt txt)
{
	import std.conv;
	import std.stdio;
	immutable aLines = a.splitLines,
		b = text(txt).chompPrefix("\n").outdent,
		bLines = b.splitLines;
	void dispDiff(in string[] lhs, in string[] rhs)
	{
		writeln("Compare is failed.");
		writeln("--------------------------");
		import std.algorithm: levenshteinDistanceAndPath, EditOp;
		size_t lpos, rpos;
		foreach (op; lhs.levenshteinDistanceAndPath(rhs)[1])
		{
			final switch (op)
			{
			case EditOp.none:
				writefln("  %s", lhs[lpos++]);
				rpos++;
				break;
			case EditOp.substitute:
				writefln("- %s", lhs[lpos++]);
				writefln("+ %s", rhs[rpos++]);
				break;
			case EditOp.insert:
				writefln("+ %s", rhs[rpos++]);
				break;
			case EditOp.remove:
				writefln("- %s", lhs[lpos++]);
				break;
			}
		}
		writeln("--------------------------");
	}
	if (aLines.length == bLines.length)
	{
		if (aLines == bLines)
			return true;
		dispDiff(aLines[], bLines[]);
		return false;
	}
	if (!aLines[$-bLines.length - 1].startsWith("     Running")
		|| !aLines.endsWith(bLines))
	{
		dispDiff(aLines[$-bLines.length..$], bLines[]);
		return false;
	}
	return true;
}

auto execArkimgCliImpl(string[] args, string[string] env)
{
	version (X86)         auto arch = "x86";
	else version (X86_64) auto arch = "x86_64";
	auto scrDir = __FILE__.dirName;
	auto projectRootDir = scrDir.buildNormalizedPath("../../..").absolutePath();
	auto arkimgCliRootDir = scrDir.buildNormalizedPath("..").absolutePath();
	auto dubArgs = [
		"-a", arch,
		"-b", "cov",
		"--root", arkimgCliRootDir];
	auto runArgs = [
		"--DRT-covopt=dstpath:" ~ projectRootDir.buildPath(".cov"),
		"--DRT-covopt=srcpath:" ~ projectRootDir,
		"--DRT-covopt=merge:1"];
	return execute(["dub", "run"] ~ dubArgs ~ ["--"] ~ args ~ runArgs, workDir: projectRootDir, env: env);
}
string execArkimgCli(string[] args = null, string[string] env = null)
{
	auto result = execArkimgCliImpl(args, env);
	enforce(result.status == 0, result.output);
	return result.output;
}

string execArkimgCliFail(string[] args = null, string[string] env = null)
{
	auto result = execArkimgCliImpl(args, env);
	enforce(result.status != 0, result.output);
	return result.output;
}
