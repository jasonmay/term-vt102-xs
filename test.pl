#!/usr/bin/env perl
use strict;
use warnings;
use blib;
use Term::VT102::XS;
use File::Slurp 'slurp';

my $v = Term::VT102::XS->new();

##$v->process( slurp 'out' );
#
#$v->process(
#    "\e[23;1H\e[24;1H\e[24;17H\e[K\r\e[24;17H11(11)\r\e[24;23H Pw:7(7) AC:9  Xp:1/0 T:2\e[17;12H\e[1m\e[37m\@\e[0m\e[18;12H<\e[0m\e[19;14H.\e[0m"
#     . "\e[A\e[A"
#    #. "\b\b\b"
#);


$v->process("hello\e[3");
warn $v->row_plaintext(1)."\n";
$v->process("7mTHERE");
warn $v->row_plaintext(1)."\n";
warn join(' ', grep { $_ != 32 } map { ord } split '', $v->row_plaintext(1));
