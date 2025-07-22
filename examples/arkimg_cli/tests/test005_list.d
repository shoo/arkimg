module examples.arkimg_cli.tests.test005_list;

import std.process;
import std.exception;
import std.file, std.path;
import std.string;

enum key = "072114BC7EA8982948A274691A580E65F306B3C6E1B6807399DAF739882C515E";

void main()
{
	immutable scrFile = __FILE_FULL_PATH__;
	immutable scrDir = scrFile.dirName.absolutePath;
	immutable rsDir = scrDir.buildPath(".common");
	immutable rsBaseImg = rsDir.buildPath("d-man.png");
	immutable rsSecretDir = rsDir.buildPath("testdir");
	immutable tempDir = createUniqueDir(scrDir.buildPath(".common"));
	scope (exit)
		rmdirRecurse(tempDir);
	immutable testFile = tempDir.uniqueName(".png");
	
	auto result = execArkimgCli(["archive", "-i", rsBaseImg, "-o", testFile, "-s", rsSecretDir, "-k", key, "-v"]);
	assert(result.compareStrings(i`
		[info] Add test.txt (text/plain)
		[info] Save $(testFile)
	`));
	
	result = execArkimgCli(["list", "-i", testFile, "-k", key, "-v"]);
	assert(result.compareStrings(i`
		test.txt
		`));
	
	result = execArkimgCli(["list", "-i", testFile, "-k", key, "-d", "-v"]);
	assert(result.compareStrings(i`
		test.txt
		    Mime:      text/plain
		    Digest:    636B9E305E2155FC427742787BBCC78267C465E5EA66843212BC13AF973C13F8
		    Modified:  $(rsSecretDir.buildPath("test.txt").timeLastModified.toLocalTime().toISOExtString())
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
