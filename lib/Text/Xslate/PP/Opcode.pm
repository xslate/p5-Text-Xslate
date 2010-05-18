package Text::Xslate::PP::Opcode;

use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(tx_error tx_warn);

use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;

no warnings 'recursion';

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
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    tx_access_lvar( $_[0], $_[0]->pc_arg, $_[0]->{sa} );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_load_lvar_to_sb {
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    $_[0]->{sb} = tx_access_lvar( $_[0], $_[0]->pc_arg );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_push {
    push @{ $_[0]->{ SP }->[ -1 ] }, $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_pop {
    #
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


sub op_literal {
    $_[0]->{sa} = $_[0]->pc_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_literal_i {
    $_[0]->{sa} = $_[0]->pc_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_s {
    $_[0]->{sa} = $_[0]->{vars}->{ $_[0]->pc_arg };
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_lvar {
    my $id     = $_[0]->pc_arg;
    my $cframe = $_[0]->frame->[ $_[0]->current_frame ];

    if ( scalar @{ $cframe } < $id + TXframe_START_LVAR + 1 ) {
        tx_error( $_[0], "Too few arguments for %s", $cframe->[ TXframe_NAME ] );
        $_[0]->{sa} = undef;
    }
    else {
        $_[0]->{sa} = tx_access_lvar( $_[0], $id );
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_field {
    my $var = $_[0]->{sb};
    my $key = $_[0]->{sa};
    $_[0]->{sa} = tx_fetch( $_[0], $var, $key );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_field_s {
    my $var = $_[0]->{sa};
    my $key = $_[0]->pc_arg;
    $_[0]->{sa} = tx_fetch( $_[0], $var, $key );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print {
    my $sv = $_[0]->{sa};

    if ( Scalar::Util::blessed( $sv ) and $sv->isa('Text::Xslate::EscapedString') ) {
        $_[0]->{ output } .= $sv;
    }
    elsif ( defined $sv ) {
        if ( $sv =~ /[&<>"']/ ) {
            $sv =~ s/&/&amp;/g;
            $sv =~ s/</&lt;/g;
            $sv =~ s/>/&gt;/g;
            $sv =~ s/"/&quot;/g;
            $sv =~ s/'/&#39;/g; # ' for poor editors
        }
        $_[0]->{ output } .= $sv;
    }
    else {
        tx_warn( $_[0], "Use of nil to printed" );
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print_raw {
    $_[0]->{ output } .= $_[0]->{sa};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print_raw_s {
    $_[0]->{ output } .= $_[0]->pc_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_include {
    my $st = Text::Xslate::PP::tx_load_template( $_[0]->self, $_[0]->{sa} );

    Text::Xslate::PP::tx_execute( $st, undef, $_[0]->{vars} );

    $_[0]->{ output } .= $st->{ output };

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_for_start {
    my $ar = $_[0]->{sa};
    my $id = $_[0]->pc_arg;

    unless ( $ar and ref $ar eq 'ARRAY' ) {
        if ( defined $ar ) {
            tx_error( $_[0], "Iterator variables must be an ARRAY reference, not %s", tx_neat( $ar ) );
        }
        else {
            tx_warn( $_[0], "Use of nil to iterate" );
        }
        $ar = [];
    }

    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );

    tx_access_lvar( $_[0], $id + 1, $ar );
    tx_access_lvar( $_[0], $id + 2, -1 );

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_for_iter {
    my $id = $_[0]->{sa};
    my $av = tx_access_lvar( $_[0], $id + 1 );
    my $i  = tx_access_lvar( $_[0], $id + 2 );

    $av = [ $av ] unless ref $av;

    if ( ++$i <= $#{ $av } ) {
        tx_access_lvar( $_[0], $id     => $av->[ $i ] );
        tx_access_lvar( $_[0], $id + 2 => $i );
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }

    $_[0]->{ pc } = $_[0]->pc_arg;
    goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
}


sub op_add {
    $_[0]->{targ} = $_[0]->{sb} + $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_sub {
    $_[0]->{targ} = $_[0]->{sb} - $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_mul {
    $_[0]->{targ} = $_[0]->{sb} * $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_div {
    $_[0]->{targ} = $_[0]->{sb} / $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_mod {
    $_[0]->{targ} = $_[0]->{sb} % $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_concat {
    my $sv = $_[0]->pc_arg;
    $sv .= $_[0]->{sb} . $_[0]->{sa};
    $_[0]->{sa} = $sv;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_filt {
    my $arg    = $_[0]->{sb};
    my $filter = $_[0]->{sa};

    local $@;

    my $ret = eval { $filter->( $arg ) };

    if ( $@ ) {
        Carp::croak( sprintf("%s\n\t... exception cought on %s", $@, 'filtering') );
    }

    $_[0]->{sa} = $ret;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_and {
    if ( $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_dand {
    if ( defined $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_or {
    if ( ! $_[0]->{sa} ) {
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
}


sub op_dor {
    my $sv = $_[0]->{sa};
    if ( defined $sv ) {
        $_[0]->{ pc } = $_[0]->pc_arg;
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


sub op_plus {
    $_[0]->{targ} = + $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_minus {
    $_[0]->{targ} = - $_[0]->{sa};
    $_[0]->{sa} = $_[0]->{targ};
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_eq {
    my $aval = $_[0]->{sa};
    my $bval = $_[0]->{sb};

    if ( defined $aval and defined $bval ) {
        # SVf_IOKかどうかのチェック
        $_[0]->{sa} = $aval eq $bval;
    }

    if ( defined $aval ) {
        $_[0]->{sa} = defined $bval && $aval eq $bval;
    }
    else {
        $_[0]->{sa} = !defined $bval;
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_ne {
    my $aval = $_[0]->{sa};
    my $bval = $_[0]->{sb};

    if ( defined $aval and defined $bval ) {
        # SVf_IOKかどうかのチェック
        $_[0]->{sa} = $aval eq $bval;
    }

    if ( defined $aval ) {
        $_[0]->{sa} = defined $bval && $aval eq $bval;
    }
    else {
        $_[0]->{sa} = !defined $bval;
    }

    $_[0]->{sa} = ! $_[0]->{sa};

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


sub op_macrocall {
    my $addr   = $_[0]->{sa}; # macro entry point
    my $cframe = tx_push_frame( $_[0] );

    $cframe->[ TXframe_RETADDR ] = $_[0]->{ pc } + 1;

    $cframe->[ TXframe_OUTPUT ] = $_[0]->{ output };

    $_[0]->{ output } = '';

    my $i   = 0;

    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );

    for my $val ( @{ pop @{ $_[0]->{ SP } } } ) {
        tx_access_lvar( $_[0], $i++, $val );
    }

    $_[0]->{ pc } = $addr;
    goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
}


sub op_macro_begin {
    $_[0]->frame->[ $_[0]->current_frame ]->[ TXframe_NAME ] = $_[0]->pc_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_macro_end {
    my $oldframe = $_[0]->frame->[ $_[0]->current_frame ];
    my $cframe   = $_[0]->frame->[ $_[0]->current_frame( $_[0]->current_frame - 1 ) ];

    $_[0]->{targ} = Text::Xslate::PP::escaped_string( $_[0]->{ output } );

    $_[0]->{sa} = $_[0]->{targ};

    $_[0]->{ output } = $oldframe->[ TXframe_OUTPUT ];

    $_[0]->{ pc } = $oldframe->[ TXframe_RETADDR ];

    goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
}


sub op_macro {
    my $name = $_[0]->pc_arg;

    $_[0]->{sa} = $_[0]->macro->{ $name };

    unless ( defined $_[0]->{sa} ) {
        croak("Macro %s is not defined", tx_neat(aTHX_ name));
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_function {
    my $name = $_[0]->pc_arg;

    if ( my $func = $_[0]->function->{ $name } ) {
        $_[0]->{sa} = $func;
    }
    else {
        Carp::croak( sprintf( "Function %s is not registered", $name ) );
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_funcall {
    my $func = $_[0]->{sa};
    my ( @args ) = @{ pop @{ $_[0]->{ SP } } };
    my $ret = tx_call( $_[0], 0, $func, @args );
    $_[0]->{targ} = $ret;
    $_[0]->{sa} = $ret;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_methodcall_s {
    require Text::Xslate::PP::Method;
    $_[0]->{sa} = Text::Xslate::PP::Method::tx_methodcall($_[0], $_[0]->pc_arg);
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_goto {
    $_[0]->{ pc } = $_[0]->pc_arg;
    goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
}


sub op_depend {
    # = noop
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_end {
    $_[0]->{ pc } = $_[0]->code_len;
    return;
}


#
# INTERNAL COMMON FUNCTIONS
#

sub tx_access_lvar {
    return $_[0]->pad->[ $_[1] + TXframe_START_LVAR ] if @_ == 2;
    $_[0]->pad->[ $_[1] + TXframe_START_LVAR ] = $_[2];
}


sub tx_push_frame {
    my ( $st ) = @_;

    if ( $st->current_frame > 100 ) {
        Carp::croak("Macro call is too deep (> 100)");
    }

    $st->current_frame( $st->current_frame + 1 );

    $st->frame->[ $st->current_frame ] ||= [];

    $st->pad( $st->frame->[ $st->current_frame ] );

    $st->frame->[ $st->current_frame ];
}


sub tx_call {
    my ( $st, $flag, $proc, @args ) = @_;
    my $obj = shift @args if ( $flag );
    my $ret;

    if ( $flag ) { # method call
        unless ( defined $obj ) {
            tx_warn( $st, "Use of nil to invoke method %s", $proc );
        }
        else {
            local $SIG{__DIE__}; # oops
            local $SIG{__WARN__};
            $ret = eval { $obj->$proc( @args ) };
        }
    }
    else { # function call
            local $SIG{__DIE__}; # oops
            local $SIG{__WARN__};
            $ret = eval { $proc->( @args ) };
    }

    $ret;
}


sub tx_fetch {
    my ( $st, $var, $key ) = @_;
    my $ret;

    if ( Scalar::Util::blessed($var) ) {
        $ret = tx_call( $st, 1, $key, $var );
    }
    elsif ( ref $var eq 'HASH' ) {
        if ( defined $key ) {
            $ret = $var->{ $key };
        }
        else {
            tx_warn( $st, "Use of nil as a field key" );
        }
    }
    elsif ( ref $var eq 'ARRAY' ) {
        if ( Scalar::Util::looks_like_number($key) ) {
            $ret = $var->[ $key ];
        }
        else {
            tx_warn( $st, "Use of %s as an array index", tx_neat( $key ) );
        }
    }
    elsif ( $var ) {
        tx_error( $st, "Cannot access %s (%s is not a container)", tx_neat($key), tx_neat($var) );
    }
    else {
        tx_warn( $st, "Use of nil to access %s", tx_neat( $key ) );
    }

    return $ret;
}


sub tx_verbose {
    my $v = $_[0]->self->{ verbose };
    defined $v ? $v : TX_VERBOSE_DEFAULT;
}


sub tx_error {
    my ( $st, $fmt, @args ) = @_;
    if( tx_verbose( $st ) >= TX_VERBOSE_DEFAULT ) {
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


sub tx_warn {
    my ( $st, $fmt, @args ) = @_;
    if( tx_verbose( $st ) > TX_VERBOSE_DEFAULT ) {
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


sub tx_neat {
    my($s) = @_;
    if ( defined $s ) {
        if ( ref($s) || Scalar::Util::looks_like_number($s) ) {
            return $s;
        }
        else {
            return "'$s'";
        }
    }
    else {
        return 'nil';
    }
}


1;
__END__

=head1 NAME

Text::Xslate::PP::Opcode - Text::Xslate opcodes in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

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
