#!/usr/bin/env perl
use strict;
use warnings;
use blib;
use Term::VT102::XS;

my $v = Term::VT102::XS->new(cols => 11);

$v->process("0123\e[32m45\e[0m67890");
warn $v->row_plaintext(1);
warn join(" ", map { ord } split '', $v->row_attr(1));

