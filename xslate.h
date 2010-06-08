/* xslate.h */

/* portability stuff */

#if !defined(__GNUC__)
#    if (!defined(__cplusplus__) || !defined(__STDC_VERSION__) ||  (__STDC_VERSION__ < 199901L)) && !defined(inline)
#        define inline
#    endif
#endif

#ifndef __attribute__format__
#define __attribute__format__(a,b,c) /* nothing */
#endif

#ifndef LIKELY /* they are just a compiler's hint */
#define LIKELY(x)   (x)
#define UNLIKELY(x) (x)
#endif

#ifndef newSVpvs_share
#define newSVpvs_share(s) Perl_newSVpvn_share(aTHX_ STR_WITH_LEN(s), 0U)
#endif

#if PERL_BCDVERSION < 0x5008005
#define LooksLikeNumber(x) (SvOK(x) && looks_like_number(x))
#else
#define LooksLikeNumber(x) looks_like_number(x)
#endif

/* xslate stuff */

#define TX_ESC_CLASS   "Text::Xslate::EscapedString"
#define TX_MACRO_CLASS "Text::Xslate::Macro"
#define TX_PAIR_CLASS  "Text::Xslate::Type::Pair"

/* arbitrary initial buffer size */
#define TX_HINT_SIZE 128

#define TXC(name) static void CAT2(TXCODE_, name)(pTHX_ tx_state_t* const txst)
/* TXC_xxx macros provide the information of arguments, interpreted by tool/opcode.pl */
#define TXC_w_sv(n)  TXC(n) /* has TX_op_arg as a SV */
#define TXC_w_int(n) TXC(n) /* has TX_op_arg as an integer (i.e. can SvIVX(arg)) */
#define TXC_w_key(n) TXC(n) /* has TX_op_arg as a keyword */
#define TXC_w_var(n) TXC(n) /* has TX_op_arg as a local variable */
#define TXC_goto(n)  TXC(n) /* does goto */

#define TXARGf_SV   ((U8)(0x01))
#define TXARGf_INT  ((U8)(0x02))
#define TXARGf_KEY  ((U8)(0x04))
#define TXARGf_VAR  ((U8)(0x08))
#define TXARGf_GOTO ((U8)(0x10))

#define TXCODE_W_SV  (TXARGf_SV)
#define TXCODE_W_INT (TXARGf_SV | TXARGf_INT)
#define TXCODE_W_VAR (TXARGf_SV | TXARGf_INT | TXARGf_VAR)
#define TXCODE_W_KEY (TXARGf_SV | TXARGf_KEY)
#define TXCODE_GOTO  (TXARGf_SV | TXARGf_INT | TXARGf_GOTO)

/* TX_st and TX_op are valid only in opcodes */
#define TX_st (txst)
#define TX_op (&(TX_st->code[TX_st->pc]))

#define TX_pop()   (*(PL_stack_sp--))

#define TX_current_framex(st) ((AV*)AvARRAY((st)->frame)[(st)->current_frame])
#define TX_current_frame()    TX_current_framex(TX_st)

/* template object, stored in $self->{template}{$file} */
enum txtmplo_ix {
    TXo_NAME,
    TXo_MTIME,

    TXo_CACHEPATH,
    TXo_FULLPATH, /* TXo_FULLPATH must be the last one */
    /* dependencies here */
    TXo_least_size
};

/* vm execution frame object */
enum txframeo_ix {
    TXframe_NAME,
    TXframe_OUTPUT,
    TXframe_RETADDR,

    TXframe_START_LVAR, /* TXframe_START_LVAR must be the last one */
    /* local variables here */
    TXframe_least_size = TXframe_START_LVAR
};

/* macro object */
enum txmacro_ix {
    TXm_NAME,
    TXm_ADDR,
    TXm_NARGS,
    TXm_OUTER,

    TXm_size,
};

struct tx_state_s;
struct tx_code_s;

typedef struct tx_state_s tx_state_t;
typedef struct tx_code_s  tx_code_t;

typedef void (*tx_exec_t)(pTHX_ tx_state_t* const);

/* virtual machine state */
struct tx_state_s {
    U32 pc;       /* the program counter */

    tx_code_t* code; /* compiled code */
    U32        code_len;

    SV* output;

    /* registers */

    SV* sa;
    SV* sb;
    SV* targ;

    /* variables */

    HV* vars;    /* template variables */

    /* stack frame */
    AV* frame;         /* see enum txframeo_ix */
    I32 current_frame; /* current frame index */
    SV** pad;          /* AvARRAY(frame[current_frame]) + 3 */

    HV* function; /* name => \&body | [macro object] */

    U32 hint_size; /* suggested template size (bytes) */

    AV* tmpl; /* see enum txtmplo_ix */
    SV* self;
    U16* lines;  /* code index -> line number */
};

/* opcode structure */
struct tx_code_s {
    tx_exec_t exec_code;

    SV* arg;
};

#define TX_VERBOSE_DEFAULT 1

/* aliases */
#define TXCODE_literal_i   TXCODE_literal
#define TXCODE_depend      TXCODE_noop
#define TXCODE_macro_begin TXCODE_noop
#define TXCODE_macro_nargs TXCODE_noop
#define TXCODE_macro_outer TXCODE_noop

void
tx_warn(pTHX_ tx_state_t* const, const char* const fmt, ...)
    __attribute__format__(__printf__, pTHX_2, pTHX_3);

void
tx_error(pTHX_ tx_state_t* const, const char* const fmt, ...)
    __attribute__format__(__printf__, pTHX_2, pTHX_3);

const char*
tx_neat(pTHX_ SV* const sv);

SV*
tx_call(pTHX_ tx_state_t* const st, SV* proc, I32 const flags, const char* const name);

SV*
tx_methodcall(pTHX_ tx_state_t* const st, SV* const method);

void
tx_register_builtin_methods(pTHX_ HV* const hv);

