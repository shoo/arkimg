module scripts.prebuild;

import std.process;
import std.file, std.path;
import std.string, std.regex;

void main()
{
	auto viewDir = __FILE_FULL_PATH__.dirName.dirName.absolutePath().buildPath("views");
	auto result = execute(["git", "describe", "--tags"]);
	string versionInfo;
	if (result.status != 0)
	{
		result = execute(["git", "describe", "--tags", "--always"]);
		versionInfo = "v0.0.0-0-g" ~ (result.status != 0 ? "0000000" : result.output.chomp);
	}
	else
	{
		versionInfo = result.output.chomp;
	}
	if (!viewDir.buildPath("version").exists || viewDir.buildPath("version").readText().chomp != versionInfo)
		std.file.write(viewDir.buildPath("version"), versionInfo);
}
