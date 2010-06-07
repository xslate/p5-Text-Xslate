#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "xslate.h"

#define TXBM_DECL(name) void name \
    (pTHX_ tx_state_t* const st PERL_UNUSED_DECL, SV* const retval, SV* const method PERL_UNUSED_DECL, SV** MARK)

#define TXBM(moniker) static TXBM_DECL(CAT2(tx_builtin_method_, moniker))

#define TXBM_SETUP(name, nargs, trait) \
    { STRINGIFY(name), CAT2(tx_builtin_method_, name), nargs, trait }

enum tx_trait_t {
    TX_TRAIT_ANY,
    TX_TRAIT_ENUMERABLE,
    TX_TRAIT_KV,
};

typedef struct {
    const char* const name;

    TXBM_DECL( (*body) );

    I16 nargs;
    U16 trait;
} tx_builtin_method_t;

static SV*
tx_make_pair(pTHX_ HV* const stash, SV* const key, SV* const val) {
    AV* av;
    SV* pair[2];
    pair[0] = key;
    pair[1] = val;

    av = av_make(2, pair);
    return sv_bless( sv_2mortal( newRV_noinc((SV*)av) ), stash );
}

static I32
tx_pair_cmp(pTHX_ SV* const a, SV* const b) {
    assert(SvROK(a));
    assert(SvTYPE(SvRV(a)) == SVt_PVAV);
    assert(SvROK(b));
    assert(SvTYPE(SvRV(b)) == SVt_PVAV);

    return sv_cmp(
        *av_fetch((AV*)SvRV(a), 0, TRUE),
        *av_fetch((AV*)SvRV(b), 0, TRUE)
    );
}

static SV*
tx_kv(pTHX_ SV* const hvref) {
    HV* const stash = gv_stashpvs(TX_PAIR_CLASS, GV_ADDMULTI);
    HV* const hv    = (HV*)SvRV(hvref);
    AV* const av    = newAV();
    SV* const avref = sv_2mortal(newRV_noinc((SV*)av));
    HE* he;

    assert(SvROK(hvref));
    assert(SvTYPE(hv) == SVt_PVHV);

    if(HvKEYS(hv) > 0) {
        av_extend(av, HvKEYS(hv) - 1);
    }

    hv_iterinit(hv);
    while((he = hv_iternext(hv))) {
        SV* const pair = tx_make_pair(aTHX_ stash,
            hv_iterkeysv(he),
            hv_iterval(hv, he));

        av_push(av, pair);
        SvREFCNT_inc_simple_void_NN(pair);
    }
    sortsv(AvARRAY(av), AvFILLp(av)+1, tx_pair_cmp);
    return avref;
}

static SV*
tx_keys(pTHX_ SV* const hvref) {
    HV* const hv    = (HV*)SvRV(hvref);
    AV* const av    = newAV();
    SV* const avref = sv_2mortal(newRV_noinc((SV*)av));
    HE* he;

    assert(SvROK(hvref));
    assert(SvTYPE(hv) == SVt_PVHV);

    if(HvKEYS(hv) > 0) {
        av_extend(av, HvKEYS(hv) - 1);
    }

    hv_iterinit(hv);
    while((he = hv_iternext(hv))) {
        SV* const key = hv_iterkeysv(he);
        av_push(av, key);
        SvREFCNT_inc_simple_void_NN(key);
    }
    sortsv(AvARRAY(av), AvFILLp(av)+1, Perl_sv_cmp);
    return avref;
}

/* Enumerable containers */

TXBM(size) {
    sv_setiv(retval, av_len((AV*)SvRV(*MARK)) + 1);
}

TXBM(join) {
    dSP;
    AV* const av     = (AV*)SvRV(*MARK);
    I32 const len    = av_len(av) + 1;
    I32 i;

    EXTEND(SP, len);
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        PUSHs(svp ? *svp : &PL_sv_undef);
    }
    /* don't do PUTBACK */

    MARK++;
    sv_setpvs(retval, "");
    do_join(retval, *MARK, MARK, SP);
}

TXBM(reverse) {
    AV* const av        = (AV*)SvRV(*MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = sv_2mortal(newRV_noinc((SV*)result));
    I32 i;

    av_fill(result, len - 1);
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        av_store(result, -(i+1), newSVsv(svp ? *svp : &PL_sv_undef));
    }

    sv_setsv(retval, resultref);
}

TXBM(sort) {
    AV* const av        = (AV*)SvRV(*MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = sv_2mortal(newRV_noinc((SV*)result));
    I32 i;

    av_fill(result, len - 1);
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        av_store(result, i, newSVsv(svp ? *svp : &PL_sv_undef));
    }
    sortsv(AvARRAY(result), len, Perl_sv_cmp);

    sv_setsv(retval, resultref);
}


/* Key-Value containers */

TXBM(keys) {
    sv_setsv(retval, tx_keys(aTHX_ *MARK));
}

TXBM(values) {
    SV* const avref = tx_keys(aTHX_ *MARK);
    HV* const hv    = (HV*)SvRV(*MARK);
    AV* const av    = (AV*)SvRV(avref);
    I32 const len   = AvFILLp(av) + 1;
    I32 i;

    /* replace keys with values */
    /* map { $hv->{$_} } @{$keys} */
    for(i = 0; i < len; i++) {
        SV* const key = AvARRAY(av)[i];
        HE* const he  = hv_fetch_ent(hv, key, TRUE, 0U);
        SV* const val = hv_iterval(hv, he);
        AvARRAY(av)[i] = val;
        SvREFCNT_inc_simple_void_NN(val);
        SvREFCNT_dec(key);
    }

    sv_setsv(retval, avref);
}

TXBM(kv) {
    sv_setsv(retval, tx_kv(aTHX_ *MARK));
}

static const tx_builtin_method_t tx_builtin_method[] = {
    TXBM_SETUP(size,    0, TX_TRAIT_ENUMERABLE),
    TXBM_SETUP(join,    1, TX_TRAIT_ENUMERABLE),
    TXBM_SETUP(reverse, 0, TX_TRAIT_ENUMERABLE),
    TXBM_SETUP(sort,    0, TX_TRAIT_ENUMERABLE),

    TXBM_SETUP(keys,    0, TX_TRAIT_KV),
    TXBM_SETUP(values,  0, TX_TRAIT_KV),
    TXBM_SETUP(kv,      0, TX_TRAIT_KV),

};

static const size_t tx_num_buildin_method
    = sizeof(tx_builtin_method) / sizeof(tx_builtin_method[0]);


static I32
tx_as_enumerable(pTHX_ tx_state_t* const st, SV** const svp) {
    SV* const sv = *svp;

    if(sv_isobject(sv)) {
        dSP;
        SV* retval;
        PUSHMARK(SP);
        XPUSHs(sv);
        PUTBACK;

        call_method("(@{}", G_SCALAR | G_EVAL);

        if(sv_true(ERRSV)) {
            tx_error(aTHX_ st, "Use of %s as %s objects",
                tx_neat(aTHX_ sv), "enumerable");
            return FALSE;
        }

        retval = TX_pop();

        SvGETMAGIC(retval);
        if(SvROK(retval) && SvTYPE(SvRV(retval)) == SVt_PVAV) {
            *svp = retval;
            return TRUE;
        }
    }
    else if(SvROK(sv)){
        if(SvTYPE(SvRV(sv)) == SVt_PVAV) {
            return TRUE;
        }
        else if(SvTYPE(SvRV(sv)) == SVt_PVHV) {
            *svp = tx_kv(aTHX_ sv);
            return TRUE;
        }
    }

    return FALSE;
}

static I32
tx_as_kv(pTHX_ tx_state_t* const st, SV** const svp) {
    SV* const sv = *svp;

    if(sv_isobject(sv)) {
        dSP;
        SV* retval;
        PUSHMARK(SP);
        XPUSHs(sv);
        PUTBACK;

        call_method("(%{}", G_SCALAR | G_EVAL);

        if(sv_true(ERRSV)) {
            tx_error(aTHX_ st, "Use of %s as %s objects",
                tx_neat(aTHX_ sv), "kv");
            return FALSE;
        }

        retval = TX_pop();

        SvGETMAGIC(retval);
        if(SvROK(retval) && SvTYPE(SvRV(retval)) == SVt_PVHV) {
            *svp = retval;
            return TRUE;
        }
    }
    else if(SvROK(sv)){
        if(SvTYPE(SvRV(sv)) == SVt_PVHV) {
            return TRUE;
        }
    }

    return FALSE;
}

SV*
tx_methodcall(pTHX_ tx_state_t* const st, SV* const method) {
    /* ENTER & LEAVE & PUSHMARK & PUSH must be done */
    dSP;
    SV** MARK = PL_stack_base + TOPMARK;
    dORIGMARK;
    SV* const invocant = *(++MARK);
    STRLEN methodlen;
    const char* const methodpv = SvPV_const(method, methodlen);
    U32 i;
    SV* retval = NULL;

    if(sv_isobject(invocant)) {
        HV* const stash = SvSTASH(SvRV(invocant));
        GV* const mgv   = gv_fetchmeth_autoload(stash, methodpv, methodlen, 0);

        if(mgv) {
            call_sv((SV*)GvCV(mgv), G_SCALAR | G_EVAL);
            if(sv_true(ERRSV)) {
                tx_error(aTHX_ st, "%"SVf"\t...", ERRSV);
            }
            retval = st->targ;
            sv_setsv_nomg(retval, TX_pop());
            goto finish;
        }
        /* fallback to builtin methods */
    }

    (void)POPMARK;

    if(!SvOK(invocant)) {
        tx_warn(aTHX_ st, "Use of nil to invoke method %"SVf, method);
        goto finish;
    }

    /* linear search */
    for(i = 0; i < tx_num_buildin_method; i++) {
        tx_builtin_method_t const bm = tx_builtin_method[i];
        if(strEQ(methodpv, bm.name)) {
            dSP;
            I32 const items = SP - MARK;

            if(bm.nargs != -1
                && bm.nargs != items) {
                tx_error(aTHX_ st,
                    "Builtin method %"SVf" requires exactly %d argument(s), "
                    "but supplied %d",
                    method, (int)bm.nargs, (int)items);
                goto finish;
            }

            if(bm.trait == TX_TRAIT_ENUMERABLE) {
                if(!tx_as_enumerable(aTHX_ st, MARK /* invocant ptr */)) {
                    goto not_found;
                }
                assert(SvROK(*MARK) && SvTYPE(SvRV(*MARK)) == SVt_PVAV);
            }
            else if(bm.trait == TX_TRAIT_KV) {
                if(!tx_as_kv(aTHX_ st, MARK /* invocant ptr */)) {
                    goto not_found;
                }
                assert(SvROK(*MARK) && SvTYPE(SvRV(*MARK)) == SVt_PVHV);
            }

            retval = st->targ;
            bm.body(aTHX_ st, retval, method, MARK);
            goto finish;
        }
    }
    not_found:
    tx_error(aTHX_ st, "Undefined method %"SVf" called for %s", method, tx_neat(aTHX_ invocant));

    finish:
    SP = ORIGMARK;
    PUTBACK;

    FREETMPS;
    LEAVE;
    return retval ? retval : &PL_sv_undef;
}

MODULE = Text::Xslate::Methods    PACKAGE = Text::Xslate::Type::Pair

void
key(AV* pair)
ALIAS:
    key   = 0
    value = 1
CODE:
{
    ST(0) = *av_fetch(pair, ix, TRUE);
    XSRETURN(1);
}
