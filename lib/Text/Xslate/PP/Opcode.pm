package Text::Xslate::PP::Opcode;

use strict;
use Data::Dumper;
use Carp ();
use Scalar::Util qw( blessed );

our $VERSION = '0.0001';

#
#
#

sub op_noop {
    $_[0]->{ pc }++;
}


sub op_move_to_sb {
    $_[0]->sb( $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_move_from_sb {
    $_[0]->sa( $_[0]->sb );
    $_[0]->{ pc }++;
}


sub op_save_to_lvar {
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    tx_access_lvar( $_[0], $_[0]->pc_arg, $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_load_lvar_to_sb {
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    $_[0]->sb( tx_access_lvar( $_[0], $_[0]->pc_arg ) );
    $_[0]->{ pc }++;
}


sub op_push {
    push @{ $_[0]->{ SP }->[ -1 ] }, $_[0]->sa;
    $_[0]->{ pc }++;
}


sub op_pop {
    #
    $_[0]->{ pc }++;
}


sub op_pushmark {
    push @{ $_[0]->{ SP } }, [];
    $_[0]->{ pc }++;
}


sub op_nil {
    $_[0]->sa( undef );
    $_[0]->{ pc }++;
}


sub op_literal {
    $_[0]->sa( $_[0]->pc_arg );
    $_[0]->{ pc }++;
}


sub op_literal_i {
    $_[0]->sa( $_[0]->pc_arg );
    $_[0]->{ pc }++;
}


sub op_fetch_s {
    my $vars = $_[0]->vars;
    my $val  = $vars->{ $_[0]->pc_arg };
    $_[0]->sa( $val );
    $_[0]->{ pc }++;
}


sub op_fetch_lvar {
    my $id     = $_[0]->pc_arg;
    my $cframe = $_[0]->frame->[ $_[0]->current_frame ];

    if ( scalar @{ $cframe } < $id + TXframe_START_LVAR + 1 ) {
        Carp::croak("Too few arguments for %s", $cframe->[ TXframe_NAME ] );
    }

    $_[0]->sa( tx_access_lvar( $_[0], $id ) );
    $_[0]->{ pc }++;
}


sub op_fetch_field {
    my $var = $_[0]->sb;
    my $key = $_[0]->sa;
    $_[0]->sa( tx_fetch( $_[0], $var, $key ) );
    $_[0]->{ pc }++;
}


sub op_fetch_field_s {
    my $var = $_[0]->sa;
    my $key = $_[0]->pc_arg;
    $_[0]->sa( tx_fetch( $_[0], $var, $key ) );
    $_[0]->{ pc }++;
}


sub op_print {
    my $sv = $_[0]->sa;

#    $sv = '' unless defined $sv;

    unless ( defined $sv ) {
        Carp::croak( 'Use of uninitialized value in subroutine entry' );
    }

    if ( blessed( $sv ) and $sv->isa('Text::Xslate::EscapedString') ) {
        $_[0]->{ output } .= $sv;
    }
    else {
        # 置換
        $sv =~ s/&/&amp;/g;
        $sv =~ s/</&lt;/g;
        $sv =~ s/>/&gt;/g;
        $sv =~ s/"/&quot;/g;
        $sv =~ s/'/&#39;/g;

        $_[0]->{ output } .= $sv;
    }

    $_[0]->{ pc }++;
}


sub op_print_raw {
    $_[0]->{ output } .= $_[0]->sa;
    $_[0]->{ pc }++;
}


sub op_print_raw_s {
    $_[0]->{ output } .= $_[0]->pc_arg;
    $_[0]->{ pc }++;
}


sub op_include {
    no warnings 'recursion';

    my $st = Text::Xslate::PP::tx_load_template( $_[0]->self, $_[0]->sa );

    Text::Xslate::PP::tx_execute( $st, undef, $_[0]->vars );

    $_[0]->{ output } .= $st->{ output };

    $_[0]->{ pc }++;
}


sub op_for_start {
    my $ar = $_[0]->sa;
    my $id = $_[0]->pc_arg;

    unless ( $ar and ref $ar eq 'ARRAY' ) { # magicについては後で
        Carp::croak(
            sprintf( "Iterator variables must be an ARRAY reference, not %s", $ar )
        );
    }

    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );

    tx_access_lvar( $_[0], $id + 1, $ar );
    tx_access_lvar( $_[0], $id + 2, -1 );

    $_[0]->{ pc }++;
}


sub op_for_iter {
    my $id = $_[0]->sa;
    my $av = tx_access_lvar( $_[0], $id + 1 );
    my $i  = tx_access_lvar( $_[0], $id + 2 );

    $av = [ $av ] unless ref $av;

    if ( ++$i <= $#{ $av } ) {
        tx_access_lvar( $_[0], $id     => $av->[ $i ] );
        tx_access_lvar( $_[0], $id + 2 => $i );
        $_[0]->{ pc }++;
        return;
    }

    $_[0]->{ pc } = $_[0]->pc_arg;
}


sub op_add {
    $_[0]->targ( $_[0]->sb + $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_sub {
    $_[0]->targ( $_[0]->sb - $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_mul {
    $_[0]->targ( $_[0]->sb * $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_div {
    $_[0]->targ( $_[0]->sb / $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_mod {
    $_[0]->targ( $_[0]->sb % $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_concat {
    my $sv = $_[0]->pc_arg;
    $sv .= $_[0]->sb . $_[0]->sa;
    $_[0]->sa( $sv );
    $_[0]->{ pc }++;
}


sub op_filt {
    my $arg    = $_[0]->sb;
    my $filter = $_[0]->sa;

    local $@;

    my $ret = eval { $filter->( $arg ) };

    if ( $@ ) {
        Carp::croak( sprintf("%s\n\t... exception cought on %s", $@, 'filtering') );
    }

    $_[0]->targ( $ret );
    $_[0]->sa( $ret );
    $_[0]->{ pc }++;
}


sub op_and {
    if ( $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_dand {
    if ( defined $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_or {
    if ( ! $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_dor {
    my $sv = $_[0]->sa;
    if ( defined $sv ) {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
    else {
        $_[0]->{ pc }++;
    }

}


sub op_not {
    $_[0]->sa( ! $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_plus {
    $_[0]->targ( + $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_minus {
    $_[0]->targ( - $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_eq {
    my $aval = $_[0]->sa;
    my $bval = $_[0]->sb;

    if ( defined $aval and defined $bval ) {
        # SVf_IOKかどうかのチェック
        $_[0]->sa( $aval eq $bval );
    }

    if ( defined $aval ) {
        $_[0]->sa( defined $bval && $aval eq $bval  );
    }
    else {
        $_[0]->sa( !defined $bval );
    }

    $_[0]->{ pc }++;
}


sub op_ne {
    op_eq( $_[0] ); # 後で直す
    $_[0]->sa( ! $_[0]->sa );
}


sub op_lt {
    $_[0]->sa( $_[0]->sb < $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_le {
    $_[0]->sa( $_[0]->sb <= $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_gt {
    $_[0]->sa( $_[0]->sb > $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_ge {
    $_[0]->sa( $_[0]->sb >= $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_macrocall {
    my $addr   = $_[0]->sa; # macro rentry point
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
}


sub op_macro_begin {
    $_[0]->frame->[ $_[0]->current_frame ]->[ TXframe_NAME ] = $_[0]->pc_arg;
    $_[0]->{ pc }++;
}


sub op_macro_end {
    my $oldframe = $_[0]->frame->[ $_[0]->current_frame ];
    my $cframe   = $_[0]->frame->[ $_[0]->current_frame( $_[0]->current_frame - 1 ) ];

    $_[0]->targ( Text::Xslate::PP::escaped_string( $_[0]->{ output } ) );

    $_[0]->sa( $_[0]->targ );

    $_[0]->{ output } = $oldframe->[ TXframe_OUTPUT ];

    $_[0]->{ pc } = $oldframe->[ TXframe_RETADDR ];
}


sub op_macro {
    my $name = $_[0]->pc_arg;

    $_[0]->sa( $_[0]->macro->{ $name } );

    $_[0]->{ pc }++;
}


sub op_function {
    my $name = $_[0]->pc_arg;

    if ( my $func = $_[0]->function->{ $name } ) {
        $_[0]->sa( $func );
    }
    else {
        Carp::croak( sprintf( "Function %s is not registered", $name ) );
    }

    $_[0]->{ pc }++;
}


sub op_funcall {
    my $func = $_[0]->sa;
    my ( @args ) = @{ pop @{ $_[0]->{ SP } } };
    my $ret = eval { $func->( @args ) };
    $_[0]->targ( $ret );
    $_[0]->sa( $ret );
    $_[0]->{ pc }++;
}


sub op_methodcall_s {
    my ( $obj, @args ) = @{ pop @{ $_[0]->{ SP } } };
    my $method = $_[0]->pc_arg;
    my $ret = eval { $obj->$method( @args ) };
    $_[0]->targ( $ret );
    $_[0]->sa( $ret );
    $_[0]->{ pc }++;
}


sub op_goto {
    $_[0]->{ pc } = $_[0]->pc_arg;
}


sub op_depend {
    # = noop
    $_[0]->{ pc }++;
}


sub op_end {
    $_[0]->{ pc } = $_[0]->code_len;
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

    $st->frame->[ $st->current_frame ] = [];

    $st->pad( $st->frame->[ $st->current_frame ] );

    $st->frame->[ $st->current_frame ];
}


sub tx_fetch {
    my ( $st, $var, $key ) = @_;

    if ( blessed $var ) {
        local $SIG{__DIE__}; # oops
        my $ret = eval q{ $var->$key() };
        return $ret;
    }
    elsif ( ref $var eq 'HASH' ) {
        return $var->{ $key };
    }
    elsif ( ref $var eq 'ARRAY' ) {
        return $var->[ $key ];
    }
    else {
        Carp::croak( sprintf( "Cannot access '%s' (%s is not a container)" ), $key, $var );
    }

}


1;
__END__
