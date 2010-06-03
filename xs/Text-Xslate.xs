#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define NEED_newSVpvn_flags_GLOBAL
#define NEED_newSVpvn_share
#include "ppport.h"

#include "xslate.h"
#include "xslate_ops.h"

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


#define MY_CXT_KEY "Text::Xslate::_guts" XS_VERSION
typedef struct {
    U32 depth;
    HV* escaped_string_stash;

    tx_state_t* current_st; /* set while tx_execute(), othewise NULL */

    /* those handlers are just \&_warn and \&_die,
       but stored here for performance */
    SV* warn_handler;
    SV* die_handler;
} my_cxt_t;
START_MY_CXT

static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv);

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name);

static const char*
tx_file(pTHX_ const tx_state_t* const st) {
    SV* const filesv = *av_fetch(st->tmpl, TXo_NAME, TRUE);
    return SvPV_nolen_const(filesv);
}

static int
tx_line(pTHX_ const tx_state_t* const st) {
    return (int)st->lines[ st->pc ];
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
    HV* const hv   = (HV*)SvRV(st->self);
    SV** const svp = hv_fetchs(hv, "verbose", FALSE);
    return svp && SvOK(*svp) ? SvIV(*svp) : TX_VERBOSE_DEFAULT;
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

static SV*
tx_fetch_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix) { /* the guts of TX_lvar() */
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

    if(st->current_frame > 100) {
        croak("Macro call is too deep (> 100)");
    }
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

static SV*
tx_call(pTHX_ tx_state_t* const st, SV* proc, I32 const flags, const char* const name) {
    SV* retval = NULL;
    /* ENTER & SAVETMPS must be done */

    if(!(flags & G_METHOD)) { /* functions */
        HV* dummy_stash;
        GV* dummy_gv;
        CV* cv;

        SvGETMAGIC(proc);
        if(!SvOK(proc)) {
            tx_code_t* const c = &(st->code[ st->pc - 1 ]);
            (void)POPMARK;
            tx_error(aTHX_ st, "Undefined function%s is called",
                c->exec_code == TXCODE_fetch_s
                    ? form(" %"SVf"()", c->arg)
                    : "");
            goto finish;
        }

        cv = sv_2cv(proc, &dummy_stash, &dummy_gv, FALSE);
        if(!cv) {
            (void)POPMARK;
            tx_error(aTHX_ st, "Functions must be a CODE reference, not %s",
                tx_neat(aTHX_ proc));

            goto finish;
        }
        proc = (SV*)cv;
    }
    else { /* methods */
        SV* const invocant = PL_stack_base[TOPMARK+1];
        if(!SvOK(invocant)) {
            (void)POPMARK;
            tx_warn(aTHX_ st, "Use of nil to invoke method %s",
                tx_neat(aTHX_ proc));

            goto finish;
        }
    }

    call_sv(proc, G_SCALAR | G_EVAL | flags);

    if(UNLIKELY(sv_true(ERRSV))) {
        tx_error(aTHX_ st, "%"SVf "\n"
            "\t... exception cought on %s", ERRSV, name);
    }

    retval = TX_pop();

    finish:
    sv_setsv_nomg(st->targ, retval);

    FREETMPS;
    LEAVE;

    return st->targ;
}

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key) {
    SV* sv = NULL;
    PERL_UNUSED_ARG(st);
    if(sv_isobject(var)) { /* sv_isobject() invokes SvGETMAGIC */
        dSP;
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        sv = tx_call(aTHX_ st, key, G_METHOD, "accessor");
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

static SV*
tx_escaped_string(pTHX_ SV* const str) {
    dMY_CXT;
    SV* const sv = sv_newmortal();
    sv_copypv(sv, str);
    return sv_2mortal(sv_bless(newRV_inc(sv), MY_CXT.escaped_string_stash));
}

static bool
tx_str_is_escaped(pTHX_ SV* const sv) {
    if(SvROK(sv) && SvOBJECT(SvRV(sv))) {
        dMY_CXT;
        return SvOK(SvRV(sv))
            && SvSTASH(SvRV(sv)) == MY_CXT.escaped_string_stash;
    }
    return FALSE;
}

/*********************

 Xslate opcodes TXC(xxx)

 *********************/

TXC(noop) {
    TX_st->pc++;
}

TXC(move_to_sb) {
    TX_st_sb = TX_st_sa;
    TX_st->pc++;
}
TXC(move_from_sb) {
    TX_st_sa = TX_st_sb;
    TX_st->pc++;
}

TXC_w_var(save_to_lvar) {
    SV* const sv = TX_lvar(SvIVX(TX_op_arg));
    sv_setsv(sv, TX_st_sa);
    TX_st_sa = sv;

    TX_st->pc++;
}

TXC_w_var(load_lvar_to_sb) {
    TX_st_sb = TX_lvar_get(SvIVX(TX_op_arg));
    TX_st->pc++;
}

/* local $vars->{$key} = $val */
/* see pp_helem() in pp_hot.c */
TXC_w_key(local_s) {
    HV* const vars   = TX_st->vars;
    SV* const key    = TX_op_arg;
    bool const preeminent
                     = hv_exists_ent(vars, key, 0U);
    HE* const he     = hv_fetch_ent(vars, key, TRUE, 0U);
    SV* const newval = TX_st_sa;
    SV** const svp   = &HeVAL(he);

    if(!preeminent) {
        STRLEN keylen;
        const char* const keypv = SvPV_const(key, keylen);
        SAVEDELETE(vars, savepvn(keypv, keylen),
            SvUTF8(key) ? -(I32)keylen : (I32)keylen);
    }
    else {
        save_helem(vars, key, svp);
    }
    sv_setsv(*svp, newval);

    TX_st->pc++;
}

TXC(push) {
    dSP;
    XPUSHs(sv_mortalcopy(TX_st_sa));
    PUTBACK;

    TX_st->pc++;
}

/* pushmark does ENTER & SAVETMPS */
TXC(pushmark) {
    dSP;
    PUSHMARK(SP);

    TX_st->pc++;
}

TXC(nil) {
    TX_st_sa = &PL_sv_undef;

    TX_st->pc++;
}

TXC_w_sv(literal) {
    TX_st_sa = TX_op_arg;

    TX_st->pc++;
}

/* the same as literal, but make sure its argument is an integer */
TXC_w_int(literal_i);

TXC_w_key(fetch_s) { /* fetch a field from the top */
    HV* const vars = TX_st->vars;
    HE* const he   = hv_fetch_ent(vars, TX_op_arg, FALSE, 0U);

    TX_st_sa = LIKELY(he != NULL) ? hv_iterval(vars, he) : &PL_sv_undef;

    TX_st->pc++;
}

TXC_w_var(fetch_lvar) {
    IV const id      = SvIVX(TX_op_arg);
    AV* const cframe = TX_current_frame();

    /* XXX: is there a better way? */
    if(AvFILLp(cframe) < (id + TXframe_START_LVAR)) {
        tx_error(aTHX_ TX_st, "Too few arguments for %"SVf, AvARRAY(cframe)[TXframe_NAME]);
        TX_st_sa = &PL_sv_undef;
    }
    else {
        TX_st_sa = TX_lvar_get(id);
    }
    TX_st->pc++;
}

TXC(fetch_field) { /* fetch a field from a variable (bin operator) */
    SV* const var = TX_st_sb;
    SV* const key = TX_st_sa;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

TXC_w_key(fetch_field_s) { /* fetch a field from a variable (for literal) */
    SV* const var = TX_st_sa;
    SV* const key = TX_op_arg;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

TXC(print) {
    SV* const sv          = TX_st_sa;
    SV* const output      = TX_st->output;

    if(tx_str_is_escaped(aTHX_ sv)) {
        sv_catsv_nomg(output, SvRV(sv));
    }
    else if(SvOK(sv)) {
        STRLEN len;
        const char*       cur = SvPV_const(sv, len);
        const char* const end = cur + len;

        (void)SvGROW(output, SvCUR(output) + len);

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
                break;
            }

            len = SvCUR(output) + parts_len + 1;
            (void)SvGROW(output, len);

            if(LIKELY(parts_len == 1)) {
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
    else {
        tx_warn(aTHX_ TX_st, "Use of nil to print");
        /* does nothing */
    }

    TX_st->pc++;
}

TXC(print_raw) {
    SV* const arg = TX_st_sa;
    SvGETMAGIC(arg);
    if(SvOK(arg)) {
        sv_catsv_nomg(TX_st->output, arg);
    }
    else {
        tx_warn(aTHX_ TX_st, "Use of nil to print");
    }
    TX_st->pc++;
}

TXC_w_sv(print_raw_s) {
    sv_catsv_nomg(TX_st->output, TX_op_arg);

    TX_st->pc++;
}

TXC(include) {
    tx_state_t* const st = tx_load_template(aTHX_ TX_st->self, TX_st_sa);

    ENTER;
    tx_execute(aTHX_ st, TX_st->output, TX_st->vars);
    LEAVE;

    TX_st->pc++;
}

TXC_w_var(for_start) {
    SV* avref    = TX_st_sa;
    IV  const id = SvIVX(TX_op_arg);

    SvGETMAGIC(avref);
    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        if(SvOK(avref)) {
            tx_error(aTHX_ TX_st, "Iterating data must be an ARRAY reference, not %s",
                tx_neat(aTHX_ avref));
        }
        else {
            tx_warn(aTHX_ TX_st, "Use of nil to iterate");
        }
        avref = sv_2mortal(newRV_noinc((SV*)newAV()));
    }

    (void)   TX_lvar(id+0);      /* for each item, ensure to allocate a sv */
    sv_setiv(TX_lvar(id+1), -1); /* (re)set iterator */
    sv_setsv(TX_lvar(id+2), avref);

    TX_st->pc++;
}

TXC_goto(for_iter) {
    SV* const idsv  = TX_st_sa;
    IV  const id    = SvIVX(idsv); /* by literal_i */
    SV* const item  = TX_lvar_get(id+0);
    SV* const i     = TX_lvar_get(id+1);
    SV* const avref = TX_lvar_get(id+2);
    AV* const av    = (AV*)SvRV(avref);

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    SvIOK_only(i); /* for $^item */

    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(LIKELY(SvRMAGICAL(av) == 0)) {
        if(LIKELY(++SvIVX(i) <= AvFILLp(av))) {
            sv_setsv(item, AvARRAY(av)[SvIVX(i)]);
            TX_st->pc++;
            return;
        }
    }
    else { /* magical variables */
        if(LIKELY(++SvIVX(i) <= av_len(av))) {
            SV** const itemp = av_fetch(av, SvIVX(i), FALSE);
            sv_setsv(item, itemp ? *itemp : &PL_sv_undef);
            TX_st->pc++;
            return;
        }
    }

    /* the loop finished */
    {
        SV* const nil = &PL_sv_undef;
        sv_setsv(item,  nil);
        sv_setsv(i,     nil);
        sv_setsv(avref, nil);
    }

    TX_st->pc = SvUVX(TX_op_arg); /* goto */
}


/* sv_2iv(the guts of SvIV_please()) can make stringification faster,
   although I don't know why it is :)
*/
TXC(add) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) + SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(sub) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) - SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(mul) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) * SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(div) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) / SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(mod) {
    sv_setiv(TX_st->targ, SvIVx(TX_st_sb) % SvIVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}

TXC_w_sv(concat) {
    SV* const sv = TX_op_arg;
    sv_setsv_nomg(sv, TX_st_sb);
    sv_catsv_nomg(sv, TX_st_sa);

    TX_st_sa = sv;

    TX_st->pc++;
}

TXC_goto(and) {
    if(sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC_goto(dand) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(SvOK(sv)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC_goto(or) {
    if(!sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC_goto(dor) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC(not) {
    TX_st_sa = boolSV( !sv_true(TX_st_sa) );

    TX_st->pc++;
}

TXC(minus) { /* unary minus */
    sv_setnv(TX_st->targ, -SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}

TXC(size) {
    SV* const avref = TX_st_sa;

    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("Oops: Not an ARRAY reference for the size operator: %s",
            tx_neat(aTHX_ avref));
    }

    sv_setiv(TX_st->targ, av_len((AV*)SvRV(avref)) + 1);
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}

static I32
tx_sv_eq(pTHX_ SV* const a, SV* const b) {
    U32 const af = (SvFLAGS(a) & (SVf_POK|SVf_IOK|SVf_NOK));
    U32 const bf = (SvFLAGS(b) & (SVf_POK|SVf_IOK|SVf_NOK));

    if(af && bf) { /* shortcut for performance */
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

TXC(eq) {
    TX_st_sa = boolSV(  tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

TXC(ne) {
    TX_st_sa = boolSV( !tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

TXC(lt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) < SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(le) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) <= SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(gt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) > SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(ge) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) >= SvNVx(TX_st_sa) );
    TX_st->pc++;
}

TXC(macrocall) {
    U32 const addr = (U32)SvUVX(TX_st_sa);
    AV* cframe;
    dSP;
    dMARK;
    I32 i;
    SV* tmp;

    /* push a new frame */
    cframe = tx_push_frame(aTHX_ TX_st);

    tmp                             = *av_fetch(cframe, TXframe_OUTPUT, TRUE);
    AvARRAY(cframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                   = tmp;
    sv_setpvs(tmp, "");

    /* macroname will be set by macro_begin */
    sv_setuv(*av_fetch(cframe, TXframe_RETADDR, TRUE), TX_st->pc + 1);

    if(SP != MARK) { /* has arguments */
        dORIGMARK;
        MARK++;
        i = 0; /* must start zero */
        while(MARK <= SP) {
            sv_setsv(TX_lvar(i), *MARK);
            MARK++;
            i++;
        }
        SP = ORIGMARK;
        PUTBACK;
    }

    TX_st->pc = addr;
}

TXC_w_key(macro_begin) {
    AV* const cframe  = TX_current_frame();

    sv_setsv(*av_fetch(cframe, TXframe_NAME, TRUE), TX_op_arg);

    ENTER;
    SAVETMPS;

    TX_st->pc++;
}

TXC(macro_end) {
    AV* const oldframe  = TX_current_frame();
    AV* const cframe    = (AV*)AvARRAY(TX_st->frame)[--TX_st->current_frame];
    SV* const retaddr   = AvARRAY(oldframe)[TXframe_RETADDR];
    SV* tmp;

    TX_st->pad = AvARRAY(cframe) + TXframe_START_LVAR; /* switch the pad */

    sv_setsv(TX_st->targ, tx_escaped_string(aTHX_ TX_st->output)); 
    TX_st_sa = TX_st->targ; /* retval */

    tmp                               = AvARRAY(oldframe)[TXframe_OUTPUT];
    AvARRAY(oldframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                     = tmp;

    TX_st->pc = SvUVX(retaddr);
    /* ENTER & SAVETMPS will be done by TXC(pushmark) */
    FREETMPS;
    LEAVE;
}

TXC_w_key(macro) {
    SV* const name = TX_op_arg;
    HE* he;
    if((he = hv_fetch_ent(TX_st->macro, name, FALSE, 0U))) {
        TX_st_sa = hv_iterval(TX_st->macro, he);
    }
    else {
        croak("Macro %s is not defined", tx_neat(aTHX_ name));
    }

    TX_st->pc++;
}

TXC_w_key(function) {
    SV* const name = TX_op_arg;
    HE* he;

    if((he = hv_fetch_ent(TX_st->function, name, FALSE, 0U))) {
        TX_st_sa = hv_iterval(TX_st->function, he);
    }
    else {
        croak("Function %s is not registered", tx_neat(aTHX_ name));
    }

    TX_st->pc++;
}


TXC(funcall) {
    /* PUSHMARK & PUSH must be done */
    ENTER;
    SAVETMPS;

    TX_st_sa = tx_call(aTHX_ TX_st, TX_st_sa, 0, "function call");

    TX_st->pc++;
}

TXC_w_key(methodcall_s) {
    ENTER;
    SAVETMPS;

    TX_st_sa = tx_methodcall(aTHX_ TX_st, TX_op_arg);

    TX_st->pc++;
}

TXC(make_array) {
    dSP;
    dMARK;
    dORIGMARK;
    I32 const items = SP - MARK;
    AV* const av    = newAV();
    SV* const avref = sv_2mortal(newRV_noinc((SV*)av));

    av_extend(av, items - 1);
    while(++MARK <= SP) {
        SV* const val = *MARK;
        /* the SV is a mortal copy */
        /* seek 'push' */
        av_push(av, val);
        SvREFCNT_inc_simple_void_NN(val);
    }

    SP = ORIGMARK;
    PUTBACK;

    TX_st_sa = avref;

    TX_st->pc++;
}

TXC(make_hash) {
    dSP;
    dMARK;
    dORIGMARK;
    I32 const items = SP - MARK;
    HV* const hv    = newHV();
    SV* const hvref = sv_2mortal(newRV_noinc((SV*)hv));

    if((items % 2) != 0) {
        tx_error(aTHX_ TX_st, "Odd number of elements for hash literals");
        XPUSHs(sv_newmortal());
    }

    while(MARK < SP) {
        SV* const key = *(++MARK);
        SV* const val = *(++MARK);

        /* the SVs are a mortal copy */
        /* seek 'push' */
        (void)hv_store_ent(hv, key, val, 0U);
        SvREFCNT_inc_simple_void_NN(val);
    }

    SP = ORIGMARK;
    PUTBACK;

    TX_st_sa = hvref;

    TX_st->pc++;
}

TXC(enter) {
    ENTER;
    SAVETMPS;

    TX_st->pc++;
}

TXC(leave) {
    FREETMPS;
    LEAVE;

    TX_st->pc++;
}

TXC_goto(goto) {
    TX_st->pc = SvUVX(TX_op_arg);
}

TXC_w_sv(depend); /* tell the vm to dependent template files */

TXC(end) {
    TX_st->pc = TX_st->code_len;
}


/* End of opcodes */

/* The virtual machine code interpreter */
/* NOTE: tx_execute() must be surrounded in ENTER and LEAVE */
static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv) {
    dMY_CXT;
    Size_t const code_len = base->code_len;
    tx_state_t st;

    StructCopy(base, &st, tx_state_t);

    st.output = output;
    st.vars   = hv;

    assert(st.tmpl != NULL);

    /* local $current_st */
    SAVEVPTR(MY_CXT.current_st);
    MY_CXT.current_st = &st;

    if(MY_CXT.depth > 100) {
        croak("Execution is too deep (> 100)");
    }

    /* local $depth = $depth + 1 */
    SAVEI32(MY_CXT.depth);
    MY_CXT.depth++;

    while(st.pc < code_len) {
#ifdef DEBUGGING
        Size_t const old_pc = st.pc;
#endif
        CALL_FPTR(st.code[st.pc].exec_code)(aTHX_ &st);
#ifdef DEBUGGING
        if(UNLIKELY(old_pc == st.pc)) {
            croak("panic: pogram counter has not been changed on [%d]", (int)st.pc);
        }
#endif
    }

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
    tx_state_t* const st  = (tx_state_t*)mg->mg_ptr;
    tx_code_t* const code = st->code;
    I32 const len         = st->code_len;
    I32 i;

    for(i = 0; i < len; i++) {
        SvREFCNT_dec(code[i].arg);
    }

    Safefree(code);
    Safefree(st->lines);

    SvREFCNT_dec(st->function);
    SvREFCNT_dec(st->macro);
    SvREFCNT_dec(st->frame);
    SvREFCNT_dec(st->targ);
    SvREFCNT_dec(st->self);

    PERL_UNUSED_ARG(sv);

    return 0;
}

#ifdef USE_ITHREADS
static SV*
tx_sv_dup_inc(pTHX_ SV* const sv, CLONE_PARAMS* const param) {
    SV* const newsv = sv_dup(sv, param);
    SvREFCNT_inc_simple_void(newsv);
    return newsv;
}
#endif

static int
tx_mg_dup(pTHX_ MAGIC* const mg, CLONE_PARAMS* const param){
#ifdef USE_ITHREADS /* single threaded perl has no "xxx_dup()" APIs */
    tx_state_t* const st              = (tx_state_t*)mg->mg_ptr;
    const U16* const proto_lines      = st->lines;
    const tx_code_t* const proto_code = st->code;
    I32 const len                     = st->code_len;
    I32 i;

    Newx(st->code, len, tx_code_t);

    for(i = 0; i < len; i++) {
        st->code[i].exec_code = proto_code[i].exec_code;
        st->code[i].arg       = tx_sv_dup_inc(aTHX_ proto_code[i].arg, param);
    }

    Newx(st->lines, len, U16);
    Copy(proto_lines, st->lines, len, U16);

    st->function = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->function, param);
    st->macro    = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->macro,    param);
    st->frame    = (AV*)tx_sv_dup_inc(aTHX_ (SV*)st->frame,    param);
    st->targ     =      tx_sv_dup_inc(aTHX_ st->targ, param);
    st->self     =      tx_sv_dup_inc(aTHX_ st->self, param);
#else
    PERL_UNUSED_VAR(mg);
    PERL_UNUSED_VAR(param);
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
        croak("%"SVf" ...", ERRSV);
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

    if(!SvIOK(cache_mtime)) { /* non-checking mode (i.e. release mode) */
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
    MY_CXT.escaped_string_stash = gv_stashpvs(TX_ESC_CLASS, GV_ADDMULTI);
    MY_CXT.warn_handler         = SvREFCNT_inc_NN((SV*)get_cv("Text::Xslate::Engine::_warn", GV_ADDMULTI));
    MY_CXT.die_handler          = SvREFCNT_inc_NN((SV*)get_cv("Text::Xslate::Engine::_die",  GV_ADDMULTI));
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
    MAGIC* mg;
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADD);
    I32 const len = av_len(proto) + 1;
    I32 i;
    U16 l = 0;
    tx_state_t st;
    AV* tmpl;
    SV* tobj;
    SV** svp;
    AV* mainframe;

    Zero(&st, 1, tx_state_t);

    svp = hv_fetchs(self, "template", FALSE);
    if(!(svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV)) {
        croak("The xslate instance has no template table");
    }

    if(!SvOK(name)) { /* for strings */
        name     = newSVpvs_flags("<input>", SVs_TEMP);
        fullpath = cachepath = &PL_sv_undef;
        mtime    = sv_2mortal(newSViv( time(NULL) ));
    }

    tobj = hv_iterval((HV*)SvRV(*svp),
         hv_fetch_ent((HV*)SvRV(*svp), name, TRUE, 0U)
    );

    svp = hv_fetchs(self, "function", FALSE);
    if(svp && SvOK(*svp)) {
        if(SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV) {
            st.function = (HV*)SvRV(*svp);
            SvREFCNT_inc_simple_void_NN(st.function);
        }
    }
    if(!st.function) {
        croak("Function table must be a HASH reference");
    }

    tmpl = newAV();
    sv_setsv(tobj, sv_2mortal(newRV_noinc((SV*)tmpl)));
    av_extend(tmpl, TXo_least_size - 1);

    sv_setsv(*av_fetch(tmpl, TXo_NAME,      TRUE),  name);
    sv_setsv(*av_fetch(tmpl, TXo_MTIME,     TRUE),  mtime);
    sv_setsv(*av_fetch(tmpl, TXo_CACHEPATH, TRUE),  cachepath);
    sv_setsv(*av_fetch(tmpl, TXo_FULLPATH,  TRUE),  fullpath);

    st.tmpl = tmpl;
    st.self = newRV_inc((SV*)self);
    sv_rvweaken(st.self);

    st.hint_size = TX_HINT_SIZE;

    st.macro    = newHV();

    st.sa       = &PL_sv_undef;
    st.sb       = &PL_sv_undef;
    st.targ     = newSV(0);

    /* stack frame */
    st.frame         = newAV();
    st.current_frame = -1;

    mainframe = tx_push_frame(aTHX_ &st);
    av_store(mainframe, TXframe_NAME,    newSVpvs_share("main"));
    av_store(mainframe, TXframe_RETADDR, newSVuv(len));

    Newxz(st.lines, len, U16);

    Newxz(st.code, len, tx_code_t);

    st.code_len = len;

    mg = sv_magicext((SV*)tmpl, NULL, PERL_MAGIC_ext, &xslate_vtbl, (char*)&st, sizeof(st));
    mg->mg_flags |= MGf_DUP;

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

                    if(tx_oparg[opnum] & TXARGf_GOTO) {
                        /* calculate relational addresses to absolute addresses */
                        UV const abs_addr = (UV)(i + SvIVX(st.code[i].arg));
                        if(abs_addr >= (UV)len) {
                            croak("Oops: goto address %"IVdf" is out of range (must be 0 <= addr <= %"IVdf")",
                                SvIVX(st.code[i].arg), (IV)len);
                        }
                        sv_setuv(st.code[i].arg, abs_addr);
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

            /* setup line number */
            if(line && SvOK(*line)) {
                l = (U16)SvIV(*line);
            }
            st.lines[i] = l;


            /* special cases */
            if(opnum == TXOP_macro_begin) {
                (void)hv_store_ent(st.macro, st.code[i].arg, newSViv(i), 0U);
            }
            else if(opnum == TXOP_depend) {
                /* add a dependent file to the tmpl object */
                av_push(tmpl, SvREFCNT_inc_simple_NN(st.code[i].arg));
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
    self   = st->self;

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
            name, (int)st->pc);

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

MODULE = Text::Xslate    PACKAGE = Text::Xslate

void
escaped_string(SV* str)
CODE:
{
    ST(0) = tx_escaped_string(aTHX_ str);
    XSRETURN(1);
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::EscapedString

FALLBACK: TRUE

void
new(SV* klass, SV* str)
CODE:
{
    if(SvROK(klass)) {
        croak("You cannot call %s->new() as an instance method", TX_ESC_CLASS);
    }
    if(strNE(SvPV_nolen_const(klass), TX_ESC_CLASS)) {
        croak("You cannot extend %s", TX_ESC_CLASS);
    }
    ST(0) = tx_escaped_string(aTHX_ str);
    XSRETURN(1);
}

void
as_string(SV* self, ...)
OVERLOAD: \"\"
CODE:
{
    if(!( SvROK(self) && SvOK(SvRV(self))) ) {
        croak("You cannot call %s->as_string() as a class method", TX_ESC_CLASS);
    }
    ST(0) = SvRV(self);
    XSRETURN(1);
}

