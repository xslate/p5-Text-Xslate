#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

/* buffer size coefficient (bits), used for memory allocation */
/* (1 << 6) * U16_MAX = about 4 MiB */
#define TX_BUFFER_SIZE_C 6

#define XSLATE(name) static void CAT2(TXCODE_, name)(pTHX_ tx_state_t* const txst)
/* XSLATE_xxx macros provide the information of arguments, interpreted by tool/opcode.pl */
#define XSLATE_w_sv(n)  XSLATE(n) /* has TX_op_arg as a SV */
#define XSLATE_w_int(n) XSLATE(n) /* has TX_op_arg as an integer (i.e. can SvIVX(arg)) */
#define XSLATE_w_key(n) XSLATE(n) /* has TX_op_arg as a keyword */
#define XSLATE_w_var(n) XSLATE(n) /* has TX_op_arg as a local variable */

#define TXARGf_SV  ((U8)(0x01))
#define TXARGf_INT ((U8)(0x02))
#define TXARGf_KEY ((U8)(0x04))
#define TXARGf_VAR ((U8)(0x08))

#define TXCODE_W_SV  (TXARGf_SV)
#define TXCODE_W_INT (TXARGf_SV | TXARGf_INT)
#define TXCODE_W_KEY (TXARGf_SV | TXARGf_KEY)
#define TXCODE_W_VAR (TXARGf_SV | TXARGf_VAR | TXARGf_VAR)

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

#define TX_pop()   (*(PL_stack_sp--))

struct tx_code_s;
struct tx_state_s;

typedef struct tx_code_s  tx_code_t;
typedef struct tx_state_s tx_state_t;

typedef void (*tx_exec_t)(pTHX_ tx_state_t*);

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
    AV* iter_c;  /* iterating containers */
    AV* iter_i;  /* iterators */

    HV* function;
    SV* error_handler;

    /* file information */
    SV*  file;
    U16* lines;  /* code index -> line number */
};

struct tx_code_s {
    tx_exec_t exec_code;

    SV* arg;
};


#define TXCODE_literal_i TXCODE_literal

#include "xslate_ops.h"

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

static const char*
tx_neat(pTHX_ SV* const sv) {
    if(SvOK(sv)) {
        if(SvROK(sv) || looks_like_number(sv)) {
            return form("%"SVf, sv);
        }
        else {
            return form("'%"SVf"'", sv);
        }
    }
    return "undef";
}

static SV*
tx_call(pTHX_ tx_state_t* const st, SV* proc, I32 const flags, const char* const name) {
    ENTER;
    SAVETMPS;

    if(!(flags & G_METHOD)) {
        HV* dummy_stash;
        GV* dummy_gv;
        CV* const cv = sv_2cv(proc, &dummy_stash, &dummy_gv, FALSE);
        if(!cv) {
            croak("Functions must be a CODE reference, not %s",
                tx_neat(aTHX_ proc));
        }
        proc = (SV*)cv;
    }

    call_sv(proc, G_SCALAR | G_EVAL | flags);

    if(sv_true(ERRSV)){
        croak("%"SVf "\n"
            "\t... exception cought on %s", ERRSV, name);
    }

    sv_setsv_nomg(st->targ, TX_pop());

    FREETMPS;
    LEAVE;

    return st->targ;
}

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key) {
    SV* sv = NULL;
    PERL_UNUSED_ARG(st);
    if(sv_isobject(var)) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        sv = tx_call(aTHX_ st, key, G_METHOD, "accessor");
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
            key, tx_neat(aTHX_ var));
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
    TX_st_sa = TX_pop();

    TX_st->pc++;
}
XSLATE(pop_to_sb) {
    TX_st_sb = TX_pop();

    TX_st->pc++;
}

XSLATE(pushmark) {
    dSP;
    PUSHMARK(SP);

    TX_st->pc++;
}

XSLATE(nil) {
    TX_st_sa = &PL_sv_undef;

    TX_st->pc++;
}

XSLATE_w_sv(literal) {
    TX_st_sa = TX_op_arg;

    TX_st->pc++;
}

/* the same as literal, but make sure its argument is an integer */
XSLATE_w_int(literal_i);

XSLATE_w_key(fetch) { /* fetch a field from the top */
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

XSLATE_w_key(fetch_field_s) { /* fetch a field from a variable (for literal) */
    SV* const var = TX_st_sa;
    SV* const key = TX_op_arg;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

XSLATE(print) {
    SV* const sv          = TX_st_sa;
    SV* const output      = TX_st->output;

    if(SvNIOK(sv) && !SvPOK(sv)){
        sv_catsv_nomg(output, sv);
    }
    else {
        STRLEN len;
        const char*       cur = SvPV_const(sv, len);
        const char* const end = cur + len;

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
    }

    TX_st->pc++;
}

XSLATE_w_sv(print_s) {
    TX_st_sa = TX_op_arg;

    TXCODE_print(aTHX_ TX_st);
}

XSLATE(print_raw) {
    sv_catsv_nomg(TX_st->output, TX_st_sa);

    TX_st->pc++;
}

XSLATE_w_sv(print_raw_s) {
    sv_catsv_nomg(TX_st->output, TX_op_arg);

    TX_st->pc++;
}

XSLATE_w_var(for_start) {
    SV* const avref = TX_st_sa;
    IV  const id    = SvIVX(TX_op_arg);
    AV* av;

    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("Iterator variables must be an ARRAY reference, not %s",
            tx_neat(aTHX_ avref));
    }

    av = (AV*)SvRV(avref);
    SvREFCNT_inc_simple_void_NN(av);
    (void)av_store(TX_st->iter_c, id, (SV*)av);
    sv_setiv(*av_fetch(TX_st->iter_i, id, TRUE), 0); /* (re)set iterator */

    TX_st->pc++;
}

XSLATE_w_int(for_next) {
    SV* const idsv = TX_st_sa;
    IV  const id   = SvIVX(idsv); /* by literal_i */
    AV* const av   = (AV*)AvARRAY(TX_st->iter_c)[ id ];
    SV* const i    =      AvARRAY(TX_st->iter_i)[ id ];

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(++SvIVX(i) <= AvFILLp(av)) {
        TX_st->pc += SvIVX(TX_op_arg); /* back to */
    }
    else {
        /* finish the for loop */

        /* don't need to clear iterator variables,
           they will be cleaned at the end of render() */

        /* IV const id = SvIV(TX_op_arg); */
        /* av_delete(TX_st->iter_c, id, G_DISCARD); */
        /* av_delete(TX_st->iter_i, id, G_DISCARD); */

        TX_st->pc++;
    }

    FREETMPS;
}

XSLATE_w_int(fetch_iter) {
    SV* const idsv = TX_op_arg;
    IV  const id   = SvIVX(idsv);
    AV* const av   = (AV*)AvARRAY(TX_st->iter_c)[ id ];
    SV* const i    =      AvARRAY(TX_st->iter_i)[ id ];
    SV** svp;

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    //warn("fetch_iter[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    svp = av_fetch(av, SvIVX(i), FALSE);
    TX_st_sa = svp ? *svp : &PL_sv_undef;

    TX_st->pc++;
}

/* For arithmatic operators, SvIV_please() can make stringification faster,
   although I don't know why it is :)
*/
XSLATE(add) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) + SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
XSLATE(sub) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) - SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
XSLATE(mul) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) * SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
XSLATE(div) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) / SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
XSLATE(mod) {
    sv_setiv(TX_st->targ, SvIVx(TX_st_sb) % SvIVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}

/* NOTE: XSLATE_w_sv will make it faster, but it may be unimportant */
XSLATE(concat) {
    SV* const sv = sv_mortalcopy(TX_st_sb);
    sv_catsv_nomg(sv, TX_st_sa);

    TX_st_sa = sv;

    TX_st->pc++;
}

XSLATE(filt) {
    SV* const arg    = TX_st_sb;
    SV* const filter = TX_st_sa;
    dSP;

    PUSHMARK(SP);
    XPUSHs(arg);
    PUTBACK;

    TX_st_sa = tx_call(aTHX_ TX_st, filter, 0, "filtering");

    TX_st->pc++;
}

XSLATE_w_int(and) {
    if(sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc += SvIVX(TX_op_arg);
    }
}

XSLATE_w_int(or) {
    if(!sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc += SvIVX(TX_op_arg);
    }
}

XSLATE_w_int(dor) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc += SvIVX(TX_op_arg);
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

XSLATE_w_key(function) {
    HE* he;
    if(TX_st->function && (he = hv_fetch_ent(TX_st->function, TX_op_arg, FALSE, 0U))) {
        TX_st_sa = hv_iterval(TX_st->function, he);
    }
    else {
        croak("Function %s is not registered", tx_neat(aTHX_ TX_st_sa));
    }

    TX_st->pc++;
}

XSLATE(call) {
    /* PUSHMARK & PUSH must be done */
    TX_st_sa = tx_call(aTHX_ TX_st, TX_st_sa, 0, "calling");

    TX_st->pc++;
}

XSLATE_w_int(pc_inc) {
    TX_st->pc += SvIVX(TX_op_arg);
}

XSLATE_w_int(goto) {
    TX_st->pc = SvIVX(TX_op_arg);
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
xslate_exec(pTHX_ const tx_state_t* const base, SV* const output, HV* const hv) {
    Size_t const code_len = base->code_len;
    tx_state_t st;

    StructCopy(base, &st, tx_state_t);

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
    SvREFCNT_dec(st->function);

    SvREFCNT_dec(st->iter_c);
    SvREFCNT_dec(st->iter_i);

    SvREFCNT_dec(st->targ);

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

MODULE = Text::Xslate    PACKAGE = Text::Xslate

PROTOTYPES: DISABLE

BOOT:
{
    HV* const ops = get_hv("Text::Xslate::_ops", GV_ADDMULTI);
    tx_init_ops(aTHX_ ops);
}

void
_initialize(HV* self, AV* proto)
CODE:
{
    MAGIC* mg;
    HV* const ops = get_hv("Text::Xslate::_ops", GV_ADD);
    I32 const len = av_len(proto) + 1;
    I32 i;
    U16 l = 0;
    tx_state_t st;
    SV** svp;

    if(SvRMAGICAL((SV*)self) && mgx_find(aTHX_ (SV*)self, &xslate_vtbl)) {
        croak("Cannot call _initialize twice");
    }

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

    svp = hv_fetchs(self, "function", FALSE);
    if(svp && SvOK(*svp)) {
        if(SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV) {
            st.function = (HV*)SvRV(*svp);
            SvREFCNT_inc(st.function);
        }
        else {
            croak("Function table must be a HASH reference");
        }
    }

    st.sa       = &PL_sv_undef;
    st.sb       = &PL_sv_undef;
    st.targ     = newSV(0);

    st.iter_c   = newAV();
    st.iter_i   = newAV();

    Newxz(st.lines, len, U16);

    Newxz(st.code, len, tx_code_t);

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
            IV  opnum;

            if(!he){
                croak("Oops: Unknown opcode '%"SVf"' on [%d]", opname, (int)i);
            }

            opnum                = SvIVx(hv_iterval(ops, he));
            st.code[i].exec_code = tx_opcode[ opnum ];
            if(tx_oparg[opnum] & TXARGf_SV) {
                if(!arg) {
                    croak("Oops: Opcode %"SVf" must have an argument on [%d]", opname, (int)i);
                }

                if(tx_oparg[opnum] & TXARGf_KEY) {
                    STRLEN len;
                    const char* const pv = SvPV_const(*arg, len);
                    st.code[i].arg = newSVpvn_share(pv, len, 0U);
                }
                else if(tx_oparg[opnum] & TXARGf_INT) {
                    st.code[i].arg = newSViv(SvIV(*arg));
                    SvREADONLY_on(st.code[i].arg);
                }
                else {
                    st.code[i].arg = newSVsv(*arg);
                    SvREADONLY_on(st.code[i].arg);
                }
            }
            else {
                if(arg && SvOK(*arg)) {
                    croak("Oops: Opcode %"SVf" has an extra argument on [%d]", opname, (int)i);
                }
                st.code[i].arg = NULL;
            }

            /* setup line number */
            if(line && SvOK(*line)) {
                l = (U16)SvIV(*line);
            }
            st.lines[i] = l;
        }
        else {
            croak("Oops: Broken code found on [%d]", (int)i);
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

