module tests.test_examples;

import std.process;
import std.exception;
import std.file;
import std.path;
import std.string;
import std.json;
import std.stdio;

void main()
{
	auto exeName = "arkimg";
	version (Windows)
		exeName = exeName.setExtension("exe");
	
	auto testDir = __FILE_FULL_PATH__.dirName.absolutePath();
	auto projDir = testDir.buildNormalizedPath("..");
	version (X86)         auto arch = "x86";
	else version (X86_64) auto arch = "x86_64";
	version (X86)         auto dmdm = "-m32";
	else version (X86_64) auto dmdm = "-m64";
	
	foreach (de; dirEntries(projDir.buildPath("examples"), SpanMode.shallow))
	{
		if (!de.name.exists || !de.name.isDir || de.name.baseName.startsWith("."))
			continue;
		
		writeln(de.name, " testing...");
		
		auto desc = execute(["dub", "describe", "--verror", "-a", arch,
			"-b=unittest-cov", "-c=unittest", "--root", de.name],
			workDir: projDir).output.parseJSON();
		auto targetExe = buildNormalizedPath(
			desc["packages"][0]["path"].str,
			desc["packages"][0]["targetPath"].str,
			desc["packages"][0]["targetFileName"].str);
		auto utResult1 = execute(["dub", "build", "-a", arch,
			"-b=unittest-cov", "-c=unittest", "--root", de.name],
			workDir: projDir);
		assert(utResult1.status == 0, utResult1.output);
		auto utResult2 = execute([targetExe,
			"--DRT-covopt=dstpath:" ~ projDir.buildNormalizedPath(".cov"),
			"--DRT-covopt=srcpath:" ~ projDir,
			"--DRT-covopt=merge:1"], workDir: testDir);
		assert(utResult2.status == 0, utResult2.output);
		auto buildResult = execute(["dub", "build", "-a", arch, "-b=release",
			"--root", de.name],
			workDir: projDir);
		assert(buildResult.status == 0, buildResult.output);
		
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
