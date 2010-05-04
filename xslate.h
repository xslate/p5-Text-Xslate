/* xslate.h */

#define TX_ESC_CLASS "Text::Xslate::EscapedString"

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

/* template representation, stored in $self->{template}{$file} */
enum txtmplo_ix {
    TXo_NAME,
    TXo_ERROR_HANDLER,
    TXo_MTIME,

    TXo_CACHEPATH,
    TXo_FULLPATH, /* TXo_FULLPATH must be the last one */
    /* dependencies here */
    TXo_least_size
};

/* vm execution frame */
enum txframeo_ix {
    TXframe_NAME,
    TXframe_OUTPUT,
    TXframe_RETADDR,

    TXframe_START_LVAR, /* TXframe_START_LVAR must be the last one */
    /* local variables here */
    TXframe_least_size = TXframe_START_LVAR
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

    HV* macro;    /* name -> $addr */
    HV* function; /* name => \&body */

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

#ifdef DEBUGGING
#define TX_st_sa  *tx_sv_safe(aTHX_ &(TX_st->sa),  "TX_st->sa",  __FILE__, __LINE__)
#define TX_st_sb  *tx_sv_safe(aTHX_ &(TX_st->sb),  "TX_st->sb",  __FILE__, __LINE__)
#define TX_op_arg *tx_sv_safe(aTHX_ &(TX_op->arg), "TX_st->arg", __FILE__, __LINE__)
static SV**
tx_sv_safe(pTHX_ SV** const svp, const char* const name, const char* const f, int const l) {
    if(UNLIKELY(*svp == NULL)) {
        croak("panic: %s is NULL at %s line %d.\n", name, f, l);
    }
    return svp;
}

#define TX_lvarx_get(st, ix) tx_lvar_get_safe(aTHX_ st, ix)

static SV*
tx_lvar_get_safe(pTHX_ tx_state_t* const st, I32 const lvar_ix) {
    AV* const cframe  = TX_current_framex(st);
    I32 const real_ix = lvar_ix + TXframe_START_LVAR;

    assert(SvTYPE(cframe) == SVt_PVAV);

    if(AvFILLp(cframe) < real_ix) {
        croak("panic: local variable storage is too small (%d < %d)",
            (int)(AvFILLp(cframe) - TXframe_START_LVAR), (int)lvar_ix); 
    }

    if(!st->pad) {
        croak("panic: access local variable (%d) before initialization",
            (int)lvar_ix);
    }
    return st->pad[lvar_ix];
}


#else /* DEBUGGING */
#define TX_st_sa        (TX_st->sa)
#define TX_st_sb        (TX_st->sb)
#define TX_op_arg       (TX_op->arg)

#define TX_lvarx_get(st, ix) ((st)->pad[ix])
#endif /* DEBUGGING */

#define TX_lvarx(st, ix) tx_fetch_lvar(aTHX_ st, ix)

#define TX_lvar(ix)     TX_lvarx(TX_st, ix)     /* init if uninitialized */
#define TX_lvar_get(ix) TX_lvarx_get(TX_st, ix)

/* aliases */
#define TXCODE_literal_i   TXCODE_literal
#define TXCODE_depend      TXCODE_noop

#include "xslate_ops.h"
