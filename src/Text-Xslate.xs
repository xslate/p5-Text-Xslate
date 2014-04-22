#define NEED_newSVpvn_flags_GLOBAL
#define NEED_newSVpvn_share
#define NEED_newSV_type
#include "xslate.h"

#include "uri_unsafe.h"

/* aliases */
#define TXCODE_literal_i   TXCODE_literal
#define TXCODE_depend      TXCODE_noop
#define TXCODE_macro_begin TXCODE_noop
#define TXCODE_macro_nargs TXCODE_noop
#define TXCODE_macro_outer TXCODE_noop
#define TXCODE_set_opinfo  TXCODE_noop
#define TXCODE_super       TXCODE_noop

#include "xslate_ops.h"

static bool dump_load = FALSE;

#ifdef DEBUGGING
#define TX_st_sa  *tx_sv_safe(aTHX_ &(TX_st->sa),  "TX_st->sa",  __FILE__, __LINE__)
#define TX_st_sb  *tx_sv_safe(aTHX_ &(TX_st->sb),  "TX_st->sb",  __FILE__, __LINE__)
static SV**
tx_sv_safe(pTHX_ SV** const svp, const char* const name, const char* const f, int const l) {
    if(*svp == NULL) {
        croak("[BUG] %s is NULL at %s line %d.\n", name, f, l);
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
        croak("[BUG] Refers to unallocated local variable %d (> %d)",
            (int)lvar_ix, (int)(AvFILLp(cframe) - TXframe_START_LVAR));
    }

    if(!st->pad) {
        croak("[BUG] Refers to local variable %d before initialization",
            (int)lvar_ix);
    }
    return st->pad[lvar_ix];
}


#else /* DEBUGGING */
#define TX_st_sa        (TX_st->sa)
#define TX_st_sb        (TX_st->sb)

#define TX_lvarx_get(st, ix) ((st)->pad[ix])
#endif /* DEBUGGING */

#define TX_op_arg    (TX_op->u_arg)
#define TX_op_arg_sv (TX_op_arg.sv)
#define TX_op_arg_iv (TX_op_arg.iv)
#define TX_op_arg_pc (TX_op_arg.pc)

#define TX_lvarx(st, ix) tx_load_lvar(aTHX_ st, ix)

#define TX_lvar(ix)     TX_lvarx(TX_st, ix)     /* init if uninitialized */
#define TX_lvar_get(ix) TX_lvarx_get(TX_st, ix)

#define TX_ckuuv_lhs(x) tx_sv_check_uuv(aTHX_ (x), "lhs")
#define TX_ckuuv_rhs(x) tx_sv_check_uuv(aTHX_ (x), "rhs")

#define TX_UNMARK_RAW(sv) SvRV(sv)

#define MY_CXT_KEY "Text::Xslate::_guts" XS_VERSION
typedef struct {
    I32 depth;
    HV* raw_stash;
    HV* macro_stash;

    tx_state_t* current_st; /* set while tx_execute(), othewise NULL */

    /* those handlers are just \&_warn and \&_die,
       but stored here for performance */
    SV* warn_handler;
    SV* die_handler;

    /* original error handlers */
    SV* orig_warn_handler;
    SV* orig_die_handler;
    SV* make_error;
} my_cxt_t;
START_MY_CXT

static void
tx_sv_clear(pTHX_ SV* const sv) {
    sv_unmagic(sv, PERL_MAGIC_taint);
    sv_setsv(sv, NULL);
}

const char*
tx_neat(pTHX_ SV* const sv);

static SV*
tx_load_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix);

static AV*
tx_push_frame(pTHX_ tx_state_t* const st);

static void
tx_pop_frame(pTHX_ tx_state_t* const st, bool const replace_output);

static SV*
tx_funcall(pTHX_ tx_state_t* const st, SV* const func, const char* const name);

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key);

static SV*
tx_sv_to_ref(pTHX_ SV* const sv, svtype const svt, int const amg_id);

int
tx_sv_is_array_ref(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV && !SvOBJECT(SvRV(sv));
}

int
tx_sv_is_hash_ref(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV && !SvOBJECT(SvRV(sv));
}

int
tx_sv_is_code_ref(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV && !SvOBJECT(SvRV(sv));
}

SV*
tx_merge_hash(pTHX_ tx_state_t* const st, SV* base, SV* value) {
    HV* const hv        = (HV*)SvRV(base);
    HV* const result    = newHVhv(hv);
    SV* const resultref = newRV_noinc((SV*)result);
    HE* he;
    HV* m;
    sv_2mortal((SV*)resultref);

    SvGETMAGIC(base);
    SvGETMAGIC(value);

    if(!tx_sv_is_hash_ref(aTHX_ value)) {
        if (st) {
            tx_error(aTHX_ st, "Merging value is not a HASH reference");
        }
        else {
            Perl_croak(aTHX_ "Merging value is not a HASH reference");
        }
        return resultref;
    }

    m = (HV*)SvRV(value);

    hv_iterinit(m);
    while((he = hv_iternext(m))) {
        (void)hv_store_ent(result,
            hv_iterkeysv(he),
            newSVsv(hv_iterval(hv, he)),
            0U);
    }

    return resultref;
}

STATIC_INLINE bool
tx_str_is_raw(pTHX_ pMY_CXT_ SV* const sv); /* doesn't handle magics */

STATIC_INLINE void
tx_sv_cat(pTHX_ SV* const dest, SV* const src);

static void
tx_sv_cat_with_html_escape_force(pTHX_ SV* const dest, SV* const src);

STATIC_INLINE void
tx_print(pTHX_ tx_state_t* const st, SV* const sv);

static SV*
tx_html_escape(pTHX_ SV* const str);

static SV*
tx_uri_escape(pTHX_ SV* const src);

STATIC_INLINE I32
tx_sv_eq(pTHX_ SV* const a, SV* const b);

static SV*
tx_sv_check_uuv(pTHX_ SV* const sv, const char* const name);

static I32
tx_sv_match(pTHX_ SV* const a, SV* const b);

static bool
tx_sv_is_macro(pTHX_ SV* const sv);

static void
tx_macro_enter(pTHX_ tx_state_t* const txst, AV* const macro, tx_pc_t const retaddr);

static void
tx_execute(pTHX_ pMY_CXT_ tx_state_t* const base, SV* const output, HV* const hv);

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name, bool const from_include);

#ifndef save_op
#define save_op() my_save_op(aTHX)
static void
my_save_op(pTHX) { /* copied from scope.c */
    SSCHECK(2);
    SSPUSHPTR(PL_op);
    SSPUSHINT(SAVEt_OP);
}
#endif

#include "src/xslate_opcode.inc"

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


static void
tx_call_error_handler(pTHX_ SV* const handler, SV* const msg) {
    dSP;
    PUSHMARK(SP);
    XPUSHs(msg);
    PUTBACK;
    call_sv(handler, G_VOID | G_DISCARD);
}

/* for trivial errors, ignored by default */
void
tx_warn(pTHX_ tx_state_t* const st, const char* const fmt, ...) {
    assert(st);
    assert(fmt);
    if(tx_verbose(aTHX_ st) > TX_VERBOSE_DEFAULT) { /* stronger than the default */
        dMY_CXT;
        SV* msg;
        va_list args;
        va_start(args, fmt);

        ENTER;
        SAVETMPS;
        msg = sv_2mortal( vnewSVpvf(fmt, &args) );
        tx_call_error_handler(aTHX_ MY_CXT.warn_handler, msg);
        va_end(args);
        FREETMPS;
        LEAVE;
    }
}

/* for severe errors, warned by default */
void
tx_error(pTHX_ tx_state_t* const st, const char* const fmt, ...) {
    assert(st);
    assert(fmt);
    if(tx_verbose(aTHX_ st) >= TX_VERBOSE_DEFAULT) { /* equal or stronger than the default */
        dMY_CXT;
        SV* msg;
        va_list args;
        va_start(args, fmt);
        msg = sv_2mortal( vnewSVpvf(fmt, &args) );
        tx_call_error_handler(aTHX_ MY_CXT.warn_handler, msg);
        /* not reached */
        va_end(args);
    }
}

static SV* /* allocate and load a lexcal variable */
tx_load_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix) { /* the guts of TX_lvar() */
    AV* const cframe  = TX_current_framex(st);
    I32 const real_ix = lvar_ix + TXframe_START_LVAR;

    assert(SvTYPE(cframe) == SVt_PVAV);

    if(AvFILLp(cframe) < real_ix
       || AvARRAY(cframe)[real_ix] == NULL
       || SvREADONLY(AvARRAY(cframe)[real_ix])) {
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
    st->current_frame++;

    newframe = (AV*)*av_fetch(st->frames, st->current_frame, TRUE);

    (void)SvUPGRADE((SV*)newframe, SVt_PVAV);
    if(AvFILLp(newframe) < TXframe_START_LVAR) {
        av_extend(newframe, TXframe_START_LVAR);
    }
    /* switch the pad */
    st->pad = AvARRAY(newframe) + TXframe_START_LVAR;
    return newframe;
}

static void
tx_pop_frame(pTHX_ tx_state_t* const st, bool const replace_output) {
    AV* const top  = TX_frame_at(st, st->current_frame);

    av_fill(top, TXframe_START_LVAR - 1);

    assert( st->current_frame >= 0 );
    if (--st->current_frame >= 0) {
        /* switch the pad */
        st->pad = AvARRAY(TX_frame_at(st, st->current_frame))
                    + TXframe_START_LVAR;
    }

    if(replace_output) {
        SV** const ary      = AvARRAY(top);
        SV* const tmp       = ary[TXframe_OUTPUT];
        ary[TXframe_OUTPUT] = st->output;
        st->output          = tmp;
    }
}

SV* /* thin wrapper of Perl_call_sv() */
tx_call_sv(pTHX_ tx_state_t* const st, SV* const sv, I32 const flags, const char* const name) {
    SV* retval;
    call_sv(sv, G_SCALAR | G_EVAL | flags);
    retval = TX_pop();
    if(TX_CATCH_ERROR()) {
        tx_error(aTHX_ st, "%"SVf "\n"
            "\t... exception caught on %s", ERRSV, name);
    }
    return retval;
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
                ? form(" %"SVf"()", c->u_arg.sv)
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
    SV* retval;

    SvGETMAGIC(var);
    if(SvROK(var) && SvOBJECT(SvRV(var))) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        return tx_call_sv(aTHX_ st, key, G_METHOD, "accessor");
    }

    retval = NULL;
    if(SvROK(var)){
        SV* const rv = SvRV(var);
        SvGETMAGIC(key);
        if(SvTYPE(rv) == SVt_PVHV) {
            if(SvOK(key)) {
                HE* const he = hv_fetch_ent((HV*)rv, key, FALSE, 0U);
                if(he) {
                    retval = hv_iterval((HV*)rv, he);
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
                    retval = *svp;
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
    TAINT_NOT;

    return retval ? retval : &PL_sv_undef;
}

#ifndef amagic_deref_call
#define amagic_deref_call(ref, method) my_amagic_deref_call(aTHX_ ref, method)
/* portability */
static SV*
my_amagic_deref_call(pTHX_ SV* ref, const int method) {
    SV* tmpsv = NULL;

    while (SvAMAGIC(ref) &&
       (tmpsv = amagic_call(ref, &PL_sv_undef, method,
                AMGf_noright | AMGf_unary))) {
        if (!SvROK(tmpsv))
            Perl_croak(aTHX_ "Overloaded dereference did not return a reference");
        if (tmpsv == ref || SvRV(tmpsv) == SvRV(ref)) {
            /* Bail out if it returns us the same reference.  */
            return tmpsv;
        }
        ref = tmpsv;
    }
    return tmpsv ? tmpsv : ref;
}
#endif

static SV*
tx_sv_to_ref(pTHX_ SV* const sv, svtype const svt, const int amg_id) {
    if(SvROK(sv)) {
        SV* const r = SvRV(sv);
        if(SvOBJECT(r)) {
            if(SvAMAGIC(sv)) {
                SV* const tmpsv = amagic_deref_call(sv, amg_id);
                if(SvROK(tmpsv)
                        && SvTYPE(SvRV(tmpsv)) == svt
                        && !SvOBJECT(SvRV(tmpsv))) {
                    return tmpsv;
                }
            }
        }
        else if(SvTYPE(r) == svt) {
            return sv;
        }
    }
    return NULL;
}

STATIC_INLINE bool
tx_str_is_raw(pTHX_ pMY_CXT_ SV* const sv) {
    if(SvROK(sv) && SvOBJECT(SvRV(sv))) {
        return SvTYPE(SvRV(sv)) <= SVt_PVMG
            && SvSTASH(SvRV(sv)) == MY_CXT.raw_stash;
    }
    return FALSE;
}

SV*
tx_mark_raw(pTHX_ SV* const str) {
    dMY_CXT;
    SvGETMAGIC(str);
    if(!SvOK(str)) {
        return str;
    }
    else if(tx_str_is_raw(aTHX_ aMY_CXT_ str)) {
        return str;
    }
    else {
        SV* const sv = newSV_type(SVt_PVMG);
        sv_setsv(sv, str);
        return sv_2mortal(sv_bless(newRV_noinc(sv), MY_CXT.raw_stash));
    }
}

SV*
tx_unmark_raw(pTHX_ SV* const str) {
    dMY_CXT;
    SvGETMAGIC(str);
    if(tx_str_is_raw(aTHX_ aMY_CXT_ str)) {
        return TX_UNMARK_RAW(str);
    }
    else {
        return str;
    }
}

/* does sv_catsv_nomg(dest, src), but significantly faster */
STATIC_INLINE void
tx_sv_cat(pTHX_ SV* const dest, SV* const src) {
    if(!SvUTF8(dest) && SvUTF8(src)) {
        sv_utf8_upgrade(dest);
    }

    {
        STRLEN len;
        const char* const pv  = SvPV_const(src, len);
        STRLEN const dest_cur = SvCUR(dest);
        char* const d         = SvGROW(dest, dest_cur + len + 1 /* count '\0' */);

        SvCUR_set(dest, dest_cur + len);
        Copy(pv, d + dest_cur, len + 1 /* copy '\0' */, char);
    }
}

static void /* doesn't care about raw-ness */
tx_sv_cat_with_html_escape_force(pTHX_ SV* const dest, SV* const src) {
    STRLEN len;
    const char*       cur = SvPV_const(src, len);
    const char* const end = cur + len;
    STRLEN const dest_cur = SvCUR(dest);
    char* d;

    (void)SvGROW(dest, dest_cur + ( len * ( sizeof("&quot;") - 1) ) + 1);
    if(!SvUTF8(dest) && SvUTF8(src)) {
        sv_utf8_upgrade(dest);
    }

    d = SvPVX(dest) + dest_cur;

#define CopyToken(token, to) STMT_START {          \
        Copy(token "", to, sizeof(token)-1, char); \
        to += sizeof(token)-1;                     \
    } STMT_END

    while(cur != end) {
        const char c = *(cur++);
        if(c == '&') {
            CopyToken("&amp;", d);
        }
        else if(c == '<') {
            CopyToken("&lt;", d);
        }
        else if(c == '>') {
            CopyToken("&gt;", d);
        }
        else if(c == '"') {
            CopyToken("&quot;", d);
        }
        else if(c == '\'') {
            // XXX: Internet Explorer (at least version 8) doesn't support &apos; in title
            // CopyToken("&apos;", d);
            CopyToken("&#39;", d);
        }
        else {
            *(d++) = c;
        }
    }

#undef CopyToken

    SvCUR_set(dest, d - SvPVX(dest));
    *SvEND(dest) = '\0';
}

STATIC_INLINE void
tx_print(pTHX_ tx_state_t* const st, SV* const sv) {
    dMY_CXT;
    SV* const out = st->output;

    SvGETMAGIC(sv);
    if(tx_str_is_raw(aTHX_ aMY_CXT_ sv)) {
        SV* const arg = TX_UNMARK_RAW(sv);
        if(SvOK(arg)) {
            tx_sv_cat(aTHX_ out, arg);
        }
        else {
            tx_warn(aTHX_ st, "Use of nil to print");
        }
    }
    else if(SvOK(sv)) {
        tx_sv_cat_with_html_escape_force(aTHX_ out, sv);
    }
    else {
        tx_warn(aTHX_ st, "Use of nil to print");
        /* does nothing */
    }
}

static SV*
tx_html_escape(pTHX_ SV* const str) {
    dMY_CXT;
    SvGETMAGIC(str);
    if(!( !SvOK(str) || tx_str_is_raw(aTHX_ aMY_CXT_ str) )) {
        SV* const dest = newSVpvs_flags("", SVs_TEMP);
        tx_sv_cat_with_html_escape_force(aTHX_ dest, str);
        return tx_mark_raw(aTHX_ dest);
    }
    else {
        return str;
    }
}


static SV*
tx_uri_escape(pTHX_ SV* const src) {
    /* TODO:
        Currently it is encoded to UTF-8, but
        the output encoding can be specified in a future (?).
     */

    SvGETMAGIC(src);
    if(SvOK(src)) {
        STRLEN len;
        const char* pv        = SvPV_const(src, len);
        const char* const end = pv + len;
        SV* const dest = sv_newmortal();
        sv_grow(dest, len * 2); /* just a hint; upgrading Svt_PV */
        SvPOK_on(dest);

        while(pv != end) {
            if(is_uri_unsafe(*pv)) {
                /* identical to PL_hexdigit + 16 */
                static const char hexdigit[] = "0123456789ABCDEF";
                char p[3];
                p[0] = '%';
                p[1] = hexdigit[((U8)*pv & 0xF0) >> 4]; /* high 4 bits */
                p[2] = hexdigit[((U8)*pv & 0x0F)];      /* low  4 bits */
                sv_catpvn(dest, p, 3);
            }
            else {
                sv_catpvn(dest, pv, 1);
            }
            pv++;
        }
        return dest;
    }
    else {
        return &PL_sv_undef;
    }
}

/* for tx_ckuuv_lhs() / tx_ckuuv_rhs() macros */
static SV*
tx_sv_check_uuv(pTHX_ SV* const sv, const char* const name) {
    /* check "Use of uninitialized value" (uuv) */
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        dMY_CXT;
        tx_warn(aTHX_ MY_CXT.current_st,
            "Use of nil for %s of binary operator", name);
        return &PL_sv_no;
    }
    return sv;
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

STATIC_INLINE I32
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

XS(XS_Text__Xslate__macrocall); /* -Wmissing-prototype */
XS(XS_Text__Xslate__macrocall){
    dVAR; dSP; /* macrocall routine do dMARK, so we don't it here */
    dMY_CXT;
    SV* const macro = (SV*)CvXSUBANY(cv).any_ptr;
    if(!(MY_CXT.current_st && macro)) {
        croak("Macro is not callable outside of templates");
    }
    XPUSHs( tx_proccall(aTHX_ MY_CXT.current_st, macro, "macro") );
    PUTBACK;
    return;
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
        tx_macro_enter(aTHX_ TX_st, (AV*)SvRV(proc), &proc_end);
        TX_RUNOPS(TX_st);
        /* after tx_macro_end */

        TX_st->pc = save_pc;
        //warn("# return from %s\n", name);

        return TX_st_sa;
    }
    else if (tx_sv_is_code_ref(aTHX_ proc) && CvXSUB((CV*)SvRV(proc)) == XS_Text__Xslate__macrocall) {
        /* macro wrapper XSUB created by Text::Xslate::Type::as_code_ref() */
        SV* const m = CvXSUBANY((CV*)SvRV(proc)).any_ptr;
        sv_dump(proc);
        sv_dump(m);
        Perl_croak(aTHX_ "xxx");
        return tx_proccall(aTHX_ TX_st, m, name);
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
    SvGROW(tmp, TX_HINT_SIZE);

    i = 0;
    if(outer > 0) { /* refers outer lexical variales */
        /* copies lexical variables from the old frame to the new one */
        AV* const oframe = TX_frame_at(TX_st, TX_st->current_frame-1);
        for(NOOP; i < outer; i++) {
            IV const real_ix = i + TXframe_START_LVAR;
            /* XXX: macros can refer to unallocated lvars */
            SV* const sv = AvFILLp(oframe) >= real_ix
                ? sv_mortalcopy(AvARRAY(oframe)[real_ix])
                : &PL_sv_undef;
            av_store(cframe, real_ix , sv);
            SvREFCNT_inc_simple_void_NN(sv);
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
    TX_st->pad = AvARRAY(cframe) + TXframe_START_LVAR;
    TX_RETURN_PC(addr);
}

/* The virtual machine code interpreter */
/* NOTE: tx_execute() must be surrounded in ENTER and LEAVE */
static void
tx_execute(pTHX_ pMY_CXT_ tx_state_t* const base, SV* const output, HV* const hv) {
    dXCPT;
    tx_state_t st;

    StructCopy(base, &st, tx_state_t);

    //PerlIO_stdoutf("#>> 0x%p %d %d\n", base, (int)MY_CXT.depth, (int)st.current_frame);
    st.output = output;
    st.vars   = hv;

    assert(st.tmpl != NULL);

    /* local $current_st */
    SAVEVPTR(MY_CXT.current_st);
    MY_CXT.current_st = &st;

    assert(MY_CXT.depth >= 0);
    if(MY_CXT.depth > TX_MAX_DEPTH) {
        croak("Execution is too deep (> %d)", TX_MAX_DEPTH);
    }

    /* local $depth = $depth + 1 */
    MY_CXT.depth++;

    XCPT_TRY_START {
        TX_RUNOPS(&st);
    }
    XCPT_TRY_END;

    /* finally */
    MY_CXT.depth--;

    XCPT_CATCH {
        I32 const start = base->current_frame;
        /* unwind the stack frames */
        while(st.current_frame > start) {
            tx_pop_frame(aTHX_ &st, TRUE);
        }
        tx_pop_frame(aTHX_ base, FALSE); // pushed before tx_execute()
        XCPT_RETHROW;
    }
    tx_pop_frame(aTHX_ base, FALSE); // pushed before tx_execute()

    /* clear temporary buffers */
    sv_setsv(st.targ, NULL);

    /* store the current buffer size as a hint size */
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

    return NULL;
}

static int
tx_mg_free(pTHX_ SV* const sv, MAGIC* const mg){
    tx_state_t* const st      = (tx_state_t*)mg->mg_ptr;
    tx_info_t* const info     = st->info;
    tx_code_t* const code     = st->code;
    I32 const len             = st->code_len;
    I32 i;

    // PerlIO_stdoutf("# tx_mg_free()\n");
    for(i = 0; i < len; i++) {
        /* opcode */
        if( tx_oparg[ info[i].optype ] & TXARGf_SV ) {
            SvREFCNT_dec(code[i].u_arg.sv);
        }

        /* opinfo */
        SvREFCNT_dec(info[i].file);
    }

    Safefree(code);
    Safefree(info);

    SvREFCNT_dec(st->symbol);
    SvREFCNT_dec(st->frames);
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
        U8 const oparg = tx_oparg[ proto_info[i].optype ];
        /* opcode */
        st->code[i].exec_code = proto_code[i].exec_code;
        if( oparg & TXARGf_SV ) {
            st->code[i].u_arg.sv = tx_sv_dup_inc(aTHX_ proto_code[i].u_arg.sv, param);
        }
        else if ( oparg & TXARGf_INT ) {
            st->code[i].u_arg.iv = proto_code[i].u_arg.iv;
        }
        else if( oparg & TXARGf_PC ) {
            st->code[i].u_arg.pc = proto_code[i].u_arg.pc;
        }

        /* opinfo */
        st->info[i].optype    = proto_info[i].optype;
        st->info[i].line      = proto_info[i].line;
        st->info[i].file      = tx_sv_dup_inc(aTHX_ proto_info[i].file, param);
    }

    st->symbol   = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->symbol, param);
    st->frames   = (AV*)tx_sv_dup_inc(aTHX_ (SV*)st->frames,   param);
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
tx_invoke_load_file(pTHX_ SV* const self, SV* const name, SV* const mtime, bool const from_include) {
    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 3);
    PUSHs(self);
    PUSHs(name);
    PUSHs(mtime ? mtime : &PL_sv_undef);
    PUSHs(boolSV(from_include));
    PUTBACK;

    call_method("load_file", G_EVAL | G_VOID);
    if(TX_CATCH_ERROR()){
        dMY_CXT;
        SV* const msg = PL_diehook == MY_CXT.die_handler
            ? sv_2mortal(newRV_inc(sv_mortalcopy(ERRSV)))
            : ERRSV;
        tx_call_error_handler(aTHX_ MY_CXT.die_handler, msg);
        /* not reached */
    }

    FREETMPS;
    LEAVE;
}

static bool
tx_all_deps_are_fresh(pTHX_ AV* const tmpl, Time_t const cache_mtime) {
    I32 const len = AvFILLp(tmpl) + 1;
    I32 i;
    Stat_t st;

    for(i = TXo_FULLPATH; i < len; i++) {
        SV* const deppath = AvARRAY(tmpl)[i];

        if(SvROK(deppath)) {
            continue;
        }

        //PerlIO_stdoutf("check deps: %"SVf" ...\n", deppath); // */
        if(PerlLIO_stat(SvPV_nolen_const(deppath), &st) < 0
               || st.st_mtime > cache_mtime) {
            SV* const main_cache = AvARRAY(tmpl)[TXo_CACHEPATH];
            /* compiled caches are no longer fresh, so it must be discarded */

            if(i != TXo_FULLPATH && SvOK(main_cache)) {
                PerlLIO_unlink(SvPV_nolen_const(main_cache));
            }
            //PerlLIO_unlink(SvPV_nolen_const(AvARRAY(tmpl);

            if (dump_load) {
                PerlIO_printf(PerlIO_stderr(),
                    "#[XS]   %"SVf": too old (%d < %d)\n",
                    deppath, (int)cache_mtime, (int)st.st_mtime);
            }
            return FALSE;
        }
        else {
            if (dump_load) {
                PerlIO_printf(PerlIO_stderr(),
                    "#[XS]   %"SVf": fresh enough (%d >= %d)\n",
                    deppath, (int)cache_mtime, (int)st.st_mtime);
            }
        }
    }
    return TRUE;
}

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name, bool const from_include) {
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

    if (dump_load) {
        PerlIO_printf(PerlIO_stderr(),
            "#[XS] load_template(%"SVf")\n", name);
    }

    if(!SvOK(name)) {
        why = "template name is invalid";
        goto err;
    }

    assert( SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV );

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
        tx_invoke_load_file(aTHX_ self, name, NULL, from_include);
        retried++;
        goto retry;
    }

    sv = hv_iterval(ttable, he);
    if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)) {
        why = "template entry is invalid";
        goto err;
    }

    tmpl = (AV*)SvRV(sv);
    if(AvFILLp(tmpl) < (TXo_least_size-1)) {
        why = form("template entry is broken (size: %d < %d)",
            (int)AvFILLp(tmpl)+1, (int)TXo_least_size);
        goto err;
    }

    mg  = mgx_find(aTHX_ (SV*)tmpl, &xslate_vtbl);
    if(!mg) {
        croak("Xslate: Invalid template holder was passed");
    }
    /* check mtime */

    cache_mtime = AvARRAY(tmpl)[TXo_MTIME];

    /* NOTE: Ensure the life of the template object  */
    sv_2mortal( (SV*)SvREFCNT_inc_simple_NN(tmpl) );

    if(!SvOK(cache_mtime)) { /* non-checking mode (i.e. release mode) */

        return (tx_state_t*)mg->mg_ptr;
    }

    if (dump_load) {
        PerlIO_printf(PerlIO_stderr(),
            "#[XS]   %"SVf" (mtime=%"SVf")\n", name, cache_mtime);
    }

    if(retried > 0 /* if already retried, it should be valid */
            || tx_all_deps_are_fresh(aTHX_ tmpl, SvIVX(cache_mtime))) {
        return (tx_state_t*)mg->mg_ptr;
    }
    else {
        tx_invoke_load_file(aTHX_ self, name, cache_mtime, from_include);
        retried++;
        goto retry;
    }

    err:
    croak("Xslate: Cannot load template %s: %s", tx_neat(aTHX_ name), why);
}

static int
tx_macro_free(pTHX_ SV* const sv PERL_UNUSED_DECL, MAGIC* const mg){
    CV* const xsub = (CV*)mg->mg_obj;

    assert(SvTYPE(xsub) == SVt_PVCV);
    assert(CvXSUB(xsub) != NULL);

    CvXSUBANY(xsub).any_ptr = NULL;
    return 0;
}

static MGVTBL macro_vtbl = { /* identity */
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    tx_macro_free, /* free */
    NULL, /* copy */
    NULL, /* dup */
#ifdef MGf_LOCAL
    NULL,  /* local */
#endif
};


static void
tx_my_cxt_init(pTHX_ pMY_CXT_ bool const cloning PERL_UNUSED_DECL) {
    MY_CXT.depth = 0;
    MY_CXT.raw_stash     = gv_stashpvs(TX_RAW_CLASS, GV_ADDMULTI);
    MY_CXT.macro_stash   = gv_stashpvs(TX_MACRO_CLASS, GV_ADDMULTI);
    MY_CXT.warn_handler  = SvREFCNT_inc_NN(
        (SV*)get_cv("Text::Xslate::Engine::_warn", GV_ADD));
    MY_CXT.die_handler   = SvREFCNT_inc_NN(
        (SV*)get_cv("Text::Xslate::Engine::_die",  GV_ADD));
    MY_CXT.make_error    = SvREFCNT_inc_NN(
        (SV*)get_cv("Text::Xslate::Engine::make_error",  GV_ADD));
}

/* Because overloading stuff of old xsubpp didn't work,
   we need to copy them. */
XS(XS_Text__Xslate__fallback); /* prototype to pass -Wmissing-prototypes */
XS(XS_Text__Xslate__fallback)
{
   dXSARGS;
   PERL_UNUSED_VAR(cv);
   PERL_UNUSED_VAR(items);
   XSRETURN_EMPTY;
}

EXTERN_C XS(boot_Text__Xslate__Methods);

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Engine

PROTOTYPES: DISABLE

BOOT:
{
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADDMULTI);
    MY_CXT_INIT;
    tx_my_cxt_init(aTHX_ aMY_CXT_ FALSE);
    tx_init_ops(aTHX_ ops);

    {
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
_register_builtin_methods(self, HV* hv)
CODE:
{
    tx_register_builtin_methods(aTHX_ hv);
}

void
_assemble(HV* self, AV* proto, SV* name, SV* fullpath, SV* cachepath, SV* mtime)
CODE:
{
    dMY_CXT;
    dTX_optable;
    MAGIC* mg;
    HV* hv;
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADD);
    U32 const len = av_len(proto) + 1;
    U32 i;
    U16 oi_line; /* opinfo.line */
    SV* oi_file;
    tx_state_t st;
    AV* tmpl;
    SV* tobj;
    SV** svp;
    AV* macro = NULL;

    TAINT_NOT; /* All the SVs we'll create here are safe */

    Zero(&st, 1, tx_state_t);

    svp = hv_fetchs(self, "template", FALSE);
    if(!(svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV)) {
        croak("The xslate instance has no template table");
    }
    hv = (HV*)SvRV(*svp);

    if(!SvOK(name)) {
        croak("Undefined template name is invalid");
    }

    /* fetch the template object from $self->{template}{$name} */
    tobj = hv_iterval(hv, hv_fetch_ent(hv, name, TRUE, 0U));

    tmpl = newAV();
    /* store the template object to $self->{template}{$name} */
    sv_setsv(tobj, sv_2mortal(newRV_noinc((SV*)tmpl)));
    av_extend(tmpl, TXo_least_size - 1);

    sv_setsv(*av_fetch(tmpl, TXo_MTIME,     TRUE),  mtime);
    sv_setsv(*av_fetch(tmpl, TXo_CACHEPATH, TRUE),  cachepath);
    sv_setsv(*av_fetch(tmpl, TXo_FULLPATH,  TRUE),  fullpath);

    /* prepare function table */
    svp = hv_fetchs(self, "function", FALSE);
    TAINT_NOT;

    if(!( SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV )) {
        croak("Function table must be a HASH reference");
    }
    /* $self->{function} must be copied
       because it might be changed per templates */
    st.symbol = newHVhv( (HV*)SvRV(*svp) );

    st.tmpl   = tmpl;
    st.engine = newRV_inc((SV*)self);
    sv_rvweaken(st.engine);

    st.hint_size = TX_HINT_SIZE;

    st.sa       = &PL_sv_undef;
    st.sb       = &PL_sv_undef;
    st.targ     = newSV(0);

    /* stack frame */
    st.frames        = newAV();
    st.current_frame = -1;

    Newxz(st.info, len + 1, tx_info_t);
    st.info[len].line = (U16)-1; /* invalid value */
    st.info[len].file = SvREFCNT_inc_simple_NN(name);

    Newxz(st.code, len, tx_code_t);

    st.code_len = len;
    st.pc       = &st.code[0];

    mg = sv_magicext((SV*)tmpl, NULL, PERL_MAGIC_ext,
        &xslate_vtbl, (char*)&st, sizeof(st));
    mg->mg_flags |= MGf_DUP;

    oi_line = 0;
    oi_file = name;

    for(i = 0; i < len; i++) {
        SV* const code = *av_fetch(proto, i, TRUE);
        if(SvROK(code) && SvTYPE(SvRV(code)) == SVt_PVAV) {
            AV* const av     = (AV*)SvRV(code);
            SV* const opname = *av_fetch(av, 0, TRUE);
            SV** const arg   =  av_fetch(av, 1, FALSE);
            SV** const line  =  av_fetch(av, 2, FALSE);
            SV** const file  =  av_fetch(av, 3, FALSE);
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

                if(tx_oparg[opnum] & TXARGf_KEY) { /* shared sv */
                    STRLEN len;
                    const char* const pv = SvPV_const(*arg, len);
                    st.code[i].u_arg.sv = newSVpvn_share(pv, SvUTF8(*arg) ? -len : len, 0U);
                }
                else if(tx_oparg[opnum] & TXARGf_INT) { /* sviv */
                    SvIV_please(*arg);
                    st.code[i].u_arg.sv = SvIsUV(*arg)
                        ? newSVuv(SvUV(*arg))
                        : newSViv(SvIV(*arg));
                }
                else { /* normal sv */
                    st.code[i].u_arg.sv = newSVsv(*arg);
                }
            }
            else if(tx_oparg[opnum] & TXARGf_INT) {
                st.code[i].u_arg.iv = SvIV(*arg);
            }
            else if(tx_oparg[opnum] & TXARGf_PC) {
                /* calculate relational addresses to absolute addresses */
                UV const abs_pos       = (UV)(i + SvIV(*arg));

                if(abs_pos >= (UV)len) {
                    croak("Oops: goto address %"IVdf" is out of range (must be 0 <= addr <= %"IVdf")",
                        SvIV(*arg), (IV)len);
                }
                st.code[i].u_arg.pc = TX_POS2PC(&st, abs_pos);
            }
            else {
                if(arg && SvOK(*arg)) {
                    croak("Oops: Opcode %"SVf" has an extra argument %s on [%d]",
                        opname, tx_neat(aTHX_ *arg), (int)i);
                }
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

            /* special cases */
            if(opnum == TXOP_macro_begin) {
                SV* const name = st.code[i].u_arg.sv;
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
                    st.code[i].u_arg.sv = NULL;
                }
                else { /* already defined */
                    macro = NULL;
                }
            }
            else if(opnum == TXOP_macro_nargs) {
                if(macro) {
                    /* the number of outer lexical variables */
                    (void)av_store(macro, TXm_NARGS, st.code[i].u_arg.sv);
                    st.code[i].u_arg.sv = NULL;
                }
            }
            else if(opnum == TXOP_macro_outer) {
                if(macro) {
                    /* the number of outer lexical variables */
                    (void)av_store(macro, TXm_OUTER, st.code[i].u_arg.sv);
                    st.code[i].u_arg.sv = NULL;
                }
            }
            else if(opnum == TXOP_depend) {
                /* add a dependent file to the tmpl object */
                av_push(tmpl, st.code[i].u_arg.sv);
                st.code[i].u_arg.sv = NULL;
            }
        }
        else {
            croak("Oops: Broken code found on [%d]", (int)i);
        }
    } /* end for each code */
}

void
render(SV* self, SV* source, SV* vars = &PL_sv_undef)
ALIAS:
    render        = 0
    render_string = 1
CODE:
{
    dMY_CXT;
    tx_state_t* st;

    TAINT_NOT; /* All the SVs we'll create here are safe */

    /* $_[0]: engine */
    if(!(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV)) {
        croak("Xslate: Invalid xslate instance: %s",
            tx_neat(aTHX_ self));
    }

    /* $_[1]: template source */
    if(ix == 1) { /* render_string() */
        dXSTARG;
        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(self);
        PUSHs(source);
        PUTBACK;
        call_method("load_string", G_VOID | G_DISCARD);
        SPAGAIN;
        source = TARG;
        sv_setpvs(source, "<string>");
    }

    SvGETMAGIC(source);
    if(!SvOK(source)) {
        croak("Xslate: Template name is not given");
    }

    /* $_[2]: template variable */
    if(!SvOK(vars)) {
        vars = sv_2mortal(newRV_noinc((SV*)newHV()));
    }
    else if(!(SvROK(vars) && SvTYPE(SvRV(vars)) == SVt_PVHV)) {
        croak("Xslate: Template variables must be a HASH reference, not %s",
            tx_neat(aTHX_ vars));
    }
    if(SvOBJECT(SvRV(vars))) {
        Perl_warner(aTHX_ packWARN(WARN_MISC),
            "Xslate: Template variables must be a HASH reference, not %s",
            tx_neat(aTHX_ vars));
    }

    st = tx_load_template(aTHX_ self, source, FALSE);

    /* local $SIG{__WARN__} = \&warn_handler */
    if (PL_warnhook != MY_CXT.warn_handler) {
        SAVEGENERICSV(PL_warnhook);
        MY_CXT.orig_warn_handler = PL_warnhook;
        PL_warnhook              = SvREFCNT_inc_NN(MY_CXT.warn_handler);
    }

    /* local $SIG{__DIE__}  = \&die_handler */
    if (PL_diehook != MY_CXT.die_handler) {
        SAVEGENERICSV(PL_diehook);
        MY_CXT.orig_die_handler = PL_diehook;
        PL_diehook              = SvREFCNT_inc_NN(MY_CXT.die_handler);
    }

    {
        AV* mainframe = tx_push_frame(aTHX_ st); // frame[0]
        SV* result = sv_newmortal();
        sv_grow(result, st->hint_size + TX_HINT_SIZE);
        SvPOK_on(result);

        av_store(mainframe, TXframe_NAME,    SvREFCNT_inc_simple_NN(source));
        av_store(mainframe, TXframe_RETADDR, newSVuv(st->code_len));
        tx_execute(aTHX_ aMY_CXT_ st, result, (HV*)SvRV(vars));
        ST(0) = result;
    }
}

void
validate(SV* self, SV* source)
CODE:
{
    TAINT_NOT; /* All the SVs we'll create here are safe */

    /* $_[0]: engine */
    if(!(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV)) {
        croak("Xslate: Invalid xslate instance: %s",
            tx_neat(aTHX_ self));
    }

    SvGETMAGIC(source);
    if(!SvOK(source)) {
        croak("Xslate: Template name is not given");
    }

    tx_load_template(aTHX_ self, source, FALSE);
}

void
current_engine(klass)
CODE:
{
    dMY_CXT;
    tx_state_t* const st = MY_CXT.current_st;
    SV* retval;
    if(st) {
        if(ix == 0) { /* current_engine */
            retval = st->engine;
        }
        else if(ix == 1) { /* current_vars */
            retval = sv_2mortal(newRV_inc((SV*)st->vars));
        }
        else { /* current_file / current_line */
            const tx_info_t* const info
                = &(st->info[ TX_PC2POS(st, st->pc) ]);

            retval = (ix == 2)
                ? info->file
                : sv_2mortal(newSViv(info->line));
        }
    }
    else {
        retval = &PL_sv_undef;
    }
    ST(0) = retval;
}
ALIAS:
    current_engine = 0
    current_vars   = 1
    current_file   = 2
    current_line   = 3

void
print(klass, ...)
CODE:
{
    dMY_CXT;
    int i;
    tx_state_t* const st = MY_CXT.current_st;
    if(!st) {
        croak("You cannot call print() method outside render()");
    }

    for(i = 1; i < items; i++) {
        tx_print(aTHX_ st, ST(i));
    }
    XSRETURN_NO; /* return false as an empty string */
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
    SV* engine;
    AV* cframe;
    SV* name;
    SV* full_message;
    SV** svp;
    CV*  handler;
    UV pc_pos;
    SV* file;


    /* restore error handlers to avoid recursion */
    SAVESPTR(PL_warnhook);
    SAVESPTR(PL_diehook);
    PL_warnhook = MY_CXT.orig_warn_handler;
    PL_diehook  = MY_CXT.orig_die_handler;
    msg = sv_mortalcopy(msg);

    if(!st) {
        croak("%"SVf, msg);
    }


    engine = st->engine;
    cframe = TX_current_framex(st);
    name   = AvARRAY(cframe)[TXframe_NAME];

    svp = (ix == 0)
        ? hv_fetchs((HV*)SvRV(engine), "warn_handler", FALSE)
        : hv_fetchs((HV*)SvRV(engine), "die_handler",  FALSE);

    if(svp && SvOK(*svp)) {
        HV* stash;
        GV* gv;
        handler = sv_2cv(*svp, &stash, &gv, 0);
    }
    else {
        handler = NULL;
    }

    pc_pos = TX_PC2POS(st, st->pc);
    file   = st->info[ pc_pos ].file;
    if(strEQ(SvPV_nolen_const(file), "<string>")) {
        svp = hv_fetchs((HV*)SvRV(engine), "string_buffer", FALSE);
        if(svp) {
            file = sv_2mortal(newRV_inc(*svp));
        }
    }
    /* TODO: append the stack info to msg */
    /* $full_message = make_error(engine, msg, file, line, vm_pos) */
    PUSHMARK(SP);
    EXTEND(SP, 6);
    PUSHs(sv_mortalcopy(engine)); /* XXX: avoid premature free */
    PUSHs(msg);
    PUSHs(file);
    mPUSHi(st->info[ pc_pos ].line);
    if(tx_verbose(aTHX_ st) >= 3) {
        if(!SvOK(name)) { // FIXME: something's wrong
            name = newSVpvs_flags("(oops)", SVs_TEMP);
        }
        mPUSHs(newSVpvf("&%"SVf"[%"UVuf"]", name, pc_pos));
    }
    PUTBACK;
    call_sv(MY_CXT.make_error, G_SCALAR);
    SPAGAIN;
    full_message = POPs;
    PUTBACK;

    if(ix == 0) { /* warn */
        /* handler can ignore warnings */
        if(handler) {
            PUSHMARK(SP);
            XPUSHs(full_message);
            PUTBACK;
            call_sv((SV*)handler, G_VOID | G_DISCARD);
            /* handler can ignore errors */
        }
        else {
            warn("%"SVf, full_message);
        }
    }
    else {
        if(handler) {
            PUSHMARK(SP);
            XPUSHs(full_message);
            PUTBACK;
            call_sv((SV*)handler, G_VOID | G_DISCARD);
            /* handler cannot ignore errors */
        }
        croak("%"SVf, full_message); /* must die */
        /* not reached */
    }
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Util

void
mark_raw(SV* str)
CODE:
{
    ST(0) = tx_mark_raw(aTHX_ str);
}

void
unmark_raw(SV* str)
CODE:
{
    ST(0) = tx_unmark_raw(aTHX_ str);
}


void
html_escape(SV* str)
CODE:
{
    ST(0) = tx_html_escape(aTHX_ str);
}

void
uri_escape(SV* str)
CODE:
{
    ST(0) = tx_uri_escape(aTHX_ str);
}

void
is_array_ref(SV* sv)
CODE:
{
    ST(0) = boolSV( tx_sv_is_array_ref(aTHX_ sv));
}

void
is_hash_ref(SV* sv)
CODE:
{
    ST(0) = boolSV( tx_sv_is_hash_ref(aTHX_ sv));
}

void
is_code_ref(SV* sv)
CODE:
{
    ST(0) = boolSV( tx_sv_is_code_ref(aTHX_ sv));
}

void
merge_hash(SV* base, SV* value)
CODE:
{
    ST(0) = tx_merge_hash(aTHX_ NULL, base, value);
}

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
        XS_Text__Xslate__fallback, file);

    /* *{'(""'} = \&as_string */
    as_string = sv_2mortal(newRV_inc(
        (SV*)get_cv( TX_RAW_CLASS "::as_string", GV_ADD)));
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
}

void
as_string(SV* self, ...)
CODE:
{
    if(!SvROK(self)) {
        croak("You cannot call %s->as_string() as a class method", TX_RAW_CLASS);
    }
    ST(0) = tx_unmark_raw(aTHX_ self);
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::Type::Macro


BOOT:
{
    SV* code_ref;
    /* overload stuff */
    PL_amagic_generation++;
    sv_setsv(
        get_sv( TX_MACRO_CLASS "::()", TRUE ),
        &PL_sv_yes
    );
    (void)newXS( TX_MACRO_CLASS "::()",
        XS_Text__Xslate__fallback, file);

    /* *{'(&{}'} = \&as_code_ref */
    code_ref = sv_2mortal(newRV_inc((SV*)get_cv( TX_MACRO_CLASS "::as_code_ref", GV_ADD)));
    sv_setsv_mg(
        (SV*)gv_fetchpvs( TX_MACRO_CLASS "::(&{}", GV_ADDMULTI, SVt_PVCV),
        code_ref);

    // debug flag
    code_ref = sv_2mortal(newRV_inc((SV*)get_cv( "Text::Xslate::Engine::_DUMP_LOAD", GV_ADD)));
    {
        dSP;
        PUSHMARK(SP);
        call_sv(code_ref, G_SCALAR);
        SPAGAIN;
        dump_load = sv_true(POPs);
        PUTBACK;
    }
}

CV*
as_code_ref(SV* self, ...)
CODE:
{
    /* the macro object is responsible to its xsub's refcount */
    MAGIC* mg;
    CV* xsub;

    if(!tx_sv_is_macro(aTHX_ self)) {
        croak("Not a macro object: %s", tx_neat(aTHX_ self));
    }

    mg = mgx_find(aTHX_ SvRV(self), &macro_vtbl);
    if(!mg) {
        xsub = newXS(NULL, XS_Text__Xslate__macrocall, __FILE__);
        sv_magicext(SvRV(self), (SV*)xsub, PERL_MAGIC_ext, &macro_vtbl,
            NULL, 0);
        SvREFCNT_dec(xsub); /* refcnt++ in sv_magicext */
        CvXSUBANY(xsub).any_ptr = (void*)self;
    }
    else {
        xsub = (CV*)mg->mg_obj;
        assert(xsub);
        assert(SvTYPE(xsub) == SVt_PVCV);
    }
    RETVAL = xsub;
}
OUTPUT:
    RETVAL
