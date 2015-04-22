#!/usr/bin/perl -w

use strictures 2;
use lib 'lib';
use t::lib;

foreach my $mod (@ARGV) {
  t::lib::prepare($mod);
}

