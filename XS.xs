#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <stdio.h>

#define CHAR_ESC 27
#define CHAR_BEL 7
#define CHAR_CR 13
#define CHAR_LF 10

#define COLOR_RED     1
#define COLOR_GREEN   2
#define COLOR_YELLOW  3
#define COLOR_BLUE    4
#define COLOR_MAGENTA 5
#define COLOR_CYAN    6
#define COLOR_WHITE   7

#define COLOR_DARK  0
#define COLOR_LIGHT 1

typedef struct _VT_OPTIONS {
    I8 linewrap;
    I8 lftocrlf;
    I8 ignorexoff;
    I16  attr; /* uh, whatever pack('S', $foo); returns */
} VT_OPTIONS;

typedef struct _VT_SWITCHES {
    I32 x;
    I32 y;
    I32 cols;
    I32 rows;
    I32 cursor;
    AV* scra;
    AV* scrt;
    SV* buf;

    VT_OPTIONS options;

} VT_SWITCHES;

SV* _process(SV* sv_buf)
{
    char* buf = SvPV(sv_buf, PL_na);

    if (buf[0]) buf[0] = 'Z';

    return sv_buf;
}

MODULE = Term::VT102::XS		PACKAGE = Term::VT102::XS

PROTOTYPES: DISABLE

SV*
new(class)
    SV* class
  PREINIT:
    SV* self;
    VT_SWITCHES *switches;
    SV* isv;
  CODE:
    New(0, switches, 1, VT_SWITCHES);

    isv = newSViv( PTR2IV(switches) );

    self = newRV(isv);

    sv_bless(self, gv_stashsv(class, 0));
    RETVAL = self;
  OUTPUT:
    RETVAL

SV*
process(self, buf)
    SV* buf
  CODE:
    if (!SvPOK(buf))
        croak("Argument must be a string");

    RETVAL = _process(buf);
  OUTPUT:
    RETVAL
