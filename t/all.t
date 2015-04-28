#!perl -w

use Test::Most;

use lib '.';
use lib 'lib';
use t::lib;

my @tests = qw(foo bar foo1);

plan tests => scalar(@tests);

foreach my $mod (@tests) {
    subtest $mod => sub {
        eval { my ($x, $y) = load_doc($mod);
        is $x, $y, $mod;
    };
};
ok 1 if $@;
}

done_testing();
