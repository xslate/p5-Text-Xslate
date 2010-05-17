package Text::Xslate::PP::Booster;

use Mouse;
#use strict;
use Data::Dumper;
use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;

our $VERSION = '0.0001';

my %CODE_MANIP = ();
my $TX_OPS = \%Text::Xslate::OPS;


has indent_depth => ( is => 'rw', default => 1 );

has indent_space => ( is => 'rw', default => '    ' );

has lines => ( is => 'rw', default => sub { []; } );

has ops => ( is => 'rw', default => sub { []; } );

has current_line => ( is => 'rw', default => 0 );

has rvalue => ( is => 'rw', default => sub { []; } );

has lvalue => ( is => 'rw', default => sub { []; } );

has exprs => ( is => 'rw' );

has sa => ( is => 'rw' );

has sb => ( is => 'rw' );

has lvar => ( is => 'rw', default => sub { []; } );

#
# public APIs
#

sub opcode2perlcode_str {
    my ( $class, $proto ) = @_;
    my $len = scalar( @$proto );
    my @lines;

    my $state = $class->new(
        ops => $proto,
    );

    # コード生成
    my $i = 0;

    while ( $state->current_line < $len ) {
        my $pair = $proto->[ $i ];

        unless ( $pair and ref $pair eq 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$pair;
        my $opnum = $TX_OPS->{ $opname };

        unless ( $CODE_MANIP{ $opname } ) {
            Carp::croak( sprintf( "Oops: opcode '%s' is not yet implemented on Booster", $opname ) );
        }

        my $manip  = $CODE_MANIP{ $opname };

        if ( my $proc = $state->{ proc }->{ $i } ) {

            if ( $proc->{ skip } ) {
                $state->current_line( ++$i );
                next;
            }

            while ( $proc->{ else_end  }-- ) { # elseブロックの閉じ
                $state->indent_depth( $state->indent_depth - 1 );
                $state->write_lines( "}\n" );
                $state->write_code( "\n" );
            }
        }

        $manip->( $state, $arg, defined $line ? $line : '' );

        $state->current_line( ++$i );
    }

    # 書き出し

    my $perlcode =<<'CODE';
sub {
    my ( $st ) = $_[0];
    my ( $sa, $sb, $sv, $targ, $st2, $pad, @sp );
    my $output = '';
    my $vars  = $st->{ vars };

    $pad = [ [ ] ];

CODE

    if ( $state->{ macro_lines } ) {
        $perlcode .=<<'CODE';
    # macro
CODE

        $perlcode .= join ( '', grep { defined } @{ $state->{ macro_lines } } );
    }

    $perlcode .=<<'CODE';

    # process start

CODE

    $perlcode .= join( '', grep { defined } @{ $state->{lines} } );


$perlcode .=<<'CODE';
    $st->{ output } = $output;
}
CODE

    return $perlcode;
}


sub opcode2perlcode {
    my ( $class, $proto, $codes ) = @_;

    my $perlcode = opcode2perlcode_str( @_ );

    # TEST
    print "$perlcode\n" if $ENV{ BOOST_DISP };

    my $evaled_code = eval $perlcode;

    die $@ unless $evaled_code;

    return $evaled_code;
}


#
#
#

$CODE_MANIP{ 'noop' } = sub {
};


$CODE_MANIP{ 'move_to_sb' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sb( $state->sa );
};


$CODE_MANIP{ 'move_from_sb' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( $state->sb );
};


$CODE_MANIP{ 'save_to_lvar' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $v = sprintf( '( $pad->[ -1 ]->[ %s ] = %s )', $arg, $state->sa );
    $state->sa( $v );
    #$state->lvar->[ $arg ] = $state->sa;
    $state->lvar->[ $arg ] = $v;
};


$CODE_MANIP{ 'load_lvar_to_sb' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sb( $state->lvar->[ $arg ] );
};


$CODE_MANIP{ 'push' } = sub { # not yet implemeted
    my ( $state, $arg, $line ) = @_;
    $state->write_lines( sprintf( 'push @{ $sp[-1] }, %s;', $state->sa() ) );
};


$CODE_MANIP{ 'pushmark' } = sub { # not yet implemeted
    my ( $state, $arg, $line ) = @_;
    $state->write_lines( 'push @sp, [];' );
};


$CODE_MANIP{ 'nil' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( 'undef' );
};


$CODE_MANIP{ 'literal' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( '"' . escape( $arg ) . '"' );
};


$CODE_MANIP{ 'literal_i' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( $arg );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'fetch_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '$vars->{ "%s" }', escape( $arg ) ) );
};


$CODE_MANIP{ 'fetch_lvar' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '$pad->[ -1 ]->[ %s ]', $arg ) );
};


$CODE_MANIP{ 'fetch_field' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( 'fetch( $st, %s, %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'fetch_field_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $sv = $state->sa();
    $state->sa( sprintf( 'fetch( $st, %s, "%s" )', $sv, escape( $arg ) ) );
};


$CODE_MANIP{ 'print_raw' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $sv = $state->sa();
    $state->write_lines( sprintf('$output .= %s;', $sv) );
    $state->write_code( "\n" );
};


$CODE_MANIP{ 'print_raw_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->write_lines( sprintf('$output .= "%s";', escape( $arg ) ) );
    $state->write_code( "\n" );
};


$CODE_MANIP{ 'print' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $sv = $state->sa();

    $state->write_lines( sprintf( <<'CODE', $sv) );
$sv = %s;

if ( Scalar::Util::blessed( $sv ) and $sv->isa('Text::Xslate::EscapedString') ) {
    $output .= $sv;
}
elsif ( defined $sv ) {
    if ( $sv =~ /[&<>"']/ ) {
        $sv =~ s/&/&amp;/g;
        $sv =~ s/</&lt;/g;
        $sv =~ s/>/&gt;/g;
        $sv =~ s/"/&quot;/g;
        $sv =~ s/'/&#39;/g;
    }
    $output .= $sv;
}
else {
    warn_in_booster( $st, "Use of nil to be printed" );
}
CODE

    $state->write_code( "\n" );
};


$CODE_MANIP{ 'include' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->write_lines( sprintf( <<'CODE', $state->sa ) );
$st2 = Text::Xslate::PP::tx_load_template( $st->self, %s );
Text::Xslate::PP::tx_execute( $st2, undef, $vars );
$output .= $st2->{ output };

CODE

};


$CODE_MANIP{ 'for_start' } = sub {
    my ( $state, $arg, $line ) = @_;

    push @{ $state->{ for_level } }, {
        stack_id => $arg,
        ar       => $state->sa,
    };
};


$CODE_MANIP{ 'for_iter' } = sub {
    my ( $state, $arg, $line ) = @_;

    $state->{ loop }->{ $state->current_line } = 1; # marked

    my $stack_id = $state->{ for_level }->[ -1 ]->{ stack_id };
    my $ar       = $state->{ for_level }->[ -1 ]->{ ar };

    $state->write_lines( sprintf( 'for ( @{ %s } ) {', $ar ) );
    $state->write_code( "\n" );

    $state->indent_depth( $state->indent_depth + 1 );

    $state->write_lines( sprintf( '$pad->[ -1 ]->[ %s ] = $_;', $state->sa() ) );
    $state->write_code( "\n" );
};


$CODE_MANIP{ 'add' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s + %s )', $state->sb(), $state->sa() ) );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'sub' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s - %s )', $state->sb(), $state->sa() ) );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'mul' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s * %s )', $state->sb(), $state->sa() ) );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'div' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s / %s )', $state->sb(), $state->sa() ) );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'mod' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s %% %s )', $state->sb(), $state->sa() ) );
    $state->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'concat' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s . %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'filt' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $i = $state->{ i };
    my $ops = $state->{ ops };

    $state->sa( sprintf('eval { $sa->( %s ) };', $state->sb ) );
};


$CODE_MANIP{ 'and' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $ops  = $state->ops;
    my $i    = $state->current_line;
    my $expr = $state->sa();

    if ( $ops->[ $i + $arg - 1 ]->[ 0 ] eq 'goto' ) { # if cond
        $expr = ($state->exprs || '') . $expr; # 前に式があれば加える
        $state->write_lines( sprintf( <<'CODE' , $expr ) );
if ( %s ) {

CODE

        $state->exprs( '' );
        $state->indent_depth( $state->indent_depth + 1 ); # ブロック内
        $state->{ if_end }->{ $i + $arg - 1 }++; # block end
    }
    else { # ternary
        my $pre_exprs = $state->exprs || '';
        $state->exprs( $pre_exprs . $expr . ' && ' ); # 保存
    }

};



$CODE_MANIP{ 'dand' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $ops  = $state->ops;
    my $i    = $state->current_line;
    my $expr = $state->sa();

    if ( $ops->[ $i + $arg - 1 ]->[ 0 ] eq 'goto' ) { # cond
        my $cond = $ops->[ $i + $arg - 1 ]->[ 1 ] < 0 ? 'while' : 'if';

        $expr = ($state->exprs || '') . $expr; # 前に式があれば加える
        $state->write_lines( sprintf( <<'CODE' , $cond, $expr ) );
%s ( defined( %s ) ) {

CODE

        $state->exprs( '' );
        $state->indent_depth( $state->indent_depth + 1 ); # ブロック内

        if ( $cond eq 'if' ) {
            $state->{ if_end }->{ $i + $arg - 1 }++; # if block end
        }
        else {
            $state->{ while_end }->{ $i + $arg - 1 }++; # while block end
        }

    }
    else { # ternary
        my $pre_exprs = $state->exprs || '';
        $state->exprs( $pre_exprs . $expr . ' && ' ); # 保存
    }

#    $state->write_lines( "# and" );
};


$CODE_MANIP{ 'or' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $ops  = $state->ops;
    my $i    = $state->current_line;
    my $expr = $state->sa();

    if ( $ops->[ $i + $arg - 1 ]->[ 0 ] eq 'goto' ) { # if cond
        $expr = ($state->exprs || '') . $expr; # 前に式があれば加える
        $state->write_lines( sprintf( <<'CODE' , $expr ) );
if ( !( %s ) ) {

CODE

        $state->exprs( '' );
        $state->indent_depth( $state->indent_depth + 1 ); # ブロック内
        $state->{ if_end }->{ $i + $arg - 1 }++; # block end
    }
    elsif ( $ops->[ $i + $arg ]->[ 0 ] =~ /and|or|dand|dor/ ) {
        my $pre_exprs = $state->exprs || '';
        $state->exprs( $pre_exprs . $expr . ' || ' ); # 保存
    }
    elsif ( $arg == 2 ) { # $x ? $y : $z;
        my $line = $state->current_line;
        my @args;

#        print $state->sa,"\n";
#        print $state->sb,"\n";
#        print $state->lvar->[0],"\n";

        while ( $arg-- ) {
            my ( $opname ) = $ops->[ ++$line ]->[0];
            push @args, (
                  $opname eq 'load_lvar_to_sb' ? $state->lvar->[0]
                : $opname eq 'move_from_sb'    ? $state->sb
                : die
            );
            $state->{ proc }->{ $line }->{ skip } = 1;
        }

        $state->sa( sprintf( '%s ? %s : %s' , $state->sa, reverse @args ) );
    }
    else {
        die;
    }

};


$CODE_MANIP{ 'not' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $sv = $state->sa();
    $state->sa( sprintf( '( !%s )', $sv ) );
};


$CODE_MANIP{ 'eq' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( 'cond_eq( %s, %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'ne' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( 'cond_ne( %s, %s )', $state->sb(), $state->sa() ) );
};



$CODE_MANIP{ 'lt' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s < %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'le' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s <= %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'gt' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s > %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'ge' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->sa( sprintf( '( %s >= %s )', $state->sb(), $state->sa() ) );
};


$CODE_MANIP{ 'macrocall' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $ops  = $state->ops;
    $state->optimize_to_print( 'num' );
    $state->write_lines( '$pad->[-1] = pop( @sp );' );
    $state->sa( sprintf( '$tx_pp_boost_macro_%s->()', $state->sa() ) );
};


$CODE_MANIP{ 'macro_begin' } = sub {
    my ( $state, $arg, $line ) = @_;

    $state->{ macro_begin } = $state->current_line;

    $state->write_lines( sprintf( 'my $tx_pp_boost_macro_%s = sub {', $arg ) );
    $state->indent_depth( $state->indent_depth + 1 );
    $state->write_lines( sprintf( 'my $output;' ) );
};


$CODE_MANIP{ 'macro_end' } = sub {
    my ( $state, $arg, $line ) = @_;

    $state->write_lines( sprintf( 'pop( @$pad );' ) );
    $state->write_code( "\n" );
    $state->write_lines( sprintf( '$output;' ) );

    $state->indent_depth( $state->indent_depth - 1 );

    $state->write_lines( sprintf( "};\n" ) );

    my $macro_start = $state->{ macro_begin };
    my $macro_end   = $state->current_line;

    push @{ $state->{ macro_lines } }, splice( @{ $state->{ lines } },  $macro_start, $macro_end );

};


$CODE_MANIP{ 'macro' } = sub {
    my ( $state, $arg, $line ) = @_;

    $state->sa( $arg );

    $state->write_lines( 'push @{$pad}, [];' );
    $state->write_code( "\n" );
};


$CODE_MANIP{ 'function' } = sub { # not yet implemebted
    my ( $state, $arg, $line ) = @_;
    $state->write_lines(
        sprintf('$sa = $st->function->{ %s } or Carp::croak( "Function %s is not registered" );', $arg, $arg )
    );
};


=pod

$CODE_MANIP{ 'funcall' } = sub {
    my ( $state, $arg, $line ) = @_;
#    $state->sa(
#        sprintf('call( $st, 0, $sa, @{ pop @sp } )' )
#    );
    $state->write_lines(
        sprintf('$sa = call( $st, 0, $sa, @{ pop @sp } );' )
    );

    $state->sa(
        sprintf( '$sa' )
    );
};

=cut

$CODE_MANIP{ 'goto' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $i = $state->current_line;

    if ( delete $state->{ loop }->{ $i + $arg + 1 } ) { # forブロックを閉じる
        $state->indent_depth( $state->indent_depth - 1 );
        pop @{ $state->{ for_level } };
        $state->write_lines( '}' );
    }
    elsif ( delete $state->{ if_end }->{ $i } ) { # ifのブロックを閉じ、elseブロックを開く
        $state->indent_depth( $state->indent_depth - 1 );

        $state->write_lines( "}\nelse {" );

        $state->{ proc }->{ $i + $arg }->{ 'else_end' }++;
        $state->indent_depth( $state->indent_depth + 1 ); # else内
    }
    elsif ( delete $state->{ while_end }->{ $i } ) { # whileブロックを閉じる
        $state->indent_depth( $state->indent_depth - 1 );
        $state->write_lines( "}" );
    }
    else {
        die "invalid goto op";
    }

    $state->write_code( "\n" );
};


$CODE_MANIP{ 'depend' } = sub {
};


$CODE_MANIP{ 'end' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->write_lines( "# process end" );
};


#
# methods
#

sub write_lines {
    my ( $state, $lines, $idx ) = @_;
    my $code = '';

    $idx = $state->current_line unless defined $idx;

    for my $line ( split/\n/, $lines ) {
        $code .= $state->indent . $line . "\n";
    }

    $state->lines->[ $idx ] .= $code;
}


sub write_code {
    my ( $state, $code, $idx ) = @_;
    $idx = $state->current_line unless defined $idx;
    $state->lines->[ $idx ] .= $code;
}


sub reset_line {
    my ( $state, $idx ) = @_;
    $idx = $state->current_line unless defined $idx;
    $state->lines->[ $idx ] = '';
}


sub optimize_to_print {
    my ( $state, $type ) = @_;
    my $ops = $state->ops->[ $state->current_line + 1 ];

    return unless $ops;
    return unless ( $ops->[0] eq 'print' );

    if ( $type eq 'num' ) {
        $ops->[0] = 'print_raw';
    }

}

#
# utils
#

sub indent {
    $_[0]->indent_space x $_[0]->indent_depth;
}


sub escape {
    my $str = $_[0];
    $str =~ s{\\}{\\\\}g;
    $str =~ s{\n}{\\n}g;
    $str =~ s{\t}{\\t}g;
    $str =~ s{"}{\\"}g;
    $str =~ s{\$}{\\\$}g;
    return $str;
}


#
# called in booster code
#

sub neat {
    if ( defined $_[0] ) {
        if ( $_[0] =~ /^-?[.0-9]+$/ ) {
            return $_[0];
        }
        else {
            return "'" . $_[0] . "'";
        }
    }
    else {
        'nil';
    }
}


sub call {
    my ( $st, $flag, $proc, @args ) = @_;
    my $obj = shift @args if ( $flag );
    my $ret;

    if ( $flag ) { # method call
        unless ( defined $obj ) {
            warn_in_booster( $st, "Use of nil to invoke method %s", $proc );
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


sub fetch {
    my ( $st, $var, $key ) = @_;
    my $ret;

    if ( Scalar::Util::blessed $var ) {
        $ret = call( $st, 1, $key, $var );
    }
    elsif ( ref $var eq 'HASH' ) {
        if ( defined $key ) {
            $ret = $var->{ $key };
        }
        else {
            warn_in_booster( $st, "Use of nil as a field key" );
        }
    }
    elsif ( ref $var eq 'ARRAY' ) {
        if ( defined $key and $key =~ /[-.0-9]/ ) {
            $ret = $var->[ $key ];
        }
        else {
            warn_in_booster( $st, "Use of %s as an array index", neat( $key ) );
        }
    }
    elsif ( defined $var ) {
        error_in_booster( $st, "Cannot access %s (%s is not a container)", neat($key), neat($var) );
    }
    else {
        print Dumper $var;
        warn_in_booster( $st, "Use of nil to access %s", neat( $key ) );
    }

    return $ret;
}


sub cond_eq {
    my ( $sa, $sb ) = @_;
    if ( defined $sa and defined $sb ) {
        return $sa eq $sb;
    }

    if ( defined $sa ) {
        return defined $sb && $sa eq $sb;
    }
    else {
        return !defined $sb;
    }
}


sub cond_ne {
    !cond_eq( @_ );
}


sub warn_in_booster {
    my ( $st, $msg, @args ) = @_;
    Carp::carp( sprintf( $msg, @args ) );
}


sub error_in_booster {
    my ( $st, $msg, @args ) = @_;
    Carp::croak( sprintf( $msg, @args ) );
}


1;
__END__


=head1 NAME

Text::Xslate::PP::Booster - Text::Xslate::PP speed up!!!!

=head1 SYNOPSYS

    use Text::Xslate::PP;
    use Text::Xslate::PP::Booster;
    
    my $tx      = Text::Xslate->new();
    my $code    = Text::Xslate::PP::Booster->opcode2perlcode_str( $tx->_compiler->compile( ... ) );
    my $coderef = Text::Xslate::PP::Booster->opcode2perlcode( $tx->_compiler->compile( ... ) );

=head1 DESCRIPTION

This module is called by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
