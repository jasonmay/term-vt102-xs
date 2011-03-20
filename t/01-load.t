#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More tests => 2;

use_ok "Term::VT102::XS";

my $vt = Term::VT102::XS->new ('cols' => 80, 'rows' => 25);
ok($vt);

