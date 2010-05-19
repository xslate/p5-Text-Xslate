package Text::Xslate::PP::Booster;

use Mouse;
#use strict;
use Data::Dumper;
use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;

our $VERSION = '0.1017';

my %CODE_MANIP = ();
my $TX_OPS = \%Text::Xslate::OPS;


has indent_depth => ( is => 'rw', default => 1 );

has indent_space => ( is => 'rw', default => '    ' );

has lines => ( is => 'rw', default => sub { []; } );

has ops => ( is => 'rw', default => sub { []; } );

has current_line => ( is => 'rw', default => 0 );

has exprs => ( is => 'rw' );

has sa => ( is => 'rw' );

has sb => ( is => 'rw' );

has lvar => ( is => 'rw', default => sub { []; } );

has framename => ( is => 'rw', default => 'main' );

has strict => ( is => 'rw', predicate => 1 );


#
# public APIs
#

sub convert_opcode {
    my ( $self, $proto, $parent, $opt ) = @_;
    my $len = scalar( @$proto );

    unless ( ref $self ) {
        $self = $self->new(
            strict => $opt->{ strict },
        );
    }

    $self->ops( $proto );

    if ( $parent ) { # 引き継ぐ
        $self->sa( $parent->sa );
        $self->sb( $parent->sb );
        $self->lvar( [ @{ $parent->lvar } ] );
    }

    # コード生成
    my $i = 0;

    while ( $self->current_line < $len ) {
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

        if ( my $proc = $self->{ proc }->{ $i } ) {

            if ( $proc->{ skip } ) {
                $self->current_line( ++$i );
                next;
            }

        }

        $manip->( $self, $arg, defined $line ? $line : '' );

        $self->current_line( ++$i );
    }

    return $self;
}


sub opcode2perlcode_str {
    my ( $self, $proto, $opt ) = @_;

    #my $tx = Text::Xslate->new;
    #print $tx->_compiler->as_assembly( $proto );

    $self->convert_opcode( $proto, undef, $opt );

    # 書き出し

    my $perlcode =<<'CODE';
sub { no warnings 'recursion';
    my ( $st ) = $_[0];
    my ( $sa, $sb, $sv, $st2, $pad, %macro, $depth );
    my $output = '';
    my $vars  = $st->{ vars };

    $pad = [ [ ] ];

CODE

    if ( $self->{ macro_mem } ) {
        for ( reverse @{ $self->{ macro_mem } } ) {
            push @{ $self->{ macro_lines } }, splice( @{ $self->{ lines } },  $_->[0], $_->[1] );
        }

        $perlcode .=<<'CODE';
    # macro
CODE

        $perlcode .= join ( '', grep { defined } @{ $self->{ macro_lines } } );
    }

    $perlcode .=<<'CODE';

    # process start

CODE

    $perlcode .= join( '', grep { defined } @{ $self->{lines} } );


$perlcode .=<<'CODE';
    $st->{ output } = $output;
}
CODE

    return $perlcode;
}


sub opcode2perlcode {
    my ( $self, $proto ) = @_;

    my $perlcode = $self->opcode2perlcode_str( $proto );

    # TEST
    print "$perlcode\n" if $ENV{ BOOST_DISP };

    my $evaled_code = eval $perlcode;

    die $@ unless $evaled_code;

    return $evaled_code;
}

sub is_strict { $_[0]->{strict} }
#
#
#

$CODE_MANIP{ 'noop' } = sub {
};


$CODE_MANIP{ 'move_to_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sb( $self->sa );
};


$CODE_MANIP{ 'move_from_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $self->sb );

    if ( $self->{ within_cond } ) {
        $self->write_lines( sprintf( '$sa = %s;', $self->sb ) );
    }

};


$CODE_MANIP{ 'save_to_lvar' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $v = sprintf( '( $pad->[ -1 ]->[ %s ] = %s )', $arg, $self->sa );
    $self->lvar->[ $arg ] = $self->sa;
    $self->sa( $v );

    my $op = $self->{ ops }->[ $self->current_line + 1 ];

    unless ( $op and $op->[0] =~ /^(?:print|and|or|dand|dor|push)/ ) { # ...
        $self->write_lines( sprintf( '%s;', $v )  );
    }

};


$CODE_MANIP{ 'load_lvar_to_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sb( $self->lvar->[ $arg ] );
};


$CODE_MANIP{ 'push' } = sub {
    my ( $self, $arg, $line ) = @_;
    push @{ $self->{ SP }->[ -1 ] }, $self->sa;
};


$CODE_MANIP{ 'pushmark' } = sub {
    my ( $self, $arg, $line ) = @_;
    push @{ $self->{ SP } }, [];
};


$CODE_MANIP{ 'nil' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( 'undef' );
};


$CODE_MANIP{ 'literal' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( '"' . escape( $arg ) . '"' );
};


$CODE_MANIP{ 'literal_i' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $arg );
    $self->optimize_to_print( 'num' );
    $self->optimize_to_expr();
};


$CODE_MANIP{ 'fetch_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '$vars->{ "%s" }', escape( $arg ) ) );
};


$CODE_MANIP{ 'fetch_lvar' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->sa( sprintf( '$pad->[ -1 ]->[ %s ]', $arg ) );

    return unless $self->is_strict;

    if ( $self->{ in_macro } ) {
        my $macro = $self->{ in_macro };
        unless ( exists $self->{ macro_args_num }->{ $macro }->{ $arg } ) {
            $self->write_lines(
                sprintf(
                    'error_in_booster( $st, %s, %s, "Too few arguments for %s" );',
                    $self->frame_and_line, $self->{ in_macro }
                )
            );
        }
    }

};


$CODE_MANIP{ 'fetch_field' } = sub {
    my ( $self, $arg, $line ) = @_;

    if ( $self->is_strict ) {
        $self->sa( sprintf( 'fetch( $st, %s, %s, %s, %s )', $self->sb(), $self->sa(), $self->frame_and_line ) );
    }
    else {
        $self->sa( sprintf( 'fetch( $st, %s, %s )', $self->sb(), $self->sa() ) );
    }


};


$CODE_MANIP{ 'fetch_field_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();

    if ( $self->is_strict ) {
        $self->sa( sprintf( 'fetch( $st, %s, "%s", %s, %s )', $sv, escape( $arg ), $self->frame_and_line ) );
    }
    else {
        $self->sa( sprintf( 'fetch( $st, %s, "%s" )', $sv, escape( $arg ) ) );
    }
};


$CODE_MANIP{ 'print_raw' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    $self->write_lines( sprintf('$output .= %s;', $sv) );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'print_raw_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( sprintf('$output .= "%s";', escape( $arg ) ) );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'print' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    my $err;

    if ( $self->is_strict ) {
        $err = sprintf( 'warn_in_booster( $st, %s, %s, "Use of nil to be printed" );', $self->frame_and_line );
    }
    else {
        $err = sprintf( 'warn_in_booster( $st, undef, undef, "Use of nil to be printed" );' );
    }


    $self->write_lines( sprintf( <<'CODE', $sv, $err ) );
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
    %s
}
CODE

    $self->write_code( "\n" );
};


$CODE_MANIP{ 'include' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( sprintf( <<'CODE', $self->sa ) );
$st2 = Text::Xslate::PP::tx_load_template( $st->self, %s );
Text::Xslate::PP::tx_execute( $st2, undef, $vars );
$output .= $st2->{ output };

CODE

};


$CODE_MANIP{ 'for_start' } = sub {
    my ( $self, $arg, $line ) = @_;

    push @{ $self->{ for_level } }, {
        stack_id => $arg,
        ar       => $self->sa,
    };
};


$CODE_MANIP{ 'for_iter' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->{ loop }->{ $self->current_line } = 1; # marked

    my $stack_id = $self->{ for_level }->[ -1 ]->{ stack_id };
    my $ar       = $self->{ for_level }->[ -1 ]->{ ar };

    if ( $self->{ in_macro } ) { # fetch_lvarのチェック用
        $self->{ macro_args_num }->{ $self->framename }->{ $self->sa() } = 1;
    }

    if ( $self->is_strict ) {
        $self->write_lines(
            sprintf( 'for ( @{ check_itr_ar( $st, %s, %s, %s ) } ) {', $ar, $self->frame_and_line )
        );
    }
    else {
        $self->write_lines( sprintf( 'for ( @{ %s } ) {', $ar eq 'undef' ? '[]' : $ar ) );
    }

    $self->write_code( "\n" );

    $self->indent_depth( $self->indent_depth + 1 );

    $self->write_lines( sprintf( '$pad->[ -1 ]->[ %s ] = $_;', $self->sa() ) );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'add' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s + %s )', $self->sb(), $self->sa() ) );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'sub' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s - %s )', $self->sb(), $self->sa() ) );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'mul' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s * %s )', $self->sb(), $self->sa() ) );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'div' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s / %s )', $self->sb(), $self->sa() ) );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'mod' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s %% %s )', $self->sb(), $self->sa() ) );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'concat' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s . %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'filt' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $i = $self->{ i };
    my $ops = $self->{ ops };

    $self->sa( sprintf('( eval { %s->( %s ) } )', $self->sa, $self->sb ) );
};


$CODE_MANIP{ 'and' } = sub {
    my ( $self, $arg, $line ) = @_;
    return check_logic( $self, $self->current_line, $arg, 'and' );
};


$CODE_MANIP{ 'dand' } = sub {
    my ( $self, $arg, $line ) = @_;
    return check_logic( $self, $self->current_line, $arg, 'dand' );
};


$CODE_MANIP{ 'or' } = sub {
    my ( $self, $arg, $line ) = @_;
    return check_logic( $self, $self->current_line, $arg, 'or' );
};


$CODE_MANIP{ 'dor' } = sub {
    my ( $self, $arg, $line ) = @_;
    return check_logic( $self, $self->current_line, $arg, 'dor' );
};


$CODE_MANIP{ 'not' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    $self->sa( sprintf( '( !%s )', $sv ) );
};


$CODE_MANIP{ 'plus' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '+ %s', $self->sa ) );
};


$CODE_MANIP{ 'minus' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '- %s', $self->sa ) );
};


$CODE_MANIP{ 'eq' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'cond_eq( %s, %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'ne' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'cond_ne( %s, %s )', $self->sb(), $self->sa() ) );
};



$CODE_MANIP{ 'lt' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s < %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'le' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s <= %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'gt' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s > %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'ge' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s >= %s )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'macrocall' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $ops  = $self->ops;

    $self->optimize_to_print( 'num' );

    # 引数の値をマーク
    for my $i ( 0 .. $#{ $self->{ SP }->[ -1 ] } ) {
        $self->{ macro_args_num }->{ $self->sa }->{ $i } = 1;
    }

    $self->sa( sprintf( '$macro{\'%s\'}->(%s)',
        $self->sa(),
        sprintf( 'push @{ $pad }, [ %s ]', join( ', ', @{ pop @{ $self->{ SP } } } ) )
    ) );
};


$CODE_MANIP{ 'macro_begin' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->{ macro_begin } = $self->current_line;
    $self->{ in_macro } = $arg;
    $self->framename( $arg );

    $self->write_lines( sprintf( '$macro{\'%s\'} = sub {', $arg ) );
    $self->indent_depth( $self->indent_depth + 1 );
    $self->write_lines( sprintf( 'my $output;' ) );
    $self->write_code( "\n" );

    $self->write_lines(
        sprintf( q{Carp::croak('Macro call is too deep (> 100) at "%s"') if ++$depth > 100;}, $arg )
    );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'macro_end' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->write_lines( sprintf( '$depth--;' ) );
    $self->write_lines( sprintf( 'pop( @$pad );' ) );
    $self->write_code( "\n" );
    $self->write_lines( sprintf( '$output;' ) );

    $self->indent_depth( $self->indent_depth - 1 );

    $self->write_lines( sprintf( "};\n" ) );

    delete $self->{ in_macro };

    push @{ $self->{ macro_mem } }, [ $self->{ macro_begin }, $self->current_line ];
};


$CODE_MANIP{ 'macro' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $arg );
};


$CODE_MANIP{ 'function' } = sub { # not yet implemebted
    my ( $self, $arg, $line ) = @_;
    $self->sa(
        sprintf('$st->function->{ %s }', $arg )
    );
};


$CODE_MANIP{ 'funcall' } = sub {
    my ( $self, $arg, $line ) = @_;

    if ( $self->is_strict ) {
        $self->sa(
            sprintf('call( $st, %s, %s, 0, %s, %s )',
                $self->frame_and_line, $self->sa, join( ', ', @{ pop @{ $self->{ SP } } } )
            )
        );
    }
    else {
        $self->sa(
            sprintf('call( $st, undef, undef, 0, %s, %s )', $self->sa, join( ', ', @{ pop @{ $self->{ SP } } } ) )
        );
    }

};


$CODE_MANIP{ 'methodcall_s' } = sub {
    my ( $self, $arg, $line ) = @_;

    if ( $self->is_strict ) {
        $self->sa(
            sprintf('methodcall( $st, %s, %s, "%s", %s )', $self->frame_and_line, $arg, join( ', ', @{ pop @{ $self->{ SP } } } ) )
        );
    }
    else {
        $self->sa(
            sprintf('methodcall( $st, undef, undef, "%s", %s )', $arg, join( ', ', @{ pop @{ $self->{ SP } } } ) )
        );
    }

};


$CODE_MANIP{ 'goto' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $i = $self->current_line;

    if ( delete $self->{ loop }->{ $i + $arg + 1 } ) { # forブロックを閉じる
        $self->indent_depth( $self->indent_depth - 1 );
        pop @{ $self->{ for_level } };
        $self->write_lines( '}' );
    }
    else {
        die "invalid goto op";
    }

    $self->write_code( "\n" );
};


$CODE_MANIP{ 'depend' } = sub {
};


$CODE_MANIP{ 'end' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( "# process end" );
};

#
#
#


sub check_logic {
    my ( $self, $i, $arg, $type ) = @_;
    my $ops = $self->ops;
    my $type_store = $type;

    my $next_opname = $ops->[ $i + $arg ]->[ 0 ] || '';

    if ( $next_opname =~ /and|or/ ) { # &&, ||
        $type = $type eq 'and'  ? ' && '
              : $type eq 'dand' ? 'defined( %s )'
              : $type eq 'or'   ? ' || '
              : $type eq 'dor'  ? '!(defined( %s ))'
              : die
              ;
        my $pre_exprs = $self->exprs || '';
        $self->exprs( $pre_exprs . $self->sa() . $type ); # 保存
        return;
    }

    my $opname = $ops->[ $i + $arg - 1 ]->[ 0 ]; # goto or ?
    my $oparg  = $ops->[ $i + $arg - 1 ]->[ 1 ];

    $type = $type eq 'and'  ? '%s'
          : $type eq 'dand' ? 'defined( %s )'
          : $type eq 'or'   ? '!( %s )'
          : $type eq 'dor'  ? '!(defined( %s ))'
          : die
          ;

    if ( $opname eq 'goto' and $oparg > 0 ) { # if-elseか三項演算子？
        my $if_block_start   = $i + 1;                  # ifブロック開始行
        my $if_block_end     = $i + $arg - 2;           # ifブロック終了行 - goto分も引く
        my $else_block_start = $i + $arg;               # elseブロック開始行
        my $else_block_end   = $i + $arg + $oparg - 2;  # elseブロック終了行 - goto分を引く

        my ( $sa_1st, $sa_2nd );

        $self->{ proc }->{ $i + $arg - 1 }->{ skip } = 1; # goto処理飛ばす

        for ( $if_block_start .. $if_block_end ) {
            $self->{ proc }->{ $_ }->{ skip } = 1; # スキップ処理
        }

        my $st_1st = ref($self)->convert_opcode(
            [ @{ $ops }[ $if_block_start .. $if_block_end ] ], undef, { strict => $self->strict }
        );

        my $code = $st_1st->code;
        if ( $code and $code !~ /^\n+$/ ) {
            my $expr = $self->sa;
            $expr = ( $self->exprs || '' ) . $expr; # 前に式があれば加える
            $self->write_lines( sprintf( 'if ( %s ) {' , sprintf( $type, $expr ) ) );
            $self->exprs( '' );
            $self->write_lines( $code );
            $self->write_lines( sprintf( '}' ) );
        }
        else { # 三項演算子として扱う
            $sa_1st = $st_1st->sa;
        }

        if ( $else_block_end >= $else_block_start ) {

            for (  $else_block_start .. $else_block_end ) { # 2
                $self->{ proc }->{ $_ }->{ skip } = 1; # スキップ処理
            }

            my $st_2nd = ref($self)->convert_opcode(
                [ @{ $ops }[ $else_block_start .. $else_block_end ] ], undef, { strict => $self->strict }
            );

            my $code = $st_2nd->code;

            if ( $code and $code !~ /^\n+$/ ) {
                $self->write_lines( sprintf( 'else {' ) );
                $self->write_lines( $code );
                $self->write_lines( sprintf( '}' ) );
            }
            else { # 三項演算子として扱う
                $sa_2nd = $st_2nd->sa;
            }

        }

        if ( defined $sa_1st and defined $sa_2nd ) {
            my $expr = $self->sa;
            $expr = ( $self->exprs || '' ) . $expr; # 前に式があれば加える
            $self->sa( sprintf( '(%s ? %s : %s)', sprintf( $type, $expr ), $sa_1st, $sa_2nd ) );
        }
        else {
            $self->write_code( "\n" );
        }

    }
    elsif ( $opname eq 'goto' and $oparg < 0 ) { # while
        my $while_block_start   = $i + 1;                  # whileブロック開始行
        my $while_block_end     = $i + $arg - 2;           # whileブロック終了行 - goto分も引く

        for ( $while_block_start .. $while_block_end ) {
            $self->{ proc }->{ $_ }->{ skip } = 1; # スキップ処理
        }

        $self->{ proc }->{ $i + $arg - 1 }->{ skip } = 1; # goto処理飛ばす

        my $st_wh = ref($self)->convert_opcode(
            [ @{ $ops }[ $while_block_start .. $while_block_end ] ], undef, { strict => $self->strict }
        );

        my $expr = $self->sa;
        $expr = ( $self->exprs || '' ) . $expr; # 前に式があれば加える
        $self->write_lines( sprintf( 'while ( %s ) {' , sprintf( $type, $expr ) ) );
        $self->exprs( '' );
        $self->write_lines( $st_wh->code );
        $self->write_lines( sprintf( '}' ) );

        $self->write_code( "\n" );
    }
    elsif ( logic_is_max_main( $ops, $i, $arg ) ) { # min, max

        for ( $i + 1 .. $i + 2 ) {
            $self->{ proc }->{ $_ }->{ skip } = 1; # スキップ処理
        }

        $self->sa( sprintf( '%s ? %s : %s', $self->sa, $self->sb, $self->lvar->[ $ops->[ $i + 1 ]->[ 1 ] ] ) );
    }
    else { # それ以外の処理

        my $true_start = $i + 1;
        my $true_end   = $i + $arg - 1; # 次の行までで完成のため、1足す
        my $false_line = $i + $arg;

            $false_line--; # 出力される場合は省略、falseで設定される値もない

        for ( $true_start .. $true_end ) {
            $self->{ proc }->{ $_ }->{ skip } = 1; # スキップ処理
        }

        my $st_true  = ref($self)->convert_opcode(
            [ @{ $ops }[ $true_start .. $true_end ] ], $self, { strict => $self->strict }
        );

        my $expr = $self->sa;
        $expr = ( $self->exprs || '' ) . $expr; # 前に式があれば加える

            $type = $type_store eq 'and'  ? 'cond_and'
                  : $type_store eq 'or'   ? 'cond_or'
                  : $type_store eq 'dand' ? 'cond_dand'
                  : $type_store eq 'dor'  ? 'cond_dor'
                  : die
                  ;

$self->sa( sprintf( <<'CODE', $type, $expr, $st_true->sa ) );
%s( %s, sub {
%s
}, )
CODE

    }

}


sub logic_is_max_main {
    my ( $ops, $i, $arg ) = @_;
        $ops->[ $i     ]->[ 0 ] eq 'or'
    and $ops->[ $i + 1 ]->[ 0 ] eq 'load_lvar_to_sb'
    and $ops->[ $i + 2 ]->[ 0 ] eq 'move_from_sb'
    and $arg == 2
}


#
# methods
#


sub code {
    join( '', grep { defined $_ } @{ $_[0]->lines } );
}


sub frame_and_line {
    my ( $self ) = @_;
    ( "'" . $self->framename . "'", $self->current_line );
}


sub write_lines {
    my ( $self, $lines, $idx ) = @_;
    my $code = '';

    $idx = $self->current_line unless defined $idx;

    for my $line ( split/\n/, $lines ) {
        $code .= $self->indent . $line . "\n";
    }

    $self->lines->[ $idx ] .= $code;
}


sub write_code {
    my ( $self, $code, $idx ) = @_;
    $idx = $self->current_line unless defined $idx;
    $self->lines->[ $idx ] .= $code;
}


sub reset_line {
    my ( $self, $idx ) = @_;
    $idx = $self->current_line unless defined $idx;
    $self->lines->[ $idx ] = '';
}


sub optimize_to_print {
    my ( $self, $type ) = @_;
    my $ops = $self->ops->[ $self->current_line + 1 ];

    return unless $ops;
    return unless ( $ops->[0] eq 'print' );

    if ( $type eq 'num' ) {
        $ops->[0] = 'print_raw';
    }

}


sub optimize_to_expr {
    my ( $self ) = @_;
    my $ops = $self->ops->[ $self->current_line + 1 ];

    return unless $ops;
    return unless ( $ops->[0] eq 'goto' );

    $self->write_lines( sprintf( '$sa = %s;', $self->sa ) );
    $self->sa( '$sa' );

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
    my ( $st, $frame, $line, $flag, $proc, @args ) = @_;
    my $obj = shift @args if ( $flag );
    my $ret;

    if ( $flag ) { # method call ... fetch() doesn't use methodcall for speed
        unless ( defined $obj ) {
            warn_in_booster( $st, $frame, $line, "Use of nil to invoke method %s", $proc );
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



use Text::Xslate::PP::Type::Pair;
use Text::Xslate::PP::Type::Array;
use Text::Xslate::PP::Type::Hash;

use constant TX_ENUMERABLE => 'Text::Xslate::PP::Type::Array';
use constant TX_KV         => 'Text::Xslate::PP::Type::Hash';

my %builtin_method = (
    size    => [0, TX_ENUMERABLE],
    join    => [1, TX_ENUMERABLE],
    reverse => [0, TX_ENUMERABLE],

    keys    => [0, TX_KV],
    values  => [0, TX_KV],
    kv      => [0, TX_KV],
);

sub methodcall {
    my ( $st, $frame, $line, $method, $invocant, @args ) = @_;

    my $retval;
    if(Scalar::Util::blessed($invocant)) {
        if($invocant->can($method)) {
            $retval = eval { $invocant->$method(@args) };
            if($@) {
                error_in_booster( $st, $frame, $line, "%s" . "\t...", $@ );
            }
            return $retval;
        }
        # fallback
    }

    if(!defined $invocant) {
        warn_in_booster( $st, $frame, $line, "Use of nil to invoke method %s", $method );
    }
    else {
        my $bm = $builtin_method{$method} || return undef;

        my($nargs, $klass) = @{$bm};
        if(@args != $nargs) {
            error_in_booster($st, $frame, $line,
                "Builtin method %s requres exactly %d argument(s), "
                . "but supplied %d",
                $method, $nargs, scalar @args);
            return undef;
         }

         $retval = eval {
            $klass->new($invocant)->$method(@args);
        };
    }

    return $retval;
}


sub fetch {
    my ( $st, $var, $key, $frame, $line ) = @_;
    my $ret;

    if ( Scalar::Util::blessed $var ) {
        $ret = call( $st, $frame, $line, 1, $key, $var );
    }
    elsif ( ref $var eq 'HASH' ) {
        if ( defined $key ) {
            $ret = $var->{ $key };
        }
        else {
            warn_in_booster( $st, $frame, $line, "Use of nil as a field key" );
        }
    }
    elsif ( ref $var eq 'ARRAY' ) {
        if ( defined $key and $key =~ /[-.0-9]/ ) {
            $ret = $var->[ $key ];
        }
        else {
            warn_in_booster( $st, $frame, $line, "Use of %s as an array index", neat( $key ) );
        }
    }
    elsif ( defined $var ) {
        error_in_booster( $st, $frame, $line, "Cannot access %s (%s is not a container)", neat($key), neat($var) );
    }
    else {
        warn_in_booster( $st, $frame, $line, "Use of nil to access %s", neat( $key ) );
    }

    return $ret;
}


sub check_itr_ar {
    my ( $st, $ar, $frame, $line ) = @_;

    unless ( $ar and ref $ar eq 'ARRAY' ) {
        if ( defined $ar ) {
            error_in_booster( $st, $frame, $line, "Iterator variables must be an ARRAY reference, not %s", neat( $ar ) );
        }
        else {
            warn_in_booster( $st, $frame, $line, "Use of nil to iterate" );
        }
        $ar = [];
    }

    return $ar;
}


sub cond_and {
    my ( $value, $subref ) = @_;
    $value ? $subref->() : $value;
}


sub cond_or {
    my ( $value, $subref ) = @_;
    !$value ? $subref->() : $value;
}


sub cond_dand {
    my ( $value, $subref ) = @_;
    defined $value ? $subref->() : $value;
}


sub cond_dor {
    my ( $value, $subref ) = @_;
    !(defined $value) ? $subref->() : $value;
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


sub is_verbose {
    my $v = $_[0]->self->{ verbose };
    defined $v ? $v : Text::Xslate::PP::Opcode::TX_VERBOSE_DEFAULT;
}


sub warn_in_booster {
    my ( $st, $frame, $line, $fmt, @args ) = @_;
    if( is_verbose( $st ) > Text::Xslate::PP::Opcode::TX_VERBOSE_DEFAULT ) {
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ Text::Xslate::PP::Opcode::TXframe_NAME ] = $frame;
        }
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


sub error_in_booster {
    my ( $st, $frame, $line, $fmt, @args ) = @_;
    if( is_verbose( $st ) >= Text::Xslate::PP::Opcode::TX_VERBOSE_DEFAULT ) {
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ Text::Xslate::PP::Opcode::TXframe_NAME ] = $frame;
        }
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


1;
__END__


=head1 NAME

Text::Xslate::PP::Booster - Text::Xslate::PP speed up!!!!

=head1 SYNOPSIS

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
