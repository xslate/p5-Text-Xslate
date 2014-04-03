package Text::Xslate::PP::Opcode;
use Mouse;
extends qw(Text::Xslate::PP::State);

our $VERSION = '3.2.0';

use Carp ();
use Scalar::Util ();

use Text::Xslate::PP;
use Text::Xslate::PP::Const;
use Text::Xslate::PP::Method;
use Text::Xslate::Util qw(
    p neat
    mark_raw unmark_raw html_escape uri_escape
    $DEBUG
);

use constant _DUMP_PP => scalar($DEBUG =~ /\b dump=pp \b/xms);

no warnings 'recursion';

if(!Text::Xslate::PP::_PP_ERROR_VERBOSE()) {
    our @CARP_NOT = qw(
        Text::Xslate
    );
}
our $_current_frame;


#
#
#

sub op_noop {
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_move_to_sb {
    $_[0]->{sb} = $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_move_from_sb {
    $_[0]->{sa} = $_[0]->{sb};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_save_to_lvar {
    tx_access_lvar( $_[0], $_[0]->op_arg, $_[0]->{sa} );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_load_lvar {
    $_[0]->{sa} = tx_access_lvar( $_[0], $_[0]->op_arg );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_load_lvar_to_sb {
    $_[0]->{sb} = tx_access_lvar( $_[0], $_[0]->op_arg );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_localize_s {
    my($st) = @_;
    my $key    = $st->op_arg;
    my $newval = $st->{sa};
    $st->localize($key, $newval);

    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_localize_vars {
    my($st) = @_;
    my $new_vars = $st->{sa};
    my $old_vars = $st->vars;

    if(ref($new_vars) ne 'HASH') {
        $st->warn(undef, "Variable map must be a HASH reference");
    }

    push @{ $st->{local_stack} }, bless sub {
            $st->vars($old_vars);
            return;
        }, 'Text::Xslate::PP::Guard';

    $st->vars($new_vars);

    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_push {
    push @{ $_[0]->{ SP }->[ -1 ] }, $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_pushmark {
    push @{ $_[0]->{ SP } }, [];
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_nil {
    $_[0]->{sa} = undef;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_vars {
    $_[0]->{sa} = $_[0]->{vars};

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_literal {
    $_[0]->{sa} = $_[0]->op_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_literal_i {
    $_[0]->{sa} = $_[0]->op_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_s {
    $_[0]->{sa} = $_[0]->{vars}->{ $_[0]->op_arg };
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_fetch_field {
    my($st) = @_;
    my $var = $st->{sb};
    my $key = $st->{sa};
    $st->{sa} = $st->fetch($var, $key);
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_fetch_field_s {
    my($st) = @_;
    my $var = $st->{sa};
    my $key = $st->op_arg;
    $st->{sa} = $st->fetch($var, $key);
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_print {
    my($st) = @_;
    $st->print($st->{sa});
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_print_raw {
    my($st) = @_;
    if(defined $st->{sa}) {
        $st->{ output } .= $st->{sa};
    }
    else {
        $st->warn( undef, "Use of nil to print" );
    }
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_print_raw_s {
    $_[0]->{ output } .= $_[0]->op_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_include {
    my($st) = @_;
    my $child = Text::Xslate::PP::tx_load_template( $st->engine, $st->{sa}, 1 );
    $st->push_frame('include', undef);
    my $output = Text::Xslate::PP::tx_execute( $child, $st->{vars} );
    $st->pop_frame(0);
    $st->{output} .= $output;
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_find_file {
    $_[0]->{sa} = eval { $_[0]->engine->find_file($_[0]->{sa}); 1 };
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_suffix {
    $_[0]->{sa} = $_[0]->engine->{suffix};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_for_start {
    my($st) = @_;
    my $id = $st->op_arg;
    my $ar = Text::Xslate::PP::tx_check_itr_ar($st, $st->{sa});

    #tx_access_lvar( $st, $id + TXfor_ITEM, undef );
    tx_access_lvar( $st, $id + TXfor_ITER, -1 );
    tx_access_lvar( $st, $id + TXfor_ARRAY, $ar );

    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_for_iter {
    my($st) = @_;
    my $id = $st->{sa};
    my $av = tx_access_lvar( $st, $id + TXfor_ARRAY );

    if(defined $av) {
        my $i = tx_access_lvar( $st, $id + TXfor_ITER );
        $av = [ $av ] unless ref $av;
        if ( ++$i < scalar(@{ $av })  ) {
            tx_access_lvar( $st, $id + TXfor_ITEM, $av->[ $i ] );
            tx_access_lvar( $st, $id + TXfor_ITER, $i );
            goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
        }
        else {
            # finish the loop
            $st->{sa} = ( $i > 0 ); # for 'for-else' block
            tx_access_lvar( $st, $id + TXfor_ITEM,  undef );
            tx_access_lvar( $st, $id + TXfor_ITER,  undef );
            tx_access_lvar( $st, $id + TXfor_ARRAY, undef );
        }
    }

    # finish
    $st->{ pc } = $st->op_arg;
    goto $st->{ code }->[ $st->{ pc } ]->{ exec_code };
}


sub op_add {
    $_[0]->{sa} = $_[0]->{sb} + $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_sub {
    $_[0]->{sa} = $_[0]->{sb} - $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_mul {
    $_[0]->{sa} = $_[0]->{sb} * $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_div {
    $_[0]->{sa} = $_[0]->{sb} / $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_mod {
    my($st) = @_;
    my $lhs = int $st->{sb};
    my $rhs = int $st->{sa};
    if($rhs == 0) {
        $st->error(undef, "Illegal modulus zero");
        $st->{sa} = 'NaN';
    }
    else {
        $st->{sa} = $lhs % $rhs;
    }
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}


sub op_concat {
    my($st) = @_;
    $st->{sa} = Text::Xslate::PP::tx_concat($st->{sb}, $st->{sa});
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_repeat {
    my($st) = @_;
    $st->{sa} = Text::Xslate::PP::tx_repeat($st->{sb}, $st->{sa});
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_bitor {
    $_[0]->{sa} = int($_[0]->{sb}) | int($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_bitand {
    $_[0]->{sa} = int($_[0]->{sb}) & int($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_bitxor {
    $_[0]->{sa} = int($_[0]->{sb}) ^ int($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_bitneg {
    $_[0]->{sa} = ~int($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}



sub op_and {
    if ( $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->op_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_dand {
    if ( defined $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->op_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_or {
    if ( ! $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->op_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_dor {
    my $sv = $_[0]->{sa};
    if ( defined $sv ) {
        $_[0]->{ pc } = $_[0]->op_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
    else {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }

}

sub op_not {
    $_[0]->{sa} = ! $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_minus {
    $_[0]->{sa} = -$_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_max_index {
    $_[0]->{sa} = scalar(@{ $_[0]->{sa} }) - 1;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_mark_raw {
    $_[0]->{sa} = mark_raw($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_unmark_raw {
    $_[0]->{sa} = unmark_raw($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_html_escape {
    $_[0]->{sa} = html_escape($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_uri_escape {
    $_[0]->{sa} = uri_escape($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_is_array_ref {
    $_[0]->{sa} = Text::Xslate::Util::is_array_ref($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_builtin_is_hash_ref {
    $_[0]->{sa} = Text::Xslate::Util::is_hash_ref($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_is_code_ref {
    $_[0]->{sa} = Text::Xslate::Util::is_code_ref($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_match {
    $_[0]->{sa} = Text::Xslate::PP::tx_match($_[0]->{sb}, $_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_eq {
    $_[0]->{sa} = Text::Xslate::PP::tx_sv_eq($_[0]->{sb}, $_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_ne {
    $_[0]->{sa} = !Text::Xslate::PP::tx_sv_eq($_[0]->{sb}, $_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_lt {
    $_[0]->{sa} = $_[0]->{sb} < $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_le {
    $_[0]->{sa} = $_[0]->{sb} <= $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_gt {
    $_[0]->{sa} = $_[0]->{sb} > $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_ge {
    $_[0]->{sa} = $_[0]->{sb} >= $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_ncmp {
    $_[0]->{sa} = $_[0]->{sb} <=> $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}
sub op_scmp {
    $_[0]->{sa} = $_[0]->{sb} cmp $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_range {
    my($self) = @_;
    push @{ $self->{ SP }->[ -1 ] }, ($self->{sb} .. $self->{sa});
    goto $self->{ code }->[ ++$self->{ pc } ]->{ exec_code };
}

sub op_fetch_symbol {
    my($st) = @_;
    my $name = $st->op_arg;
    $st->{sa} = $st->fetch_symbol($name);

    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub tx_macro_enter {
    my($st, $macro, $retaddr) = @_;
    my $name   = $macro->name;
    my $addr   = $macro->addr;
    my $nargs  = $macro->nargs;
    my $outer  = $macro->outer;
    my $args   = pop @{ $st->{SP} };

    print STDERR " " x $st->current_frame, "tx_macro_enter($name) to $retaddr\n" if _DUMP_PP;

    if(@{$args} != $nargs) {
        $st->error(undef, "Wrong number of arguments for %s (%d %s %d)",
            $name, scalar(@{$args}), scalar(@{$args}) > $nargs ? '>' : '<', $nargs);
        $st->{ sa } = undef;
        $st->{ pc }++;
        return;
    }

    my $cframe = $st->push_frame($name, $retaddr);

    $cframe->[ TXframe_OUTPUT ]  = $st->{ output };

    $st->{ output } = '';

    my $i = 0;
    if($outer > 0) {
        # copies lexical variables from the old frame to the new one
        my $oframe = $st->frame->[ $st->current_frame - 1 ];
        for(; $i < $outer; $i++) {
            my $real_ix = $i + TXframe_START_LVAR;
            $cframe->[$real_ix] = $oframe->[$real_ix];
        }
    }

    for my $val (@{$args}) {
        tx_access_lvar( $st, $i++, $val );
    }

    $st->{ pc } = $addr;
    if($st->{code}->[$addr]->{opname} ne 'macro_begin') {
        Carp::croak("Oops: entering non-macros: ", p($st->{code}->[$addr]));
    }
    return;
}

sub op_macro_end {
    my($st) = @_;

    my $top = $st->frame->[ $st->current_frame ];
    printf STDERR "%stx_macro_end(%s)]\n", ' ' x $st->current_frame - 1, $top->[ TXframe_NAME ] if _DUMP_PP;

    $st->{sa} = mark_raw( $st->{ output } );
    $st->pop_frame(1);

    $st->{ pc } = $top->[ TXframe_RETADDR ];
    goto $st->{ code }->[ $st->{ pc } ]->{ exec_code };
}

sub op_funcall {
    my($st) = @_;
    my $func = $st->{sa};
    if(ref $func eq TXt_MACRO) {
        tx_macro_enter($st, $func, $st->{ pc } + 1);
        goto $st->{ code }->[ $st->{ pc } ]->{ exec_code };
    }
    else {
        $st->{sa} = tx_funcall( $st, $func );
        goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
    }
}

sub op_methodcall_s {
    my($st) = @_;
    $st->{sa} = Text::Xslate::PP::Method::tx_methodcall(
        $st, undef, $st->op_arg, @{ pop @{ $st->{SP} } });
    goto $st->{ code }->[ ++$st->{ pc } ]->{ exec_code };
}

sub op_make_array {
    my $args = pop @{ $_[0]->{SP} };
    $_[0]->{sa} = $args;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_make_hash {
    my $args = pop @{ $_[0]->{SP} };
    $_[0]->{sa} = { @{$args} };
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_merge_hash {
    $_[0]->{sa} = Text::Xslate::Util::merge_hash($_[0]->{sa}, $_[0]->{sb});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_enter {
    push @{$_[0]->{save_local_stack} ||= []}, delete $_[0]->{local_stack};

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_leave {
    $_[0]->{local_stack} = pop @{$_[0]->{save_local_stack}};

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub op_goto {
    $_[0]->{ pc } = $_[0]->op_arg;
    goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
}

sub op_end {
    my($st) = @_;
    printf STDERR "op_end at %d\n", $st->{pc} if _DUMP_PP;
    $st->{ pc } = $st->code_len;

    if($st->current_frame != 0) {
        #Carp::croak("Oops: broken stack frame:" .  p($st->frame));
    }
    return;
}

sub op_depend;      *op_depend      = \&op_noop;
sub op_macro_begin; *op_macro_begin = \&op_noop;
sub op_macro_nargs; *op_macro_nargs = \&op_noop;
sub op_macro_outer; *op_macro_outer = \&op_noop;
sub op_set_opinfo;  *op_set_opinfo  = \&op_noop;
sub op_super;       *op_super       = \&op_noop;

#
# INTERNAL COMMON FUNCTIONS
#

sub tx_access_lvar {
    return $_[0]->pad->[ $_[1] + TXframe_START_LVAR ] if @_ == 2;
    $_[0]->pad->[ $_[1] + TXframe_START_LVAR ] = $_[2];
}


sub tx_funcall {
    my ( $st, $proc ) = @_;
    my ( @args ) = @{ pop @{ $st->{ SP } } };
    my $ret;

    if(!defined $proc) {
        my $c = $st->{code}->[ $st->{pc} - 1 ];
        $st->error( undef, "Undefined function%s is called",
            $c->{ opname } eq 'fetch_s' ? " $c->{arg}()" : ""
        );
    }
    else {
        $ret = eval { $proc->( @args ) };
        $st->error( undef, "%s", $@) if $@;
    }

    return $ret;
}

sub proccall {
    my($st, $proc) = @_;
    if(ref $proc eq TXt_MACRO) {
        local $st->{pc} = $st->{pc};
        tx_macro_enter($st, $proc, $st->{code_len});
        $st->{code}->[ $st->{pc} ]->{ exec_code }->( $st );
        return $st->{sa};
    }
    else {
        return tx_funcall($st, $proc);
    }
}

no Mouse;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::PP::Opcode - Text::Xslate opcode implementation in pure Perl

=head1 DESCRIPTION

This module is a pure Perl implementation of the Xslate opcodes.

The is enabled with C<< $ENV{ENV}='pp=opcode' >>.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
