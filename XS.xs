#include <stdio.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "vt102.h"

/* NOTE:
 *
 * So yeah... I haven't written C
 * in like five or six years. If you
 * see something that might look a
 * little off, chances are it is!
 * Please let me know if you spot
 * anything.
 *
 * - jasonmay
 */


/* functions */

VT_CELL *_current_cell(VT_SWITCHES *switches)
{
    int x = switches->x,
        y = switches->y;

    return &switches->rows[y].cells[x];
}

char _is_csi_terminator(char c)
{
    switch (c) {
        case CSI_IGN:
        case CSI_ICH:
        case CSI_CUU:
        case CSI_CUD:
        case CSI_CUF:
        case CSI_CUB:
        case CSI_CNL:
        case CSI_CPL:
        case CSI_CHA:
        case CSI_CUP:
        case CSI_ED:
        case CSI_EL:
        case CSI_IL:
        case CSI_DL:
        case CSI_DCH:
        case CSI_ECH:
        case CSI_HPR:
        case CSI_DA:
        case CSI_VPA:
        case CSI_VPR:
        case CSI_HVP:
        case CSI_TBC:
        case CSI_SM:
        case CSI_RM:
        case CSI_SGR:
        case CSI_DSR:
        case CSI_DECLL:
        case CSI_DECSTBM:
        case CSI_CUPSV:
        case CSI_CUPRS:
        case CSI_HPA:
        return c;

        default:
        return '\0';
    }
}

SV *_process_csi(VT_SWITCHES *switches, char **buf)
{
    int i, terminated = 0;
    char c;

    for (i = 0; i < 64; ++i) {
        c = *( (*buf) + i );
        if (!c)
            break;

        if ( _is_csi_terminator(c) ) {
            terminated = 1;
            break;
        }
    }
}

SV *_process_ctl(VT_SWITCHES *switches, char **buf)
{
    VT_CELL *current_cell;

    char c = **buf;
    (*buf)++;

    if ( switches->xon == 0 )
        return;

    switch (c) {
        case CHAR_CTL_BS:
            if(switches->x > 0) --switches->x;
            current_cell = _current_cell(switches);
            current_cell->attr  = 0;
            current_cell->used  = 0;
            current_cell->value = '\0';
            break;

        case CHAR_CTL_CR:
            switches->x = 0;
            break;

        case CHAR_CTL_LF:
            _inc_y(switches);
            break;

        case CHAR_CTL_HT:
            if (switches->x < switches->num_cols-1)
                ++switches->x;

            while (switches->x < switches->num_cols-1) {
                if (switches->tabstops[switches->x])
                    break;

                ++switches->x;
            }
            break;

        case CHAR_CTL_ESC:
            /* are beloved \e[...# */
            if (**buf == '[') {
                ++(*buf);
            }
            break;
        default:
            printf("Dunno, buddy!\n");
    }

}

void _process_text(VT_SWITCHES *switches, char **buf)
{
    VT_CELL     *cell;

    cell = &switches->rows[switches->y].cells[switches->x];

    cell->value = **buf;
    cell->used  = 1;

    switches->x++;
    if (switches->x > switches->num_cols-1) {
        switches->x = 0;
    }

    (*buf)++;

    return;
}

void _process(VT_SWITCHES *switches, SV *sv_in)
{
    char *buf = SvPV_nolen(sv_in);
    STRLEN c;

    while (*buf != '\0') {
        if ( _IS_CTL( *buf ) ) {
            _process_ctl(switches, &buf);
        }
        else if ( *buf != 127) {
            _process_text(switches, &buf);
        }
        else {
            ++buf;
        }

    }

    return;
}

void _inc_y(VT_SWITCHES *switches) {
    int row;
    int end_index = switches->num_rows - 1;
    VT_ROW *first_row;

    switches->y++;

    if (switches->y >= switches->num_rows) {
        switches->y = end_index;

        /* row 0 will be overwritten, store it 
         * to use for the last row */
        first_row = &switches->rows[0];

        /* move every row pointer up one */
        for (row = 0; row < end_index; ++row) {
            switches->rows[row] = switches->rows[row + 1];
        }
        switches->rows[end_index] = *first_row;
    }
}

void _check_rows_param(SV *sv_param, SV *sv_value, VT_SWITCHES *switches)
{
    char *param = SvPV_nolen( sv_param );
    int value;

    if ( strEQ(param, "rows") ) {
        if ( SvIOK( sv_value ) ) {
            value = SvIV(sv_value);

            if (value > 0)
                switches->num_rows = value;
        }
        else {
            croak("rows => INTEGER, ...");
        }
    };
}

void _check_cols_param(SV *sv_param, SV *sv_value, VT_SWITCHES *switches)
{
    char *param = SvPV_nolen( sv_param );
    int value;

    if ( strEQ(param, "cols") ) {
        if ( SvIOK( sv_value ) ) {
            value = SvIV(sv_value);

            if (value > 0)
                switches->num_cols = value;
        }
        else {
            croak("cols => INTEGER, ...");
        }
    };
}

void _clear_row(VT_SWITCHES *switches, int row)
{
    int x;
    VT_ROW *s_row = &switches->rows[row];

    for (x = 0; x < switches->num_cols; ++x) {
        s_row->cells[x].value = '\0';
        s_row->cells[x].attr  = 0;
        s_row->cells[x].used  = 0;
    }
}

void _init(VT_SWITCHES *switches)
{
    int x, y;
    VT_CELL *cur_cell;

    /* allocate rows */
    New(0, switches->rows,     switches->num_rows, VT_ROW);
    New(0, switches->tabstops, switches->num_cols, int);

    /* establish tabstops 1000000010000000... */
    for (x = 0; x < switches->num_cols; ++x) {
        switches->tabstops[x] = (x % 8 == 0);
    }

    for (y = 0; y < switches->num_rows; ++y) {

        /* allocate cells for row y */
        New(0, switches->rows[y].cells, switches->num_cols, VT_CELL);

        for (x = 0; x < switches->num_cols; ++x) {
            cur_cell = &switches->rows[y].cells[x];

            cur_cell->attr = 0;
            cur_cell->used = 0;
            cur_cell->value = '\0';
        }
    }

    switches->xon = 1;
}

SV* _row_text(VT_SWITCHES *switches, int rownum, int plain)
{
    SV          *ret;
    char        *retbuf;
    int          i, len;

    VT_CELL     *cell;

    len = switches->num_cols;
    New(0, retbuf, len, char);

    for (i = 0; i < len; ++i) {
        cell = &switches->rows[rownum-1].cells[i];

        /*printf("Text: %d, x=%d y=%d\n",
            retbuf[i], i, rownum-1);*/

        if (plain) {
            retbuf[i] = cell->used ? cell->value : ' ';
        }
        else {
            retbuf[i] = cell->value;
        }
    }

    ret = newSVpv(retbuf, len);
    Safefree(retbuf);
    return ret;
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
            _check_cols_param( ST(i), ST(i+1), switches );
        }
    }

    /* $iv_addr = 0xDEADBEEF in an IV */
    iv_addr = newSViv( PTR2IV(switches) );

    /* my $self = \$iv_addr */
    self = newRV_noinc(iv_addr);

    /* bless($iv_addr, $class) */
    sv_bless(self, gv_stashsv(class, 0));

    /* allocate all my shit */
    _init(switches);

    /* return $self */
    RETVAL = self;
  OUTPUT:
    RETVAL

void
process(self, buf)
    SV *self
    SV *buf
  PREINIT:
    VT_SWITCHES *switches;
  CODE:
    if (!SvPOK(buf))
        croak("Argument must be a string");

    _GET_SWITCHES(switches, self);

    _process(switches, buf);

SV*
row_plaintext(self, sv_rownum)
    SV *self
    SV *sv_rownum
  PREINIT:
    VT_SWITCHES *switches;
    int          rownum;
  CODE:
    _GET_SWITCHES(switches, self);

    if ( !SvIOK(sv_rownum) )
        croak("row_plaintext: Please provide a row# for the argument.");

    rownum = SvIV(sv_rownum);

    if (rownum < 1 || rownum >= switches->num_cols) {
        croak("row_plaintext: Argument out of range!");
    }

    RETVAL = _row_text(switches, rownum, 0);
  OUTPUT:
    RETVAL

SV*
row_text(self, sv_rownum)
    SV *self
    SV *sv_rownum
  PREINIT:
    VT_SWITCHES *switches;
    int rownum;
  CODE:
    _GET_SWITCHES(switches, self);

    if ( !SvIOK(sv_rownum) )
        croak("row_plaintext: Please provide a row# for the argument.");

    rownum = SvIV(sv_rownum);

    if (rownum < 1 || rownum >= switches->num_cols) {
        croak("row_plaintext: Argument out of range!");
    }

    RETVAL = _row_text(switches, rownum, 0);
  OUTPUT:
    RETVAL

SV*
size(self)
    SV *self
  PREINIT:
    VT_SWITCHES *switches;
  PPCODE:

    _GET_SWITCHES(switches, self);

    EXTEND(SP, 2);

    mPUSHs( newSViv(switches->num_cols) );
    mPUSHs( newSViv(switches->num_rows) );


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
    Safefree(switches->tabstops);
    Safefree(switches);
