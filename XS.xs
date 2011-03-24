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

    return &switches->rows[y]->cells[x];
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

    /* \e[m */
    if (!*buf)
        _reset_attr(&switches->attr);

    while (*buf) {
        char next_char = *(buf + 1);

        /* 30-37 */
        if ( *buf == '3' && next_char >= '0' && next_char <= '7' ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.fg = next_char - '0';
                buf += 2;
            }
        }
        else if ( strnEQ(buf, "38", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.ul = 1;
                switches->attr.fg = 7;
            }
        }
        else if ( strnEQ(buf, "39", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.ul = 0;
                switches->attr.fg = 7;
            }
        }
        else if ( *buf == '4' && next_char >= '0' && next_char <= '7' ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.bg = next_char - '0';
                buf += 2;
            }
        }
        else if ( strnEQ(buf, "49", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switches->attr.bg = 0;
            }
        }
        else if ( *buf == '0' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                _reset_attr(&switches->attr);
            }
            ++buf;
        }
        else if ( *buf == '1' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                switches->attr.bo = 1;
            }
            ++buf;
        }
        else if ( *buf == '2' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                switches->attr.bo = 0;
                switches->attr.fa = 1;
                ++buf;
            }
            else if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switch (next_char) {
                    case '1':
                    case '2':
                        switches->attr.bo = 0;
                        switches->attr.fa = 0;
                        break;
                    case '4':
                        switches->attr.ul = 0;
                        break;
                    case '5':
                        switches->attr.bl = 0;
                        break;
                    case '7':
                        switches->attr.rv = 0;
                        break;
                    default:
                        buf -= 2;
                        break;
                }
                buf += 2;
            }
        }
        else if ( *buf == '4' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                switches->attr.ul = 1;
                ++buf;
            }
        }
        else if ( *buf == '5' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                switches->attr.bl = 1;
                ++buf;
            }
        }
        else if ( *buf == '7' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                switches->attr.rv = 1;
                ++buf;
            }
        }

        ++buf;
    }


}

void _process_CUP(VT_SWITCHES *switches)
{
    char *buf = switches->seq_buf;

    int to_x = 0, to_y = 0;

    SV *sv_num = sv_2mortal( newSVpv("", PL_na) );

    /* \e[m */
    if (*buf) {
        while (*buf && *buf != ';') {
            if ( *buf >= '0' && *buf <= '9' ) {
                char s = *buf;
                sv_catpvn(sv_num, &s, 1);
                /* fprintf(stderr, "sv_num: %s\n", SvPV_nolen(sv_num));*/
            }
            ++buf;
        }
        to_y = SvIV(sv_num) - 1;
    }

    sv_setpvn(sv_num, "", 0);
    if (*buf) {
        ++buf; /* skip the ; */
        /* fprintf(stderr, "... %s\n", buf); */

        while (*buf && *buf != ';') {
            if ( *buf >= '0' && *buf <= '9' ) {
                char s = *buf;
                sv_catpvn(sv_num, &s, 1);
                /*fprintf(stderr, "sv_num: %s\n", SvPV_nolen(sv_num));*/
            }
            ++buf;
        }
        to_x = SvIV(sv_num) - 1;
    }

    switches->x = to_x;
    switches->y = to_y;
}

int _get_number_from_string(char *buf) {
    SV *sv_num = sv_2mortal( newSVpv("", PL_na) );
    int ret = 0;

    if (*buf) {
        while (*buf) {
            if ( *buf >= '0' && *buf <= '9' ) {
                char s = *buf;
                sv_catpvn(sv_num, &s, 1);
            }
            ++buf;
        }
        ret = SvIV(sv_num);
    }

    return ret;
}

void _process_CUU(VT_SWITCHES *switches)
{
    int i, offset = _get_number_from_string(switches->seq_buf);
    if ( !offset ) offset = 1;

    for (i = 0; i < offset; ++i) {
        /* INEFFICIENT!! - TODO shift all rows around at one time */
        _dec_y(switches);
    }

}

void _process_CUD(VT_SWITCHES *switches)
{
    int i, offset = _get_number_from_string(switches->seq_buf);
    if ( !offset ) offset = 1;

    for (i = 0; i < offset; ++i) {
        /* INEFFICIENT!! - TODO shift all rows around at one time */
        _inc_y(switches);
    }

}

void _process_CUB(VT_SWITCHES *switches)
{
    int i, offset = _get_number_from_string(switches->seq_buf);
    if ( !offset ) offset = 1;

    switches->x -= offset;

    if ( switches->x < 0 )
        switches->x = 0;
}

void _process_CUF(VT_SWITCHES *switches)
{
    int i, offset = _get_number_from_string(switches->seq_buf);
    if ( !offset ) offset = 1;

    switches->x += offset;

    if ( switches->x >= switches->num_cols )
        switches->x = switches->num_cols - 1;
}

void _process_ECH(VT_SWITCHES *switches)
{
    int col, end, chars = _get_number_from_string(switches->seq_buf);
    if ( !chars ) chars = 1;

    end = switches->x + chars;

    if ( end >= switches->num_cols ) end = switches->num_cols - 1;

    for (col = switches->x;
         col < switches->x + chars && col < switches->num_cols;
         ++col) {

        switches->rows[switches->y]->cells[col].value = '\0';
        _reset_attr(&switches->rows[switches->y]->cells[col].attr);
    }
}

void _process_EL(VT_SWITCHES *switches)
{
    int row, col, num = _get_number_from_string(switches->seq_buf);

    if ( !num && !switches->x && !switches->y )
        num = 2;

    /* cursor to end */
    switch (num) {
        case 0:
            for (col = switches->x; col < switches->num_cols; ++col) {
                switches->rows[switches->y]->cells[col].value = '\0';
                _reset_attr(&switches->rows[switches->y]->cells[col].attr);
            }
            break;

        case 1:
            for (col = 0; col <= switches->x; ++col) {
                switches->rows[switches->y]->cells[col].value = '\0';
                _reset_attr(&switches->rows[switches->y]->cells[col].attr);
            }
            break;

        default:
            for (col = 0; col < switches->num_cols; ++col) {
                switches->rows[switches->y]->cells[col].value = '\0';
                _reset_attr(&switches->rows[switches->y]->cells[col].attr);
            }
            break;
    }
}

void _process_ED(VT_SWITCHES *switches)
{
    int row, col, num = _get_number_from_string(switches->seq_buf);

    if ( !num && !switches->x && !switches->y )
        num = 2;

    /* cursor to end */
    switch (num) {
        case 0:
            for (col = switches->x; col < switches->num_cols; ++col) {
                switches->rows[switches->y]->cells[col].value = '\0';
                _reset_attr(&switches->rows[switches->y]->cells[col].attr);
            }

            for (row = switches->y + 1; row < switches->num_rows; ++row) {
                for (col = 0; col < switches->num_cols; ++col) {
                    switches->rows[row]->cells[col].value = '\0';
                    _reset_attr(&switches->rows[row]->cells[col].attr);
                }
            }
            break;

        case 1:
            for (col = 0; col <= switches->x; ++col) {
                switches->rows[switches->y]->cells[col].value = '\0';
                _reset_attr(&switches->rows[switches->y]->cells[col].attr);
            }

            for (row = 0; row < switches->y; ++row) {
                for (col = 0; col < switches->num_cols; ++col) {
                    switches->rows[row]->cells[col].value = '\0';
                    _reset_attr(&switches->rows[row]->cells[col].attr);
                }
            }
            break;

        default:
            for (row = 0; row < switches->num_rows; ++row) {
                for (col = 0; col <= switches->num_cols; ++col) {
                    switches->rows[row]->cells[col].value = '\0';
                    _reset_attr(&switches->rows[row]->cells[col].attr);
                }
            }
            break;
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
                case CSI_CUP:
                    _process_CUP(switches);
                    break;

                case CSI_CUU:
                    _process_CUU(switches);
                    break;

                case CSI_CUD:
                    _process_CUD(switches);
                    break;

                case CSI_CUB:
                    _process_CUB(switches);
                    break;

                case CSI_CUF:
                    _process_CUF(switches);
                    break;

                case CSI_ECH:
                    _process_ECH(switches);
                    break;

                case CSI_EL:
                    _process_EL(switches);
                    break;

                case CSI_ED:
                    _process_ED(switches);
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
            if ( **buf == 'M' ) {
                ++(*buf);
                _dec_y(switches);
            }
            break;
        default:
            /*printf("Dunno, buddy!\n");*/
            break;
    }

}

void _copy_attr(VT_ATTR *src, VT_ATTR *dest) {
    /* I can't figure out how to use Copy :| */
    /* Copy(src, dest, 1, VT_ATTR); */
    dest->fg = src->fg;
    dest->bg = src->bg;
    dest->bo = src->bo;
    dest->fa = src->fa;
    dest->st = src->st;
    dest->ul = src->ul;
    dest->bl = src->bl;
    dest->rv = src->rv;
}

void _process_text(VT_SWITCHES *switches, char **buf)
{
    VT_CELL     *cell;


    if ( switches->x < switches->num_cols ) {
        cell = &switches->rows[switches->y]->cells[switches->x];
        cell->value = **buf;
        cell->used  = 1;
        _copy_attr(&switches->attr, &cell->attr);

        switches->x++;
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

void _dec_y(VT_SWITCHES *switches) {
    int row, col;
    int end_index = switches->num_rows - 1;
    VT_ROW *last_row;

    switches->y--;

    if ( switches->y < 0 ) {
        switches->y = 0;

        last_row = switches->rows[end_index];

        /* move every row pointer up one */
        for (row = end_index - 1; row >= 0; --row) {
            switches->rows[row + 1] = switches->rows[row];
        }
        switches->rows[0] = last_row;
        for (col = 0; col < switches->num_cols; ++col) {
            _reset_attr(&switches->rows[0]->cells[col].attr);
        }
    }
}

void _inc_y(VT_SWITCHES *switches) {
    int row, col;
    int end_index = switches->num_rows - 1;
    VT_ROW *first_row;

    switches->y++;

    if ( switches->y >= switches->num_rows ) {
        switches->y = end_index;

        /* row 0 will be overwritten, store it 
         * to use for the last row */
        first_row = switches->rows[0];

        /* move every row pointer up one */
        for (row = 0; row < end_index; ++row) {
            switches->rows[row] = switches->rows[row + 1];
        }
        switches->rows[end_index] = first_row;
        for (col = 0; col < switches->num_cols; ++col) {
            _reset_attr(&switches->rows[end_index]->cells[col].attr);
            switches->rows[end_index]->cells[col].value = '\0';
        }
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
    VT_ROW *s_row = switches->rows[row];

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
    int len = (endcol - startcol + 1) * 2;
    int col;
    char *bufpv;

    SV *ret;

    New(0, bufpv, len, char);

    for (col = startcol; col <= endcol; ++col) {
        char *pack;
        SV *sv_pack;
        int idx = (col - startcol) * 2;
        VT_ATTR *attr =
            &switches->rows[row-1]->cells[col].attr;

        sv_pack = _vt_attr_pack(*attr);
        pack = SvPV_nolen(sv_pack);
        *(bufpv + idx)     = pack[0];
        *(bufpv + idx + 1) = pack[1];
    }

    ret = newSVpv(bufpv, len);
    Safefree(bufpv);

    return ret;
}

void _init(VT_SWITCHES *switches)
{
    int x, y;
    VT_CELL *cur_cell;

    /* allocate rows */
    New(0, switches->rows,     switches->num_rows, VT_ROW*);
    New(0, switches->tabstops, switches->num_cols, int);

    /* establish tabstops 1000000010000000... */
    for (x = 0; x < switches->num_cols; ++x) {
        switches->tabstops[x] = (x % 8 == 0);
    }

    _reset_attr(&switches->attr);

    for (y = 0; y < switches->num_rows; ++y) {
        New(0, switches->rows[y], 1, VT_ROW);

        /* allocate cells for row y */
        New(0, switches->rows[y]->cells, switches->num_cols, VT_CELL);

        for (x = 0; x < switches->num_cols; ++x) {
            cur_cell = &switches->rows[y]->cells[x];

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
        cell = &switches->rows[rownum-1]->cells[i];

        /*printf("Text: %d, x=%d y=%d\n",
            retbuf[i], i, rownum-1);*/

        if (plain) {
            retbuf[i] = cell->value ? cell->value : ' ';
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

    /* fprintf(stderr, "bits[0]: %d\n", attr_bits[0]);
    fprintf(stderr, "bits[1]: %d\n", attr_bits[1]); */
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

    if (rownum < 1 || rownum > switches->num_cols) {
        croak("row_plaintext: Argument out of range!");
    }

    RETVAL = _row_text(switches, rownum, 1);
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

    if (rownum < 1 || rownum > switches->num_cols) {
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

    _GET_SWITCHES(switches, self);

    error = 0;
    if ( !SvIOK(row) )
        error = 1;

    if ( items != 2 && items != 4 ) {
        error = 1;
    }

    if ( items == 4 ) {

        if ( !SvIOK( ST(2) ) || !SvIOK( ST(3) ) ) {
            error = 1;
        }
        else {
            startcol = SvIV( ST(2) );
            endcol   = SvIV( ST(2) );
        }
    }
    else {
        startcol = 0;
        endcol   = switches->num_cols - 1;
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
        Safefree(switches->rows[i]->cells);
        Safefree(switches->rows[i]);
    }
    Safefree(switches->rows);
    Safefree(switches->tabstops);
    Safefree(switches);
