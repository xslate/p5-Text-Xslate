package Text::Xslate::PP::Opcode;

use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(tx_error tx_warn);

use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;
use Text::Xslate::Util qw(p mark_raw unmark_raw html_escape);

use constant TXframe_NAME       => Text::Xslate::PP::TXframe_NAME;
use constant TXframe_OUTPUT     => Text::Xslate::PP::TXframe_OUTPUT;
use constant TXframe_RETADDR    => Text::Xslate::PP::TXframe_RETADDR;
use constant TXframe_START_LVAR => Text::Xslate::PP::TXframe_START_LVAR;

use constant TX_VERBOSE_DEFAULT => Text::Xslate::PP::TX_VERBOSE_DEFAULT;

use constant _FOR_ITEM  => 0;
use constant _FOR_ITER  => 1;
use constant _FOR_ARRAY => 2;

no warnings 'recursion';

our @CARP_NOT = qw(Text::Xslate);


my %html_escape = (
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    "'" => '&apos;',
);
my $html_unsafe_chars = sprintf '[%s]', join '', map { quotemeta } keys %html_escape;

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

{
    package
        Text::Xslate::PP::Opcode::Guard;

    sub DESTROY { $_[0]->() }
}

sub op_localize_s {
    my($st) = @_;
    my $vars   = $st->{vars};
    my $key    = $st->op_arg;
    my $preeminent
               = exists $vars->{$key};
    my $oldval = delete $vars->{$key};
    my $newval = $st->{sa};

    my $cleanup = $preeminent
        ? sub { $vars->{$key} = $oldval; return }
        : sub { delete $vars->{$key};    return };
    push @{ $_[0]->{local_stack} ||= [] },
        bless($cleanup, 'Text::Xslate::PP::Opcode::Guard');

    $vars->{$key} = $newval;

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
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
    my $var = $_[0]->{sb};
    my $key = $_[0]->{sa};
    $_[0]->{sa} = tx_fetch( $_[0], $var, $key );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_fetch_field_s {
    my $var = $_[0]->{sa};
    my $key = $_[0]->op_arg;
    $_[0]->{sa} = tx_fetch( $_[0], $var, $key );
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print {
    my $sv = $_[0]->{sa};

    if ( ref( $sv ) eq 'Text::Xslate::Type::Raw' ) {
        if(defined ${$sv}) {
            $_[0]->{ output } .= ${$sv};
        }
        else {
            tx_warn( $_[0], "Use of nil to print" );
        }
    }
    elsif ( defined $sv ) {
        $sv =~ s/($html_unsafe_chars)/$html_escape{$1}/xmsgeo;
        $_[0]->{ output } .= $sv;
    }
    else {
        tx_warn( $_[0], "Use of nil to print" );
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print_raw {
    if(defined $_[0]->{sa}) {
        $_[0]->{ output } .= $_[0]->{sa};
    }
    else {
        tx_warn( $_[0], "Use of nil to print" );
    }
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_print_raw_s {
    $_[0]->{ output } .= $_[0]->op_arg;
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_include {
    my $st = Text::Xslate::PP::tx_load_template( $_[0]->self, $_[0]->{sa} );

    $_[0]->{ output } .= Text::Xslate::PP::tx_execute( $st, $_[0]->{vars} );

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_for_start {
    my $ar = $_[0]->{sa};
    my $id = $_[0]->op_arg;

    unless ( $ar and ref $ar eq 'ARRAY' ) {
        if ( defined $ar ) {
            tx_error( $_[0], "Iterator variables must be an ARRAY reference, not %s", tx_neat( $ar ) );
        }
        else {
            tx_warn( $_[0], "Use of nil to iterate" );
        }
        $ar = [];
    }

    #tx_access_lvar( $_[0], $id + _FOR_ITEM, undef );
    tx_access_lvar( $_[0], $id + _FOR_ITER, -1 );
    tx_access_lvar( $_[0], $id + _FOR_ARRAY, $ar );

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_for_iter {
    my $id = $_[0]->{sa};
    my $av = tx_access_lvar( $_[0], $id + _FOR_ARRAY );

    if(defined $av) {
        my $i = tx_access_lvar( $_[0], $id + _FOR_ITER );
        $av = [ $av ] unless ref $av;
        if ( ++$i < scalar(@{ $av })  ) {
            tx_access_lvar( $_[0], $id + _FOR_ITEM, $av->[ $i ] );
            tx_access_lvar( $_[0], $id + _FOR_ITER, $i );
            goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
        }
        else {
            tx_access_lvar( $_[0], $id + _FOR_ITEM,  undef );
            tx_access_lvar( $_[0], $id + _FOR_ITER,  undef );
            tx_access_lvar( $_[0], $id + _FOR_ARRAY, undef );
        }
    }

    # finish
    $_[0]->{ pc } = $_[0]->op_arg;
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
    my $sv = $_[0]->op_arg;
    $sv .= $_[0]->{sb} . $_[0]->{sa};
    $_[0]->{sa} = $sv;
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

sub op_builtin_html_escape{
    $_[0]->{sa} = html_escape($_[0]->{sa});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub _sv_eq {
    my($x, $y) = @_;
    if ( defined $x and defined $y ) {
        return $x eq $y;
    }

    if ( defined $x ) {
        return defined $y && $x eq $y;
    }
    else {
        return !defined $y;
    }
}

sub op_eq {
    $_[0]->{sa} =  _sv_eq($_[0]->{sa}, $_[0]->{sb});
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}


sub op_ne {
    $_[0]->{sa} = !_sv_eq($_[0]->{sa}, $_[0]->{sb});
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

sub op_symbol {
    my $name = $_[0]->op_arg;

    if ( my $func = $_[0]->symbol->{ $name } ) {
        $_[0]->{sa} = $func;
    }
    else {
        Carp::croak( sprintf( "Undefined symbol %s", $name ) );
    }

    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
}

sub _do_macrocall {
    my($st, $macro) = @_;
    my $name   = $macro->name;
    my $addr   = $macro->addr;
    my $nargs  = $macro->nargs;
    my $outer  = $macro->outer;
    my $args   = pop @{ $st->{SP} };

    if(@{$args} != $nargs) {
        tx_error($st, "Wrong number of arguments for %s (%d %s %d)",
            $name, scalar(@{$args}), scalar(@{$args}) > $nargs ? '>' : '<', $nargs);
        $st->{ sa } = undef;
        $st->{ pc }++;
        return;
    }

    my $cframe = tx_push_frame( $st );

    $cframe->[ TXframe_RETADDR ] = $st->{ pc } + 1;
    $cframe->[ TXframe_OUTPUT ]  = $st->{ output };
    $cframe->[ TXframe_NAME ]    = $name;

    $_[0]->{ output } = '';

    if($outer > 0) {
        # copies lexical variables from the old frame to the new one
        my $oframe = $_[0]->frame->[ $_[0]->current_frame - 1 ];
        for(my $i = 0; $i < $outer; $i++) {
            my $real_ix = $i + TXframe_START_LVAR;
            $cframe->[$real_ix] = $oframe->[$real_ix];
        }
    }

    my $i  = 0;
    for my $val (@{$args}) {
        tx_access_lvar( $_[0], $i++, $val );
    }

    $_[0]->{ pc } = $addr;
    return;
}

sub op_macro_end {
    my($st) = @_;
    my $frames   = $st->frame;
    my $oldframe = $frames->[ $st->current_frame ];
    my $cframe   = $frames->[ $st->current_frame( $st->current_frame - 1 ) ]; # pop frame

    if($st->op_arg) { # immediate macros
        $st->{targ} = $st->{ output };
    }
    else {
        $st->{targ} = mark_raw( $st->{ output } );
    }

    $st->{sa} = $st->{targ};

    $st->{ output } = $oldframe->[ TXframe_OUTPUT ];
    $st->{ pc }     = $oldframe->[ TXframe_RETADDR ];

    goto $st->{ code }->[ $st->{ pc } ]->{ exec_code };
}

sub op_funcall {
    my $func = $_[0]->{sa};
    if(ref $func eq 'Text::Xslate::PP::Macro') {
        _do_macrocall($_[0], $func);
        goto $_[0]->{ code }->[ $_[0]->{ pc } ]->{ exec_code };
    }
    else {
        my ( @args ) = @{ pop @{ $_[0]->{ SP } } };
        $_[0]->{sa} = tx_call( $_[0], 0, $func, @args );
        goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
    }
}

sub op_methodcall_s {
    require Text::Xslate::PP::Method;
    $_[0]->{sa} = Text::Xslate::PP::Method::tx_methodcall($_[0], $_[0]->op_arg);
    goto $_[0]->{ code }->[ ++$_[0]->{ pc } ]->{ exec_code };
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
    $_[0]->{ pc } = $_[0]->code_len;

    if($_[0]->current_frame != 0) {
        Carp::croak("Oops: broken stack frame:" .  p($_[0]->frame));
    }
    return;
}

sub op_depend; *op_depend = \&op_noop;

sub op_macro_begin; *op_macro_begin = \&op_noop;
sub op_macro_nargs; *op_macro_nargs = \&op_noop;
sub op_macro_outer; *op_macro_outer = \&op_noop;

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

    return $st->frame->[ $st->current_frame( $st->current_frame + 1 ) ] ||= [];
}

sub tx_call {
    my ( $st, $is_method_call, $proc, @args ) = @_;
    my $ret;

    if ( $is_method_call ) { # XXX: fetch() doesn't use methodcall for speed
        my $obj = shift @args;

        unless ( defined $obj ) {
            tx_warn( $st, "Use of nil to invoke method %s", $proc );
        }
        else {
            $ret = eval { $obj->$proc( @args ) };
            #_error( $st, $frame, $line, "%s\t...", $@) if $@;
        }
    }
    else { # function call
        if(!defined $proc) {
            my $c = $st->{code}->[ $st->{pc} - 1 ];
            tx_error( $st, "Undefined function is called%s",
                $c->{ opname } eq 'fetch_s' ? " $c->{arg}()" : ""
            );
        }
        else {
            $ret = eval { $proc->( @args ) };
            tx_error( $st, "%s\t...", $@) if $@;
        }
    }

    return $ret;
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

sub tx_error {
    my ( $st, $fmt, @args ) = @_;
    if( $st->self->{verbose} >= TX_VERBOSE_DEFAULT ) {
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


sub tx_warn {
    my ( $st, $fmt, @args ) = @_;
    if( $st->self->{verbose} > TX_VERBOSE_DEFAULT ) {
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
