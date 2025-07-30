module src.main;

import std.exception;
import std.logger;
import arkimg;
import src.archive;
import src.extract;
import src.encrypt;
import src.decrypt;
import src.edit;
import src.remove;
import src.list;
import src.keyutil;
import src.help;


void setupLogger()
{
	import std.stdio;
	class MyLogger: StdForwardLogger
	{
		this(LogLevel lv) @safe
		{
			super(lv);
		}
		override void writeLogMsg(ref LogEntry payload) @trusted
		{
			stderr.writefln("[%s] %s", payload.logLevel, payload.msg);
		}
	}
	sharedLog = cast(shared) new MyLogger(LogLevel.info);
}

int main(string[] args)
{
	import std.getopt;
	import std.range, std.array, std.algorithm;
	import std.file, std.path;
	import std.string, std.ascii, std.conv;
	auto cmdArgs = args[1..$];
	setupLogger();
	int dispDefaultHelp(bool fallback = false)
	{
		import std.typecons, std.format, std.array;
		auto app = appender!string;
		app.formattedWrite("<CMD>:");
		foreach (t; [
			tuple("archive a",     "Archive secret files to arkimg."),
			tuple("extract x",     "Extract secret files from arkimg including."),
			tuple("encrypt enc e", "Encrypt and add file to arkimg."),
			tuple("decrypt dec d", "Decrypt and copy file from arkimg including."),
			tuple("list ls",       "List files arkimg including."),
			tuple("remove rm",     "Delete file from arkimg including."),
			tuple("edit",          "Edit file information of arkimg including."),
			tuple("keyutil",       "Make keys."),
			tuple("-h     --help", "Help messages."),
			tuple("--license",     "Display license information."),
			])
		{
			app.formattedWrite("\n%15s | %s", t[0], t[1]);
		}
		return fallback
			? dispFallbackHelp(args[0].baseName.stripExtension, "<CMD>", GetoptResult.init, app.data)
			: dispHelp(args[0].baseName.stripExtension, "<CMD>", GetoptResult.init, app.data);
	}
	if (cmdArgs.length == 0)
		return dispDefaultHelp(true);
	switch (cmdArgs[0])
	{
	case "help":
	case "h":
	case "-h":
		dispDefaultHelp();
		return 0;
	case "archive":
	case "a":
		return archiveCommand(cmdArgs);
	case "encrypt":
	case "enc":
	case "e":
		return encryptCommand(cmdArgs);
	case "decrypt":
	case "dec":
	case "d":
		return decryptCommand(cmdArgs);
	case "list":
	case "ls":
		return listCommand(cmdArgs);
	case "extract":
	case "x":
		return extractCommand(cmdArgs);
	case "edit":
		return editCommand(cmdArgs);
	case "rm":
	case "remove":
		return removeCommand(cmdArgs);
	case "keyutil":
		return keyutilCommand(cmdArgs);
	case "--license":
		return dispLicenseInfo(args[0].baseName.stripExtension);
	default:
		return dispDefaultHelp(true);
	}
	return 0;
}
