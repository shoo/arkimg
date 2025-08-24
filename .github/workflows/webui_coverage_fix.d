import std.file, std.path;
import std.json;
import std.getopt;
import std.stdio;
import std.array;

int main(string[] args)
{
	string target;
	string base;
	string dst;
	string[string] remap;
	args.getopt(
		"target|t", &target,
		"base|b", &base,
		"output|o", &dst,
		"remap", &remap);
	target = target.absolutePath();
	dst = dst.absolutePath();
	if (base is null)
		base = dst.dirName;
	base = base.absolutePath();
	auto report = parseJSON(std.file.readText(target));
	if (report.type != JSONType.object)
	{
		stderr.writeln("Invalid coverage report.");
		return -1;
	}
	auto dstJson = JSONValue.emptyObject;
	foreach (k, v; report.object)
	{
		if (v.type != JSONType.object || "path" !in v || v["path"].type != JSONType.string)
		{
			stderr.writeln("Invalid coverage report.");
			return -1;
		}
		auto p = v["path"].str;
		if (k != p)
		{
			stderr.writeln("Invalid coverage report.");
			return -1;
		}
		foreach (remapFrom, remapTo; remap)
			p = std.array.replace(p, remapFrom, remapTo);
		// WindowsであってもPosixパスに統一する
		auto relPath = std.array.replace(relativePath(p, base), "\\", "/");
		if (!relPath.exists || filenameCmp(relPath.absolutePath().buildNormalizedPath(), p.buildNormalizedPath()) != 0)
		{
			stderr.writeln("Invalid base path: " ~ relPath);
			return -1;
		}
		v["path"].str = relPath;
		dstJson[relPath] = v;
	}
	std.file.write(dst, dstJson.toString(JSONOptions.doNotEscapeSlashes));
	return 0;
}
