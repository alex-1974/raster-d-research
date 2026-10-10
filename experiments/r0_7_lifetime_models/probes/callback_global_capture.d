module callback_global_capture;
struct View { const(ubyte)[] data; }
View escaped;
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(scope View) @safe visitor)
{
    visitor(View(input));
}
@safe void leakViaMatchingDelegate(scope const(ubyte)[] input)
{
    // The explicit scope parameter matches the callback signature.
    withBorrow(input, (scope View v) @safe { escaped = v; });
}
