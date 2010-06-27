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

#if defined(__GNUC__) && !defined(TX_NO_DTC)
/* enable DTC optimization */
#define TX_DIRECT_THREADED_CODE
#endif

#define TX_RAW_CLASS   "Text::Xslate::Type::Raw"
#define TX_PAIR_CLASS  "Text::Xslate::Type::Pair"
#define TX_MACRO_CLASS "Text::Xslate::Macro"

/* arbitrary initial buffer size */
#define TX_HINT_SIZE 128

/* max calling depth (execution/macrocall) */
#define TX_MAX_DEPTH 100

#define TXC(name) static void CAT2(TXCODE_, name)(pTHX_ tx_state_t* const txst PERL_UNUSED_DECL)
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
struct tx_info_s;

typedef struct tx_state_s  tx_state_t;
typedef struct tx_code_s   tx_code_t;
typedef struct tx_info_s   tx_info_t;

#define TX_op            (TX_st->pc)
#define TX_PC2POS(st, p) ((UV)((p) - (st)->code))
#define TX_POS2PC(st, u) ((st)->code + (u))

typedef tx_code_t* tx_pc_t;

#define TX_RETURN_NEXT() STMT_START { TX_st->pc++;                     return; } STMT_END
#define TX_RETURN_PC(x)  STMT_START { TX_st->pc = INT2PTR(tx_pc_t, x); return; } STMT_END

#ifdef TX_DIRECT_THREADED_CODE

typedef const void* tx_exec_t;
#define TX_RUNOPS(st) tx_runops(aTHX_ st)

#else /* TX_DIRECT_THREADED_CODE */

typedef void (*tx_exec_t)(pTHX_ tx_state_t* const);
#define TX_RUNOPS(st) STMT_START {                      \
        while((st)->pc->exec_code != TXCODE_end) {      \
            CALL_FPTR((st)->pc->exec_code)(aTHX_ (st)); \
        }                                               \
    } STMT_END

#endif /* TX_DIRECT_THREADED_CODE */

/* virtual machine state */
struct tx_state_s {
    tx_pc_t pc;      /* the program counter */

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

    HV* symbol; /* symbol table (e.g. name => \&body | [macro object]) */

    U32 hint_size; /* suggested template size (bytes) */

    AV* tmpl;    /* template objects. see enum txtmplo_ix */
    SV* engine;  /* Text::Xslate instance */
    tx_info_t* info;  /* index -> an oinfo object */
};

/* opcode structure */
struct tx_code_s {
    tx_exec_t exec_code;

    SV* arg;
};

/* opcode information */
struct tx_info_s {
    U16 optype;
    U16 line;
    SV* file;
    SV* symbol;
};

#define TX_VERBOSE_DEFAULT 1

void
tx_warn(pTHX_ tx_state_t* const, const char* const fmt, ...)
    __attribute__format__(__printf__, pTHX_2, pTHX_3);

void
tx_error(pTHX_ tx_state_t* const, const char* const fmt, ...)
    __attribute__format__(__printf__, pTHX_2, pTHX_3);

const char*
tx_neat(pTHX_ SV* const sv);

SV*
tx_call_sv(pTHX_ tx_state_t* const st, SV* const sv, I32 const flags, const char* const name);

SV*
tx_proccall(pTHX_ tx_state_t* const st, SV* const proc, const char* const name);

SV*
tx_mark_raw(pTHX_ SV* const str);

SV*
tx_unmark_raw(pTHX_ SV* const str);


/* builtin method stuff */

SV*
tx_methodcall(pTHX_ tx_state_t* const st, SV* const method);

void
tx_register_builtin_methods(pTHX_ HV* const hv);
