/*********************

 Xslate opcode definitions

 *********************/

TXC(noop) {
    TX_RETURN_NEXT();
}

TXC(move_to_sb) {
    TX_st_sb = TX_st_sa;
    TX_RETURN_NEXT();
}

TXC(move_from_sb) {
    TX_st_sa = TX_st_sb;
    TX_RETURN_NEXT();
}

TXC_w_var(save_to_lvar) {
    SV* const sv = TX_lvar(TX_op_arg_iv);
    sv_setsv(sv, TX_st_sa);
    TX_st_sa = sv;

    TX_RETURN_NEXT();
}

TXC_w_var(load_lvar) {
    TX_st_sa = TX_lvar_get(TX_op_arg_iv);
    TX_RETURN_NEXT();
}

TXC_w_var(load_lvar_to_sb) {
    TX_st_sb = TX_lvar_get(TX_op_arg_iv);
    TX_RETURN_NEXT();
}

/* local $vars->{$key} = $val */
/* see pp_helem() in pp_hot.c */
TXC_w_key(localize_s) {
    HV* const vars   = TX_st->vars;
    const bool tied = SvRMAGICAL(vars) && mg_find((const SV *)vars, PERL_MAGIC_tied);
    SV* const key    = TX_op_arg_sv;
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
        if (tied) {
#ifdef SAVEf_KEEPOLDELEM /* 5.12.0 or higher versions */
            save_helem_flags(vars, key, svp, SAVEf_KEEPOLDELEM);
#else
            SV *tmp = newSVsv(*svp);
            save_helem(vars, key, &tmp);
#endif
        }
        else {
            save_helem(vars, key, svp);
        }
    }
    sv_setsv_mg(*svp, newval);

    TX_RETURN_NEXT();
}

/* local $engine->{vars} = expr; */
TXC(localize_vars) {
    SV* vars = sv_mortalcopy(TX_st_sa);

    if(!( SvROK(vars) && SvTYPE(SvRV(vars)) == SVt_PVHV
            && !SvOBJECT(SvRV(vars)) )) {
        tx_warn(aTHX_ TX_st, "Variable map must be a HASH reference, not %s",
            tx_neat(aTHX_ vars));
        vars = sv_2mortal(newRV_noinc((SV*)newHV()));
    }

    save_hptr(&(TX_st->vars));
    TX_st->vars = (HV*)SvRV(vars);

    TX_RETURN_NEXT();
}

TXC(push) {
    dSP;
    XPUSHs(sv_mortalcopy(TX_st_sa));
    PUTBACK;

    TX_RETURN_NEXT();
}

TXC(pushmark) {
    dSP;
    PUSHMARK(SP);

    TX_RETURN_NEXT();
}

TXC(nil) {
    TX_st_sa = &PL_sv_undef;

    TX_RETURN_NEXT();
}

TXC_w_sv(literal) {
    TX_st_sa = TX_op_arg_sv;

    TX_RETURN_NEXT();
}

/* the same as literal, but make sure its argument is an integer */
TXC_w_sviv(literal_i);

TXC_w_key(fetch_s) { /* fetch a field from the top */
    HV* const vars = TX_st->vars;
    HE* const he   = hv_fetch_ent(vars, TX_op_arg_sv, FALSE, 0U);

    TX_st_sa = he ? hv_iterval(vars, he) : &PL_sv_undef;

    TX_RETURN_NEXT();
}

TXC(fetch_field) { /* fetch a field from a variable (bin operator) */
    SV* const var = TX_st_sb;
    SV* const key = TX_st_sa;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_RETURN_NEXT();
}

TXC_w_key(fetch_field_s) { /* fetch a field from a variable (for literal) */
    SV* const var = TX_st_sa;
    SV* const key = TX_op_arg_sv;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_RETURN_NEXT();
}

TXC(print) {
    tx_print(aTHX_ TX_st, TX_st_sa);
    TX_RETURN_NEXT();
}

TXC(print_raw) {
    SV* const arg = tx_unmark_raw(aTHX_ TX_st_sa);
    if(SvOK(arg)) {
        tx_sv_cat(aTHX_ TX_st->output, arg);
    }
    else {
        tx_warn(aTHX_ TX_st, "Use of nil to print");
    }
    TX_RETURN_NEXT();
}

TXC_w_sv(print_raw_s) {
    tx_sv_cat(aTHX_ TX_st->output, TX_op_arg_sv);

    TX_RETURN_NEXT();
}

TXC(include) {
    dMY_CXT;
    tx_state_t* const st = tx_load_template(aTHX_ TX_st->engine, TX_st_sa, TRUE);

    ENTER;
    SAVETMPS;
    tx_push_frame(aTHX_ st);
    tx_execute(aTHX_ aMY_CXT_ st, TX_st->output, TX_st->vars);
    FREETMPS;
    LEAVE;

    TX_RETURN_NEXT();
}

TXC(find_file) {
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(TX_st->engine);
    XPUSHs(TX_st_sa);
    PUTBACK;

    call_method("find_file", G_SCALAR|G_EVAL);

    SPAGAIN;
    if (SvTRUE(ERRSV)) {
        sv_setsv(TX_st_sa, &PL_sv_no);
    }
    else {
        sv_setsv(TX_st_sa, &PL_sv_yes);
    }
    (void)POPs;
    PUTBACK;

    FREETMPS;
    LEAVE;

    TX_RETURN_NEXT();
}

TXC(suffix) {
    TX_st_sa = *hv_fetchs((HV*)SvRV(TX_st->engine), "suffix", 0);
    TX_RETURN_NEXT();
}

TXC_w_var(for_start) {
    SV* avref    = TX_st_sa;
    IV  const id = TX_op_arg_iv;
    SV* tmpsv;

    SvGETMAGIC(avref);
    if((tmpsv = tx_sv_to_ref(aTHX_ avref, SVt_PVAV, to_av_amg))) {
        avref = tmpsv;
    }
    else {
        if(SvOK(avref)) {
            tx_error(aTHX_ TX_st,
                "Iterating data must be an ARRAY reference, not %s",
                tx_neat(aTHX_ avref));
        }
        avref = sv_2mortal(newRV_noinc((SV*)newAV()));
    }

    (void)   TX_lvar(id+TXfor_ITEM); /* allocate the space */
    sv_setiv(TX_lvar(id+TXfor_ITER), -1); /* (re)set iterator */
    sv_setsv(TX_lvar(id+TXfor_ARRAY), avref);

    TX_RETURN_NEXT();
}

TXC_goto(for_iter) {
    SV* const idsv  = TX_st_sa;
    IV  const id    = SvIVX(idsv); /* by literal_i */
    SV* const item  = TX_lvar_get(id+TXfor_ITEM);
    SV* const i     = TX_lvar_get(id+TXfor_ITER);
    SV* const avref = TX_lvar_get(id+TXfor_ARRAY);
    AV* const av    = (AV*)SvRV(avref);

    assert(SvROK(avref));
    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    SvIOK_only(i); /* for $^item */
    SvIVX(i)++;
    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(LIKELY(!SvRMAGICAL(av))) {
        if(SvIVX(i) <= AvFILLp(av)) {
            sv_setsv(item, AvARRAY(av)[SvIVX(i)]);
            TX_RETURN_NEXT();
        }
    }
    else { /* magical variables */
        if(SvIVX(i) <= av_len(av)) {
            SV** const itemp = av_fetch(av, SvIVX(i), FALSE);
            sv_setsv(item, itemp ? *itemp : NULL);
            TX_RETURN_NEXT();
        }
    }

    /* the loop finished */
    TX_st_sa = boolSV( SvIVX(i) > 0 ); /* for foreach-else */
    tx_sv_clear(aTHX_ item);
    tx_sv_clear(aTHX_ i);
    tx_sv_clear(aTHX_ avref);

    TX_RETURN_PC( TX_op_arg_pc );
}


/* sv_2iv(the guts of SvIV_please()) can make stringification faster,
   although I don't know why it is :)
*/
TXC(add) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) + SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}
TXC(sub) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) - SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}
TXC(mul) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) * SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}
TXC(div) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) / SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}
TXC(mod) {
    IV const lhs = SvIVx(TX_st_sb);
    IV const rhs = SvIVx(TX_st_sa);
    if(rhs == 0) {
        tx_error(aTHX_ TX_st, "Illegal modulus zero");
        sv_setpvs(TX_st->targ, "NaN");
    }
    else {
        sv_setiv(TX_st->targ,  lhs % rhs);
    }
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC_w_sv(concat) {
    dMY_CXT;
    SV*       sv  = TX_op_arg_sv;
    SV* const lhs = TX_st_sb;
    SV* const rhs = TX_st_sa;

    SvGETMAGIC(lhs);
    SvGETMAGIC(rhs);

    if(!SvOK(lhs)){
        sv_setsv_nomg(sv, rhs);
        TX_st_sa = sv;
        TX_RETURN_NEXT();
    }
    if(!SvOK(rhs)){
        sv_setsv_nomg(sv, lhs);
        TX_st_sa = sv;
        TX_RETURN_NEXT();
    }

    if(tx_str_is_raw(aTHX_ aMY_CXT_ lhs)) {
        sv_setsv_nomg(sv, TX_UNMARK_RAW(lhs));

        if(tx_str_is_raw(aTHX_ aMY_CXT_ rhs)) {
            sv_catsv_nomg(sv, TX_UNMARK_RAW(rhs));
        }
        else {
            tx_sv_cat_with_html_escape_force(aTHX_ sv, rhs);
        }
        sv = tx_mark_raw(aTHX_ sv);
    }
    else {
        if(tx_str_is_raw(aTHX_ aMY_CXT_ rhs)) {
            sv_setpvs(sv, "");
            tx_sv_cat_with_html_escape_force(aTHX_ sv, lhs);
            sv_catsv_nomg(sv, TX_UNMARK_RAW(rhs));
            sv = tx_mark_raw(aTHX_ sv);
        }
        else {
            sv_setsv_nomg(sv, lhs);
            sv_catsv_nomg(sv, rhs);
        }
    }

    TX_st_sa = sv;

    TX_RETURN_NEXT();
}

TXC_w_sv(repeat) {
    dMY_CXT;
    IV const lhs_is_raw  = tx_str_is_raw(aTHX_ aMY_CXT_ TX_st_sb);
    SV* const lhs        = lhs_is_raw ? TX_UNMARK_RAW(TX_st_sb) : TX_st_sb;
    SV* const rhs = TX_st_sa;

    SvGETMAGIC(lhs);
    if(!SvOK(lhs)) {
        tx_warn(aTHX_ TX_st, "Use of nil for repeat operator");
        TX_st_sa = &PL_sv_undef;
    }
    else if(!looks_like_number(rhs)) {
        tx_error(aTHX_ TX_st, "Repeat count must be a number, not %s",
            tx_neat(aTHX_ TX_st_sa));
        TX_st_sa = &PL_sv_undef;
    }
    else {
        STRLEN const len  = sv_len(lhs);
        UV const count    = SvUV(rhs);
        SV* const sv      = TX_op_arg_sv;
        UV i;

        sv_setpvs(sv, "");
        SvGROW(sv, len * count + 1);
        for(i = 0; i < count; i++) {
            tx_sv_cat(aTHX_ sv, lhs);
        }
        TX_st_sa = lhs_is_raw ? tx_mark_raw(aTHX_ sv) : sv;
    }

    TX_RETURN_NEXT();
}

TXC(bitor) {
    sv_setuv(TX_st->targ, SvUVx(TX_st_sb) | SvUVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(bitand) {
    sv_setuv(TX_st->targ, SvUVx(TX_st_sb) & SvUVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(bitxor) {
    sv_setuv(TX_st->targ, SvUVx(TX_st_sb) ^ SvUVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(bitneg) {
    sv_setuv(TX_st->targ, ~SvUVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}



TXC_goto(and) {
    if(sv_true(TX_st_sa)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( TX_op_arg_pc );
    }
}

TXC_goto(dand) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(SvOK(sv)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( TX_op_arg_pc );
    }
}

TXC_goto(or) {
    if(!sv_true(TX_st_sa)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( TX_op_arg_pc );
    }
}

TXC_goto(dor) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( TX_op_arg_pc );
    }
}

TXC(not) {
    TX_st_sa = boolSV( !sv_true(TX_st_sa) );

    TX_RETURN_NEXT();
}

TXC(minus) { /* unary minus */
    sv_setnv(TX_st->targ, -SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(max_index) {
    SV* const avref = TX_st_sa;

    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("Oops: Not an ARRAY reference for builtin max_index: %s",
            tx_neat(aTHX_ avref));
    }

    sv_setiv(TX_st->targ, av_len((AV*)SvRV(avref)));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(builtin_mark_raw) {
    TX_st_sa = tx_mark_raw(aTHX_ TX_st_sa);
    TX_RETURN_NEXT();
}

TXC(builtin_unmark_raw) {
    TX_st_sa = tx_unmark_raw(aTHX_ TX_st_sa);
    TX_RETURN_NEXT();
}

TXC(builtin_uri_escape) {
    TX_st_sa = tx_uri_escape(aTHX_ TX_st_sa);
    TX_RETURN_NEXT();
}

TXC(builtin_is_array_ref) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    TX_st_sa = boolSV( tx_sv_is_array_ref(aTHX_ sv) );
    TX_RETURN_NEXT();
}

TXC(builtin_is_hash_ref) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    TX_st_sa = boolSV( tx_sv_is_hash_ref(aTHX_ sv) );
    TX_RETURN_NEXT();
}

TXC(builtin_html_escape) {
    TX_st_sa = tx_html_escape(aTHX_ TX_st_sa);
    TX_RETURN_NEXT();
}

TXC(is_code_ref) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    TX_st_sa = boolSV( tx_sv_is_code_ref(aTHX_ sv) );
    TX_RETURN_NEXT();
}

TXC(merge_hash) {
    SV* const base = TX_st_sa;
    SV* const value = TX_st_sb;
    TX_st_sa = tx_merge_hash(aTHX_ TX_st, base, value);
    TX_RETURN_NEXT();
}

TXC(match) {
    TX_st_sa = boolSV( tx_sv_match(aTHX_ TX_st_sb, TX_st_sa) );
    TX_RETURN_NEXT();
}

TXC(eq) {
    TX_st_sa = boolSV(  tx_sv_eq(aTHX_ TX_st_sb, TX_st_sa) );
    TX_RETURN_NEXT();
}

TXC(ne) {
    TX_st_sa = boolSV( !tx_sv_eq(aTHX_ TX_st_sb, TX_st_sa) );
    TX_RETURN_NEXT();
}

TXC(lt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) < SvNVx(TX_st_sa) );
    TX_RETURN_NEXT();
}
TXC(le) {
    TX_st_sa = boolSV(
        SvNVx(TX_ckuuv_lhs(TX_st_sb)) <= SvNVx(TX_ckuuv_rhs(TX_st_sa))
    );
    TX_RETURN_NEXT();
}
TXC(gt) {
    TX_st_sa = boolSV(
        SvNVx(TX_ckuuv_lhs(TX_st_sb)) > SvNVx(TX_ckuuv_rhs(TX_st_sa))
    );
    TX_RETURN_NEXT();
}
TXC(ge) {
    TX_st_sa = boolSV(
        SvNVx(TX_ckuuv_lhs(TX_st_sb)) >= SvNVx(TX_ckuuv_rhs(TX_st_sa))
    );
    TX_RETURN_NEXT();
}

TXC(ncmp) {
    NV const lhs = SvNVx(TX_ckuuv_lhs(TX_st_sb));
    NV const rhs = SvNVx(TX_ckuuv_rhs(TX_st_sa));
    IV value;
    if(lhs == rhs) {
        value =  0;
    }
    else if(lhs < rhs) {
        value = -1;
    }
    else if(lhs > rhs) {
        value =  1;
    }
    else {
        /* compares NaN with something */
        TX_st_sa = &PL_sv_undef;
        TX_RETURN_NEXT();
    }

    sv_setiv(TX_st->targ, value);
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(scmp) {
    sv_setiv(TX_st->targ,
        sv_cmp(TX_ckuuv_lhs(TX_st_sb), TX_ckuuv_rhs(TX_st_sa))
    );
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(range) {
    dSP;
    SV* const lhs = TX_st_sb;
    SV* const rhs = TX_st_sa;
    OP myop;
    Zero(&myop, 1, OP);
    myop.op_ppaddr = PL_ppaddr[OP_FLOP];
    myop.op_type   = OP_FLOP;

    /* call pp_flop() */
    ENTER;
    SAVEOP();
    PL_op = &myop;
    /* set GIMME to G_ARRAY (see op.h) */
    PL_op->op_flags |= OPf_WANT_LIST;
    EXTEND(SP, 2);
    PUSHs(TX_ckuuv_lhs(lhs));
    PUSHs(TX_ckuuv_rhs(rhs));
    PUTBACK;
    myop.op_ppaddr(aTHX);

    LEAVE;
    TX_RETURN_NEXT();
}

TXC_w_key(fetch_symbol) { /* functions, macros, constants */
    SV* const name = TX_op_arg_sv;
    HE* he;

    if((he = hv_fetch_ent(TX_st->symbol, name, FALSE, 0U))) {
        TX_st_sa = HeVAL(he);
    }
    else {
        croak("Undefined symbol %s", tx_neat(aTHX_ name));
    }

    TX_RETURN_NEXT();
}

TXC(funcall) { /* call a function or a macro */
    /* PUSHMARK must be done */
    SV* const proc = TX_st_sa;

    if(tx_sv_is_macro(aTHX_ proc)) {
        tx_macro_enter(aTHX_ TX_st, (AV*)SvRV(proc), TX_st->pc + 1 /* retaddr  */);
    }
    else {
        TX_st_sa = tx_funcall(aTHX_ TX_st, proc, "function call");
        TX_RETURN_NEXT();
    }
}

TXC(macro_end) {
    SV* const retaddr = AvARRAY(TX_current_frame())[TXframe_RETADDR];

    TX_st_sa = tx_mark_raw(aTHX_ TX_st->output);

    tx_pop_frame(aTHX_ TX_st, TRUE);

    TX_RETURN_PC( INT2PTR(tx_pc_t, SvUVX(retaddr)) );
}

TXC_w_key(methodcall_s) {
    TX_st_sa = tx_methodcall(aTHX_ TX_st, TX_op_arg_sv);

    TX_RETURN_NEXT();
}

TXC(make_array) {
    /* PUSHMARK must be done */
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
        /* see 'push' */
        av_push(av, val);
        SvREFCNT_inc_simple_void_NN(val);
    }

    SP = ORIGMARK;
    PUTBACK;

    TX_st_sa = avref;

    TX_RETURN_NEXT();
}

TXC(make_hash) {
    /* PUSHMARK must be done */
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
        /* see 'push' */
        (void)hv_store_ent(hv, key, val, 0U);
        SvREFCNT_inc_simple_void_NN(val);
    }

    SP = ORIGMARK;
    PUTBACK;

    TX_st_sa = hvref;

    TX_RETURN_NEXT();
}

TXC(enter) {
    ENTER;
    SAVETMPS;

    TX_RETURN_NEXT();
}

TXC(leave) {
    FREETMPS;
    LEAVE;

    TX_RETURN_NEXT();
}

TXC_goto(goto) {
    /* To catch SIGALRM and SIGXCPU */
    PERL_ASYNC_CHECK();
    TX_RETURN_PC( TX_op_arg_pc );
}

TXC(vars) {
    TX_st_sa = sv_2mortal(newRV_inc((SV*)TX_st->vars));
    TX_RETURN_NEXT();
}

/* opcode markers (noop) */
TXC_w_sv(depend); /* tell the vm to dependent template files */
TXC_w_key(macro_begin);
TXC_w_sviv(macro_nargs);
TXC_w_sviv(macro_outer);
TXC(set_opinfo);
TXC(super);

/* "end" must be here (the last opcode) */
TXC(end) {
    //assert(TX_st->current_frame == 0);
}

/* vim: set filetype=xs: */
