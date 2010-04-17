#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

/* buffer size coefficient (bits), used for memory allocation */
/* (1 << 6) * U16_MAX = about 4 MiB */
#define TX_BUFFER_SIZE_C 6

#define XSLATE(name) static void CAT2(XSLATE_, name)(pTHX_ tx_state_t* const txst)

#define TX_st (txst)
#define TX_op (&(TX_st->code[TX_st->pc]))

#ifdef DEBUGGING
#define TX_st_sa  *tx_sv_safe(aTHX_ &(TX_st->sa),  "TX_st->sa",  __FILE__, __LINE__)
#define TX_st_sb  *tx_sv_safe(aTHX_ &(TX_st->sb),  "TX_st->sb",  __FILE__, __LINE__)
#define TX_op_arg *tx_sv_safe(aTHX_ &(TX_op->arg), "TX_st->arg", __FILE__, __LINE__)
static SV**
tx_sv_safe(pTHX_ SV** const svp, const char* const name, const char* const f, int const l) {
    if(UNLIKELY(*svp == NULL)) {
        croak("panic: %s is NULL at %s line %d.\n", name, f, l);
    }
    else if(UNLIKELY(SvIS_FREED(*svp))) {
        croak("panic: %s is a freed sv at %s line %d.\n", name, f, l);
    }
    return svp;
}
#else
#define TX_st_sa  (TX_st->sa)
#define TX_st_sb  (TX_st->sb)
#define TX_op_arg (TX_op->arg)
#endif

struct tx_code_s;
struct tx_state_s;

typedef struct tx_code_s  tx_code_t;
typedef struct tx_state_s tx_state_t;

typedef void (*tx_exec_t)(pTHX_ tx_state_t*);

struct tx_state_s {
    U32 pc;       /* the program counter */

    tx_code_t* code; /* compiled code */
    U32        code_len;

    /* registers */

    SV* sa;
    SV* sb;

    /* variables */

    HV* vars;    /* template variables */
    AV* iter_v;  /* iterator variables */
    AV* iter_i;  /* iterator counter */

    SV* output;

    SV* error_handler;

    /* file information */
    SV*  file;
    U16* lines;  /* code index -> line number */
};

struct tx_code_s {
    tx_exec_t exec_code;

    SV* arg;
};

static const char*
tx_file(pTHX_ const tx_state_t* const st) {
    if(st->file) {
        assert(SvPOK(st->file));
        return SvPVX_const(st->file);
    }
    else {
        return "<input>";
    }
}

static int
tx_line(pTHX_ const tx_state_t* const st) {
    return (int)st->lines[ st->pc ];
}

static SV*
tx_fetch(pTHX_ const tx_state_t* const st, SV* const var, SV* const key) {
    SV* sv = NULL;
    PERL_UNUSED_ARG(st);
    if(sv_isobject(var)) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        ENTER;
        SAVETMPS;

        call_sv(key, G_SCALAR | G_METHOD | G_EVAL);

        SPAGAIN;
        sv = newSVsv(POPs);
        PUTBACK;

        if(sv_true(ERRSV)){
            croak("%"SVf "\n\t... exception cought on %"SVf".%"SVf,
                ERRSV, var, key);
        }

        FREETMPS;
        LEAVE;

        sv_2mortal(sv);
    }
    else if(SvROK(var)){
        SV* const rv = SvRV(var);
        if(SvTYPE(rv) == SVt_PVHV) {
            HE* const he = hv_fetch_ent((HV*)rv, key, FALSE, 0U);

            sv = he ? hv_iterval((HV*)rv, he) : &PL_sv_undef;
        }
        else if(SvTYPE(rv) == SVt_PVAV) {
            SV** const svp = av_fetch((AV*)rv, SvIV(key), FALSE);

            sv = svp ? *svp : &PL_sv_undef;
        }
        else {
            goto invalid_container;
        }
    }
    else {
        invalid_container:
        croak("Cannot access '%"SVf"' (%s is not a container)",
            key, SvOK(var) ? form("'%"SVf"'", var) : "undef");
    }
    return sv;
}

XSLATE(noop) {
    TX_st->pc++;
}

XSLATE(move_sa_to_sb) {
    TX_st_sb = TX_st_sa;

    TX_st->pc++;
}

XSLATE(swap) { /* swap sa and sb */
    SV* const tmp = TX_st_sa;
    TX_st_sa      = TX_st_sb;
    TX_st_sb      = tmp;

    TX_st->pc++;
}

XSLATE(push) {
    dSP;
    XPUSHs(TX_st_sa);
    PUTBACK;

    TX_st->pc++;
}

XSLATE(pop) {
    dSP;
    TX_st_sa = POPs;
    PUTBACK;

    TX_st->pc++;
}
XSLATE(pop_to_sb) {
    dSP;
    TX_st_sb = POPs;
    PUTBACK;

    TX_st->pc++;
}

XSLATE(literal) {
    TX_st_sa = TX_op_arg;

    TX_st->pc++;
}

XSLATE(fetch) { /* fetch a field from top */
    HV* const vars = TX_st->vars;
    HE* const he   = hv_fetch_ent(vars, TX_op_arg, FALSE, 0U);

    TX_st_sa = LIKELY(he != NULL) ? hv_iterval(vars, he) : &PL_sv_undef;

    TX_st->pc++;
}

XSLATE(fetch_field) { /* fetch a field from a variable (bin operator) */
    SV* const var = TX_st_sb;
    SV* const key = TX_st_sa;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

XSLATE(fetch_field_s) { /* fetch a field from a variable (for literal) */
    SV* const var = TX_st_sa;
    SV* const key = TX_op_arg;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

XSLATE(print) {
    SV* const sv          = TX_st_sa;
    SV* const output      = TX_st->output;
    STRLEN len;
    const char*       cur = SvPV_const(sv, len);
    const char* const end = cur + len;

    (void)SvGROW(output, len + SvCUR(output) + 1);

    while(cur != end) {
        const char* parts;
        STRLEN      parts_len;

        switch(*cur) {
        case '<':
            parts     =        "&lt;";
            parts_len = sizeof("&lt;") - 1;
            break;
        case '>':
            parts     =        "&gt;";
            parts_len = sizeof("&gt;") - 1;
            break;
        case '&':
            parts     =        "&amp;";
            parts_len = sizeof("&amp;") - 1;
            break;
        case '"':
            parts     =        "&quot;";
            parts_len = sizeof("&quot;") - 1;
            break;
        case '\'':
            parts     =        "&#39;";
            parts_len = sizeof("&#39;") - 1;
            break;
        default:
            parts     = cur;
            parts_len = 1;
            break;
        }

        len = SvCUR(output) + parts_len + 1;
        (void)SvGROW(output, len);

        if(parts_len == 1) {
            *SvEND(output) = *parts;
        }
        else {
            Copy(parts, SvEND(output), parts_len, char);
        }
        SvCUR_set(output, SvCUR(output) + parts_len);

        cur++;
    }
    *SvEND(output) = '\0';

    TX_st->pc++;
}

XSLATE(print_s) {
    TX_st_sa = TX_op_arg;

    XSLATE_print(aTHX_ TX_st);
}

XSLATE(print_raw) {
    sv_catsv_nomg(TX_st->output, TX_st_sa);

    TX_st->pc++;
}

XSLATE(print_raw_s) {
    sv_catsv_nomg(TX_st->output, TX_op_arg);

    TX_st->pc++;
}

XSLATE(for_start) {
    SV* const avref = TX_st_sa;
    IV  const id    = SvIV(TX_op_arg);
    AV* av;

    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("Iterator variables must be an ARRAY reference");
    }

    av = (AV*)SvRV(avref);
    SvREFCNT_inc_simple_void_NN(av);
    (void)av_store(TX_st->iter_v, id, (SV*)av);
    sv_setiv(*av_fetch(TX_st->iter_i, id, TRUE), 0); /* (re)set iterator */

    TX_st->pc++;
}

XSLATE(for_next) {
    SV* const idsv = TX_st_sa;
    IV  const id   = SvIV(idsv);
    AV* const av   = (AV*)AvARRAY(TX_st->iter_v)[ id ];
    SV* const i    =      AvARRAY(TX_st->iter_i)[ id ];

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(++SvIVX(i) <= AvFILLp(av)) {
        TX_st->pc += SvIV(TX_op_arg); /* back to */
    }
    else {
        /* finish the for loop */

        /* don't need to clear iterator variables,
           they will be cleaned at the end of render() */

        /* IV const id = SvIV(TX_op_arg); */
        /* av_delete(TX_st->iter_v, id, G_DISCARD); */
        /* av_delete(TX_st->iter_i, id, G_DISCARD); */

        TX_st->pc++;
    }
}

XSLATE(fetch_iter) {
    SV* const idsv = TX_op_arg;
    IV  const id   = SvIV(idsv);
    AV* const av   = (AV*)AvARRAY(TX_st->iter_v)[ id ];
    SV* const i    =      AvARRAY(TX_st->iter_i)[ id ];
    SV** svp;

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    //warn("fetch_iter[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    svp = av_fetch(av, SvIVX(i), FALSE);
    TX_st_sa = svp ? *svp : &PL_sv_undef;

    TX_st->pc++;
}

XSLATE(add) {
    TX_st_sa = sv_2mortal( newSVnv( SvNVx(TX_st_sb) + SvNVx(TX_st_sa) ) );
    TX_st->pc++;
}
XSLATE(sub) {
    TX_st_sa = sv_2mortal( newSVnv( SvNVx(TX_st_sb) - SvNVx(TX_st_sa) ) );
    TX_st->pc++;
}
XSLATE(mul) {
    TX_st_sa = sv_2mortal( newSVnv( SvNVx(TX_st_sb) * SvNVx(TX_st_sa) ) );
    TX_st->pc++;
}
XSLATE(div) {
    TX_st_sa = sv_2mortal( newSVnv( SvNVx(TX_st_sb) / SvNVx(TX_st_sa) ) );
    TX_st->pc++;
}
XSLATE(mod) {
    TX_st_sa = sv_2mortal( newSVnv( SvIVx(TX_st_sb) % SvIVx(TX_st_sa) ) );
    TX_st->pc++;
}

XSLATE(and) {
    if(sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc += SvIVx(TX_op_arg);
    }
}

XSLATE(or) {
    if(!sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc += SvIVx(TX_op_arg);
    }
}

XSLATE(not) {
    assert(TX_st_sa != NULL);
    TX_st_sa = boolSV( !sv_true(TX_st_sa) );

    TX_st->pc++;
}

static I32
tx_sv_eq(pTHX_ SV* const a, SV* const b) {
    U32 const af = (SvFLAGS(a) & (SVf_POK|SVf_IOK|SVf_NOK));
    U32 const bf = (SvFLAGS(a) & (SVf_POK|SVf_IOK|SVf_NOK));

    if(af && bf) {
        if(af == SVf_IOK && bf == SVf_IOK) {
            return SvIVX(a) == SvIVX(b);
        }
        else {
            return sv_eq(a, b);
        }
    }

    SvGETMAGIC(a);
    SvGETMAGIC(b);

    if(SvOK(a)) {
        return SvOK(b) && sv_eq(a, b);
    }
    else { /* !SvOK(a) */
        return !SvOK(b);
    }
}

XSLATE(eq) {
    TX_st_sa = boolSV(  tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

XSLATE(ne) {
    TX_st_sa = boolSV( !tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

XSLATE(lt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) < SvNVx(TX_st_sa) );
    TX_st->pc++;
}
XSLATE(le) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) <= SvNVx(TX_st_sa) );
    TX_st->pc++;
}
XSLATE(gt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) > SvNVx(TX_st_sa) );
    TX_st->pc++;
}
XSLATE(ge) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) >= SvNVx(TX_st_sa) );
    TX_st->pc++;
}

XSLATE(pc_inc) {
    TX_st->pc += SvIV(TX_op_arg);
}

XSLATE(goto) {
    TX_st->pc = SvIV(TX_op_arg);
}


XS(XS_Text__Xslate__error); /* -Wmissing-prototypes */
XS(XS_Text__Xslate__error) {
    dVAR; dXSARGS;
    tx_state_t* const st = (tx_state_t*)XSANY.any_ptr;
    assert(st);

    PERL_UNUSED_ARG(items);

    /* avoid recursion; they are retrieved at the end of the scope, anyway */
    PL_diehook  = NULL;
    PL_warnhook = NULL;

    croak("Xslate(%s:%d): %"SVf,
        tx_file(aTHX_ st), tx_line(aTHX_ st), ST(0));
    XSRETURN_EMPTY; /* not reached */
}

static SV*
xslate_exec(pTHX_ tx_state_t* const parent, SV* const output, HV* const hv) {
    Size_t const code_len = parent->code_len;
    tx_state_t st;

    StructCopy(parent, &st, tx_state_t);

    st.output = output;
    st.vars   = hv;

    ENTER;
    SAVETMPS;

    /* local $SIG{__WARN__} = \&error_handler */
    SAVESPTR(PL_warnhook);
    PL_warnhook = st.error_handler;

    /* local $SIG{__DIE__} = \&error_handler */
    SAVESPTR(PL_diehook);
    PL_diehook = st.error_handler;

    if(SvTYPE(st.error_handler) == SVt_PVCV
        && CvXSUB((CV*)st.error_handler) == XS_Text__Xslate__error) {
        CvXSUBANY(st.error_handler).any_ptr = &st;
    }

    while(st.pc < code_len) {
        Size_t const old_pc = st.pc;
        CALL_FPTR(st.code[st.pc].exec_code)(aTHX_ &st);

        if(UNLIKELY(old_pc == st.pc)) {
            croak("panic: pogram counter has not been changed on [%d]", (int)st.pc);
        }
    }

    FREETMPS;
    LEAVE;

    return st.output;
}

static MAGIC*
mgx_find(pTHX_ SV* const sv, const MGVTBL* const vtbl){
    MAGIC* mg;

    assert(sv   != NULL);
    assert(vtbl != NULL);

    for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
        if(mg->mg_virtual == vtbl){
            assert(mg->mg_type == PERL_MAGIC_ext);
            return mg;
        }
    }

    croak("MAGIC(0x%p) not found", vtbl);
    return NULL; /* not reached */
}

static int
tx_mg_free(pTHX_ SV* const sv, MAGIC* const mg){
    tx_state_t* const st  = (tx_state_t*)mg->mg_ptr;
    tx_code_t* const code = st->code;
    I32 const len         = st->code_len;
    I32 i;

    for(i = 0; i < len; i++) {
        SvREFCNT_dec(code[i].arg);
    }

    Safefree(code);
    PERL_UNUSED_ARG(sv);

    SvREFCNT_dec(st->error_handler);

    SvREFCNT_dec(st->iter_v);
    SvREFCNT_dec(st->iter_i);

    SvREFCNT_dec(st->file);
    Safefree(st->lines);

    return 0;
}

static MGVTBL xslate_vtbl = { /* for identity */
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    tx_mg_free, /* free */
    NULL, /* copy */
    NULL, /* dup */
    NULL,  /* local */
};

enum {
    TXOP_noop,

    TXOP_move_sa_to_sb,
    TXOP_swap,
    TXOP_push,
    TXOP_pop,
    TXOP_pop_to_sb,

    TXOP_literal,
    TXOP_fetch,
    TXOP_fetch_field,
    TXOP_fetch_field_s,
    TXOP_fetch_iter,

    TXOP_print,
    TXOP_print_s,
    TXOP_print_raw,
    TXOP_print_raw_s,

    TXOP_for_start,
    TXOP_for_next,

    TXOP_add,
    TXOP_sub,
    TXOP_mul,
    TXOP_div,
    TXOP_mod,

    TXOP_and,
    TXOP_or,
    TXOP_not,
    TXOP_eq,
    TXOP_ne,
    TXOP_lt,
    TXOP_le,
    TXOP_gt,
    TXOP_ge,

    TXOP_pc_inc,
    TXOP_goto,

    TXOP_last
};

static const tx_exec_t tx_opcode[] = {
    XSLATE_noop,

    XSLATE_move_sa_to_sb,
    XSLATE_swap,
    XSLATE_push,
    XSLATE_pop,
    XSLATE_pop_to_sb,

    XSLATE_literal,
    XSLATE_fetch,
    XSLATE_fetch_field,
    XSLATE_fetch_field_s,
    XSLATE_fetch_iter,

    XSLATE_print,
    XSLATE_print_s,
    XSLATE_print_raw,
    XSLATE_print_raw_s,

    XSLATE_for_start,
    XSLATE_for_next,

    XSLATE_add,
    XSLATE_sub,
    XSLATE_mul,
    XSLATE_div,
    XSLATE_mod,

    XSLATE_and,
    XSLATE_or,
    XSLATE_not,
    XSLATE_eq,
    XSLATE_ne,
    XSLATE_lt,
    XSLATE_le,
    XSLATE_gt,
    XSLATE_ge,

    XSLATE_pc_inc,
    XSLATE_goto,

    NULL
};


#define REG_TXOP(name) (void)hv_stores(ops, STRINGIFY(name), newSViv(CAT2(TXOP_, name)))

MODULE = Text::Xslate    PACKAGE = Text::Xslate

PROTOTYPES: DISABLE


BOOT:
{
    HV* const ops = get_hv("Text::Xslate::_ops", GV_ADDMULTI);

    REG_TXOP(noop);

    REG_TXOP(move_sa_to_sb);
    REG_TXOP(swap);
    REG_TXOP(push);
    REG_TXOP(pop);
    REG_TXOP(pop_to_sb);

    REG_TXOP(literal);
    REG_TXOP(fetch);
    REG_TXOP(fetch_field);
    REG_TXOP(fetch_field_s);
    REG_TXOP(fetch_iter);

    REG_TXOP(print);
    REG_TXOP(print_s);
    REG_TXOP(print_raw);
    REG_TXOP(print_raw_s);

    REG_TXOP(for_start);
    REG_TXOP(for_next);

    REG_TXOP(add);
    REG_TXOP(sub);
    REG_TXOP(mul);
    REG_TXOP(div);
    REG_TXOP(mod);

    REG_TXOP(and);
    REG_TXOP(or);
    REG_TXOP(not);
    REG_TXOP(eq);
    REG_TXOP(ne);
    REG_TXOP(lt);
    REG_TXOP(le);
    REG_TXOP(gt);
    REG_TXOP(ge);

    REG_TXOP(pc_inc);
    REG_TXOP(goto);
}

void
_initialize(HV* self, AV* proto)
CODE:
{
    if(SvRMAGICAL((SV*)self) && mgx_find(aTHX_ (SV*)self, &xslate_vtbl)) {
        croak("Cannot call _initialize twice");
    }


    {
        MAGIC* mg;
        HV* const ops = get_hv("Text::Xslate::_ops", GV_ADD);
        I32 const len = av_len(proto) + 1;
        I32 i;
        U16 l = 0;
        tx_state_t st;
        SV** svp;

        Zero(&st, 1, tx_state_t);

        svp = hv_fetchs(self, "loaded", FALSE);
        if(svp) {
            st.file = newSVsv(*svp);
        }

        svp = hv_fetchs(self, "error_handler", FALSE);
        if(svp && SvOK(*svp)) {
            st.error_handler = *svp;
        }
        else {
            CV* const eh = newXS(NULL, XS_Text__Xslate__error, __FILE__);
            st.error_handler = (SV*)eh;
        }

        st.sa       = &PL_sv_undef;
        st.sb       = &PL_sv_undef;

        st.iter_v   = newAV();
        st.iter_i   = newAV();

        Newx(st.lines, len, U16);

        Newx(st.code, len, tx_code_t);

        st.code_len = len;

        mg = sv_magicext((SV*)self, NULL, PERL_MAGIC_ext, &xslate_vtbl, (char*)&st, sizeof(st));
        mg->mg_private = 1; /* initial hint size */

        for(i = 0; i < len; i++) {
            SV* const pair = *av_fetch(proto, i, TRUE);
            if(SvROK(pair) && SvTYPE(SvRV(pair)) == SVt_PVAV) {
                AV* const av     = (AV*)SvRV(pair);
                SV* const opname = *av_fetch(av, 0, TRUE);
                SV** const arg   =  av_fetch(av, 1, FALSE);
                SV** const line  =  av_fetch(av, 2, FALSE);
                HE* const he     = hv_fetch_ent(ops, opname, FALSE, 0U);
                SV* opnum;

                if(!he){
                    croak("Unknown opcode '%"SVf"' on [%d]", opname, (int)i);
                }

                opnum             = hv_iterval(ops, he);
                st.code[i].exec_code = tx_opcode[ SvIV(opnum) ];
                if(arg && SvOK(*arg)) {
                    if(SvIV(opnum) == TXOP_fetch) {
                        STRLEN len;
                        const char* const pv = SvPV_const(*arg, len);
                        st.code[i].arg = newSVpvn_share(pv, len, 0U);
                    }
                    else {
                        st.code[i].arg = newSVsv(*arg);
                    }
                }
                else {
                    st.code[i].arg = &PL_sv_undef;
                }

                /* setup line number */
                if(line && SvOK(*line)) {
                    l = (U16)SvIV(*line);
                }
                st.lines[i] = l;
            }
            else {
                croak("Broken code found on [%d]", (int)i);
            }
        }
    }
}

SV*
render(HV* self, HV* hv)
CODE:
{
    MAGIC* const mg      = mgx_find(aTHX_ (SV*)self, &xslate_vtbl);
    tx_state_t* const st = (tx_state_t*)mg->mg_ptr;
    STRLEN hint_size;
    assert(st);

    RETVAL = sv_newmortal();
    sv_grow(RETVAL, mg->mg_private << TX_BUFFER_SIZE_C);
    SvPOK_on(RETVAL);

    xslate_exec(aTHX_ st, RETVAL, hv);

    /* store a hint size for the next time */
    hint_size = SvCUR(RETVAL) >> TX_BUFFER_SIZE_C;
    if(hint_size > mg->mg_private) {
        mg->mg_private = (U16)(hint_size > U16_MAX ? U16_MAX : hint_size);
    }

    ST(0) = RETVAL;
    XSRETURN(1);
}

