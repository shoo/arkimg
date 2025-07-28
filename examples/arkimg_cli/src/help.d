module src.help;

import std.getopt;

/*******************************************************************************
 * 
 */
int dispHelp(string exePath, string cmdName, GetoptResult result, string msg)
{
	import std.stdio, std.path, std.algorithm, std.range, std.conv;
	if (result.options.length > 0)
		writefln("%s %s <OPTIONS>\n\n%s\n<OPTIONS> of %s:", exePath.baseName, cmdName, msg, cmdName);
	else
		writefln("%s %s <OPTIONS>\n\n%s", exePath.baseName, cmdName, msg);
	auto optMaxLen = result.options.map!(x => x.optLong.length).chain(9.only).maxElement;
	foreach (opt; result.options)
	{
		import std.string;
		auto lines = opt.help.splitLines;
		foreach (idx; 0..lines.length)
		{
			if (idx == 0)
				writefln(text(i"%3s %$(optMaxLen)s | %s%s"), opt.optShort, opt.optLong, opt.required ? "* " : "  ", lines[idx]);
			else
				writefln(text(i"    %$(optMaxLen)s     %s"), "", lines[idx]);
		}
	}
	return 0;
}

/// ditto
int dispFallbackHelp(string exePath, string cmdName, GetoptResult result, string msg)
{
	cast()dispHelp(exePath, cmdName, result, msg);
	return -1;
}
