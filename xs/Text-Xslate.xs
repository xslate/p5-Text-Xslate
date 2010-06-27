#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define NEED_newSVpvn_flags_GLOBAL
#define NEED_newSVpvn_share
#define NEED_newSV_type
#include "ppport.h"

#include "xslate.h"

/* aliases */
#define TXCODE_literal_i   TXCODE_literal
#define TXCODE_depend      TXCODE_noop
#define TXCODE_macro_begin TXCODE_noop
#define TXCODE_macro_nargs TXCODE_noop
#define TXCODE_macro_outer TXCODE_noop
#define TXCODE_set_opinfo  TXCODE_noop

#include "xslate_ops.h"

#ifdef DEBUGGING
#define TX_st_sa  *tx_sv_safe(aTHX_ &(TX_st->sa),  "TX_st->sa",  __FILE__, __LINE__)
#define TX_st_sb  *tx_sv_safe(aTHX_ &(TX_st->sb),  "TX_st->sb",  __FILE__, __LINE__)
#define TX_op_arg *tx_sv_safe(aTHX_ &(TX_op->arg), "TX_st->arg", __FILE__, __LINE__)
static SV**
tx_sv_safe(pTHX_ SV** const svp, const char* const name, const char* const f, int const l) {
    if(*svp == NULL) {
        croak("Oops: %s is NULL at %s line %d.\n", name, f, l);
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
        croak("Oops: Refers to unallocated local variable %d (> %d)",
            (int)lvar_ix, (int)(AvFILLp(cframe) - TXframe_START_LVAR));
    }

    if(!st->pad) {
        croak("Oops: Refers to local variable %d before initialization",
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

#define TX_lvarx(st, ix) tx_load_lvar(aTHX_ st, ix)

#define TX_lvar(ix)     TX_lvarx(TX_st, ix)     /* init if uninitialized */
#define TX_lvar_get(ix) TX_lvarx_get(TX_st, ix)

#define MY_CXT_KEY "Text::Xslate::_guts" XS_VERSION
typedef struct {
    U32 depth;
    HV* raw_stash;
    HV* macro_stash;

    tx_state_t* current_st; /* set while tx_execute(), othewise NULL */

    /* those handlers are just \&_warn and \&_die,
       but stored here for performance */
    SV* warn_handler;
    SV* die_handler;
} my_cxt_t;
START_MY_CXT

const char*
tx_neat(pTHX_ SV* const sv);

static SV*
tx_load_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix);

static AV*
tx_push_frame(pTHX_ tx_state_t* const st);

static SV*
tx_funcall(pTHX_ tx_state_t* const st, SV* const func, const char* const name);

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key);

static inline bool
tx_str_is_marked_raw(pTHX_ SV* const sv);

static inline void
tx_force_html_escape(pTHX_ SV* const src, SV* const dest);

static SV*
tx_html_escape(pTHX_ SV* const str);

static inline I32
tx_sv_eq(pTHX_ SV* const a, SV* const b);

static I32
tx_sv_match(pTHX_ SV* const a, SV* const b);

static bool
tx_sv_is_macro(pTHX_ SV* const sv);

static void
tx_macro_enter(pTHX_ tx_state_t* const txst, AV* const macro, tx_pc_t const retaddr);

static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv);

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name);


#include "xs/xslate_opcode.inc"


static const char*
tx_file(pTHX_ const tx_state_t* const st) {
    return SvPV_nolen_const(st->info[ TX_PC2POS(st, st->pc) ].file);
}

static int
tx_line(pTHX_ const tx_state_t* const st) {
    return (int)st->info[ TX_PC2POS(st, st->pc) ].line;
}

const char*
tx_neat(pTHX_ SV* const sv) {
    if(SvOK(sv)) {
        if(SvROK(sv) || looks_like_number(sv) || isGV(sv)) {
            return form("%"SVf, sv);
        }
        else {
            return form("'%"SVf"'", sv);
        }
    }
    return "nil";
}

static IV
tx_verbose(pTHX_ tx_state_t* const st) {
    HV* const hv = (HV*)SvRV(st->engine);
    SV* const sv = *hv_fetchs(hv, "verbose", TRUE);
    return SvIV(sv);
}

/* for trivial errors, ignored by default */
void
tx_warn(pTHX_ tx_state_t* const st, const char* const fmt, ...) {
    assert(st);
    assert(fmt);
    if(tx_verbose(aTHX_ st) > TX_VERBOSE_DEFAULT) { /* stronger than the default */
        va_list args;
        va_start(args, fmt);
        vwarn(fmt, &args);
        va_end(args);
    }
}

/* for severe errors, warned by default */
void
tx_error(pTHX_ tx_state_t* const st, const char* const fmt, ...) {
    assert(st);
    assert(fmt);
    if(tx_verbose(aTHX_ st) >= TX_VERBOSE_DEFAULT) { /* equal or stronger than the default */
        va_list args;
        va_start(args, fmt);
        vwarn(fmt, &args);
        va_end(args);
    }
}

static SV* /* allocate and load a lexcal variable */
tx_load_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix) { /* the guts of TX_lvar() */
    AV* const cframe  = TX_current_framex(st);
    I32 const real_ix = lvar_ix + TXframe_START_LVAR;

    assert(SvTYPE(cframe) == SVt_PVAV);

    if(AvFILLp(cframe) < real_ix || SvREADONLY(AvARRAY(cframe)[real_ix])) {
        av_store(cframe, real_ix, newSV(0));
    }
    st->pad = AvARRAY(cframe) + TXframe_START_LVAR;

    return TX_lvarx_get(st, lvar_ix);
}

static AV*
tx_push_frame(pTHX_ tx_state_t* const st) {
    AV* newframe;

    if(st->current_frame > TX_MAX_DEPTH) {
        croak("Macro call is too deep (> %d)", TX_MAX_DEPTH);
    }
    /* local $st->{current_frame} = $st->{current_frame} + 1 */
    SAVEI32(st->current_frame);
    st->current_frame++;

    newframe = (AV*)*av_fetch(st->frame, st->current_frame, TRUE);

    (void)SvUPGRADE((SV*)newframe, SVt_PVAV);
    if(AvFILLp(newframe) < TXframe_START_LVAR) {
        av_extend(newframe, TXframe_START_LVAR);
    }
    /* switch the pad */
    st->pad = AvARRAY(newframe) + TXframe_START_LVAR;
    return newframe;
}

SV* /* thin wrapper of Perl_call_sv() */
tx_call_sv(pTHX_ tx_state_t* const st, SV* const sv, I32 const flags, const char* const name) {
    call_sv(sv, G_SCALAR | G_EVAL | flags);

    if(UNLIKELY(!!sv_true(ERRSV))) {
        tx_error(aTHX_ st, "%"SVf "\n"
            "\t... exception cought on %s", ERRSV, name);
    }

    return TX_pop();
}

static SV*
tx_funcall(pTHX_ tx_state_t* const st, SV* const func, const char* const name) {
    HV* dummy_stash;
    GV* dummy_gv;
    CV* cv;
    SV* retval;
    SvGETMAGIC(func);

    if(UNLIKELY(!SvOK(func))) {
        dTX_optable;
        tx_code_t* const c = st->pc - 1;
        (void)POPMARK;
        tx_error(aTHX_ st, "Undefined function%s is called on %s",
            c->exec_code == tx_optable[TXOP_fetch_s]
                ? form(" %"SVf"()", c->arg)
                : "", name);
        retval = NULL;
        goto finish;
    }

    cv = sv_2cv(func, &dummy_stash, &dummy_gv, FALSE);

    if(UNLIKELY(!cv)) {
        (void)POPMARK;
        tx_error(aTHX_ st, "Functions must be a CODE reference, not %s",
            tx_neat(aTHX_ func));
        retval = NULL;
        goto finish;
    }

    retval = tx_call_sv(aTHX_ st, (SV*)cv, 0, "function call");

    finish:
    sv_setsv_nomg(st->targ, retval);

    return st->targ;
}

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key) {
    SV* sv = NULL;
    PERL_UNUSED_ARG(st);
    SvGETMAGIC(var);
    if(SvROK(var) && SvOBJECT(SvRV(var))) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        sv = tx_call_sv(aTHX_ st, key, G_METHOD, "accessor");
    }
    else if(SvROK(var)){
        SV* const rv = SvRV(var);
        SvGETMAGIC(key);
        if(SvTYPE(rv) == SVt_PVHV) {
            if(SvOK(key)) {
                HE* const he = hv_fetch_ent((HV*)rv, key, FALSE, 0U);
                if(he) {
                    sv = hv_iterval((HV*)rv, he);
                }
            }
            else {
                tx_warn(aTHX_ st, "Use of nil as a field key");
            }
        }
        else if(SvTYPE(rv) == SVt_PVAV) {
            if(LooksLikeNumber(key)) {
                SV** const svp = av_fetch((AV*)rv, SvIV(key), FALSE);
                if(svp) {
                    sv = *svp;
                }
            }
            else {
                tx_warn(aTHX_ st, "Use of %s as an array index",
                    tx_neat(aTHX_ key));
            }
        }
        else {
            goto invalid_container;
        }
    }
    else if(SvOK(var)){ /* string, number, etc. */
        invalid_container:
        tx_error(aTHX_ st, "Cannot access %s (%s is not a container)",
            tx_neat(aTHX_ key), tx_neat(aTHX_ var));
    }
    else { /* undef */
        tx_warn(aTHX_ st, "Use of nil to access %s", tx_neat(aTHX_ key));
    }

    return sv ? sv : &PL_sv_undef;
}

static inline bool
tx_str_is_marked_raw(pTHX_ SV* const sv) {
    if(SvROK(sv) && SvOBJECT(SvRV(sv))) {
        dMY_CXT;
        return SvTYPE(SvRV(sv)) <= SVt_PVMG
            && SvSTASH(SvRV(sv)) == MY_CXT.raw_stash;
    }
    return FALSE;
}

SV*
tx_mark_raw(pTHX_ SV* const str) {
    if(tx_str_is_marked_raw(aTHX_ str)) {
        return str;
    }
    else {
        dMY_CXT;
        SV* const sv = newSV_type(SVt_PVMG);
        sv_setsv(sv, str);
        return sv_2mortal(sv_bless(newRV_noinc(sv), MY_CXT.raw_stash));
    }
}

SV*
tx_unmark_raw(pTHX_ SV* const str) {
    if(tx_str_is_marked_raw(aTHX_ str)) {
        return SvRV(str);
    }
    else {
        return str;
    }
}

static inline void /* doesn't care about raw-ness */
tx_force_html_escape(pTHX_ SV* const src, SV* const dest) {
    STRLEN len;
    const char*       cur = SvPV_const(src, len);
    const char* const end = cur + len;

    (void)SvGROW(dest, SvCUR(dest) + len);

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
            parts     =        "&apos;";
            parts_len = sizeof("&apos;") - 1;
            break;
        default:
            parts     = cur;
            parts_len = 1;
            len       = SvCUR(dest) + 2; /* parts_len + 1 */
            SvGROW(dest, len);
            *SvEND(dest) = *parts;
            SvCUR_set(dest, SvCUR(dest) + 1);
            goto loop_continue;
            break;
        }

        /* copy special characters */

        len = SvCUR(dest) + parts_len + 1;
        (void)SvGROW(dest, len);

        Copy(parts, SvEND(dest), parts_len, char);

        SvCUR_set(dest, SvCUR(dest) + parts_len);

        loop_continue:
        cur++;
    }
    *SvEND(dest) = '\0';
}

static SV*
tx_html_escape(pTHX_ SV* const str) {
    if(!( tx_str_is_marked_raw(aTHX_ str) || !SvOK(str) )) {
        SV* const dest = newSVpvs_flags("", SVs_TEMP);
        tx_force_html_escape(aTHX_ str, dest);
        return tx_mark_raw(aTHX_ dest);
    }
    else {
        return str;
    }
}

static I32
tx_sv_eq_nomg(pTHX_ SV* const a, SV* const b) {
    if(SvOK(a)) {
        if(SvOK(b)) {
            U32 const af = (SvFLAGS(a) & (SVf_POK|SVf_IOK|SVf_NOK));
            U32 const bf =  SvFLAGS(b) & af;
            return bf == SVf_IOK
                ? SvIVX(a) == SvIVX(b)
                : sv_eq(a, b);
        }
        else {
            return FALSE;
        }
    }
    else { /* !SvOK(a) */
        return !SvOK(b);
    }
}

static inline I32
tx_sv_eq(pTHX_ SV* const a, SV* const b) {
    SvGETMAGIC(a);
    SvSETMAGIC(b);
    return tx_sv_eq_nomg(aTHX_ a, b);
}

static I32
tx_sv_match(pTHX_ SV* const a, SV* const b) {
    SvGETMAGIC(a);
    SvGETMAGIC(b);

    if(SvROK(b)) {
        SV* const r = SvRV(b);
        if(SvOBJECT(r)) { /* a ~~ $object */
            /* XXX: what I should do? */
            return tx_sv_eq_nomg(aTHX_ a, b);
        }
        else if(SvTYPE(r) == SVt_PVAV) { /* a ~~ [ ... ] */
            AV* const av  = (AV*)r;
            I32 const len = av_len(av) + 1;
            I32 i;
            for(i = 0; i < len; i++) {
                SV** const svp = av_fetch(av, i, FALSE);
                SV* item;
                if(svp) {
                    item = *svp;
                    SvGETMAGIC(item);
                }
                else {
                    item = &PL_sv_undef;
                }
                if(tx_sv_eq_nomg(aTHX_ a, item)) {
                    return TRUE;
                }
            }
            return FALSE;
        }
        else if(SvTYPE(r) == SVt_PVHV) { /* a ~~ { ... } */
            if(SvOK(a)) {
                HV* const hv = (HV*)r;
                return hv_exists_ent(hv, a, 0U);
            }
            else {
                return FALSE;
            }
        }
        /* fallthrough */
    }

    return tx_sv_eq_nomg(aTHX_ a, b);
}

static bool
tx_sv_is_macro(pTHX_ SV* const sv) {
    if(sv_isobject(sv)) {
        AV* const macro = (AV*)SvRV(sv);
        dMY_CXT;
        if(SvSTASH(macro) == MY_CXT.macro_stash) {
            if(!(SvTYPE(macro) == SVt_PVAV && AvFILLp(macro) == (TXm_size - 1))) {
                croak("Oops: Invalid macro object");
            }
            return TRUE;
        }
    }
    return FALSE;
}

/* called by tx_methodcall() */
/* proc may be a Xslate macro or a Perl subroutine (code ref) */
SV*
tx_proccall(pTHX_ tx_state_t* const txst, SV* const proc, const char* const name) {
    if(tx_sv_is_macro(aTHX_ proc)) {
        dTX_optable;
        tx_pc_t const save_pc = TX_st->pc;
        tx_code_t proc_end;

        proc_end.exec_code = tx_optable[ TXOP_end ];
        proc_end.arg = NULL;
        tx_macro_enter(aTHX_ TX_st, (AV*)SvRV(proc), &proc_end);
        TX_RUNOPS(TX_st);
        /* after tx_macro_end */

        TX_st->pc = save_pc;
        //warn("# return from %s\n", name);

        return TX_st_sa;
    }
    else {
        return tx_funcall(aTHX_ TX_st, proc, name);
    }
}

static void
tx_macro_enter(pTHX_ tx_state_t* const txst, AV* const macro, tx_pc_t const retaddr) {
    dSP;
    dMARK;
    I32 const items    = SP - MARK;
    SV* const name     = AvARRAY(macro)[TXm_NAME];
    tx_pc_t const addr = INT2PTR(tx_pc_t, SvUVX(AvARRAY(macro)[TXm_ADDR]));
    IV const nargs     = SvIVX(AvARRAY(macro)[TXm_NARGS]);
    UV const outer     = SvUVX(AvARRAY(macro)[TXm_OUTER]);
    AV* cframe; /* new frame */
    UV i;
    SV* tmp;

    if(items != nargs) {
        tx_error(aTHX_ TX_st, "Wrong number of arguments for %"SVf" (%d %c %d)",
            name, (int)items, items > nargs ? '>' : '<', (int)nargs);
        TX_st->sa = &PL_sv_undef;
        TX_RETURN_NEXT();
    }

    /* create a new frame */
    ENTER; /* to save current_frame */
    cframe = tx_push_frame(aTHX_ TX_st);

    /* setup frame info: name, retaddr and output buffer */
    sv_setsv(*av_fetch(cframe, TXframe_NAME,    TRUE), name);
    sv_setuv(*av_fetch(cframe, TXframe_RETADDR, TRUE), PTR2UV(retaddr));

    /* swap TXframe_OUTPUT and TX_st->output.
       I know it's ugly. Any ideas?
    */
    tmp                             = *av_fetch(cframe, TXframe_OUTPUT, TRUE);
    AvARRAY(cframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                   = tmp;
    sv_setpvs(tmp, "");
    SvUTF8_on(tmp); /* sv_utf8_upgrade(tmp); */

    i = 0;
    if(outer > 0) { /* refers outer lexical variales */
        /* copies lexical variables from the old frame to the new one */
        AV* const oframe = (AV*)AvARRAY(TX_st->frame)[TX_st->current_frame-1];
        for(NOOP; i < outer; i++) {
            UV const real_ix = i + TXframe_START_LVAR;
            av_store(cframe, real_ix , SvREFCNT_inc_NN(AvARRAY(oframe)[real_ix]));
        }
    }

    if(items > 0) { /* has arguments */
        dORIGMARK;
        MARK++;
        for(NOOP; MARK <= SP; i++) {
            sv_setsv(TX_lvar(i), *MARK);
            MARK++;
        }
        SP = ORIGMARK;
        PUTBACK;
    }
    TX_RETURN_PC(addr);
}

/* The virtual machine code interpreter */
/* NOTE: tx_execute() must be surrounded in ENTER and LEAVE */
static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv) {
    dMY_CXT;
    tx_state_t st;

    StructCopy(base, &st, tx_state_t);

    st.output = output;
    st.vars   = hv;

    assert(st.tmpl != NULL);

    /* local $current_st */
    SAVEVPTR(MY_CXT.current_st);
    MY_CXT.current_st = &st;

    if(MY_CXT.depth > TX_MAX_DEPTH) {
        croak("Execution is too deep (> %d)", TX_MAX_DEPTH);
    }

    /* local $depth = $depth + 1 */
    SAVEI32(MY_CXT.depth);
    MY_CXT.depth++;

    TX_RUNOPS(&st);

    /* clear temporary buffers */
    sv_setsv(st.targ, &PL_sv_undef);

    base->hint_size = SvCUR(st.output);
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

    croak("Xslate: Invalid template holder was passed");
    return NULL; /* not reached */
}

static int
tx_mg_free(pTHX_ SV* const sv, MAGIC* const mg){
    tx_state_t* const st      = (tx_state_t*)mg->mg_ptr;
    tx_info_t* const info     = st->info;
    tx_code_t* const code     = st->code;
    I32 const len             = st->code_len;
    I32 i;

    for(i = 0; i < len; i++) {
        /* opcode */
        SvREFCNT_dec(code[i].arg);

        /* opinfo */
        SvREFCNT_dec(info[i].file);
        SvREFCNT_dec(info[i].symbol);
    }

    Safefree(code);
    Safefree(info);

    SvREFCNT_dec(st->symbol);
    SvREFCNT_dec(st->frame);
    SvREFCNT_dec(st->targ);
    SvREFCNT_dec(st->engine);

    PERL_UNUSED_ARG(sv);

    return 0;
}

#ifdef USE_ITHREADS
static SV*
tx_sv_dup_inc(pTHX_ SV* const sv, CLONE_PARAMS* const param) {
    return SvREFCNT_inc( sv_dup(sv, param) );
}
#endif

static int
tx_mg_dup(pTHX_ MAGIC* const mg, CLONE_PARAMS* const param){
#ifdef USE_ITHREADS /* single threaded perl has no "xxx_dup()" APIs */
    tx_state_t*       st        = (tx_state_t*)mg->mg_ptr;
    tx_info_t* const proto_info = st->info;
    tx_code_t* const proto_code = st->code;
    U32 const len               = st->code_len;
    U32 i;

    Newx(st->code, len, tx_code_t);
    Newx(st->info, len, tx_info_t);

    for(i = 0; i < len; i++) {
        /* opcode */
        st->code[i].exec_code = proto_code[i].exec_code;
        st->code[i].arg       = tx_sv_dup_inc(aTHX_ proto_code[i].arg, param);

        /* opinfo */
        st->info[i].optype    = proto_info[i].optype;
        st->info[i].line      = proto_info[i].line;
        st->info[i].file      = tx_sv_dup_inc(aTHX_ proto_info[i].file, param);
        st->info[i].symbol    = tx_sv_dup_inc(aTHX_ proto_info[i].symbol, param);
    }

    st->symbol   = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->symbol, param);
    st->frame    = (AV*)tx_sv_dup_inc(aTHX_ (SV*)st->frame,    param);
    st->targ     =      tx_sv_dup_inc(aTHX_ st->targ, param);
    st->engine   =      tx_sv_dup_inc(aTHX_ st->engine, param);
#else
    PERL_UNUSED_ARG(mg);
    PERL_UNUSED_ARG(param);
#endif
    return 0;
}


static MGVTBL xslate_vtbl = { /* for identity */
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    tx_mg_free, /* free */
    NULL, /* copy */
    tx_mg_dup, /* dup */
#ifdef MGf_LOCAL
    NULL,  /* local */
#endif
};


static void
tx_invoke_load_file(pTHX_ SV* const self, SV* const name, SV* const mtime) {
    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 3);
    PUSHs(self);
    PUSHs(name);
    if(mtime) {
        PUSHs(mtime);
    }
    PUTBACK;

    call_method("load_file", G_EVAL | G_VOID);
    if(sv_true(ERRSV)){
        croak("%"SVf"\t...", ERRSV);
    }

    FREETMPS;
    LEAVE;
}

static bool
tx_all_deps_are_fresh(pTHX_ AV* const tmpl, Time_t const cache_mtime) {
    I32 const len = AvFILLp(tmpl) + 1;
    I32 i;
    Stat_t f;

    for(i = TXo_FULLPATH; i < len; i++) {
        SV* const deppath = AvARRAY(tmpl)[i];

        if(!SvOK(deppath)) {
            continue;
        }

        //PerlIO_stdoutf("check deps: %"SVf" ... ", path); // */
        if(PerlLIO_stat(SvPV_nolen_const(deppath), &f) < 0
               || f.st_mtime > cache_mtime) {
            SV* const main_cache = AvARRAY(tmpl)[TXo_CACHEPATH];
            /* compiled caches are no longer fresh, so it must be discarded */

            if(i != TXo_FULLPATH && SvOK(main_cache)) {
                PerlLIO_unlink(SvPV_nolen_const(main_cache));
            }
            //PerlLIO_unlink(SvPV_nolen_const(AvARRAY(tmpl);

            //PerlIO_stdoutf("%"SVf": too old (%d > %d)\n", deppath, (int)f.st_mtime, (int)cache_mtime); // */
            return FALSE;
        }
        else {
            //PerlIO_stdoutf("%"SVf": fresh enough (%d <= %d)\n", deppath, (int)f.st_mtime, (int)cache_mtime); // */
        }
    }
    return TRUE;
}

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name) {
    HV* hv;
    const char* why = NULL;
    HE* he;
    SV** svp;
    SV* sv;
    HV* ttable;
    AV* tmpl;
    MAGIC* mg;
    SV* cache_mtime;
    int retried = 0;

    //PerlIO_stdoutf("load_template(%"SVf")\n", name);

    if(!(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV)) {
        croak("Invalid xslate instance: %s", tx_neat(aTHX_ self));
    }

    hv = (HV*)SvRV(self);

    retry:
    if(retried > 1) {
        why = "retried reloading, but failed";
        goto err;
    }

    /* validation by modified time (mtime) */

    /* my $ttable = $self->{template} */
    svp = hv_fetchs(hv, "template", FALSE);
    if(!svp) {
        why = "template table is not found";
        goto err;
    }

    sv = *svp;
    if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)) {
        why = "template table is not a HASH reference";
        goto err;
    }

    ttable = (HV*)SvRV(sv);

    /* $tmpl = $ttable->{$name} */
    he = hv_fetch_ent(ttable, name, FALSE, 0U);
    if(!he) {
        tx_invoke_load_file(aTHX_ self, name, NULL);
        retried++;
        goto retry;
    }

    sv = hv_iterval(ttable, he);
    if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)) {
        why = "template entry is invalid";
        goto err;
    }

    tmpl = (AV*)SvRV(sv);
    mg   = mgx_find(aTHX_ (SV*)tmpl, &xslate_vtbl);

    if(AvFILLp(tmpl) < (TXo_least_size-1)) {
        why = form("template entry is broken (size:%d < %d)", AvFILLp(tmpl)+1, TXo_least_size);
        goto err;
    }

    /* check mtime */

    cache_mtime = AvARRAY(tmpl)[TXo_MTIME];

    if(!SvOK(cache_mtime)) { /* non-checking mode (i.e. release mode) */
        return (tx_state_t*)mg->mg_ptr;
    }

    //PerlIO_stdoutf("###%d %d\n", (int)retried, (int)SvIVX(cache_mtime));

    if(retried > 0 /* if already retried, it should be valid */
            || tx_all_deps_are_fresh(aTHX_ tmpl, SvIVX(cache_mtime))) {
        return (tx_state_t*)mg->mg_ptr;
    }
    else {
        tx_invoke_load_file(aTHX_ self, name, cache_mtime);
        retried++;
        goto retry;
    }

    err:
    croak("Xslate: Cannot load template %s: %s", tx_neat(aTHX_ name), why);
}

static void
tx_my_cxt_init(pTHX_ pMY_CXT_ bool const cloning PERL_UNUSED_DECL) {
    MY_CXT.depth = 0;
    MY_CXT.raw_stash     = gv_stashpvs(TX_RAW_CLASS, GV_ADDMULTI);
    MY_CXT.macro_stash   = gv_stashpvs(TX_MACRO_CLASS, GV_ADDMULTI);
    MY_CXT.warn_handler  = SvREFCNT_inc_NN((SV*)get_cv("Text::Xslate::Engine::_warn", GV_ADDMULTI));
    MY_CXT.die_handler   = SvREFCNT_inc_NN((SV*)get_cv("Text::Xslate::Engine::_die",  GV_ADDMULTI));
}

/* Because overloading stuff of old xsubpp didn't work,
   we need to copy them. */
XS(XS_Text__Xslate__Type__Raw_fallback); /* prototype to pass -Wmissing-prototypes */
XS(XS_Text__Xslate__Type__Raw_fallback)
{
   dXSARGS;
   PERL_UNUSED_VAR(cv);
   PERL_UNUSED_VAR(items);
   XSRETURN_EMPTY;
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Engine

PROTOTYPES: DISABLE

BOOT:
{
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADDMULTI);
    MY_CXT_INIT;
    tx_my_cxt_init(aTHX_ aMY_CXT_ FALSE);
    tx_init_ops(aTHX_ ops);

    {
        EXTERN_C XS(boot_Text__Xslate__Methods);
        PUSHMARK(SP);
        boot_Text__Xslate__Methods(aTHX_ cv);
    }
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    tx_my_cxt_init(aTHX_ aMY_CXT_ FALSE);
    PERL_UNUSED_VAR(items);
}

#endif

void
_assemble(HV* self, AV* proto, SV* name, SV* fullpath, SV* cachepath, SV* mtime)
CODE:
{
    dMY_CXT;
    MAGIC* mg;
    dTX_optable;
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADD);
    U32 const len = av_len(proto) + 1;
    U32 i;
    U16 oi_line; /* opinfo.line */
    SV* oi_file;
    tx_state_t st;
    AV* tmpl;
    SV* tobj;
    SV** svp;
    AV* mainframe;
    AV* macro = NULL;

    Zero(&st, 1, tx_state_t);

    svp = hv_fetchs(self, "template", FALSE);
    if(!(svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV)) {
        croak("The xslate instance has no template table");
    }

    if(!SvOK(name)) { /* for strings */
        name     = sv_2mortal(newSVpvs_share("<input>"));
        fullpath = cachepath = &PL_sv_undef;
        mtime    = sv_2mortal(newSViv( time(NULL) ));
    }

    tobj = hv_iterval((HV*)SvRV(*svp),
         hv_fetch_ent((HV*)SvRV(*svp), name, TRUE, 0U)
    );

    svp = hv_fetchs(self, "function", FALSE);
    if(!( SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV )) {
        croak("Function table must be a HASH reference");
    }
    st.symbol = newHVhv((HV*)SvRV(*svp)); /* must be copied */
    tx_register_builtin_methods(aTHX_ st.symbol);

    tmpl = newAV();
    sv_setsv(tobj, sv_2mortal(newRV_noinc((SV*)tmpl)));
    av_extend(tmpl, TXo_least_size - 1);

    sv_setsv(*av_fetch(tmpl, TXo_NAME,      TRUE),  name);
    sv_setsv(*av_fetch(tmpl, TXo_MTIME,     TRUE),  mtime);
    sv_setsv(*av_fetch(tmpl, TXo_CACHEPATH, TRUE),  cachepath);
    sv_setsv(*av_fetch(tmpl, TXo_FULLPATH,  TRUE),  fullpath);

    st.tmpl   = tmpl;
    st.engine = newRV_inc((SV*)self);
    sv_rvweaken(st.engine);

    st.hint_size = TX_HINT_SIZE;

    st.sa       = &PL_sv_undef;
    st.sb       = &PL_sv_undef;
    st.targ     = newSV(0);

    /* stack frame */
    st.frame         = newAV();
    st.current_frame = -1;

    mainframe = tx_push_frame(aTHX_ &st);
    av_store(mainframe, TXframe_NAME,    newSVpvs_share("main"));
    av_store(mainframe, TXframe_RETADDR, newSVuv(len));

    Newxz(st.info, len + 1, tx_info_t);
    st.info[len].line = (U16)-1; /* invalid value */
    st.info[len].file = SvREFCNT_inc_simple_NN(name);

    Newxz(st.code, len, tx_code_t);

    st.code_len = len;
    st.pc       = &st.code[0];

    mg = sv_magicext((SV*)tmpl, NULL, PERL_MAGIC_ext, &xslate_vtbl, (char*)&st, sizeof(st));
    mg->mg_flags |= MGf_DUP;

    oi_line = 0;
    oi_file = name;

    for(i = 0; i < len; i++) {
        SV* const pair = *av_fetch(proto, i, TRUE);
        if(SvROK(pair) && SvTYPE(SvRV(pair)) == SVt_PVAV) {
            AV* const av     = (AV*)SvRV(pair);
            SV* const opname = *av_fetch(av, 0, TRUE);
            SV** const arg   =  av_fetch(av, 1, FALSE);
            SV** const line  =  av_fetch(av, 2, FALSE);
            SV** const file  =  av_fetch(av, 3, FALSE);
            SV** const sym   =  av_fetch(av, 4, FALSE);
            HE* const he     = hv_fetch_ent(ops, opname, FALSE, 0U);
            IV  opnum;

            if(!he){
                croak("Oops: Unknown opcode '%"SVf"' on [%d]", opname, (int)i);
            }

            opnum                = SvIVx(hv_iterval(ops, he));
            st.code[i].exec_code = tx_optable[opnum];
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

                    if(tx_oparg[opnum] & TXARGf_GOTO) {
                        /* calculate relational addresses to absolute addresses */
                        UV const abs_pos       = (UV)(i + SvIVX(st.code[i].arg));

                        if(abs_pos >= (UV)len) {
                            croak("Oops: goto address %"IVdf" is out of range (must be 0 <= addr <= %"IVdf")",
                                SvIVX(st.code[i].arg), (IV)len);
                        }
                        sv_setuv(st.code[i].arg, PTR2UV(TX_POS2PC(&st, abs_pos)));
                    }
                    SvREADONLY_on(st.code[i].arg);
                }
                else { /* normal sv */
                    st.code[i].arg = newSVsv(*arg);
                }
            }
            else {
                if(arg && SvOK(*arg)) {
                    croak("Oops: Opcode %"SVf" has an extra argument %s on [%d]",
                        opname, tx_neat(aTHX_ *arg), (int)i);
                }
                st.code[i].arg = NULL;
            }

            /* setup opinfo */
            if(line && SvOK(*line)) {
                oi_line = (U16)SvUV(*line);
            }
            if(file && SvOK(*file) && !sv_eq(*file, oi_file)) {
                oi_file = sv_mortalcopy(*file);
            }
            st.info[i].optype = (U16)opnum;
            st.info[i].line   = oi_line;
            st.info[i].file   = SvREFCNT_inc_simple_NN(oi_file);
            st.info[i].symbol = (sym && SvOK(*sym)) ? newSVsv(*sym) : NULL;

            /* special cases */
            if(opnum == TXOP_macro_begin) {
                SV* const name = st.code[i].arg;
                SV* const ent  = hv_iterval(st.symbol,
                    hv_fetch_ent(st.symbol, name, TRUE, 0U));

                if(!sv_true(ent)) {
                    SV* mref;
                    macro = newAV();
                    mref  = sv_2mortal(newRV_noinc((SV*)macro));
                    sv_bless(mref, MY_CXT.macro_stash);
                    sv_setsv(ent, mref);

                    (void)av_store(macro, TXm_OUTER, newSViv(0));
                    (void)av_store(macro, TXm_NARGS, newSViv(0));
                    (void)av_store(macro, TXm_ADDR,  newSVuv(PTR2UV(TX_POS2PC(&st, i))));
                    (void)av_store(macro, TXm_NAME,  name);
                    st.code[i].arg = NULL;
                }
                else { /* already defined */
                    macro = NULL;
                }
            }
            else if(opnum == TXOP_macro_nargs) {
                if(macro) {
                    /* the number of outer lexical variables */
                    (void)av_store(macro, TXm_NARGS, st.code[i].arg);
                    st.code[i].arg = NULL;
                }
            }
            else if(opnum == TXOP_macro_outer) {
                if(macro) {
                    /* the number of outer lexical variables */
                    (void)av_store(macro, TXm_OUTER, st.code[i].arg);
                    st.code[i].arg = NULL;
                }
            }
            else if(opnum == TXOP_depend) {
                /* add a dependent file to the tmpl object */
                av_push(tmpl, st.code[i].arg);
                st.code[i].arg = NULL;
            }
        }
        else {
            croak("Oops: Broken code found on [%d]", (int)i);
        }
    } /* end for each code */
}

SV*
render(SV* self, SV* source, SV* vars = &PL_sv_undef)
ALIAS:
    render        = 0
    render_string = 1
CODE:
{
    dMY_CXT;
    tx_state_t* st;

    if(!(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV)) {
        croak("Xslate: Invalid xslate instance: %s",
            tx_neat(aTHX_ self));
    }

    if(!SvOK(vars)) {
        vars = sv_2mortal(newRV_noinc((SV*)newHV()));
    }
    else if(!(SvROK(vars) && SvTYPE(SvRV(vars)) == SVt_PVHV)) {
        croak("Xslate: Template variables must be a HASH reference, not %s",
            tx_neat(aTHX_ vars));
    }


    if(ix == 1) { /* render_string() */
        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(self);
        PUSHs(source);
        PUTBACK;
        call_method("load_string", G_VOID | G_DISCARD);
        SPAGAIN;
        source = &PL_sv_undef;
    }

    SvGETMAGIC(source);
    if(!SvOK(source)) {
        dXSTARG;
        sv_setpvs(TARG, "<input>");
        source = TARG;
    }

    st = tx_load_template(aTHX_ self, source);

    /* local $SIG{__WARN__} = \&warn_handler */
    SAVESPTR(PL_warnhook);
    PL_warnhook = MY_CXT.warn_handler;

    /* local $SIG{__DIE__}  = \&die_handler */
    SAVESPTR(PL_diehook);
    PL_diehook = MY_CXT.die_handler;

    RETVAL = sv_newmortal();
    sv_grow(RETVAL, st->hint_size + TX_HINT_SIZE);
    SvPOK_on(RETVAL);

    tx_execute(aTHX_ st, RETVAL, (HV*)SvRV(vars));

    ST(0) = RETVAL;
    XSRETURN(1);
}

void
engine(klass)
CODE:
{
    dMY_CXT;
    tx_state_t* const st = MY_CXT.current_st;
    ST(0) = st ? st->engine : &PL_sv_undef;
    XSRETURN(1);
}

void
_warn(SV* msg)
ALIAS:
    _warn = 0
    _die  = 1
CODE:
{
    dMY_CXT;
    tx_state_t* const st = MY_CXT.current_st;
    SV* self;
    AV* cframe;
    SV* name;
    const char* prefix;
    SV* full_message;
    SV** svp;
    CV*  handler;

    if(!st) {
        SAVESPTR(PL_warnhook);
        SAVESPTR(PL_diehook);
        PL_warnhook = NULL;
        PL_diehook  = NULL;
        croak("Not in $xslate->render()");
    }
    self   = st->engine;

    cframe = TX_current_framex(st);
    name   = AvARRAY(cframe)[TXframe_NAME];

    svp = (ix == 0)
        ? hv_fetchs((HV*)SvRV(self), "warn_handler", FALSE)
        : hv_fetchs((HV*)SvRV(self), "die_handler",  FALSE);

    if(svp && SvOK(*svp)) {
        HV* stash;
        GV* gv;
        handler = sv_2cv(*svp, &stash, &gv, 0);
        if(!handler) {
            croak("Not a subroutine reference for %s handler",
                ix == 0 ? "warn" : "die");
        }
    }
    else {
        handler = NULL;
    }

    prefix = form("Xslate(%s:%d &%"SVf"[%d]): ",
            tx_file(aTHX_ st), tx_line(aTHX_ st),
            name, (int)TX_PC2POS(st, st->pc));

    if(instr(SvPV_nolen_const(msg), prefix)) {
        full_message = msg; /* msg has the prefix */
    }
    else {
        full_message = newSVpvf("%s%"SVf, prefix, msg);
        sv_2mortal(full_message);
    }

    /* warnhook/diehook = NULL is to avoid recursion */
    ENTER;
    if(ix == 0) { /* warn */
        SAVESPTR(PL_warnhook);
        PL_warnhook = NULL;

        /* handler can ignore warnings */
        if(handler) {
            PUSHMARK(SP);
            XPUSHs(full_message);
            PUTBACK;
            call_sv((SV*)handler, G_VOID | G_DISCARD);
        }
        else {
            warn("%"SVf, full_message);
        }
    }
    else {
        SAVESPTR(PL_diehook);
        PL_diehook = NULL;

        /* unroll the stack frame */
        /* to fix TXframe_OUTPUT */
        /* TODO: append the stack info to msg */
        while(st->current_frame > 0) {
            AV* const frame = (AV*)AvARRAY(st->frame)[st->current_frame];
            SV* tmp;
            st->current_frame--;

            /* swap st->output and TXframe_OUTPUT */
            tmp                            = AvARRAY(frame)[TXframe_OUTPUT];
            AvARRAY(frame)[TXframe_OUTPUT] = st->output;
            st->output                     = tmp;
        }

        /* handler cannot ignore errors */
        if(handler) {
            PUSHMARK(SP);
            XPUSHs(full_message);
            PUTBACK;
            call_sv((SV*)handler, G_VOID | G_DISCARD);
        }
        croak("%"SVf, full_message);
        /* not reached */
    }
    LEAVE;
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Util

void
mark_raw(SV* str)
CODE:
{
    ST(0) = tx_mark_raw(aTHX_ str);
    XSRETURN(1);
}

void
unmark_raw(SV* str)
CODE:
{
    ST(0) = tx_unmark_raw(aTHX_ str);
    XSRETURN(1);
}


void
html_escape(SV* str)
CODE:
{
    ST(0) = tx_html_escape(aTHX_ str);
    XSRETURN(1);
}

bool
match(SV* a, SV* b)
CODE:
{
    RETVAL = tx_sv_match(aTHX_ a, b);
}
OUTPUT:
    RETVAL

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Type::Raw

BOOT:
{
    SV* as_string;
    /* overload stuff */
    PL_amagic_generation++;
    sv_setsv(
        get_sv( TX_RAW_CLASS "::()", TRUE ),
        &PL_sv_yes
    );
    (void)newXS( TX_RAW_CLASS "::()",
        XS_Text__Xslate__Type__Raw_fallback, file);

    /* *{'(""'} = \&as_string */
    as_string = sv_2mortal(newRV_inc((SV*)get_cv( TX_RAW_CLASS "::as_string", GV_ADD)));
    sv_setsv_mg(
        (SV*)gv_fetchpvs( TX_RAW_CLASS "::(\"\"", GV_ADDMULTI, SVt_PVCV),
        as_string);
}

void
new(SV* klass, SV* str)
CODE:
{
    if(SvROK(klass)) {
        croak("You cannot call %s->new() as an instance method", TX_RAW_CLASS);
    }
    if(strNE(SvPV_nolen_const(klass), TX_RAW_CLASS)) {
        croak("You cannot extend %s", TX_RAW_CLASS);
    }
    ST(0) = tx_mark_raw(aTHX_ tx_unmark_raw(aTHX_ str));
    XSRETURN(1);
}

void
as_string(SV* self, ...)
CODE:
{
    if(! tx_str_is_marked_raw(aTHX_ self) ) {
        croak("You cannot call %s->as_string() as a class method", TX_RAW_CLASS);
    }
    ST(0) = SvRV(self);
    XSRETURN(1);
}
