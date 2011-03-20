#!/usr/bin/perl -w
#
# Make sure the VT102 module can set its size OK.
#
# Copyright (C) Andrew Wood
# NO WARRANTY - see COPYING.
#

require Term::VT102::XS;
use Test::More;

@testsizes = (
  1, 1,
  80, 24,
  0, 0,
  -1000, -1000,
  1000, 1000
);

$nt = ($#testsizes + 1) / 2;		# number of sub-tests
plan tests => $nt;

foreach my $i (1 .. $nt) {

	$cols = shift @testsizes;
	$rows = shift @testsizes;

	my $vt = Term::VT102::XS->new ('cols' => $cols, 'rows' => $rows);

	($ncols, $nrows) = $vt->size ();

	$cols = 80 if ($cols < 1);
	$rows = 24 if ($rows < 1);

	ok (($cols == $ncols && $rows == $nrows),
		"returned size: $ncols x $nrows, wanted $cols x $rows\n");
}

