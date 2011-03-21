#!/usr/bin/env perl
use strict;
use warnings;
use blib;
use Term::VT102::XS;

my $v = Term::VT102::XS->new(cols => 4);

$v->process("0\e[32m12\e[m3");
warn $v->row_plaintext(1);
warn join(" ", map { ord } split '', $v->row_attr(1));

