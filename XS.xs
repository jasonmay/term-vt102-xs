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

int _has_semicolon(char *s)
{
    while (*s) {
        if (*s == ';') return 1;
        ++s;
    }

    return 0;
}

void _process_SGR(VT_SWITCHES *switches)
{
    char *buf = switches->seq_buf;

    while (*buf) {
        char next_char = *(buf + 1);

        /* 30-37 */
        if ( *buf == '3' && next_char >= '0' && next_char <= '7' ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.fg = next_char - '0';
                buf += 2;
            }
        }

        ++buf;
    }


}

void _process_csi(VT_SWITCHES *switches, char **buf)
{
    int i, terminated = 0;
    char c;

    for (i = 0; i < 64; ++i) {
        c = *( (*buf) + i );

        if ( !c )
            break;

        if ( _is_csi_terminator(c) ) {
            switches->seq_buf[i] = '\0';
            (*buf) += i + 1;
            terminated = 1;
            switch (c) {
                case CSI_SGR:
                    _process_SGR(switches);
                  /*  fprintf(stderr, "THE COLORS, DUKE! THE COLORS! %s\n",
                        switches->seq_buf); */

                    break;

                default:
                    break;
            }

            break;
        }
        else {
            switches->seq_buf[i] = c;
        }
    }
}

void _process_ctl(VT_SWITCHES *switches, char **buf)
{
    VT_CELL *current_cell;

    char c = **buf;
    (*buf)++;

    if ( switches->xon == 0 )
        return;

    switch (c) {
        case CHAR_CTL_BS:
            if ( switches->x > 0 ) --switches->x;
            current_cell = _current_cell(switches);
            /* _reset_attr ??? */
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
            if ( switches->x < switches->num_cols-1 )
                ++switches->x;

            while (switches->x < switches->num_cols-1) {
                if ( switches->tabstops[switches->x] )
                    break;

                ++switches->x;
            }
            break;

        case CHAR_CTL_ESC:
            /* our beloved \e[...# */
            if ( **buf == '[' ) {
                ++(*buf);
                _process_csi(switches, buf);
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
    Copy(&switches->attr, &cell->attr, 1, VT_ATTR);

    switches->x++;
    if ( switches->x > switches->num_cols-1 ) {
        switches->x = 0;
    }

    (*buf)++;

    return;
}

void _process(VT_SWITCHES *switches, SV *sv_in)
{
    char *buf = SvPV_nolen(sv_in);

    while (*buf != '\0') {
        if ( _IS_CTL( *buf ) ) {
            _process_ctl(switches, &buf);
        }
        else if ( *buf != 127 ) {
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

    if ( switches->y >= switches->num_rows ) {
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

            if ( value > 0 )
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

            if ( value > 0 )
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
        _reset_attr(&s_row->cells[x].attr);
        s_row->cells[x].used  = 0;
    }
}

void _reset_attr(VT_ATTR *attr)
{

    attr->fg = 7;

    attr->bg = attr->bo =
    attr->fa = attr->st =
    attr->ul = attr->bl =
    attr->rv = 0;

}

SV *_row_attr(VT_SWITCHES *switches, int row, int startcol, int endcol)
{
    int len = (endcol - startcol) * 2;
    int col;
    char *buf;

    SV *ret;

    New(0, buf, len, char);

    for (col = startcol; col <= endcol; ++col) {
        int idx = (col - startcol) * 2;
        VT_ATTR *attr =
            &switches->rows[row].cells[col].attr;

        /* this may be horrible but I think this is awesome */
        Copy(buf + idx, SvPV_nolen(_vt_attr_pack(*attr)), 2, char);
    }

    ret = newSVpv(buf, len);
    Safefree(buf);

    return ret;
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

            _reset_attr(&cur_cell->attr);
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

SV *_attr_pack(int fg, int bg, int bo, int fa, int st, int ul, int bl, int rv)
{
    char attr_bits[2];

    attr_bits[0] = ((fg & 7)     ) /* parens unnecessary but I may have OCD */
                 | ((bg & 7) << 4);

    attr_bits[1] = ( bo      )
                 | ( fa << 1 )
                 | ( st << 2 )
                 | ( ul << 3 )
                 | ( bl << 4 )
                 | ( rv << 5 );

    return newSVpv(attr_bits, 2);
}

SV *_vt_attr_pack(VT_ATTR attr)
{
    char attr_bits[2];

    attr_bits[0] = ((attr.fg & 7)     )
                 | ((attr.bg & 7) << 4);

    attr_bits[1] = ( attr.bo      )
                 | ( attr.fa << 1 )
                 | ( attr.st << 2 )
                 | ( attr.ul << 3 )
                 | ( attr.bl << 4 )
                 | ( attr.rv << 5 );

    return newSVpv(attr_bits, 2);
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
            if ( !SvPOK( ST(i) ) ) croak("Invalid constructor parameter");

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

SV*
attr_unpack(sv, ...)
    SV *sv
  PREINIT:
    SV *sv_buf;
  PPCODE:

    if (items > 1)
        sv_buf = ST(1);
    else
        sv_buf = sv;

    char *buf = SvPV_nolen(sv_buf);

    EXTEND(SP, 8);

    mPUSHs( newSViv(  buf[0]       & 7 ) );
    mPUSHs( newSViv( (buf[0] >> 4) & 7 ) );
    mPUSHs( newSViv(  buf[1]       & 1 ) );
    mPUSHs( newSViv( (buf[1] >> 1) & 1 ) );
    mPUSHs( newSViv( (buf[1] >> 2) & 1 ) );
    mPUSHs( newSViv( (buf[1] >> 3) & 1 ) );
    mPUSHs( newSViv( (buf[1] >> 4) & 1 ) );
    mPUSHs( newSViv( (buf[1] >> 5) & 1 ) );

SV *attr_pack(sv, ...)
    SV *sv
  PREINIT:
    SV *ret;
    int i, attrs[8], offset, args;
    I16 attr_int;
    char attr_bits[2];
  CODE:
    offset = 0;
    if ( SvROK(sv) ) {
        offset = 1;
    }

    args = items - offset;

    if ( args != 8 ) {
        croak("Usage: attr_pack(fg, bg, bo, fa, st, ul, bl, rv)");
    }

    for (i = 0; i < args; ++i) {
        SV *arg = ST(i + offset);
        if ( !SvIOK(arg) )
            croak("attr_pack: all flags must be integers");

        attrs[i] = SvIV(arg);
    }

    RETVAL = _attr_pack(attrs[0],
                        attrs[1],
                        attrs[2],
                        attrs[3],
                        attrs[4],
                        attrs[5],
                        attrs[6],
                        attrs[7]);
  OUTPUT:
    RETVAL

SV*
row_attr(self, row, ...)
    SV *self
    SV *row
  PREINIT:
    SV *ret;
    int error, startcol, endcol;
    VT_SWITCHES *switches;
  CODE:


    error = 0;
    if ( !SvIOK(row) )
        error = 1;

    if ( items != 2 && items != 4 ) {
        error = 1;
    }

    if ( items == 4 ) {

        if ( !SvIOK( ST(2) ) || !SvIOK( ST(3) ) )
            croak("2");error = 1;

        startcol = SvIV( ST(2) );
        endcol   = SvIV( ST(2) );
    }
    else {
        _GET_SWITCHES(switches, self);
        startcol = endcol = switches->x;
    }

    if ( error )
        croak("Usage: row_attr(row, [startcol], [endcol])");

    ret = _row_attr(switches, SvIV(row), startcol, endcol);

    RETVAL =  ret;
  OUTPUT:
    RETVAL


void option_set(self, option, value)
    SV *self
    SV *option
    SV *value
  CODE:
    /* TODO */

SV *option_read(self, option)
    SV *self
    SV *option
  CODE:
    /* TODO */
    RETVAL = newSViv(0);
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
    Safefree(switches->tabstops);
    Safefree(switches);
