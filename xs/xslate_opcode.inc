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
    SV* const sv = TX_lvar(SvIVX(TX_op_arg));
    sv_setsv(sv, TX_st_sa);
    TX_st_sa = sv;

    TX_RETURN_NEXT();
}

TXC_w_var(load_lvar) {
    TX_st_sa = TX_lvar_get(SvIVX(TX_op_arg));
    TX_RETURN_NEXT();
}

TXC_w_var(load_lvar_to_sb) {
    TX_st_sb = TX_lvar_get(SvIVX(TX_op_arg));
    TX_RETURN_NEXT();
}

/* local $vars->{$key} = $val */
/* see pp_helem() in pp_hot.c */
TXC_w_key(localize_s) {
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
    TX_st_sa = TX_op_arg;

    TX_RETURN_NEXT();
}

/* the same as literal, but make sure its argument is an integer */
TXC_w_int(literal_i);

TXC_w_key(fetch_s) { /* fetch a field from the top */
    HV* const vars = TX_st->vars;
    HE* const he   = hv_fetch_ent(vars, TX_op_arg, FALSE, 0U);

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
    SV* const key = TX_op_arg;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_RETURN_NEXT();
}

TXC(print) {
    SV* const sv          = TX_st_sa;
    SV* const output      = TX_st->output;

    if(tx_str_is_marked_raw(aTHX_ sv)) {
        if(SvOK(SvRV(sv))) {
            sv_catsv_nomg(output, SvRV(sv));
        }
        else {
            tx_warn(aTHX_ TX_st, "Use of nil to print");
        }
    }
    else if(SvOK(sv)) {
        tx_force_html_escape(aTHX_ sv, output);
    }
    else {
        tx_warn(aTHX_ TX_st, "Use of nil to print");
        /* does nothing */
    }

    TX_RETURN_NEXT();
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
    TX_RETURN_NEXT();
}

TXC_w_sv(print_raw_s) {
    sv_catsv_nomg(TX_st->output, TX_op_arg);

    TX_RETURN_NEXT();
}

TXC(include) {
    tx_state_t* const st = tx_load_template(aTHX_ TX_st->engine, TX_st_sa);

    ENTER;
    tx_execute(aTHX_ st, TX_st->output, TX_st->vars);
    LEAVE;

    TX_RETURN_NEXT();
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

    TX_RETURN_NEXT();
}

TXC_goto(for_iter) {
    SV* const idsv  = TX_st_sa;
    IV  const id    = SvIVX(idsv); /* by literal_i */
    SV* const item  = TX_lvar_get(id+0);
    SV* const i     = TX_lvar_get(id+1);
    SV* const avref = TX_lvar_get(id+2);
    AV* const av    = (AV*)SvRV(avref);

    assert(SvROK(avref));
    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    SvIOK_only(i); /* for $^item */

    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(LIKELY(!SvRMAGICAL(av))) {
        if(++SvIVX(i) <= AvFILLp(av)) {
            sv_setsv(item, AvARRAY(av)[SvIVX(i)]);
            TX_RETURN_NEXT();
        }
    }
    else { /* magical variables */
        if(++SvIVX(i) <= av_len(av)) {
            SV** const itemp = av_fetch(av, SvIVX(i), FALSE);
            sv_setsv(item, itemp ? *itemp : &PL_sv_undef);
            TX_RETURN_NEXT();
        }
    }

    /* the loop finished */
    {
        SV* const nil = &PL_sv_undef;
        sv_setsv(item,  nil);
        sv_setsv(i,     nil);
        sv_setsv(avref, nil);
    }

    TX_RETURN_PC( SvUVX(TX_op_arg) );
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
    sv_setiv(TX_st->targ, SvIVx(TX_st_sb) % SvIVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC_w_sv(concat) {
    SV* const sv = TX_op_arg;
    sv_setsv_nomg(sv, TX_st_sb);
    sv_catsv_nomg(sv, TX_st_sa);

    TX_st_sa = sv;

    TX_RETURN_NEXT();
}

TXC_goto(and) {
    if(sv_true(TX_st_sa)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( SvUVX(TX_op_arg) );
    }
}

TXC_goto(dand) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(SvOK(sv)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( SvUVX(TX_op_arg) );
    }
}

TXC_goto(or) {
    if(!sv_true(TX_st_sa)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( SvUVX(TX_op_arg) );
    }
}

TXC_goto(dor) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        TX_RETURN_NEXT();
    }
    else {
        TX_RETURN_PC( SvUVX(TX_op_arg) );
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

TXC(builtin_html_escape) {
    TX_st_sa = tx_html_escape(aTHX_ TX_st_sa);
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
    TX_st_sa = boolSV( SvNVx(TX_st_sb) <= SvNVx(TX_st_sa) );
    TX_RETURN_NEXT();
}
TXC(gt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) > SvNVx(TX_st_sa) );
    TX_RETURN_NEXT();
}
TXC(ge) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) >= SvNVx(TX_st_sa) );
    TX_RETURN_NEXT();
}

TXC(ncmp) {
    NV const lhs = SvNVx(TX_st_sb);
    NV const rhs = SvNVx(TX_st_sa);
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
        TX_st_sa = &PL_sv_undef;
        TX_RETURN_NEXT();
    }

    sv_setiv(TX_st->targ, value);
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC(scmp) {
    sv_setiv(TX_st->targ, sv_cmp(TX_st_sb, TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_RETURN_NEXT();
}

TXC_w_key(fetch_symbol) { /* functions, macros, constants */
    SV* const name = TX_op_arg;
    HE* he;

    if((he = hv_fetch_ent(TX_st->symbol, name, FALSE, 0U))) {
        TX_st_sa = HeVAL(he);
    }
    else {
        croak("Undefined symbol %s", tx_neat(aTHX_ name));
    }

    TX_RETURN_NEXT();
}

TXC_w_int(macro_end) {
    AV* const oldframe  = TX_current_frame();
    AV* const cframe    = (AV*)AvARRAY(TX_st->frame)[TX_st->current_frame-1]; /* pop frame */
    SV* const retaddr   = AvARRAY(oldframe)[TXframe_RETADDR];
    SV* tmp;

    TX_st->pad = AvARRAY(cframe) + TXframe_START_LVAR; /* switch the pad */

    if(SvIVX(TX_op_arg) > 0) { /* immediate macros; skip to mark as raw */
        sv_setsv(TX_st->targ, TX_st->output);
    }
    else { /* normal macros */
        sv_setsv(TX_st->targ, tx_mark_raw(aTHX_ TX_st->output));
    }
    TX_st_sa = TX_st->targ;

    tmp                               = AvARRAY(oldframe)[TXframe_OUTPUT];
    AvARRAY(oldframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                     = tmp;

    LEAVE; /* to retrieve saved current_frame */
    TX_RETURN_PC( SvUVX(retaddr) );
}

TXC(funcall) { /* call a function or a macro */
    /* PUSHMARK must be done */
    SV* const func = TX_st_sa;

    if(tx_sv_is_macro(aTHX_ func)) {
        AV* const macro = (AV*)SvRV(func);
        tx_macro_enter(aTHX_ TX_st, macro, TX_st->pc + 1 /* retaddr */);
    }
    else {
        TX_st_sa = tx_funcall(aTHX_ TX_st, TX_st_sa, "function call");
        TX_RETURN_NEXT();
    }
}

TXC_w_key(methodcall_s) {
    TX_st_sa = tx_methodcall(aTHX_ TX_st, TX_op_arg);

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
    TX_RETURN_PC( SvUVX(TX_op_arg) );
}

/* opcode markers (noop) */
TXC_w_sv(depend); /* tell the vm to dependent template files */
TXC_w_key(macro_begin);
TXC_w_int(macro_nargs);
TXC_w_int(macro_outer);
TXC(set_opinfo);

/* "end" must be here (the last opcode) */
TXC(end) {
    assert(TX_st->current_frame == 0);
}

