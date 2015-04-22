package bar;

our $VERSION = 1;

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
