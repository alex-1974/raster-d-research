module callback_scope_positive;
struct View { const(ubyte)[] data; }
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(scope View) @safe visitor)
{
    visitor(View(input));
}
@safe void consume(scope const(ubyte)[] input)
{
    withBorrow(input, (scope View v) @safe { assert(v.data.length <= size_t.max); });
}
