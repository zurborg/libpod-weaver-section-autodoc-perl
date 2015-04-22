#!perl -w

use Test::Most;

use lib '.';
use lib 'lib';
use t::lib;

my @tests = qw(foo bar);

plan tests => scalar(@tests);

foreach my $mod (@tests) {
    my ($a, $b) = load_doc($mod);
    is $a, $b, $mod;
}

done_testing();
