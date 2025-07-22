module tests.test008_keyutil;

import std.process;
import std.exception;
import std.file, std.path;
import std.string;
import std.regex;

void main()
{
	immutable scrFile = __FILE_FULL_PATH__;
	immutable scrDir = scrFile.dirName.absolutePath;
	
	auto result = execArkimgCli(["keyutil", "--genkey", "--genprvkey", "--genpubkey", "-v"]);
	
	string key;
	string prvkey;
	string pubkey;
	if (auto m = result.matchFirst(regex(r"^CommonKey:  ([0-9A-F]{32})$", "m")))
		key = m.captures[1].dup;
	assert(key.length > 0, result);
	if (auto m = result.matchFirst(regex(r"^PrivateKey: ([0-9A-F]{64})$", "m")))
		prvkey = m.captures[1].dup;
	assert(prvkey.length > 0, result);
	if (auto m = result.matchFirst(regex(r"^PublicKey:  ([0-9A-F]{64})$", "m")))
		pubkey = m.captures[1].dup;
	assert(pubkey.length > 0, result);
	assert(result.compareStrings(i`
		CommonKey:  $(key)
		PrivateKey: $(prvkey)
		PublicKey:  $(pubkey)
		`));
	
	string pubkey2;
	result = execArkimgCli(["keyutil", "--prvkey", prvkey, "--genpubkey", "-v"]);
	if (auto m = result.matchFirst(regex(r"^PublicKey:  ([0-9A-F]{64})$", "m")))
		pubkey2 = m.captures[1].dup;
	assert(pubkey == pubkey2, result);
	assert(result.compareStrings(i`
		PublicKey:  $(pubkey2)
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
	if (!aLines[$-bLines.length - 1].startsWith("     Running")
		|| !aLines.endsWith(bLines))
	{
		writeln("----------\n", a, "\n-----\n", b, "\n----------");
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
	enforce(result.status == 0);
	return result.output;
}

string execArkimgCliFail(string[] args = null, string[string] env = null)
{
	auto result = execArkimgCliImpl(args, env);
	enforce(result.status != 0);
	return result.output;
}
