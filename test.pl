#!/usr/bin/env perl
use strict;
use warnings;
use blib;
use Term::VT102::XS;

my $v = Term::VT102::XS->new(cols => 4);

$v->process("0123\e[Dh\e[D\e[Do");
warn $v->row_plaintext(1);

