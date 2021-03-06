#!/usr/bin/perl -w
#
# Test XOFF and XON.
#
# Copyright (C) Andrew Wood
# NO WARRANTY - see COPYING.
#

require Term::VT102::XS;
require 't/testbase';

run_tests ([(
#              (F,B,b,f,s,u,F,r)
  [ { 'IGNOREXOFF' => 0 },
    6, 2, "foo\023bar\e[1m\021baz",
    "foobaz", [ [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0] ],
    "\0\0\0\0\0\0",
             [ [7,0,0,0,0,0,0,0],
               [7,0,0,0,0,0,0,0],
               [7,0,0,0,0,0,0,0],
               [7,0,0,0,0,0,0,0],
               [7,0,0,0,0,0,0,0],
               [7,0,0,0,0,0,0,0] ],
  ],
  [ { 'IGNOREXOFF' => 1 },
    9, 1, "foo\023bar\e[1m\021baz",
    "foobarbaz",
              [ [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,0,0,0,0,0,0],
                [7,0,1,0,0,0,0,0],
                [7,0,1,0,0,0,0,0],
                [7,0,1,0,0,0,0,0] ],
  ],
)]);

# EOF
