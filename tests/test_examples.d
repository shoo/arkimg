module tests.test_examples;

import std.process;
import std.exception;
import std.file;
import std.path;
import std.string;
import std.stdio;

void main()
{
	auto exeName = "arkimg";
	version (Windows)
		exeName = exeName.setExtension("exe");
	
	auto testDir = __FILE_FULL_PATH__.dirName;
	version (X86)         auto arch = "x86";
	else version (X86_64) auto arch = "x86_64";
	version (X86)         auto dmdm = "-m32";
	else version (X86_64) auto dmdm = "-m64";
	
	foreach (de; dirEntries(testDir.buildPath("..", "examples"), SpanMode.shallow))
	{
		if (!de.name.exists || !de.name.isDir || de.name.baseName.startsWith("."))
			continue;
		
		writeln(de.name, " testing...");
		
		auto result1 = execute(["dub", "test", "--coverage", "-a", arch, "-v",
			"--root", de.name,
			"--",
			"--DRT-covopt=dstpath:" ~ testDir.buildNormalizedPath("../.cov"),
			"--DRT-covopt=srcpath:" ~ testDir.buildNormalizedPath(".."),
			"--DRT-covopt=merge:1"],
			workDir: testDir.buildNormalizedPath(".."));
		assert(result1.status == 0, result1.output);
		auto result2 = execute(["dub", "build", "-b=cov", "-a", arch,
			"--root", de.name],
			workDir: testDir.buildNormalizedPath(".."));
		assert(result2.status == 0, result2.output);
		if (de.name.buildPath("tests").exists)
		{
			foreach (de2; dirEntries(de.name.buildPath("tests"), SpanMode.shallow))
			{
				if (de2.name.baseName.startsWith("."))
					continue;
				if (de2.isDir)
				{
					writeln("    ", de2.name, " testing...");
					auto result3 = execute(["dub", "-b=debug", "-a", arch, "run"], workDir: de2.name);
					assert(result3.status == 0, result3.output);
					writeln("    ", de2.name, " test completed.");
				}
				else if (de2.name.endsWith(".script.d"))
				{
					writeln("    ", de2.name, " testing...");
					auto result3 = execute(["dub", "-b=debug", "-a", arch, de2.name], workDir: de2.name.dirName);
					assert(result3.status == 0, result3.output);
					writeln("    ", de2.name, " test completed.");
				}
				else if (de2.extension == ".d")
				{
					writeln("    ", de2.name, " testing...");
					auto result3 = execute(["rdmd", "-debug", "-g", dmdm, de2.name], workDir: de2.name.dirName);
					assert(result3.status == 0, result3.output);
					writeln("    ", de2.name, " test completed.");
				}
				else
				{
					// DO-NOTHING
				}
			}
		}
		writeln(de.name, " test completed.");
	}
}
