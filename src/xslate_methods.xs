#include "xs_version.h"
#include "xslate.h"

#define TXBM_DECL(name) void name \
    (pTHX_ tx_state_t* const st PERL_UNUSED_DECL, SV* const retval, SV* const method PERL_UNUSED_DECL, SV** MARK)

/* tx_bm _ TYPE _ MONIKER */
#define TXBM_NAME(t, n) CAT2( CAT2(tx_bm, _), CAT2(t, CAT2(_, n)))
#define TXBM(t, moniker) static TXBM_DECL( TXBM_NAME(t, moniker))

#define TXBM_SETUP(t, name, nargs_min, nargs_max) \
    { STRINGIFY(t) "::" STRINGIFY(name), TXBM_NAME(t, name), nargs_min, nargs_max }

typedef struct {
    const char* const name;

    TXBM_DECL( (*body) );

    U8 nargs_min;
    U8 nargs_max;
} tx_builtin_method_t;

#define MY_CXT_KEY "Text::Xslate::Methods::_guts" XS_VERSION
typedef struct {
    tx_state_t* cmparg_st;
    SV*         cmparg_proc;

    HV* pair_stash;
} my_cxt_t;
START_MY_CXT;

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
tx_keys(pTHX_ SV* const hvref) {
    HV* const hv    = (HV*)SvRV(hvref);
    AV* const av    = newAV();
    SV* const avref = sv_2mortal(newRV_noinc((SV*)av));
    HE* he;
    I32 i;

    assert(SvROK(hvref));
    assert(SvTYPE(hv) == SVt_PVHV);

    if(HvKEYS(hv) > 0) {
        av_extend(av, HvKEYS(hv) - 1);
    }

    hv_iterinit(hv);
    i = 0;
    while((he = hv_iternext(hv))) {
        SV* const key = hv_iterkeysv(he);
        (void)av_store(av, i++, key);
        SvREFCNT_inc_simple_void_NN(key);
    }
    sortsv(AvARRAY(av), i, Perl_sv_cmp);
    return avref;
}

/* NIL */

/* SCALAR */

/* ARRAY */
TXBM(array, first) {
    SV **svp = av_fetch((AV*)SvRV(*MARK), 0, FALSE);
    sv_setsv(retval, svp ? *svp : &PL_sv_undef);
}

TXBM(array, last) {
    AV* const av = (AV*)SvRV(*MARK);
    SV **svp = av_fetch(av, av_len(av), FALSE);
    sv_setsv(retval, svp ? *svp : &PL_sv_undef);
}

TXBM(array, size) {
    sv_setiv(retval, av_len((AV*)SvRV(*MARK)) + 1);
}

TXBM(array, join) {
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

TXBM(array, reverse) {
    AV* const av        = (AV*)SvRV(*MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = sv_2mortal(newRV_noinc((SV*)result));
    I32 i;

    av_fill(result, len - 1);
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        (void)av_store(result, -(i+1), newSVsv(svp ? *svp : &PL_sv_undef));
    }

    sv_setsv(retval, resultref);
}

static I32
tx_sv_cmp(pTHX_ SV* const x, SV* const y) {
    dMY_CXT;
    dSP;
    tx_state_t* const st = MY_CXT.cmparg_st;
    SV* const proc       = MY_CXT.cmparg_proc;
    SV* result;

    assert(st);
    assert(proc);

    PUSHMARK(SP);
    /* no need to extend SP because of the args of the method (sort) is >= 2 */
    PUSHs(x);
    PUSHs(y);
    PUTBACK;
    result = tx_unmark_raw(aTHX_ tx_proccall(aTHX_ st, proc, "sort callback"));
    return SvIV(result);
}

static SVCOMPARE_t
tx_prepare_compare_func(pTHX_ tx_state_t* const st, I32 const items, SV** const MARK) {
    assert(items == 0 || items == 1);
    if(items == 0) {
        return Perl_sv_cmp;
    }
    else {
        dMY_CXT;
        SAVEVPTR(MY_CXT.cmparg_st);
        SAVESPTR(MY_CXT.cmparg_proc);

        MY_CXT.cmparg_st   = st;
        MY_CXT.cmparg_proc = *(MARK + 1);
        return tx_sv_cmp;
    }
}

TXBM(array, sort) {
    dSP;
    I32 const items     = SP - MARK;
    AV* const av        = (AV*)SvRV(*MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = newRV_noinc((SV*)result);
    SVCOMPARE_t cmpfunc;
    I32 i;

    ENTER;
    SAVETMPS;
    sv_2mortal(resultref);

    cmpfunc = tx_prepare_compare_func(aTHX_ st, items, MARK);

    av_extend(result, len - 1);
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        (void)av_store(result, i, newSVsv(svp ? *svp : &PL_sv_undef));
    }
    sortsv(AvARRAY(result), len, cmpfunc);

    sv_setsv(retval, resultref);

    FREETMPS;
    LEAVE;
}

TXBM(array, map) {
    AV* const av        = (AV*)SvRV(*MARK);
    SV* const proc      = *(++MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = newRV_noinc((SV*)result);
    I32 i;

    ENTER;
    SAVETMPS;
    sv_2mortal(resultref);
    av_extend(result, len - 1);
    for(i = 0; i < len; i++) {
        dSP;
        SV** const svp = av_fetch(av, i, FALSE);
        SV* sv;

        PUSHMARK(SP);
        /* no need to extend SP because of the args of the method is > 0 */
        PUSHs(svp ? *svp : &PL_sv_undef);
        PUTBACK;
        sv = tx_proccall(aTHX_ st, proc, "map callback");
        (void)av_store(result, i, newSVsv(sv));
    }
    /* setting retval must be here because retval is actually st->targ */
    sv_setsv(retval, resultref);
    FREETMPS;
    LEAVE;
}

TXBM(array, reduce) {
    AV* const av        = (AV*)SvRV(*MARK);
    SV* const proc      = *(++MARK);
    I32 const len       = av_len(av) + 1;
    SV** svp;
    SV* a;
    I32 i;

    if(len < 2) {
        svp = av_fetch(av, 0, FALSE);
        sv_setsv(retval, svp ? *svp : NULL);
        return;
    }

    ENTER;
    SAVETMPS;
    svp = av_fetch(av, 0, FALSE);
    a = svp ? *svp : &PL_sv_undef;

    for(i = 1; i < len; i++) {
        dSP;
        SV* b;
        svp = av_fetch(av, i, FALSE);
        b   = svp ? *svp : &PL_sv_undef;

        PUSHMARK(SP);
        PUSHs(a);
        PUSHs(b);
        PUTBACK;
        a = tx_proccall(aTHX_ st, proc, "reduce callback");
    }
    /* setting retval must be here because retval is actually st->targ */
    sv_setsv(retval, a);
    FREETMPS;
    LEAVE;
}

TXBM(array, merge) {
    AV* const av        = (AV*)SvRV(*MARK);
    SV* const value     = *(++MARK);
    I32 const len       = av_len(av) + 1;
    AV* const result    = newAV();
    SV* const resultref = newRV_noinc((SV*)result);
    AV* m = NULL;
    I32 mlen;
    I32 i;

    ENTER;
    SAVETMPS;
    sv_2mortal(resultref);

    if(tx_sv_is_array_ref(aTHX_ value)) {
        m    = (AV*)SvRV(value);
        mlen = av_len(m) + 1;
    }
    else {
        mlen = 1;
    }
    av_extend(result, len + mlen - 1);

    /* copy */
    for(i = 0; i < len; i++) {
        SV** const svp = av_fetch(av, i, FALSE);
        SV* const sv   = svp ? *svp : &PL_sv_undef;
        (void)av_store(result, i, newSVsv(sv));
    }
    /* merge */
    if(m) {
        for(i = 0; i < mlen; i++) {
            SV** const svp = av_fetch(m, i, FALSE);
            SV* const sv   = svp ? *svp : &PL_sv_undef;
            av_push(result, newSVsv(sv));
        }
    }
    else {
        av_push(result, newSVsv(value));
    }

    /* setting retval must be here because retval is actually st->targ */
    sv_setsv(retval, resultref);
    FREETMPS;
    LEAVE;
}

/* HASH */

TXBM(hash, size) {
    HV* const hv = (HV*)SvRV(*MARK);
    IV i = 0;
    hv_iterinit(hv);
    while(hv_iternext(hv)) {
        i++;
    }
    sv_setiv(retval, i);
}

TXBM(hash, keys) {
    sv_setsv(retval, tx_keys(aTHX_ *MARK));
}

TXBM(hash, values) {
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
        SvREFCNT_dec(key);
        AvARRAY(av)[i] = newSVsv(val);
    }

    sv_setsv(retval, avref);
}

TXBM(hash, kv) {
    dMY_CXT;
    SV* const hvref = *MARK;
    HV* const hv    = (HV*)SvRV(hvref);
    AV* const av    = newAV();
    SV* const avref = newRV_noinc((SV*)av);
    HE* he;
    I32 i;

    ENTER;
    SAVETMPS;
    sv_2mortal(avref);

    if(HvKEYS(hv) > 0) {
        av_extend(av, HvKEYS(hv) - 1);
    }

    hv_iterinit(hv);
    i = 0;
    while((he = hv_iternext(hv))) {
        SV* const pair = tx_make_pair(aTHX_ MY_CXT.pair_stash,
            hv_iterkeysv(he),
            hv_iterval(hv, he));

        (void)av_store(av, i++, pair);
        SvREFCNT_inc_simple_void_NN(pair);
    }
    sortsv(AvARRAY(av), i, tx_pair_cmp);
    sv_setsv(retval, avref);

    FREETMPS;
    LEAVE;
}

TXBM(hash, merge) {
    sv_setsv(retval, tx_merge_hash(aTHX_ st, *MARK, *(MARK + 1)));
}

static const tx_builtin_method_t tx_builtin_method[] = {
    TXBM_SETUP(array,  first,   0, 0),
    TXBM_SETUP(array,  last,    0, 0),
    TXBM_SETUP(array,  size,    0, 0),
    TXBM_SETUP(array,  join,    1, 1),
    TXBM_SETUP(array,  reverse, 0, 0),
    TXBM_SETUP(array,  sort,    0, 1), /* can take a compare function */
    TXBM_SETUP(array,  map,     1, 1),
    TXBM_SETUP(array,  reduce,  1, 1),
    TXBM_SETUP(array,  merge,   1, 1),

    TXBM_SETUP(hash,   size,    0, 0),
    TXBM_SETUP(hash,   keys,    0, 0), /* TODO: can take a compare function */
    TXBM_SETUP(hash,   values,  0, 0), /* TODO: can take a compare function */
    TXBM_SETUP(hash,   kv,      0, 0), /* TODO: can take a compare function */
    TXBM_SETUP(hash,   merge,   1, 1),
};

static const size_t tx_num_builtin_method
    = sizeof(tx_builtin_method) / sizeof(tx_builtin_method[0]);

SV*
tx_methodcall(pTHX_ tx_state_t* const st, SV* const method) {
    /* PUSHMARK must be done */
    dSP;
    dMARK;
    dORIGMARK;
    SV* const invocant = *(++MARK);
    const char* type_name;
    SV* fq_name;
    HE* he;
    SV* retval;

    if(sv_isobject(invocant)) {
        PUSHMARK(ORIGMARK); /* re-pushmark */
        return tx_call_sv(aTHX_ st, method, G_METHOD, "method call");
    }

    retval = NULL;
    if(SvROK(invocant)) {
        SV* const referent = SvRV(invocant);
        if(SvTYPE(referent) == SVt_PVAV) {
            type_name = "array::";
        }
        else if(SvTYPE(referent) == SVt_PVHV) {
            type_name = "hash::";
        }
        else {
            type_name = "scalar::";
        }
    }
    else {
        if(SvOK(invocant)) {
            type_name = "scalar::";
        }
        else {
            type_name = "nil::";
        }
    }

    /* make type::method */
    fq_name = st->targ;
    sv_setpv(fq_name, type_name);
    sv_catsv(fq_name, method);

    he = hv_fetch_ent(st->symbol, fq_name, FALSE, 0U);
    if(he) {
        SV* const entity = HeVAL(he);

        if(SvIOK(entity)) {
            I32 const items = SP - MARK;
            const tx_builtin_method_t* bm;

            if(SvUVX(entity) >= tx_num_builtin_method) {
                croak("Oops: Builtin method index of %"SVf" is out of range",
                    fq_name);
            }

            bm = &tx_builtin_method[SvUVX(entity)];

            if(!(items >= bm->nargs_min && items <= bm->nargs_max)) {
                tx_error(aTHX_ st, "Wrong number of arguments for %"SVf,
                    method);
                goto finish;
            }

            retval = st->targ;
            bm->body(aTHX_ st, retval, method, MARK);
            goto finish;
        }
        else { /* user defined methods */
            PUSHMARK(ORIGMARK); /* re-pushmark */
            return tx_proccall(aTHX_ st, entity, "method call");
        }
    }
    if(!SvOK(invocant)) {
        tx_warn(aTHX_ st, "Use of nil to invoke method %"SVf, method);
        goto finish;
    }
    tx_error(aTHX_ st, "Undefined method %"SVf" called for %s", method,
        tx_neat(aTHX_ invocant));

    finish:
    SP = ORIGMARK;
    PUTBACK;
    return retval ? retval : &PL_sv_undef;
}

void
tx_register_builtin_methods(pTHX_ HV* const hv) {
    U32 i;
    assert(hv);
    for(i = 0; i < tx_num_builtin_method; i++) {
        const tx_builtin_method_t* const bm = &tx_builtin_method[i];
        SV* const sv = *hv_fetch(hv, bm->name, strlen(bm->name), TRUE);

        if(!SvOK(sv)) { /* users can override it */
            TAINT_NOT;
            sv_setiv(sv, i);
        }
    }
}

MODULE = Text::Xslate::Methods    PACKAGE = Text::Xslate::Type::Pair

PROTOTYPES:   DISABLE
VERSIONCHECK: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.pair_stash = gv_stashpvs(TX_PAIR_CLASS, GV_ADDMULTI);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.pair_stash = gv_stashpvs(TX_PAIR_CLASS, GV_ADDMULTI);
    PERL_UNUSED_VAR(items);
}

#endif

void
key(AV* pair)
ALIAS:
    key   = 0
    value = 1
CODE:
{
    ST(0) = *av_fetch(pair, ix, TRUE);
}

