#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <stdio.h>

#define DEFAULT_COLS 80
#define DEFAULT_ROWS 24

#define CHAR_CTL_NUL  0
#define CHAR_CTL_ENQ  5
#define CHAR_CTL_BEL  7
#define CHAR_CTL_BS   8
#define CHAR_CTL_HT   9
#define CHAR_CTL_LF   10
#define CHAR_CTL_VT   11
#define CHAR_CTL_FF   12
#define CHAR_CTL_CR   13
#define CHAR_CTL_SO   14
#define CHAR_CTL_SI   15
#define CHAR_CTL_XON  17
#define CHAR_CTL_XOFF 19
#define CHAR_CTL_CAN  24
#define CHAR_CTL_SUB  26
#define CHAR_CTL_ESC  27
#define CHAR_CTL_DEL  127
#define CHAR_CTL_CSI  255

#define CHAR_ESC_RIS     "c"
#define CHAR_ESC_IND     "D"
#define CHAR_ESC_NEL     "E"
#define CHAR_ESC_HTS     "H"
#define CHAR_ESC_RI      "M"
#define CHAR_ESC_DECID   "Z"
#define CHAR_ESC_DECSC   "7"
#define CHAR_ESC_DECRC   "8"
#define CHAR_ESC_CSI     "["
#define CHAR_ESC_IGN     "[["
#define CHAR_ESC_CSDFL   "%@"
#define CHAR_ESC_CSUTF8  "%G"
#define CHAR_ESC_CSUTF8  "%8"
#define CHAR_ESC_DECALN  "#8"
#define CHAR_ESC_G0DFL   "(8"
#define CHAR_ESC_G0GFX   "(0"
#define CHAR_ESC_G0ROM   "(U"
#define CHAR_ESC_G0USR   "(K"
#define CHAR_ESC_G0TXT   "(B"
#define CHAR_ESC_G1DFL   ")8"
#define CHAR_ESC_G1GFX   ")0"
#define CHAR_ESC_G1ROM   ")U"
#define CHAR_ESC_G1USR   ")K"
#define CHAR_ESC_G1TXT   ")B"
#define CHAR_ESC_G2DFL   "*8"
#define CHAR_ESC_G2GFX   "*0"
#define CHAR_ESC_G2ROM   "*U"
#define CHAR_ESC_G2USR   "*K"
#define CHAR_ESC_G3DFL   "+8"
#define CHAR_ESC_G3GFX   "+0"
#define CHAR_ESC_G3ROM   "+U"
#define CHAR_ESC_G3USR   "+K"
#define CHAR_ESC_DECPNM  ">"
#define CHAR_ESC_DECPAM  "="
#define CHAR_ESC_SS2     "N"
#define CHAR_ESC_SS3     "O"
#define CHAR_ESC_DCS     "P"
#define CHAR_ESC_SOS     "X"
#define CHAR_ESC_PM      "^"
#define CHAR_ESC_APC     "_"
#define CHAR_ESC_ST      "\\"
#define CHAR_ESC_LS2     "n"
#define CHAR_ESC_LS3     "o"
#define CHAR_ESC_LS3R    "|"
#define CHAR_ESC_LS2R    "}"
#define CHAR_ESC_LS1R    "~"
#define CHAR_ESC_OSC     "]"
#define CHAR_ESC_BEL     "g"

#define COLOR_RED     1
#define COLOR_GREEN   2
#define COLOR_YELLOW  3
#define COLOR_BLUE    4
#define COLOR_MAGENTA 5
#define COLOR_CYAN    6
#define COLOR_WHITE   7

#define COLOR_DARK  0
#define COLOR_LIGHT 1

#define _GET_SWITCHES(V, O) V = INT2PTR(SWITCHES*, SvIV(SvRV(O)))

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

    /* internal toggles */

    I8 in_esc;
} VT_SWITCHES;

SV* _process(SV* sv_buf)
{
    char* buf = SvPV(sv_buf, PL_na);

    if (buf[0]) buf[0] = 'Z';

    return sv_buf;
}

void _init(SV* self)
{
    SWITCHES* switches;
    _GET_SWITCHES(switches, self);

    switches->x = switches->y = 1;

    switches->cols = DEFAULT_COLS;
    switches->rows = DEFAULT_ROWS;
}

MODULE = Term::VT102::XS        PACKAGE = Term::VT102::XS

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

    _init(self);

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
