package bar;

use base 'foo';

use Method::Signatures::WithDocumentation;

method mbar :
    Purpose(
        mfoo_purpose
    )
{
    ...
}

1;
