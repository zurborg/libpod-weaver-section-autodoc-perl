package foo;

use Method::Signatures::WithDocumentation;

func ffoo ($A, $B, $C?, $D = 1) :
    Purpose(
        ffoo_purpose
    )
    Example(
        ffoo_example
    )
    Param(
        $A: ffoo_a
    )
    Param(
        $B: ffoo_b
    )
    Param(
        $C: ffoo_c
    )
    Pod(
        ffoo_pod1
    )
    Pod(
        ffoo_pod2
    )
    Author(
        ffoo_author1
    )
    Author(
        ffoo_author2
    )
    Deprecated(
        ffoo_deprecated
    )
    Returns(
        ffoo_returns
    )
    Throws(
        ffoo_throws1
    )
    Throws(
        ffoo_throws2
    )
    Since(
        ffoo_since
    )
{
    ...
}

method mfoo (Int :$A, Str \:$B, Int|Str :$C!, :$D = 2 when { 1 == 0 }) :
    Purpose(
        mfoo_purpose
    )
    Example(
        mfoo_example
    )
    Param(
        $A: mfoo_a
    )
    Param(
        $B: mfoo_b
    )
    Param(
        $C: mfoo_c
    )
    Pod(
        mfoo_pod1
    )
    Pod(
        mfoo_pod2
    )
    Author(
        mfoo_author1
    )
    Author(
        mfoo_author2
    )
    Deprecated(
        mfoo_deprecated
    )
    Returns(
        mfoo_returns
    )
    Throws(
        mfoo_throws1
    )
    Throws(
        mfoo_throws2
    )
    Since(
        mfoo_since
    )
{
    ...
}

1;
