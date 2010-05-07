package Text::Xslate::PP::Opcode;

use strict;
use Data::Dumper;
use Carp ();
use Scalar::Util qw( blessed );

our $VERSION = '0.0001';

#
#
#

sub op_noop { # 0
    $_[0]->{ pc }++;
}


sub op_move_to_sb { # 1
    $_[0]->sb( $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_move_from_sb { # 2
    $_[0]->sa( $_[0]->sb );
    $_[0]->{ pc }++;
}


sub op_save_to_lvar { # 3
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    tx_access_lvar( $_[0], $_[0]->pc_arg, $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_load_lvar_to_sb { # 4
    $_[0]->pad( $_[0]->frame->[ $_[0]->current_frame ] );
    $_[0]->sb( tx_access_lvar( $_[0], $_[0]->pc_arg ) );
    $_[0]->{ pc }++;
}


sub op_push { # 5
    push @{ $_[0]->{ SP }->[ -1 ] }, $_[0]->sa;
    $_[0]->{ pc }++;
}


sub op_pop { # 6
    #
    $_[0]->{ pc }++;
}


sub op_pushmark { # 7
    push @{ $_[0]->{ SP } }, [];
    $_[0]->{ pc }++;
}


sub op_nil { # 8
    $_[0]->sa( undef );
    $_[0]->{ pc }++;
}


sub op_literal { # 9
    $_[0]->sa( $_[0]->pc_arg );
    $_[0]->{ pc }++;
}


sub op_literal_i { # 10 = 9
    $_[0]->sa( $_[0]->pc_arg );
    $_[0]->{ pc }++;
}


sub op_fetch_s { # 11
    my $vars = $_[0]->vars;
    my $val  = $vars->{ $_[0]->pc_arg };
    $_[0]->sa( $val );
    $_[0]->{ pc }++;
}


sub op_fetch_lvar { # 12
    my $id     = $_[0]->pc_arg;
    my $cframe = $_[0]->frame->[ $_[0]->current_frame ];

    if ( scalar @{ $cframe } < $id + TXframe_START_LVAR + 1 ) {
        Carp::croak("Too few arguments for %s", $cframe->[ TXframe_NAME ] );
    }

    $_[0]->sa( tx_access_lvar( $_[0], $id ) );
    $_[0]->{ pc }++;
}


sub op_fetch_field { # 13
    my $var = $_[0]->sb;
    my $key = $_[0]->sa;
    $_[0]->sa( tx_fetch( $_[0], $var, $key ) );
    $_[0]->{ pc }++;
}


sub op_fetch_field_s { # 14
    my $var = $_[0]->sa;
    my $key = $_[0]->pc_arg;
    $_[0]->sa( tx_fetch( $_[0], $var, $key ) );
    $_[0]->{ pc }++;
}


sub op_print { # 15
    my $sv = $_[0]->sa;

    $sv = '' unless defined $sv;

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


sub op_print_raw { # 16
    $_[0]->{ output } .= $_[0]->sa;
    $_[0]->{ pc }++;
}


sub op_print_raw_s { # 17
    $_[0]->{ output } .= $_[0]->pc_arg;
    $_[0]->{ pc }++;
}


sub op_include { # 18
    no warnings 'recursion';

    my $st = Text::Xslate::PP::tx_load_template( $_[0]->self, $_[0]->sa );

    Text::Xslate::PP::tx_execute( $st, undef, $_[0]->vars );

    $_[0]->{ output } .= $st->{ output };

    $_[0]->{ pc }++;
}


sub op_for_start { # 19
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


sub op_for_iter { # 20
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


sub op_add { # 21
    $_[0]->targ( $_[0]->sb + $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_sub { # 22
    $_[0]->targ( $_[0]->sb - $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_mul { # 23
    $_[0]->targ( $_[0]->sb * $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_div { # 24
    $_[0]->targ( $_[0]->sb / $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_mod { # 25
    $_[0]->targ( $_[0]->sb % $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_concat { # 26
    my $sv = $_[0]->pc_arg;
    $sv .= $_[0]->sb . $_[0]->sa;
    $_[0]->sa( $sv );
    $_[0]->{ pc }++;
}


sub op_filt { # 27
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


sub op_and { # 28
    if ( $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_dand { #
    if ( defined $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_or { # 29
    if ( ! $_[0]->sa ) {
        $_[0]->{ pc }++;
    }
    else {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
}


sub op_dor { # 30
    my $sv = $_[0]->sa;
    if ( defined $sv ) {
        $_[0]->{ pc } = $_[0]->pc_arg;
    }
    else {
        $_[0]->{ pc }++;
    }

}


sub op_not { # 31
    $_[0]->sa( ! $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_plus { # 32
    $_[0]->targ( + $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_minus { # 33
    $_[0]->targ( - $_[0]->sa );
    $_[0]->sa( $_[0]->targ );
    $_[0]->{ pc }++;
}


sub op_eq { # 34
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


sub op_ne { # 35
    op_eq( $_[0] ); # 後で直す
    $_[0]->sa( ! $_[0]->sa );
}


sub op_lt { # 36
    $_[0]->sa( $_[0]->sb < $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_le { # 37
    $_[0]->sa( $_[0]->sb <= $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_gt { # 38
    $_[0]->sa( $_[0]->sb > $_[0]->sa );
    $_[0]->{ pc }++;
}

sub op_ge { # 39
    $_[0]->sa( $_[0]->sb >= $_[0]->sa );
    $_[0]->{ pc }++;
}


sub op_macrocall { # 40
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


sub op_macro_begin { # 41
    $_[0]->frame->[ $_[0]->current_frame ]->[ TXframe_NAME ] = $_[0]->pc_arg;
    $_[0]->{ pc }++;
}


sub op_macro_end { # 42
    my $oldframe = $_[0]->frame->[ $_[0]->current_frame ];
    my $cframe   = $_[0]->frame->[ $_[0]->current_frame( $_[0]->current_frame - 1 ) ];

    $_[0]->targ( Text::Xslate::PP::escaped_string( $_[0]->{ output } ) );

    $_[0]->sa( $_[0]->targ );

    $_[0]->{ output } = $oldframe->[ TXframe_OUTPUT ];

    $_[0]->{ pc } = $oldframe->[ TXframe_RETADDR ];
}


sub op_macro { # 43
    my $name = $_[0]->pc_arg;

    $_[0]->sa( $_[0]->macro->{ $name } );

    $_[0]->{ pc }++;
}


sub op_function { # 44
    my $name = $_[0]->pc_arg;

    if ( my $func = $_[0]->function->{ $name } ) {
        $_[0]->sa( $func );
    }
    else {
        Carp::croak( sprintf( "Function %s is not registered", $name ) );
    }

    $_[0]->{ pc }++;
}


sub op_funcall { # 45
    my $func = $_[0]->sa;
    my ( @args ) = @{ pop @{ $_[0]->{ SP } } };
    my $ret = eval { $func->( @args ) };
    $_[0]->targ( $ret );
    $_[0]->sa( $ret );
    $_[0]->{ pc }++;
}


sub op_methodcall_s { # 46
    my ( $obj, @args ) = @{ pop @{ $_[0]->{ SP } } };
    my $method = $_[0]->pc_arg;
    my $ret = eval { $obj->$method( @args ) };
    $_[0]->targ( $ret );
    $_[0]->sa( $ret );
    $_[0]->{ pc }++;
}


sub op_goto { # 47
    $_[0]->{ pc } = $_[0]->pc_arg;
}


sub op_depend { # 48
    # = noop
    $_[0]->{ pc }++;
}


sub op_end { # 49
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
        return $var->$key();
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
