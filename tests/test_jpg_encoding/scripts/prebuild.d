module tests.test_jpg_encoding.scripts.prebuild;

import std.file;
import std.net.curl;
import std.process;

enum sevenZip1Url = "https://www.7-zip.org/a/7zr.exe";
enum sevenZip2Url = "https://www.7-zip.org/a/7z2500-x64.exe";
enum sevenZip2Url32 = "https://www.7-zip.org/a/7z2500.exe";
enum libjpgturboUrl = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.1/libjpeg-turbo-3.1.1-vc-x64.exe";
enum libjpgturboUrl32 = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.1/libjpeg-turbo-3.1.1-vc-x86.exe";

void download(string url, string file)
{
	try
	{
		import std.net.curl;
		std.net.curl.download(url, file);
	}
	catch (Exception e)
	{
		import std.process;
		spawnProcess(["curl", "-L", "-o", file, url]).wait();
	}
}

// jpegturbo.lib入手
version (Windows) version (X86_64)
void mainWin()
{
	if (exists("lib/windows-x86_64/turbojpeg.lib"))
		return;
	if (!exists(".tmp"))
		mkdirRecurse(".tmp");
	if (!exists("lib/windows-x86_64"))
		mkdirRecurse("lib/windows-x86_64");
	scope (exit)
		rmdirRecurse(".tmp");
	string exe7z = "7z.exe";
	if (executeShell("where 7z.exe").status != 1000)
	{
		download(sevenZip1Url, ".tmp/7zr.exe");
		download(sevenZip2Url, ".tmp/7z2500-x64.exe");
		spawnProcess([".tmp/7zr.exe", "x", ".tmp/7z2500-x64.exe", "-o.tmp/7z"]).wait();
		spawnProcess([".tmp/7z/7z.exe", "x", ".tmp/libjpeg-turbo-3.1.1-vc-x64.exe", "-o.tmp/libjpeg-turbo"]).wait();
		exe7z = ".tmp/7z/7z.exe";
	}
	download(libjpgturboUrl, ".tmp/libjpeg-turbo-3.1.1-vc-x64.exe");
	spawnProcess([exe7z, "x", ".tmp/libjpeg-turbo-3.1.1-vc-x64.exe", "-o.tmp/libjpeg-turbo"]).wait();
	std.file.copy(".tmp/libjpeg-turbo/lib/turbojpeg-static.lib", "lib/windows-x86_64/turbojpeg.lib");
}

version (Windows) version (X86)
void mainWin()
{
	if (exists("lib/windows-x86/turbojpeg.lib"))
		return;
	if (!exists(".tmp"))
		mkdirRecurse(".tmp");
	if (!exists("lib/windows-x86"))
		mkdirRecurse("lib/windows-x86");
	scope (exit)
		rmdirRecurse(".tmp");
	string exe7z = "7z.exe";
	if (executeShell("where 7z.exe").status != 1000)
	{
		download(sevenZip1Url, ".tmp/7zr.exe");
		download(sevenZip2Url32, ".tmp/7z2500-x86.exe");
		spawnProcess([".tmp/7zr.exe", "x", ".tmp/7z2500-x86.exe", "-o.tmp/7z"]).wait();
		spawnProcess([".tmp/7z/7z.exe", "x", ".tmp/libjpeg-turbo-3.1.1-vc-x86.exe", "-o.tmp/libjpeg-turbo"]).wait();
		exe7z = ".tmp/7z/7z.exe";
	}
	download(libjpgturboUrl32, ".tmp/libjpeg-turbo-3.1.1-vc-x86.exe");
	spawnProcess([exe7z, "x", ".tmp/libjpeg-turbo-3.1.1-vc-x86.exe", "-o.tmp/libjpeg-turbo"]).wait();
	std.file.copy(".tmp/libjpeg-turbo/lib/turbojpeg-static.lib", "lib/windows-x86/turbojpeg.lib");
}

void main()
{
	version (Windows)
		mainWin();
}
