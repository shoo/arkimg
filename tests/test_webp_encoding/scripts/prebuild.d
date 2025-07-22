module tests.test_webp_encoding.scripts.prebuild;

import std.file, std.path;
import std.zip;
import std.stdio;
import std.process;

enum webpUrl64 = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0-windows-x64.zip";
enum webpFile64 = "libwebp-windows-x86_64.zip";
enum webpUrl32 = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.0.3-windows-x86.zip";
enum webpFile32 = "libwebp-windows-x86.zip";

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

// webp.lib入手
version (Windows) version (X86_64)
void mainWin()
{
	if (exists("lib/windows-x86_64/webp.lib"))
		return;
	if (!exists(".tmp"))
		mkdirRecurse(".tmp");
	if (!exists("lib/windows-x86_64"))
		mkdirRecurse("lib/windows-x86_64");
	scope (exit)
		rmdirRecurse(".tmp");
	download(webpUrl64, ".tmp".buildPath(webpFile64));
	auto webpZip = new ZipArchive(std.file.read(".tmp".buildPath(webpFile64)));
	foreach (p, m; webpZip.directory)
	{
		auto path = buildPath(".tmp", p);
		//if (true && p[$-1] != '/')
		//{
		//	mkdirRecurse(path.dirName);
		//	std.file.write(path, webpZip.expand(m));
		//}
		if (path.baseName == "libwebp.lib")
		{
			std.file.write("lib/windows-x86_64/webp.lib", webpZip.expand(m));
			break;
		}
	}
	//std.file.copy(".tmp/libwebp-1.6.0-windows-x64/lib/libwebp.lib", "lib/windows-x86_64/webp.lib");
}
version (Windows) version (X86)
void mainWin()
{
	if (exists("lib/windows-x86/webp.lib"))
		return;
	if (!exists(".tmp"))
		mkdirRecurse(".tmp");
	if (!exists("lib/windows-x86"))
		mkdirRecurse("lib/windows-x86");
	scope (exit)
		rmdirRecurse(".tmp");
	download(webpUrl32, ".tmp".buildPath(webpFile32));
	auto webpZip = new ZipArchive(std.file.read(".tmp".buildPath(webpFile32)));
	foreach (p, m; webpZip.directory)
	{
		auto path = buildPath(".tmp", p);
		//if (true && p[$-1] != '/')
		//{
		//	mkdirRecurse(path.dirName);
		//	std.file.write(path, webpZip.expand(m));
		//}
		if (path.baseName == "libwebp.lib")
		{
			std.file.write("lib/windows-x86/webp.lib", webpZip.expand(m));
			break;
		}
	}
	//std.file.copy(".tmp/libwebp-1.6.0-windows-x64/lib/libwebp.lib", "lib/windows-x86_64/webp.lib");
}

void main()
{
	version (Windows)
		mainWin();
}
