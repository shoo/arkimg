module arkimg._internal.misc;

package(arkimg):
import std.json;
import std.traits;

ref JSONValue req(T)(ref JSONValue jv, string key, lazy T value = T.init) @safe
{
	return jv.req(key, JSONValue(value));
}
ref JSONValue req(T: JSONValue)(ref JSONValue jv, string key, lazy T defaultValue = T.init) @trusted
{
	if (jv.type != JSONType.object)
		jv = JSONValue.emptyObject;
	return jv.object.require(key, defaultValue);
}

ref JSONValue req(T)(ref JSONValue jv, size_t idx, lazy T value = T.init) @safe
{
	jv.req(key, JSONValue(value));
}
ref JSONValue req(T: JSONValue)(ref JSONValue jv, size_t idx, lazy T defaultValue = T.init) @trusted
{
	if (jv.type != JSONType.array)
		jv = JSONValue.emptyArray;
	if (idx < jv.array.length)
		return jv.array[idx];
	jv.array.length = idx + 1;
	return jv.array[idx];
}
ref JSONValue reqo(ref JSONValue jv, string key) @trusted
{
	return jv.req(key, JSONValue.emptyObject);
}
ref JSONValue reqo(ref JSONValue jv, size_t idx) @trusted
{
	return jv.req(idx, JSONValue.emptyObject);
}
ref JSONValue reqa(ref JSONValue jv, string key) @trusted
{
	return jv.req(key, JSONValue.emptyArray);
}
ref JSONValue reqa(ref JSONValue jv, size_t idx) @trusted
{
	return jv.req(idx, JSONValue.emptyArray);
}

unittest
{
	auto jv = JSONValue.emptyObject;
	jv.req!string("test").str = "test1";
	assert(jv["test"].str == "test1");
}

auto assumePure(T)(T t)
if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

auto assumeNogc(T)(T t)
if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.nogc_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

auto assumeNothrow(T)(T t)
if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.nothrow_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}
