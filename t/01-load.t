#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use_ok "Term::VT102::XS";

my $vt = Term::VT102::XS->new ('cols' => 80, 'rows' => 25);
ok($vt);

done_testing();

# EOF
