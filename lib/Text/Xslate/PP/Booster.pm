package Text::Xslate::PP::Booster;

use strict;
use Data::Dumper;
use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;

our $VERSION = '0.0001';

my %CODE_MANIP = ();
my $TX_OPS = \%Text::Xslate::OPS;


#
# public APIs
#

sub opcode2perlcode_str {
    my ( $class, $proto ) = @_;
    my $len = scalar( @$proto );
    my @lines;

    $class->compactioin( $proto );

    my $state = {
        indent => 1,
        ops    => $proto,
        lines  => \@lines,
        i      => 0,
        loop   => {},
        cond   => {},
    };

    # コード生成
    my $i = $state->{ i };

    while ( $i < $len ) {
        my $pair = $proto->[ $i ];

        $state->{ i } = $i;

        unless ( $pair and ref $pair eq 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$pair;
        my $opnum = $TX_OPS->{ $opname };

        unless ( $CODE_MANIP{ $opname } ) {
            Carp::croak( sprintf( "Oops: opcode '%s' is not yet implemented on Booster", $opname ) );
        }

        my $manip  = $CODE_MANIP{ $opname };

        if ( my $proc = $state->{ proc }->{ $i } ) { # elseブロックの閉じ
            while ( $proc->{ else_end  }-- ) {
                $state->{ indent }--;
                $state->{ lines }->[ $i ] .= sprintf( "\n%s}\n", indent( $state ) );
            }
        }

        $manip->( $state, $arg, defined $line ? $line : '' );

        $i = ++$state->{ i };
    }

    # 書き出し

    my $perlcode =<<'CODE';
sub {
    my ( $st ) = $_[0];
    my ( $output, $sa, $sb, $sv, $targ, $st2, @pad );
    my $vars = $st->{ vars };

    # process start

CODE

    $perlcode .= join( '', @{ $state->{lines} } );


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


sub compactioin { # destructive to $proto
    my ( $class, $proto ) = @_;
    my $len = scalar( @$proto );

    # opコードの圧縮、数値出力の最適化
    for ( my $i = 0; $i < $len; $i++ ) {
        my $opname      = $proto->[ $i ]->[0];
        my $prev_opname = $proto->[ $i - 1 ]->[0];

        if ( $opname eq 'print' ) {
            if ( $prev_opname eq 'fetch_s' ) {
                $proto->[ $i ]->[0]     = 'ex_fetch_s_and_print';
                $proto->[ $i ]->[1]     = $proto->[ $i - 1 ]->[1];
                $proto->[ $i - 1 ]->[0] = 'noop';
            }
            elsif ( $prev_opname eq 'fetch_field_s' ) {
                $proto->[ $i ]->[0]     = 'ex_fetch_field_s_and_print';
                $proto->[ $i ]->[1]     = $proto->[ $i - 1 ]->[1];
                $proto->[ $i - 1 ]->[0] = 'noop';
            }
            elsif ( $prev_opname eq 'literal_i' ) {
                $proto->[ $i ]->[0]     = 'ex_literal_i_and_print';
                $proto->[ $i ]->[1]     = $proto->[ $i - 1 ]->[1];
                $proto->[ $i - 1 ]->[0] = 'noop';
            }
            elsif ( $prev_opname =~ /(?:ex_)?(?:add|mod)/ ) {
                $proto->[ $i ]->[0]     = 'print_raw';
            }
        }
        elsif ( $opname =~ /^(add|mod)$/ ) {
            if ( $prev_opname eq 'literal_i' ) {
                $proto->[ $i ]->[0]     = "ex_$1_literal_i";
                $proto->[ $i ]->[1]     = $proto->[ $i - 1 ]->[1];
                $proto->[ $i - 1 ]->[0] = 'noop';
            }
        }
        elsif ( $opname eq 'move_to_sb' ) {
            if ( $prev_opname eq 'fetch_s' ) {
                $proto->[ $i ]->[0]     = 'ex_fetch_s_and_move_to_sb';
                $proto->[ $i ]->[1]     = $proto->[ $i - 1 ]->[1];
                $proto->[ $i - 1 ]->[0] = 'noop';
            }
        }
    }

}


#
# utils
#

sub indent {
    '    ' x $_[0]->{ indent };
}


sub escape {
    my $str = $_[0];
    $str =~ s{\n}{\\n}g;
    $str =~ s{"}{\\"}g;
    return $str;
}


#
# opcods / コードの生成は後で綺麗にする
#


$CODE_MANIP{ 'noop' } = sub {
    $_[0]->{ lines }->[ $_[0]->{ i } ] .= '';
};


$CODE_MANIP{ 'move_to_sb' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# move_to_sb\n", indent( $state ) );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent( $state ) );
%s$sb = $sa;

CODE

};


$CODE_MANIP{ 'save_to_lvar' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# save_to_lvar %s\n", indent( $state ), $arg );

    $state->{ ops }->[ $state->{ i } ]->[ 1 ] = '$sa';

    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent( $state ), $arg );
%s$pad[ %s ] = $sa;

CODE

};


$CODE_MANIP{ 'nil' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->{ lines }->[ $_[0]->{ i } ] .= sprintf( <<'CODE', indent( $state ) );
%s$sa = undef;

CODE

};


$CODE_MANIP{ 'literal' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# literal \"%s\" #%s\n", indent($state), escape( $arg ), $line );
    $arg =~ s{\\}{\\\\}g;
    $arg =~ s{"}{\\"}g;
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state), $arg );
%s$sa = "%s";

CODE

};


$CODE_MANIP{ 'literal_i' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# literal_i %s #%s\n", indent($state), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state), $arg );
%s$sa = %s;

CODE

};


$CODE_MANIP{ 'fetch_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf("%s# fetch_s \"%s\" #%s\n", indent( $state ), escape( $arg ), $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state), escape( $arg ) );
%s$sa = $vars->{ '%s' };

CODE

};


$CODE_MANIP{ 'fetch_lvar' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# fetch_lvar %s #%s\n", indent( $state ), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent( $state ), $arg );
%s$sa = $pad[ %s ];

CODE

};


$CODE_MANIP{ 'fetch_field_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# fetch_field_s %s #%s\n", indent( $state ), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . _fetch_field_s( $state, '$sa', $arg );
};


$CODE_MANIP{ 'print' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf("%s# print #%s\n", indent( $state ), $line );
    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', indent( $state ) );
%s$sv = $sa;

CODE

    $state->{ lines }->[ $state->{ i } ] .= $comment . _print( $state );
};


$CODE_MANIP{ 'print_raw' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# print_raw #%s\n", indent($state), $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state) );
%s$output .= $sa;

CODE

};


$CODE_MANIP{ 'print_raw_s' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# print_raw_s \"%s\" #%s\n", indent($state), escape( $arg ), $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state), escape( $arg ) );
%s$output .= "%s";

CODE

};


$CODE_MANIP{ 'include' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# include #%s\n", indent($state), $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent($state) );
%s$st2 = Text::Xslate::PP::tx_load_template( $st->self, $sa );
Text::Xslate::PP::tx_execute( $st2, undef, $vars );
$output .= $st2->{ output };

CODE

};


$CODE_MANIP{ 'for_start' } = sub {
    my ( $state, $arg, $line ) = @_;

    push @{ $state->{ for_level } }, {
        stack_id => $arg,
    };

    my $comment = sprintf( "%s# for_start %s #%s\n", indent($state), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] = $comment . sprintf( <<'CODE', indent($state), $arg );
CODE

};


$CODE_MANIP{ 'for_iter' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf( "%s# for_iter\n", indent( $state ) );

    $state->{ lines }->[ $state->{ i } - 1 ] = ''; # delete literal_i op
    $state->{ loop }->{ $state->{ i } } = 1; # marked

    my $stack_id = $state->{ for_level }->[ -1 ]->{ stack_id };

    $state->{ lines }->[ $state->{ i } ] = $comment
        . sprintf( <<'CODE', indent($state), $stack_id );
%sfor ( @{ $sa } ) {
CODE

    $state->{ indent }++;

    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', indent($state), $stack_id );
%s$pad[ %s ] = $_;

CODE

};


$CODE_MANIP{ 'add' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s + %s )' );
};


$CODE_MANIP{ 'sub' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s - %s )' );
};


$CODE_MANIP{ 'mul' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s * %s )' );
};


$CODE_MANIP{ 'div' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s / %s )' );
};


$CODE_MANIP{ 'mod' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s %% %s )' );
};


$CODE_MANIP{ 'and' } = sub { # if-else あるいは && 等
    my ( $state, $arg, $line ) = @_;

    my $ops  = $state->{ ops };
    my $i    = $state->{ i };
    my $expr = $ops->[ $i - 1 ]->[ 1 ];

    if ( $ops->[ $i + $arg - 1 ]->[ 0 ] eq 'goto' ) { # if cond
        my $prev_expr = delete $state->{ cond_prev_expr } || ''; # 前に式があれば加える
        $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', indent( $state ), $prev_expr, $expr );
%sif ( %s%s ) {

CODE

        $state->{ indent }++; # ブロック内
        $state->{ if_end }->{ $i + $arg - 1 }++; # block end

    }
    else { # ternary
        $state->{ lines }->[ $state->{ i } ] = '';
        $state->{ cond_prev_expr } .= $expr . ' && '; # 式を保存
    }

};


$CODE_MANIP{ 'dand' } = sub { # if-else あるいは && 等
    my ( $state, $arg, $line ) = @_;

    my $ops  = $state->{ ops };
    my $i    = $state->{ i };
    my $expr = $ops->[ $i - 1 ]->[ 1 ];

    if ( $ops->[ $i + $arg - 1 ]->[ 0 ] eq 'goto' ) { # cond
        my $cond = $ops->[ $i + $arg - 1 ]->[ 1 ] < 0 ? 'while' : 'if';
        my $prev_expr = delete $state->{ cond_prev_expr } || ''; # 前に式があれば加える
        $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', indent( $state ), $cond, $prev_expr, $expr );
%s%s ( %sdefined %s ) {

CODE

        $state->{ indent }++; # ブロック内

        if ( $cond eq 'if' ) {
            $state->{ if_end }->{ $i + $arg - 1 }++; # if block end
        }
        else {
            $state->{ while_end }->{ $i + $arg - 1 }++; # while block end
        }

    }
    else { # ternary
        $state->{ lines }->[ $state->{ i } ] = '';
        $state->{ cond_prev_expr } .= $expr . ' && '; # 式を保存
    }

};


$CODE_MANIP{ 'eq' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, 'cond_eq( %s, %s )' );
};


$CODE_MANIP{ 'ne' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, 'cond_ne( %s, %s )' );
};


$CODE_MANIP{ 'lt' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s < %s )' );
};


$CODE_MANIP{ 'le' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s <= %s )' );
};


$CODE_MANIP{ 'gt' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s > %s )' );
};


$CODE_MANIP{ 'ge' } = sub {
    my ( $state, $arg, $line ) = @_;
    _make_expr( $state, $arg, '( %s >= %s )' );
};


$CODE_MANIP{ 'goto' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $i = $state->{ i };

    if ( delete $state->{ loop }->{ $state->{ i } + $arg + 1 } ) { # for loop
        $state->{ indent }--;
        pop @{ $state->{ for_level } };
        $state->{ lines }->[ $state->{ i } ] .= sprintf( "\n%s}\n", indent( $state ) );
    }
    elsif ( delete $state->{ if_end }->{ $state->{ i } } ) { # ifのブロックを閉じ、elseブロックを開く
        $state->{ indent }--;
        $state->{ lines }->[ $state->{ i } ] .= sprintf( "\n%s}\n%selse {\n", indent( $state ), indent( $state ) );

        $state->{ proc }->{ $state->{ i } + $arg }->{ 'else_end' }++;
        $state->{ indent }++; # else内
    }
    elsif ( delete $state->{ while_end }->{ $state->{ i } } ) { # whileのブロックを閉じる
        $state->{ indent }--;
        $state->{ lines }->[ $state->{ i } ] .= sprintf( "\n%s}\n", indent( $state ) );
    }
    else {
        die "invalid goto op";
        #$state->{ lines }->[ $state->{ i } ] = sprintf( "%s# goto %s\n", indent( $state ), $arg );
    }

};


$CODE_MANIP{ 'end' } = sub {
    $_[0]->{ lines }->[ $_[0]->{ i } ] .= "\n    # process end\n";
};


#
# EXTRA OPCODES
#


$CODE_MANIP{ 'ex_fetch_s_and_print' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->{ lines }->[ $state->{ i } ] .= sprintf("%s# ex_fetch_s_and_print \"%s\" #%s\n", indent($state), escape( $arg ), $line );
    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', $arg );
    $sv = $vars->{ '%s' };

CODE

    $state->{ lines }->[ $state->{ i } ] .= _print( $state );
};


$CODE_MANIP{ 'ex_fetch_field_s_and_print' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->{ lines }->[ $state->{ i } ] .= sprintf("%s# ex_fetch_field_s_and_print \"%s\" #%s\n", indent( $state ), escape( $arg ), $line );
    $state->{ lines }->[ $state->{ i } ] .= _fetch_field_s( $state, '$sv', $arg );
    $state->{ lines }->[ $state->{ i } ] .= _print( $state );
};


$CODE_MANIP{ 'ex_literal_i_and_print' } = sub {
    my ( $state, $arg, $line ) = @_;
    $state->{ lines }->[ $state->{ i } ] .= sprintf("%s# ex_literal_i_and_print \"%s\" #%s\n", indent( $state ), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', indent( $state ), $arg );
%s$output .= %s;

CODE

};


$CODE_MANIP{ 'ex_add_literal_i' } = sub {
    my ( $state, $arg, $line ) = @_;

    if ( $state->{ ops }->[ $state->{ i } + 1 ]-> [ 0 ] =~ /^(?:and|not)$/ ) {
        my $i = $state->{ i };
        return _make_expr( $state, $arg, '( %s + %s )' );
    }

    $state->{ lines }->[ $state->{ i } ] .= sprintf("%s# ex_add_literal_i #%s\n", indent( $state ), $line );
    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', $arg );
    $targ = $sa = $sb + %s;

CODE

};


$CODE_MANIP{ 'ex_mod_literal_i' } = sub {
    my ( $state, $arg, $line ) = @_;

    if ( $state->{ ops }->[ $state->{ i } + 1 ]-> [ 0 ] =~ /^(?:and|not)$/ ) {
        my $i = $state->{ i };
        return _make_expr( $state, $arg, '( %s %% %s )' );
    }

    $state->{ lines }->[ $state->{ i } ] .= sprintf("%s# ex_mod_literal_i #%s\n", indent( $state ), $line );
    $state->{ lines }->[ $state->{ i } ] .= sprintf( <<'CODE', $arg );
    $targ = $sa = $sb %% %s;

CODE

};


$CODE_MANIP{ 'ex_fetch_s_and_move_to_sb' } = sub {
    my ( $state, $arg, $line ) = @_;
    my $comment = sprintf("%s# ex_fetch_s_and_move_to_sb %s #%s\n", indent( $state ), $arg, $line );
    $state->{ lines }->[ $state->{ i } ] .= $comment . sprintf( <<'CODE', indent( $state ), $arg );
%s$sb = $vars->{ '%s' };

CODE

};


#
# functions called in boost code
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
    elsif ( $var ) {
        error_in_booster( $st, "Cannot access %s (%s is not a container)", neat($key), neat($var) );
    }
    else {
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


#
# tempalte helpers
#


sub _expr { # ops
    my $opname = $_[0]->[0];
    my $val    = defined $_[0]->[1] ? $_[0]->[1] : 'undef';

    if ( $opname =~ /literal_i/ ) {
        return $val;
    }
    elsif ( $opname =~ /literal/ ) {
        return '"' . escape( $val ) . '"';
    }
    elsif ( $opname =~ /fetch_s/ ) {
        return '$vars->{' . $val . '}';
    }
    else {
        return $val;
    }
}


sub _make_expr {
    my ( $state, $arg, $type ) = @_;
    my $ops = $state->{ ops };
    my $i   = $state->{ i };

    my ( $sb_ops, $sa_ops ) = @{ $ops }[ $i - 1, $i - 3 ];
    $sa_ops = $ops->[ $i - 2 ] if ( $sa_ops->[0] eq 'noop' ); # compactioned


    my $left  = _expr( $sa_ops );
    my $right = _expr( $sb_ops );
    my $str   = sprintf( $type, $left, $right );

    $state->{ ops }->[ $i ]->[1] = $str;

    my $next_op = $ops->[ $i + 1 ]->[0];

    if ( $next_op =~ /(?:and|not)/ ) { # 条件式
        $state->{ ops }->[ $i - 1 ]->[0] = 'noop';
        $state->{ ops }->[ $i - 2 ]->[0] = 'noop';
        $state->{ ops }->[ $i - 3 ]->[0] = 'noop';
        $state->{ lines }->[ $i - 1 ] = '';
        $state->{ lines }->[ $i - 2 ] = '';
        $state->{ lines }->[ $i - 3 ] = '';
        $state->{ lines }->[ $state->{ i } ] .= '';
    }
    else {
        $state->{ lines }->[ $state->{ i } ] .= sprintf( "%s\$sa = %s;\n\n", indent( $state ), $str );
    }

}


sub _fetch_field_s {
    my ( $state, $name, $arg ) = @_;
    my $indent = indent( $state );

    return sprintf( <<'CODE', $indent, $name, escape($arg) );
%s%s = fetch( $st, $sa, "%s" );

CODE

    my $lines = sprintf( <<'CODE', $name, $arg, $name, $arg, $name, $arg );
if ( ref $sa eq 'HASH' ) {
    %s = $sa->{%s};
}
elsif ( ref $sa eq 'ARRAY' ) {
    %s = $sa->["%s"];
}
elsif ( Scalar::Util::blessed($sa) ) {
    %s = $sa->%s();
}
CODE

    my $ret;

    for my $line ( split/\n/, $lines ) {
        $ret .= $indent . $line . "\n";
    }

    return $ret;
}


sub _print {
    my ( $state ) = @_;
    my $indent = indent( $state );

my $lines =<<'CODE';

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

    my $ret;

    for my $line ( split/\n/, $lines ) {
        $ret .= $indent . $line . "\n";
    }

    return $ret;
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
