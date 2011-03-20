#!/usr/bin/env perl
use strict;
use warnings;
use blib;
use Term::VT102::XS;

my $v = Term::VT102::XS->new();

$v->process("hello\njasong\bmay\n");
warn $v->row_plaintext(1);
warn $v->row_plaintext(2);

