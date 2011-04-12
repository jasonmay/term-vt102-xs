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

VT_CELL *vt102_current_cell(vt_state_t *self)
{
    int x = self->x,
        y = self->y;

    return &self->rows[y]->cells[x];
}

char vt102_is_csi_terminator(char c)
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

int vt102_has_semicolon(char *s)
{
    while (*s) {
        if (*s == ';') return 1;
        ++s;
    }

    return 0;
}

void vt102_process_SGR(vt_state_t *self)
{
    char *buf = self->seq_buf;

    /* \e[m */
    if (!*buf)
        vt102_reset_attr(&self->attr);

    while (*buf && buf - self->seq_buf < 64) {
        char next_char = *(buf + 1);

        /* 30-37 */
        if ( *buf == '3' && next_char >= '0' && next_char <= '7' ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                self->attr.fg = next_char - '0';
                buf += 2;
            }
        }
        else if ( strnEQ(buf, "38", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                self->attr.ul = 1;
                self->attr.fg = 7;
            }
        }
        else if ( strnEQ(buf, "39", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                self->attr.ul = 0;
                self->attr.fg = 7;
            }
        }
        else if ( *buf == '4' && next_char >= '0' && next_char <= '7' ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                self->attr.bg = next_char - '0';
                buf += 2;
            }
        }
        else if ( strnEQ(buf, "49", 2) ) {
            if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                self->attr.bg = 0;
            }
        }
        else if ( *buf == '0' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                vt102_reset_attr(&self->attr);
            }
            ++buf;
        }
        else if ( *buf == '1' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                self->attr.bo = 1;
            }
            ++buf;
        }
        else if ( *buf == '2' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                self->attr.bo = 0;
                self->attr.fa = 1;
                ++buf;
            }
            else if ( *(buf + 2) == ';' || *(buf + 2) == '\0' ) {
                switch (next_char) {
                    case '1':
                    case '2':
                        self->attr.bo = 0;
                        self->attr.fa = 0;
                        break;
                    case '4':
                        self->attr.ul = 0;
                        break;
                    case '5':
                        self->attr.bl = 0;
                        break;
                    case '7':
                        self->attr.rv = 0;
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
                self->attr.ul = 1;
                ++buf;
            }
        }
        else if ( *buf == '5' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                self->attr.bl = 1;
                ++buf;
            }
        }
        else if ( *buf == '7' ) {
            if ( next_char == ';' || next_char == '\0' ) {
                self->attr.rv = 1;
                ++buf;
            }
        }

        ++buf;
    }
}

void vt102_process_CUP(vt_state_t *self)
{
    char *buf = self->seq_buf;

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

    self->x = to_x;
    self->y = to_y;
}

int vt102_get_number_from_string(char *buf) {
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

void vt102_process_CUU(vt_state_t *self)
{
    int i, offset = vt102_get_number_from_string(self->seq_buf);
    if ( !offset ) offset = 1;

    for (i = 0; i < offset; ++i) {
        /* INEFFICIENT!! - TODO shift all rows around at one time */
        vt102_dec_y(self);
    }

}

void vt102_process_CUD(vt_state_t *self)
{
    int i, offset = vt102_get_number_from_string(self->seq_buf);
    if ( !offset ) offset = 1;

    for (i = 0; i < offset; ++i) {
        /* INEFFICIENT!! - TODO shift all rows around at one time */
        vt102_inc_y(self);
    }

}

void vt102_process_CUB(vt_state_t *self)
{
    int i, offset = vt102_get_number_from_string(self->seq_buf);
    if ( !offset ) offset = 1;

    self->x -= offset;

    if ( self->x < 0 )
        self->x = 0;
}

void vt102_process_CUF(vt_state_t *self)
{
    int i, offset = vt102_get_number_from_string(self->seq_buf);
    if ( !offset ) offset = 1;

    self->x += offset;

    if ( self->x >= self->num_cols )
        self->x = self->num_cols - 1;
}

void vt102_clear_cell(VT_CELL *cell)
{
    cell->value = '\0';
    vt102_reset_attr(&cell->attr);
}

void vt102_process_ECH(vt_state_t *self)
{
    int col, end, chars = vt102_get_number_from_string(self->seq_buf);
    if ( !chars ) chars = 1;

    end = self->x + chars;

    if ( end >= self->num_cols ) end = self->num_cols - 1;

    for (col = self->x;
         col < self->x + chars && col < self->num_cols;
         ++col) {

        self->rows[self->y]->cells[col].value = '\0';
        vt102_reset_attr(&self->rows[self->y]->cells[col].attr);
    }
}

void vt102_clear_row(vt_state_t *self, int row)
{
    int col;
    VT_ROW *s_row = self->rows[row];

    for (col = 0; col < self->num_cols; ++col) {
        vt102_clear_cell(&s_row->cells[col]);
    }
}

void vt102_process_EL(vt_state_t *self)
{
    int row, col, num = vt102_get_number_from_string(self->seq_buf);

    if ( !num && !self->x && !self->y )
        num = 2;

    /* cursor to end */
    switch (num) {
        case 0:
            for (col = self->x; col < self->num_cols; ++col) {
                vt102_clear_cell( &self->rows[self->y]->cells[col] );
            }
            break;

        case 1:
            for (col = 0; col <= self->x; ++col) {
                vt102_clear_cell( &self->rows[self->y]->cells[col] );
            }
            break;

        default:
            vt102_clear_row(self, self->y);
            break;
    }
}

void vt102_process_ED(vt_state_t *self)
{
    int row, col, num = vt102_get_number_from_string(self->seq_buf);

    if ( !num && !self->x && !self->y )
        num = 2;

    /* cursor to end */
    switch (num) {
        case 0:
            for (col = self->x; col < self->num_cols; ++col) {
                vt102_clear_cell( &self->rows[self->y]->cells[col] );
            }

            for (row = self->y + 1; row < self->num_rows; ++row) {
                vt102_clear_row( self, row );
            }
            break;

        case 1:
            for (col = 0; col <= self->x; ++col) {
                vt102_clear_cell( &self->rows[self->y]->cells[col] );
            }

            for (row = 0; row < self->y; ++row) {
                vt102_clear_row( self, row );
            }
            break;

        default:
            for (row = 0; row < self->num_rows; ++row) {
                vt102_clear_row( self, row );
            }
            break;
    }
}

void vt102_process_csi(vt_state_t *self)
{
    int i, terminated = 0;
    char c;

    for (i = 0; i < 64; ++i) {

        if ( self->cur + i >= self->end )
            break;

        c = *(self->cur + i);

        if ( !c )
            break;

        if ( vt102_is_csi_terminator(c) ) {
            self->seq_buf[i] = '\0';
            self->cur += i + 1;
            terminated = 1;
            switch (c) {
                case CSI_SGR:
                    vt102_process_SGR(self);
                  /*  fprintf(stderr, "THE COLORS, DUKE! THE COLORS! %s\n",
                        self->seq_buf); */

                    break;
                case CSI_CUP:
                    vt102_process_CUP(self);
                    break;

                case CSI_CUU:
                    vt102_process_CUU(self);
                    break;

                case CSI_CUD:
                    vt102_process_CUD(self);
                    break;

                case CSI_CUB:
                    vt102_process_CUB(self);
                    break;

                case CSI_CUF:
                    vt102_process_CUF(self);
                    break;

                case CSI_ECH:
                    vt102_process_ECH(self);
                    break;

                case CSI_EL:
                    vt102_process_EL(self);
                    break;

                case CSI_ED:
                    vt102_process_ED(self);
                    break;

                default:
                    break;
            }

            break;
        }
        else {
            self->seq_buf[i] = c;
        }
    }
}

void vt102_process_ctl(vt_state_t *self)
{
    char c = *self->cur;
    ++self->cur;

    if ( self->xon == 0 )
        return;

    switch (c) {
        case CHAR_CTL_BS:
            if ( self->x > 0 ) --self->x;
            break;

        case CHAR_CTL_CR:
            self->x = 0;
            break;

        case CHAR_CTL_LF:
            vt102_inc_y(self);
            if (self->options.lftocrlf)
                self->x = 0;
            break;

        case CHAR_CTL_HT:
            if ( self->x < self->num_cols-1 )
                ++self->x;

            while (self->x < self->num_cols-1) {
                if ( self->tabstops[self->x] )
                    break;

                ++self->x;
            }
            break;

        case CHAR_CTL_ESC:
            /* our beloved \e[...# */
            if ( *self->cur == '[' ) {
                ++self->cur;
                vt102_process_csi(self);
            }
            if ( *self->cur == 'M' ) {
                ++self->cur;
                vt102_dec_y(self);
            }
            break;
        default:
            /*printf("Dunno, buddy!\n");*/
            break;
    }

}

void vt102_copy_attr(VT_ATTR *src, VT_ATTR *dest) {
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

void vt102_process_text(vt_state_t *self)
{
    VT_CELL     *cell;

    if ( self->x >= self->num_cols ) {
        if ( self->options.linewrap ) {
            vt102_inc_y(self);
            self->x = 0;
        }
        else {
            return;
        }
    }

    cell        = &self->rows[self->y]->cells[self->x];
    cell->value = *self->cur;
    cell->used  = 1;
    vt102_copy_attr(&self->attr, &cell->attr);

    self->x++;

    return;
}

void vt102_process(vt_state_t *self)
{
    while (self->cur < self->end) {
        if ( *self->cur >= 0 && *self->cur <= 0x1f ) {
            vt102_process_ctl(self);
        }
        else if ( *self->cur != 127 ) {
            vt102_process_text(self);
            ++self->cur;
        }
        else {
            ++self->cur;
        }

    }

    return;
}

void vt102_dec_y(vt_state_t *self) {
    int row, col;
    int end_index = self->num_rows - 1;
    VT_ROW *last_row;

    self->y--;

    if ( self->y < 0 ) {
        self->y = 0;

        last_row = self->rows[end_index];

        /* move every row pointer up one */
        for (row = end_index - 1; row >= 0; --row) {
            self->rows[row + 1] = self->rows[row];
        }
        self->rows[0] = last_row;
        for (col = 0; col < self->num_cols; ++col) {
            vt102_reset_attr(&self->rows[0]->cells[col].attr);
        }
    }
}

void vt102_inc_y(vt_state_t *self) {
    int row, col;
    int end_index = self->num_rows - 1;
    VT_ROW *first_row;

    self->y++;

    if ( self->y >= self->num_rows ) {
        self->y = end_index;

        /* row 0 will be overwritten, store it 
         * to use for the last row */
        first_row = self->rows[0];

        /* move every row pointer up one */
        for (row = 0; row < end_index; ++row) {
            self->rows[row] = self->rows[row + 1];
        }
        self->rows[end_index] = first_row;
        for (col = 0; col < self->num_cols; ++col) {
            vt102_reset_attr(&self->rows[end_index]->cells[col].attr);
            self->rows[end_index]->cells[col].value = '\0';
        }
    }
}

void vt102_check_rows_param(SV *sv_param, SV *sv_value, vt_state_t *self)
{
    char *param = SvPV_nolen( sv_param );
    int value;

    if ( strEQ(param, "rows") ) {
        if ( SvIOK( sv_value ) ) {
            value = SvIV(sv_value);

            if ( value > 0 )
                self->num_rows = value;
        }
        else {
            croak("rows => INTEGER, ...");
        }
    };
}

void vt102_check_cols_param(SV *sv_param, SV *sv_value, vt_state_t *self)
{
    char *param = SvPV_nolen( sv_param );
    int value;

    if ( strEQ(param, "cols") ) {
        if ( SvIOK( sv_value ) ) {
            value = SvIV(sv_value);

            if ( value > 0 )
                self->num_cols = value;
        }
        else {
            croak("cols => INTEGER, ...");
        }
    };
}

void vt102_check_zerobased_param(SV *sv_param, SV *sv_value, vt_state_t *self)
{
    char *param = SvPV_nolen( sv_param );

    if ( strEQ(param, "zerobased") ) {
        self->zerobased = (I8) SvTRUE(sv_value);
    };
}

void vt102_reset_attr(VT_ATTR *attr)
{

    attr->fg = 7;

    attr->bg = attr->bo =
    attr->fa = attr->st =
    attr->ul = attr->bl =
    attr->rv = 0;

}

SV *vt102_row_attr(vt_state_t *self, IV row, IV startcol, IV endcol)
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
            &self->rows[row]->cells[col].attr;

        sv_pack = vt102_vt_attr_pack(*attr);
        pack = SvPV_nolen(sv_pack);
        *(bufpv + idx)     = pack[0];
        *(bufpv + idx + 1) = pack[1];
    }

    ret = newSVpv(bufpv, len);
    Safefree(bufpv);

    return ret;
}

void vt102_option_check(vt_state_t *self, SV *option, SV *value, char *flagstr, I8 *flag, SV **ret)
{
    if ( strEQ(SvPV_nolen(option), flagstr) ) {
        *ret = newSViv(*flag);
        /* $one_or_zero = !!$value */
        *flag = (I8) SvTRUE(value);
    }
}

I8 *vt102_option_return(vt_state_t *self, SV *option)
{
    if ( strEQ(SvPV_nolen(option), "LINEWRAP") ) {
        return &self->options.linewrap;
    }

    if ( strEQ(SvPV_nolen(option), "LFTOCRLF") ) {
        return &self->options.lftocrlf;
    }

    if ( strEQ(SvPV_nolen(option), "IGNOREXOFF") ) {
        return &self->options.ignorexoff;
    }

    return NULL;
}

void vt102_init(vt_state_t *self)
{
    int x, y;
    VT_CELL *cur_cell;

    /* allocate rows */
    New(0, self->rows,     self->num_rows, VT_ROW*);
    New(0, self->tabstops, self->num_cols, int);

    /* establish tabstops 1000000010000000... */
    for (x = 0; x < self->num_cols; ++x) {
        self->tabstops[x] = (x % 8 == 0);
    }

    vt102_reset_attr(&self->attr);

    for (y = 0; y < self->num_rows; ++y) {
        New(0, self->rows[y], 1, VT_ROW);

        /* allocate cells for row y */
        New(0, self->rows[y]->cells, self->num_cols, VT_CELL);

        for (x = 0; x < self->num_cols; ++x) {
            cur_cell = &self->rows[y]->cells[x];

            vt102_reset_attr(&cur_cell->attr);
            cur_cell->used = 0;
            cur_cell->value = '\0';
        }
    }

    self->xon    =
    self->cursor = 1;

    self->options.linewrap   =
    self->options.lftocrlf   =
    self->options.ignorexoff = 0;

}

SV* vt102_row_text(vt_state_t *self, int rownum, int startcol, int endcol, int plain)
{
    SV          *ret;
    char        *retbuf;
    int          i, len;

    VT_CELL     *cell;

    len = endcol - startcol + 1;
    New(0, retbuf, len, char);

    for (i = startcol; i <= endcol; ++i) {

        /*fprintf(stderr, "Text: %d, x=%d y=%d\r\n",
            retbuf[i], i, rownum-1);*/

        cell = &self->rows[rownum]->cells[i];

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

void vt102_clip_row(vt_state_t *self, int *row_var, int zerobased)
{
    int offset = zerobased ? 0 : 1; /* hey it's readable ok */

    if ( *row_var < offset )
        *row_var = offset;
    if ( *row_var >= self->num_rows + offset )
        *row_var = self->num_rows + offset - 1;
}

void vt102_clip_col(vt_state_t *self, int *col_var, int zerobased)
{
    int offset = zerobased ? 0 : 1;

    if ( *col_var < offset )
        *col_var = offset;
    if ( *col_var >= self->num_cols + offset )
        *col_var = self->num_cols + offset - 1;
}

SV *vt102_attr_pack(int fg, int bg, int bo, int fa, int st, int ul, int bl, int rv)
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

SV *vt102_vt_attr_pack(VT_ATTR attr)
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
        vt_state_t* self;
        SV* instance;
        SV* iv_addr;
        int i;
  CODE:

    New(0, self, 1, vt_state_t);

    self->num_cols        = DEFAULT_COLS;
    self->num_rows        = DEFAULT_ROWS;
    self->x = self->y = 0;
    self->zerobased       = 0;

    if (items > 1) {
        if (items % 2 == 0) {
            croak("->new takes named parameters or a hash.");
        }

        for (i = 1; i < items; i += 2) {
            if ( !SvPOK( ST(i) ) ) croak("Invalid constructor parameter");

            vt102_check_rows_param( ST(i), ST(i+1), self );
            vt102_check_cols_param( ST(i), ST(i+1), self );
            vt102_check_zerobased_param( ST(i), ST(i+1), self );
        }
    }

    /* $iv_addr = 0xDEADBEEF in an IV */
    iv_addr = newSViv( PTR2IV(self) );

    /* my $self = \$iv_addr */
    instance = newRV_noinc(iv_addr);

    /* bless($iv_addr, $class) */
    sv_bless(instance, gv_stashsv(class, 0));

    /* allocate all my shit */
    vt102_init(self);

    /* return $self */
    RETVAL = instance;
  OUTPUT:
    RETVAL

void
process(self, sv_buf)
    vt_state_t *self
    SV         *sv_buf
  PREINIT:
    STRLEN      len;
  CODE:

    self->cur = SvPVX(sv_buf);
    self->end = SvEND(sv_buf);

    vt102_process(self);

SV*
row_plaintext(self, row, ...)
    vt_state_t *self
    IV row
  PREINIT:
    int startcol, endcol, error;
  CODE:

    error = 0;

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
        startcol = 1;
        endcol   = self->num_cols;

        if ( self->zerobased ) {
            --startcol; --endcol;
        }
    }

    if ( error )
        croak("Usage: row_plaintext(row, [startcol], [endcol])");

    if ( !self->zerobased ) {
        --row;
        --startcol;
        --endcol;
    }

    if ( row      < 0 || row      >= self->num_rows ) XSRETURN_UNDEF;
    if ( startcol < 0 || startcol >= self->num_cols ) XSRETURN_UNDEF;
    if ( endcol   < 0 || endcol   >= self->num_cols ) XSRETURN_UNDEF;

    RETVAL = vt102_row_text(self, row, startcol, endcol, 1);
  OUTPUT:
    RETVAL

SV*
row_text(self, row, ...)
    vt_state_t *self
    IV row
  PREINIT:
    int startcol, endcol, error;
  CODE:

    error = 0;

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
        startcol = 1;
        endcol   = self->num_cols;

        if ( self->zerobased ) {
            --startcol; --endcol;
        }
    }

    if ( !self->zerobased ) {
        --row;
        --startcol;
        --endcol;
    }


    if ( row      < 0 || row      >= self->num_rows ) XSRETURN_UNDEF;
    if ( startcol < 0 || startcol >= self->num_cols ) XSRETURN_UNDEF;
    if ( endcol   < 0 || endcol   >= self->num_cols ) XSRETURN_UNDEF;

    if ( error )
        croak("Usage: row_text(row, [startcol], [endcol])");


    RETVAL = vt102_row_text(self, row, startcol, endcol, 0);
  OUTPUT:
    RETVAL

SV*
size(self)
    vt_state_t *self
  PPCODE:


    EXTEND(SP, 2);

    mPUSHs( newSViv(self->num_cols) );
    mPUSHs( newSViv(self->num_rows) );

IV
rows(self)
    vt_state_t *self
  CODE:


    RETVAL = self->num_rows;
  OUTPUT:
    RETVAL

IV
cols(self)
    vt_state_t *self
  CODE:


    RETVAL = self->num_cols;
  OUTPUT:
    RETVAL

IV
x(self)
    vt_state_t *self
  PREINIT:
    int x;
  CODE:


    x = self->x;
    if ( !self->zerobased ) ++x;

    RETVAL = x;
  OUTPUT:
    RETVAL

IV
y(self)
    vt_state_t *self
  PREINIT:
    IV y;
  CODE:


    y = self->y;
    if ( !self->zerobased ) ++y;

    RETVAL = y;
  OUTPUT:
    RETVAL

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

    RETVAL = vt102_attr_pack(attrs[0],
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
row_attr(self, rownum, ...)
    vt_state_t *self
    IV rownum
  PREINIT:
    SV *ret;
    int error, startcol, endcol;
  CODE:

    error = 0;

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
        startcol = 1;
        endcol   = self->num_cols;

        if ( self->zerobased ) {
            --startcol; --endcol;
        }
    }

    if ( error )
        croak("Usage: row_attr(row, [startcol], [endcol])");

    if ( !self->zerobased ) {
        --rownum;
        --startcol;
        --endcol;
    }

    ret = vt102_row_attr(self, rownum, startcol, endcol);

    RETVAL =  ret;
  OUTPUT:
    RETVAL


SV*
option_set(self, option, value)
    vt_state_t *self
    SV *option
    SV *value
  PREINIT:
    SV *ret;
  CODE:

    ret = NULL;
    vt102_option_check(self, option, value, "LINEWRAP",
                       &self->options.linewrap, &ret);

    vt102_option_check(self, option, value, "LFTOCRLF",
                       &self->options.lftocrlf, &ret);

    vt102_option_check(self, option, value, "IGNOREXOFF",
                       &self->options.ignorexoff, &ret);

    if ( ret == NULL )
        XSRETURN_UNDEF;

    RETVAL = ret;
  OUTPUT:
    RETVAL

IV
option_read(self, option)
    vt_state_t *self
    SV *option
  PREINIT:
    I8 *ret;
  CODE:

    ret = vt102_option_return(self, option);

    if ( ret == NULL ) {
        XSRETURN_UNDEF;
    }

    RETVAL = *ret;
  OUTPUT:
    RETVAL

SV*
callback_set(self, action, ...)
    vt_state_t *self
    SV *action
  PREINIT:
    SV *callback;
    SV *private;
  CODE:

    RETVAL = newSViv(0);
  OUTPUT:
    RETVAL

SV*
callback_call(self, action, param1, param2)
    vt_state_t *self
    SV *action
    SV *param1
    SV *param2
  PREINIT:
  CODE:

    RETVAL = newSViv(0);
  OUTPUT:
    RETVAL

void
DESTROY(self)
    vt_state_t *self
  PREINIT:
    int i;
  CODE:
    for (i = 0; i < self->num_rows; ++i) {
        Safefree(self->rows[i]->cells);
        Safefree(self->rows[i]);
    }
    Safefree(self->rows);
    Safefree(self->tabstops);
    Safefree(self);
