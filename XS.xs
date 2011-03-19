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

#define _IS_CTL(C) ((C) >= 0 && (C) < 32)

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

#define _GET_SWITCHES(V, O) V = INT2PTR(VT_SWITCHES*, SvIV(SvRV(O)))

typedef struct _VT_OPTIONS {
    I8 linewrap;
    I8 lftocrlf;
    I8 ignorexoff;
    I16  attr;
} VT_OPTIONS;

typedef struct _VT_CELL {
    I16  attr;
    char value;
    I8   used;
} VT_CELL;

typedef struct _VT_ROW {
    VT_CELL *cells; /* array of cells (switches->num_cols) */
} VT_ROW;

typedef struct _VT_SWITCHES {
    I32 x;
    I32 y;
    I32 num_cols;
    I32 num_rows;
    I32 cursor;

    VT_ROW *rows; /* array of rows (switches->num_rows) */

    SV* buf;

    VT_OPTIONS options;

    /* internal toggles */
    I8 in_esc;
    I8 xon;

} VT_SWITCHES;

SV* _process_ctl(SV* self, char **buf)
{
    VT_SWITCHES* switches;
    _GET_SWITCHES(switches, self);

    char c = **buf;
    *buf++;

    if ( switches->xon == 0 )
        return;

    if (c == CHAR_CTL_BS)
        if(switches->x > 0) --switches->x;

    if (c == CHAR_CTL_LF) {
        switches->x = 0;
        if (switches->y < switches->num_rows-1) switches->y++;
    }
}

STATIC I32 _process_text(SV* self, char **buf)
{
    VT_SWITCHES* switches;
    VT_CELL *cell;
    _GET_SWITCHES(switches, self);

    cell = &switches->rows[switches->y].cells[switches->x];

    cell->value = **buf;
    cell->used  = 1;

    switches->x++;
    if (switches->x > switches->num_rows-1) {
        switches->x = 0;
    }

    (*buf)++;

    return 0;
}

void _init(VT_SWITCHES *switches)
{
    int x, y;

    /* allocate rows */
    New(0, switches->rows, switches->num_rows, VT_ROW);

    for (y = 0; y < switches->num_rows; ++y) {

        /* allocate cells for row y */
        New(0, switches->rows[y].cells, switches->num_cols, VT_CELL);

        for (x = 0; x < switches->num_cols; ++x) {
            switches->rows[y].cells[x].attr = 0;
            switches->rows[y].cells[x].used = 0;
            switches->rows[y].cells[x].value = '\0';
        }
    }
}

SV* _process(SV* self, SV* sv_in)
{
    char *buf = SvPV_nolen(sv_in);
    STRLEN c;

    while (*buf != '\0') {

        if ( _IS_CTL( *buf ) ) {
            _process_ctl(self, &buf);
        }
        else if ( *buf != 127) {
            _process_text(self, &buf);
        }
        else {
            ++buf;
        }

    }

    return newSViv(1);
}

void _check_rows_param(SV *sv_param, SV *sv_value, VT_SWITCHES *switches) {
    char *param = SvPV_nolen( sv_param );

    if ( strEQ(param, "rows") ) {
        if ( SvIOK( sv_value ) ) {
            switches->num_rows = SvIV(sv_value);
        }
        else {
            croak("rows => INTEGER, ...");
        }
    };
}

void _check_cols_param(SV *sv_param, SV *sv_value, VT_SWITCHES **switches) {
    char *param = SvPV_nolen( sv_param );

    if ( strEQ(param, "cols") ) {
        if ( SvIOK( sv_value ) ) {
            (*switches)->num_cols = SvIV(sv_value);
        }
        else {
            croak("cols => INTEGER, ...");
        }
    };
}

void _inc_y(VT_SWITCHES *switches) {
    /* TODO: if y > num_rows, move everything up, etc */
    switches->y++;

    if (switches->y >= switches->num_rows) {

    }
}

MODULE = Term::VT102::XS        PACKAGE = Term::VT102::XS

PROTOTYPES: DISABLE

SV*
new(class, ...)
    SV* class
  PREINIT:
        SV* self;
        VT_SWITCHES *switches;
        SV* iv_addr;
        int i;
  CODE:

    New(0, switches, 1, VT_SWITCHES);

    switches->num_cols        = DEFAULT_COLS;
    switches->num_rows        = DEFAULT_ROWS;
    switches->x = switches->y = 0;

    if (items > 1) {
        if (items % 2 == 0) {
            croak("->new takes named parameters or a hash.");
        }

        for (i = 1; i < items; i += 2) {
            if (!SvPOK( ST(i) )) croak("Invalid constructor parameter");

            _check_rows_param( ST(i), ST(i+1), switches );
            _check_cols_param( ST(i), ST(i+1), &switches );
        }
    }

    /* $iv_addr = 0xDEADBEEF in an IV */
    iv_addr = newSViv( PTR2IV(switches) );
    /* fprintf(stderr, "iv_addr: "); sv_dump(iv_addr); */

    /* my $self = \$iv_addr */
    self = newRV_noinc(iv_addr);
    /* fprintf(stderr, "self: "); sv_dump(self);*/

    /* bless($iv_addr, $class) */
    sv_bless(self, gv_stashsv(class, 0));
    /*fprintf(stderr, "self (again): "); sv_dump(self);*/
    /*fprintf(stderr, "class: "); sv_dump(class);*/

    /* allocate all my shit */
    _init(switches);

    /* return $self */
    RETVAL = self;
    OUTPUT:
    RETVAL

SV*
process(self, buf)
    SV *self
    SV *buf
  CODE:
    if (!SvPOK(buf))
        croak("Argument must be a string");

    RETVAL = _process(self, buf);
  OUTPUT:
    RETVAL

SV*
row_plaintext(self, sv_rownum)
    SV *self
    SV *sv_rownum
  PREINIT:
    VT_SWITCHES *switches;
    SV          *ret;
    char        *retbuf;
    int          i;
    int          rownum;
    VT_CELL     *cell;
  CODE:

    _GET_SWITCHES(switches, self);

    if ( !SvIOK(sv_rownum) )
        croak("row_plaintext takes an integer.");

    rownum = SvIV(sv_rownum);

    if (rownum < 1 || rownum >= switches->num_cols) {
        croak("row_plaintext: Argument out of range!");
    }

    New(0, retbuf, switches->num_cols + 1, char);

    for (i = 0; i < switches->num_cols; ++i) {
        cell = &switches->rows[rownum-1].cells[i];

        retbuf[i] = cell->value ? cell->value : ' ';
    }

    retbuf[switches->num_cols] = '\0';
    ret = newSVpv(retbuf, switches->num_cols);
    Safefree(retbuf);

    RETVAL = ret;
  OUTPUT:
    RETVAL


void
DESTROY(self)
    SV *self
  PREINIT:
    VT_SWITCHES *switches;
    int i;
  CODE:
    _GET_SWITCHES(switches, self);
    for (i = 0; i < switches->num_rows; ++i) {
        Safefree(switches->rows[i].cells);
    }
    Safefree(switches->rows);
    Safefree(switches);
