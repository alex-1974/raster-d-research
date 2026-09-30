module callable_contract;


/++
    Research-only compile-time point-transform callable prototype.

    The wrapper deliberately carries the strongest desired library attributes.
    D must reject a transform alias whose body cannot satisfy them.
+/
void applyPointTransform(alias transform, T)(
    scope const(T)[] source,
    scope T[] destination
)
@safe
pure
nothrow
@nogc
{
    assert(source.length == destination.length);

    foreach (i; 0 .. source.length)
        destination[i] = transform(source[i]);
}


@safe
pure
nothrow
@nogc
float validTransform(float value)
{
    return value + 1.0f;
}


float impureState;

@safe
nothrow
@nogc
float impureTransform(float value)
{
    impureState = value;
    return value;
}


@safe
pure
float throwingTransform(float value)
{
    if (value < 0)
        throw new Exception("negative");

    return value;
}


@safe
pure
nothrow
float allocatingTransform(float value)
{
    auto storage = new float[1];
    storage[0] = value;
    return storage[0];
}


@system
pure
nothrow
@nogc
float systemTransform(float value)
{
    return value;
}


private void instantiate(alias transform)()
{
    float[1] source = [1.0f];
    float[1] destination;

    applyPointTransform!transform(
        source[],
        destination[]
    );
}


static assert(
    __traits(compiles, instantiate!validTransform())
);

static assert(
    !__traits(compiles, instantiate!impureTransform())
);

static assert(
    !__traits(compiles, instantiate!throwingTransform())
);

static assert(
    !__traits(compiles, instantiate!allocatingTransform())
);

static assert(
    !__traits(compiles, instantiate!systemTransform())
);
