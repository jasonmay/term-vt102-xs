#ifndef _VT102_H_

#define _VT102_H_

/* VT102 macros */
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

#define _IS_CTL(C) ((C) >= 0 && (C) < 0x1F)

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

#define CSI_IGN     '['
#define CSI_ICH     '@'
#define CSI_CUU     'A'
#define CSI_CUD     'B'
#define CSI_CUF     'C'
#define CSI_CUB     'D'
#define CSI_CNL     'E'
#define CSI_CPL     'F'
#define CSI_CHA     'G'
#define CSI_CUP     'H'
#define CSI_ED      'J'
#define CSI_EL      'K'
#define CSI_IL      'L'
#define CSI_DL      'M'
#define CSI_DCH     'P'
#define CSI_ECH     'X'
#define CSI_HPR     'a'
#define CSI_DA      'c'
#define CSI_VPA     'd'
#define CSI_VPR     'e'
#define CSI_HVP     'f'
#define CSI_TBC     'g'
#define CSI_SM      'h'
#define CSI_RM      'l'
#define CSI_SGR     'm'
#define CSI_DSR     'n'
#define CSI_DECLL   'q'
#define CSI_DECSTBM 'r'
#define CSI_CUPSV   's'
#define CSI_CUPRS   'u'
#define CSI_HPA     '`'

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

    char seq_buf[64];

    VT_OPTIONS options;

    /* internal toggles */
    I8 in_esc;
    I8 xon;

    int *tabstops;

} VT_SWITCHES;

/* prototypes */
VT_CELL *_current_cell(VT_SWITCHES *);
char     _is_csi_terminator(char);
SV      *_process_csi(VT_SWITCHES *, char **);
SV      *_process_ctl(VT_SWITCHES *, char **);
void     _process_text(VT_SWITCHES *, char **);
void     _process(VT_SWITCHES *, SV *);
void     _inc_y(VT_SWITCHES *);
void     _check_rows_param(SV *, SV *, VT_SWITCHES *);
void     _check_cols_param(SV *, SV *, VT_SWITCHES *);
void     _clear_row(VT_SWITCHES *, int);
void     _init(VT_SWITCHES *);
SV      *_row_text(VT_SWITCHES *, int, int);

#endif /* end of include guard: _VT102_H_ */