package Text::Xslate::PP::Booster;
# to output perl code, set "XSLATE=pp=dump"

use Any::Moose;
use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;
use Text::Xslate::Util qw($DEBUG p value_to_literal);

use constant _DUMP_PP => scalar($DEBUG =~ /\b dump=pp \b/xms);

use constant _FOR_ITEM  => 0;
use constant _FOR_ITER  => 1;
use constant _FOR_ARRAY => 2;

my %CODE_MANIP = ();

our @CARP_NOT = qw(Text::Xslate);

has indent_depth => ( is => 'rw', default => 1 );

has indent_space => ( is => 'rw', default => '    ' );

has lines => ( is => 'rw', default => sub { []; } );

has macro_lines => ( is => 'rw', default => sub { []; } );

has ops => ( is => 'rw', default => sub { []; } );

has current_line => ( is => 'rw', default => 0 );

has exprs => ( is => 'rw' );

has sa => ( is => 'rw' );

has sb => ( is => 'rw' );

has lvar => ( is => 'rw', default => sub { []; } ); # local variable

has framename => ( is => 'rw', default => 'main' ); # current frame name

has SP => ( is => 'rw', default => sub { []; } ); # stack

has is_completed => ( is => 'rw', default => 1 );

has stash => ( is => 'rw', default => sub { {}; } ); # store misc data

our %html_escape = (
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    "'" => '&apos;',
);
our $html_unsafe_chars = sprintf '[%s]', join '', map { quotemeta } keys %html_escape;

#
# public APIs
#

sub opcode_to_perlcode {
    my ( $self, $opcode ) = @_;

    my $perlcode = $self->opcode_to_perlcode_string( $opcode );

    print STDERR "$perlcode\n" if _DUMP_PP;

    return eval($perlcode) || Carp::confess("Eval error: $@");
}


sub opcode_to_perlcode_string {
    my ( $self, $opcode, $opt ) = @_;

    $self->_convert_opcode( $opcode, undef, $opt );

    my $perlcode = sprintf("#line %d %s\n", 1, __FILE__) . <<'CODE';
sub {
    no warnings 'recursion';
    my ( $st ) = @_;
    my ( $sv, $pad, %macro, $depth );
    my $output = q{};
    my $vars   = $st->{ vars };

    $pad = [ [ ] ];

CODE

    if ( @{ $self->macro_lines } ) {
        $perlcode .= "    # macro\n\n";
        $perlcode .= join ( '', grep { defined } @{ $self->macro_lines } );
    }

    $perlcode .= "    # process start\n\n";
    $perlcode .= join( '', grep { defined } @{ $self->{lines} } );
    $perlcode .= "\n" . '    return $output;' . "\n}";

    return $perlcode;
}


#
# op to perl
#

$CODE_MANIP{ 'noop' } = sub {};


$CODE_MANIP{ 'move_to_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sb( $self->sa );
};


$CODE_MANIP{ 'move_from_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $self->sb );
};


$CODE_MANIP{ 'save_to_lvar' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $v = sprintf( '( $pad->[ -1 ]->[ %s ] = %s )', $arg, $self->sa );
    $self->lvar->[ $arg ] = $self->sa;
    $self->sa( $v );

    my $op = $self->ops->[ $self->current_line + 1 ];

    unless ( $op and $op->[0] =~ /^(?:print|and|or|dand|dor|push)/ ) { # ...

        my $i = $self->current_line + 1;

        while ( my $op = $self->ops->[ ++$i ] ) {
            if ( $op->[0] =~ /^(?:print|and|or|dand|dor|push|for|macrocall)/ ) {
                last;
            }
            if ( $op->[0] eq 'load_lvar_to_sb' ) {
                return;
            }
        }

        $self->write_lines( sprintf( '%s;', $v )  );
    }

};


$CODE_MANIP{ 'local_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $key    = $arg;
    my $newval = $self->sa;

    $self->write_lines( sprintf( 'local_s( $st, "%s", %s );', $key, $newval ) );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'load_lvar_to_sb' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sb( $self->lvar->[ $arg ] );
};


$CODE_MANIP{ 'push' } = sub {
    my ( $self, $arg, $line ) = @_;
    push @{ $self->SP->[ -1 ] }, $self->sa;
};


$CODE_MANIP{ 'pushmark' } = sub {
    my ( $self, $arg, $line ) = @_;
    push @{ $self->SP }, [];
};


$CODE_MANIP{ 'nil' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( 'undef' );
};


$CODE_MANIP{ 'literal' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( value_to_literal( $arg ) );
};


$CODE_MANIP{ 'literal_i' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $arg );
    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'fetch_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '$vars->{ %s }', value_to_literal( $arg ) ) );
};


$CODE_MANIP{ 'fetch_lvar' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->sa( sprintf( '$pad->[ -1 ]->[ %s ]', $arg ) );

    if ( $self->stash->{ in_macro } ) {
        my $macro = $self->stash->{ in_macro };
        unless ( exists $self->stash->{ macro_args_num }->{ $macro }->{ $arg } ) {
            $self->write_lines(
                sprintf(
                    '_error( $st, %s, %s, "Too few arguments for %s" );',
                    $self->frame_and_line, $self->stash->{ in_macro }
                )
            );
        }
    }

};


$CODE_MANIP{ 'fetch_field' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->sa( sprintf( 'fetch( $st, %s, %s, %s, %s )', $self->sb(), $self->sa(), $self->frame_and_line ) );
};


$CODE_MANIP{ 'fetch_field_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();

    $self->sa( sprintf( 'fetch( $st, %s, %s, %s, %s )', $sv, value_to_literal( $arg ), $self->frame_and_line ) );
};


$CODE_MANIP{ 'print_raw' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    my $err = sprintf( '_warn( $st, %s, %s, "Use of nil to print" );', $self->frame_and_line );

    $self->write_lines( sprintf( <<'CODE', $sv, $err ) );
# print_raw
if ( defined(my $s = %s) ) {
    $output .= $s;
}
else {
   %s
}
CODE
};


$CODE_MANIP{ 'ex_print_raw' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    $self->write_lines( sprintf(<<'CODE', $sv) );
# ex_print_raw
$output .= %s;
CODE
};


$CODE_MANIP{ 'print_raw_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( sprintf(<<'CODE', value_to_literal( $arg )) );
# print_raw_s
$output .= %s;
CODE
};


$CODE_MANIP{ 'print' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    my $err;

    $err = sprintf( '_warn( $st, %s, %s, "Use of nil to print" );', $self->frame_and_line );

    $self->write_lines( sprintf( <<'CODE', $sv, $err ) );
# print
$sv = %s;
if ( ref($sv) eq 'Text::Xslate::EscapedString' ) {
    $output .= $sv;
}
elsif ( defined $sv ) {
    $sv =~ s/($html_unsafe_chars)/$html_escape{$1}/xmsgeo;
    $output .= $sv;
}
else {
    %s
}
CODE

};


$CODE_MANIP{ 'include' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( sprintf( <<'CODE', $self->sa ) );
# include
{
    my $st2 = Text::Xslate::PP::tx_load_template( $st->self, %s );
    $output .= Text::Xslate::PP::tx_execute( $st2, $vars );
}
CODE

};


$CODE_MANIP{ 'for_start' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->stash->{ for_start_line } = $self->current_line;

    push @{ $self->stash->{ for_level } }, {
        stack_id => $arg,
        ar       => $self->sa,
    };
};


$CODE_MANIP{ 'for_iter' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->stash->{ loop }->{ $self->current_line } = 1; # marked

    my $stack_id = $self->stash->{ for_level }->[ -1 ]->{ stack_id };
    my $ar       = $self->stash->{ for_level }->[ -1 ]->{ ar };

    if ( $self->stash->{ in_macro } ) { # check for fetch_lvar
        $self->stash->{ macro_args_num }->{ $self->framename }->{ $self->sa() } = 1;
    }

    my $item_var = sprintf '$pad->[-1][%s+_FOR_ITEM]',  $self->sa();
    my $iterator = sprintf '$pad->[-1][%s+_FOR_ITER]',  $self->sa();
    my $array    = sprintf '$pad->[-1][%s+_FOR_ARRAY]', $self->sa();

    $self->write_lines(
        sprintf( '%s = check_itr_ar( $st, %s, %s, %s );',
            $array, $ar,
            value_to_literal($self->framename), $self->stash->{ for_start_line } )
    );
    $self->write_lines(sprintf <<'CODE', $iterator, $array);
for(%1$s = 0; %1$s < @{%2$s}; %1$s++) {
CODE

    $self->indent_depth( $self->indent_depth + 1 );

    $self->write_lines( sprintf( '%s = %s->[ %s ];', $item_var, $array, $iterator ) );
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


$CODE_MANIP{ 'and' } = sub {
    my ( $self, $arg, $line ) = @_;
    return $self->_check_logic( and => $arg, $line );
};


$CODE_MANIP{ 'dand' } = sub {
    my ( $self, $arg, $line ) = @_;
    return $self->_check_logic( dand => $arg, $line );
};


$CODE_MANIP{ 'or' } = sub {
    my ( $self, $arg, $line ) = @_;
    return $self->_check_logic( or => $arg, $line );
};


$CODE_MANIP{ 'dor' } = sub {
    my ( $self, $arg, $line ) = @_;
    return $self->_check_logic( dor => $arg, $line );
};


$CODE_MANIP{ 'not' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    $self->sa( sprintf( '( !%s )', $sv ) );
};

$CODE_MANIP{ 'minus' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '- %s', $self->sa ) );
};

$CODE_MANIP{ 'size' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'scalar(@{%s})', $self->sa ) );
};


$CODE_MANIP{ 'eq' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'cond_eq( %s, %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'ne' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'cond_ne( %s, %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};



$CODE_MANIP{ 'lt' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s < %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'le' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s <= %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'gt' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s > %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'ge' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s >= %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'macrocall' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $ops  = $self->ops;

    $self->optimize_to_print( 'macro' );

    # mark argument value
    for my $i ( 0 .. $#{ $self->SP->[ -1 ] } ) {
        $self->stash->{ macro_args_num }->{ $self->sa }->{ $i } = 1;
    }

    $self->sa( sprintf( '$macro{ %s }->( $st, %s )',
        value_to_literal($self->sa()),
        sprintf( 'push_pad( $pad, [ %s ] )', join( ', ', @{ pop @{ $self->SP } } )  )
    ) );
};


$CODE_MANIP{ 'macro_begin' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->stash->{ macro_begin } = $self->current_line;
    $self->stash->{ in_macro }    = $arg;
    $self->framename( $arg );

    my $name = value_to_literal($arg);
    $self->write_lines( sprintf( '$macro{%s} = $st->{ booster_macro }->{%s} ||= sub {',
        $name, $name ) );
    $self->indent_depth( $self->indent_depth + 1 );

    $self->write_lines( 'my ( $st, $pad ) = @_;' );
    $self->write_lines( 'my $vars = $st->{ vars };' );
    $self->write_lines( sprintf( 'my $output = q{};' ) );
    $self->write_code( "\n" );

    $self->write_lines(
        sprintf( q{Carp::croak('Macro call is too deep (> 100) on %s') if ++$depth > 100;}, $name )
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
    $self->write_code( "\n" );

    delete $self->stash->{ in_macro };

    push @{ $self->macro_lines },
        splice( @{ $self->{ lines } },  $self->stash->{ macro_begin }, $self->current_line );
};


$CODE_MANIP{ 'macro' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( $arg );
};


$CODE_MANIP{ 'function' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa(
        sprintf('$st->function->{ %s }', value_to_literal($arg) )
    );
};


$CODE_MANIP{ 'funcall' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $args_str = join( ', ', @{ pop @{ $self->SP } } );

    $args_str = ', ' . $args_str if length $args_str;

    $self->sa(
        sprintf('call( $st, %s, %s, 0, %s%s )',
            $self->frame_and_line, $self->sa, $args_str
        )
    );
};


$CODE_MANIP{ 'methodcall_s' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->sa(
        sprintf('methodcall( $st, %s, %s, %s, %s )', $self->frame_and_line,
            value_to_literal($arg), join( ', ', @{ pop @{ $self->SP } } ) )
    );
};


$CODE_MANIP{ 'make_array' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $array = sprintf( '[ %s ]', join( ', ', @{ pop @{ $self->SP } } ) );

    $self->sa( $array );
};


$CODE_MANIP{ 'make_hash' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $array = sprintf( '{ %s }', join( ', ', @{ pop @{ $self->SP } } ) );

    $self->sa( $array );
};


$CODE_MANIP{ 'enter' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( <<'CODE' );
push @{ $st->{ save_local_stack } ||= [] }, delete $st->{ local_stack };
CODE

};


$CODE_MANIP{ 'leave' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( <<'CODE' );
$st->{ local_stack } = pop @{ $st->{ save_local_stack } };
CODE

};


$CODE_MANIP{ 'goto' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $i = $self->current_line;

    if ( delete $self->stash->{ loop }->{ $i + $arg + 1 } ) {
        # finish "for" blocks
        $self->indent_depth( $self->indent_depth - 1 );
        pop @{ $self->stash->{ for_level } };
        $self->write_lines( '}' );
    }
    else {
        die "invalid goto op";
    }

    $self->write_code( "\n" );
};


$CODE_MANIP{ 'depend' } = sub {};


$CODE_MANIP{ 'end' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( "# process end" );
};


#
# Internal APIs
#

sub _spawn_child {
    my ( $self, $opts ) = @_;
    $opts ||= {};
    ( ref $self )->new($opts);
}


sub _convert_opcode {
    my ( $self, $ops_orig ) = @_;

    my $ops  = [ map { [ @$_ ] } @$ops_orig ]; # this method is destructive to $ops. so need to copy.
    my $len  = scalar( @$ops );

    # reset
    if ( $self->is_completed ) {
        $self->sa( undef );
        $self->sb( undef );
        $self->lvar( [] );
        $self->lines( [] );
        $self->SP( [] );
        $self->stash( {} );
        $self->is_completed( 0 );
    }

    $self->ops( $ops );

    # create code
    my $i = 0;

    while ( $self->current_line < $len ) {
        my $op = $ops->[ $i ];

        if ( ref $op ne 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$op;

        my $manip  = $CODE_MANIP{ $opname };
        unless ( $manip ) {
            Carp::croak( sprintf( "Oops: opcode '%s' is not yet implemented on Booster", $opname ) );
        }

        if ( my $proc = $self->stash->{ proc }->{ $i } ) {
            if ( $proc->{ skip } ) {
                $self->current_line( ++$i );
                next;
            }
        }

        $manip->( $self, $arg, defined $line ? $line : '' );

        $self->current_line( ++$i );
    }

    $self->is_completed( 1 );

    return $self;
}


sub _check_logic {
    my ( $self, $type, $addr ) = @_;
    my $i = $self->current_line;

    $self->write_lines("# $type [$i]");

    my $ops = $self->ops;

    my $next_opname = $ops->[ $i + $addr ]->[ 0 ] || '';

    if ( $next_opname =~ /and|or/ ) { # &&, ||
        my $fmt = $type eq 'and'  ? ' && '
                : $type eq 'dand' ? 'defined( %s )'
                : $type eq 'or'   ? ' || '
                : $type eq 'dor'  ? '!(defined( %s ))'
                : die $type;
        my $pre_exprs = $self->exprs || '';
        $self->exprs( $pre_exprs . $self->sa() . $fmt ); # store
        return;
    }

    my $opname = $ops->[ $i + $addr - 1 ]->[ 0 ]; # goto or ?
    my $oparg  = $ops->[ $i + $addr - 1 ]->[ 1 ];

    my $fmt = $type eq 'and'  ? '%s'
            : $type eq 'dand' ? 'defined( %s )'
            : $type eq 'or'   ? '!( %s )'
            : $type eq 'dor'  ? '!(defined( %s ))'
            : die $type;

    if ( $opname eq 'goto' and $oparg > 0 ) { # if-else or ternary?
        my $if_block_start   = $i + 1;                  # open if block
        my $if_block_end     = $i + $addr - 2;           # close if block - subtract goto line
        my $else_block_start = $i + $addr;               # open else block
        my $else_block_end   = $i + $addr + $oparg - 2;  # close else block - subtract goto line

        my ( $sa_1st, $sa_2nd );

        $self->stash->{ proc }->{ $i + $addr - 1 }->{ skip } = 1; # skip goto

        for ( $if_block_start .. $if_block_end ) {
            $self->stash->{ proc }->{ $_ }->{ skip } = 1; # mark skip
        }

        my $has_else_block = ($else_block_end >= $else_block_start);

        my $last_opname = $ops->[ $i + $addr + $oparg - 1 ]->[0]; # check print or move_to_sb

        my $st_1st = $self->_spawn_child->_convert_opcode(
            [ @{ $ops }[ $if_block_start .. $if_block_end ] ]
        );

        # treat as ternary
        if ( $has_else_block and $last_opname and ( $last_opname eq 'print' or $last_opname eq 'move_to_sb' ) ) {

            for (  $else_block_start .. $else_block_end ) { # 2
                $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
            }

            my $st_2nd = $self->_spawn_child->_convert_opcode( # add $last_code for nested ternary
                [ @{ $ops }[ $else_block_start .. $else_block_end ], [ $last_opname ] ]
            );

        $self->sa( sprintf(  <<'CODE', $self->sa, _rm_tailed_lf( $st_1st->sa ), _rm_tailed_lf( $st_2nd->sa ) ) );
cond_ternary( %s, sub { %s; }, sub { %s; } )
CODE

            return;
        }

        my $code = $st_1st->code;

        if ( $code and $code !~ /^\n+$/ ) {
            my $expr = $self->sa;
            $expr = ( $self->exprs || '' ) . $expr; # adding expr if exists
            $self->write_lines( sprintf( 'if ( %s ) {' , sprintf( $fmt, $expr ) ) );
            $self->exprs( '' );
            $self->write_lines( $code );
            $self->write_lines( sprintf( '}' ) );
        }
        else { # treat as ternary
            $sa_1st = $st_1st->sa;
        }

        if ( $has_else_block ) {

            for (  $else_block_start .. $else_block_end ) { # 2
                $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
            }

            # else block
            my $st_2nd = $self->_spawn_child->_convert_opcode(
                [ @{ $ops }[ $else_block_start .. $else_block_end ] ]
            );

            my $code = $st_2nd->code;
            if ( $code and $code !~ /^\n+$/ ) {
                $self->write_lines( sprintf( 'else {' ) );
                $self->write_lines( $code );
                $self->write_lines( sprintf( '}' ) );
            }
            else { # treat as ternary
                $sa_2nd = $st_2nd->sa;
            }

        }

        if ( defined $sa_1st and defined $sa_2nd ) {
            my $expr = $self->sa;
            $expr = ( $self->exprs || '' ) . $expr; # adding expr if exists
            $self->sa( sprintf( '(%s ? %s : %s)', sprintf( $fmt, $expr ), $sa_1st, $sa_2nd ) );
        }
        else {
            $self->write_code( "\n" );
        }

    }
    elsif ( $opname eq 'goto' and $oparg < 0 ) { # while
        my $while_block_start   = $i + 1;                  # open while block
        my $while_block_end     = $i + $addr - 2;           # close while block - subtract goto line

        for ( $while_block_start .. $while_block_end ) {
            $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
        }

        $self->stash->{ proc }->{ $i + $addr - 1 }->{ skip } = 1; # skip goto

        my $st_wh = $self->_spawn_child->_convert_opcode(
            [ @{ $ops }[ $while_block_start .. $while_block_end ] ]
        );

        my $expr = $self->sa;
        $expr = ( $self->exprs || '' ) . $expr; # adding expr if exists
        $self->write_lines( sprintf( 'while ( %s ) {' , sprintf( $fmt, $expr ) ) );
        $self->exprs( '' );
        $self->write_lines( $st_wh->code );
        $self->write_lines( sprintf( '}' ) );

        $self->write_code( "\n" );
    }
    elsif ( _logic_is_max_min( $ops, $i, $addr ) ) { # min, max

        for ( $i + 1 .. $i + 2 ) {
            $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
        }

        $self->sa( sprintf( '%s ? %s : %s', $self->sa, $self->sb, $self->lvar->[ $ops->[ $i + 1 ]->[ 1 ] ] ) );
    }
    else {

        my $true_start = $i + 1;
        my $true_end   = $i + $addr - 1; # add 1 for complete process line is next.

        for ( $true_start .. $true_end ) {
            $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
        }

        my $opts = { sa => $self->sa, sb => $self->sb, lvar => $self->lvar };
        my $st_true  = $self->_spawn_child( $opts )->_convert_opcode(
            [ @{ $ops }[ $true_start .. $true_end ] ]
        );

        my $expr = $self->sa;
        $expr = ( $self->exprs || '' ) . $expr; # adding expr if exists

        $self->sa( sprintf( <<'CODE', $type, $expr, _rm_tailed_lf( $st_true->sa ) ) );
cond_%s( %s, sub { %s } )
CODE

    }

    $self->write_lines("# end $type [$i]");
}


sub _logic_is_max_min {
    my ( $ops, $i, $arg ) = @_;
        $ops->[ $i     ]->[ 0 ] eq 'or'
    and $ops->[ $i + 1 ]->[ 0 ] eq 'load_lvar_to_sb'
    and $ops->[ $i + 2 ]->[ 0 ] eq 'move_from_sb'
    and $arg == 2
}


sub _rm_tailed_lf {
    my ( $str ) = @_;
    return unless defined $str;
    $str =~ s/\n+//;
    return $str;
}


#
# methods
#

sub indent {
    $_[0]->indent_space x $_[0]->indent_depth;
}


sub code {
    join( '', grep { defined $_ } @{ $_[0]->lines } );
}


sub frame_and_line {
    my ( $self ) = @_;
    ( value_to_literal($self->framename), $self->current_line );
}


sub write_lines {
    my ( $self, $lines, $idx ) = @_;
    my $code = '';

    $idx = $self->current_line unless defined $idx;

    my $indent = $self->indent;
    for my $line ( split/\n/, $lines, -1 ) {
        if($line ne '') {
            $code .= $indent . $line;
        }
        $code .= "\n";
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

    if ( $type eq 'num' ) { # currently num only
        $ops->[0] = 'print_raw';
    }
    elsif ( $type eq 'macro' ) { # extent op code for booster
        $ops->[0] = 'ex_print_raw';
    }

}


#
# functions called in booster code
#

sub neat {
    my($s) = @_;
    if ( defined $s ) {
        if ( ref($s) || Scalar::Util::looks_like_number($s) ) {
            return $s;
        }
        else {
            return qq{'$s'};
        }
    }
    else {
        return 'nil';
    }
}


sub call {
    my ( $st, $frame, $line, $method_call, $proc, @args ) = @_;
    my $ret;

    if ( $method_call ) { # XXX: fetch() doesn't use methodcall for speed
        my $obj = shift @args;

        unless ( defined $obj ) {
            _warn( $st, $frame, $line, "Use of nil to invoke method %s", $proc );
        }
        else {
            $ret = eval { $obj->$proc( @args ) };
            #_error( $st, $frame, $line, "%s\t...", $@) if $@;
        }
    }
    else { # function call
        if(!defined $proc) {
            if ( defined $line ) {
                my $c = $st->{code}->[ $line - 1 ];
                _error(
                    $st, $frame, $line, "Undefined function is called%s",
                    $c->{ opname } eq 'fetch_s' ? " $c->{arg}()" : ""
                );
            }
        }
        else {
            $ret = eval { $proc->( @args ) };
            _error( $st, $frame, $line, "%s\t...", $@) if $@;
        }
    }

    return $ret;
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
    sort    => [0, TX_ENUMERABLE],

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
                _error( $st, $frame, $line, "%s" . "\t...", $@ );
            }
            return $retval;
        }
        # fallback
    }

    if(!defined $invocant) {
        _warn( $st, $frame, $line, "Use of nil to invoke method %s", $method );
    }
    else {
        my $bm = $builtin_method{$method} || return undef;

        my($nargs, $klass) = @{$bm};
        if(@args != $nargs) {
            _error($st, $frame, $line,
                "Builtin method %s requires exactly %d argument(s), "
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

    if ( Scalar::Util::blessed($var) ) {
        return call( $st, $frame, $line, 1, $key, $var );
    }
    elsif ( ref $var eq 'HASH' ) {
        if ( defined $key ) {
            return $var->{ $key };
        }
        else {
            _warn( $st, $frame, $line, "Use of nil as a field key" );
        }
    }
    elsif ( ref $var eq 'ARRAY' ) {
        if ( Scalar::Util::looks_like_number($key) ) {
            return $var->[ $key ];
        }
        else {
            _warn( $st, $frame, $line, "Use of %s as an array index", neat( $key ) );
        }
    }
    elsif ( defined $var ) {
        _error( $st, $frame, $line, "Cannot access %s (%s is not a container)", neat($key), neat($var) );
    }
    else {
        _warn( $st, $frame, $line, "Use of nil to access %s", neat( $key ) );
    }

    return;
}


sub check_itr_ar {
    my ( $st, $ar, $frame, $line ) = @_;

    if ( ref($ar) ne 'ARRAY' ) {
        if ( defined $ar ) {
            _error( $st, $frame, $line, "Iterator variables must be an ARRAY reference, not %s", neat( $ar ) );
        }
        else {
            _warn( $st, $frame, $line, "Use of nil to iterate" );
        }
        $ar = [];
    }

    return $ar;
}


sub cond_ternary {
    my ( $value, $subref1, $subref2 ) = @_;
    $value ? $subref1->() : $subref2->();
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


sub push_pad {
    push @{ $_[0] }, $_[1];
    $_[0];
}


sub local_s {
    my( $st, $key, $newval ) = @_;
    my $vars       = $st->{vars};
    my $preeminent = exists $vars->{$key};
    my $oldval     = delete $vars->{$key};

    my $cleanup = $preeminent
            ? sub {  $vars->{$key} = $oldval; return }
            : sub { delete $vars->{$key};     return }
    ;

    push @{ $st->{local_stack} ||= [] }, bless( $cleanup, 'Text::Xslate::PP::Booster::Guard' );

    $vars->{$key} = $newval;
}


sub _verbose {
    my $v = $_[0]->self->{ verbose };
    defined $v ? $v : Text::Xslate::PP::TX_VERBOSE_DEFAULT;
}


sub _warn {
    my ( $st, $frame, $line, $fmt, @args ) = @_;
    if( _verbose( $st ) > Text::Xslate::PP::TX_VERBOSE_DEFAULT ) {
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ Text::Xslate::PP::TXframe_NAME ] = $frame;
        }
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


sub _error {
    my ( $st, $frame, $line, $fmt, @args ) = @_;
    if( _verbose( $st ) >= Text::Xslate::PP::TX_VERBOSE_DEFAULT ) {
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ Text::Xslate::PP::TXframe_NAME ] = $frame;
        }
        Carp::carp( sprintf( $fmt, @args ) );
    }
}


{
    package
        Text::Xslate::PP::Booster::Guard;

    sub DESTROY { $_[0]->() }
}


no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Text::Xslate::PP::Booster - Text::Xslate code generator to build Perl code

=head1 SYNOPSIS

    # If you want to check created codes, you can use it directly.
    use Text::Xslate::PP;
    use Text::Xslate::PP::Booster;

    my $tx      = Text::Xslate->new();
    my $booster = Text::Xslate::PP::Booster->new();

    my $optext  = q{<: $value :>};
    my $code    = $booster->opcode_to_perlcode_string( $tx->_compiler->compile( $optext ) );
    my $coderef = $booster->opcode_to_perlcode( $tx->_compiler->compile( $optext ) );
    # $coderef takes a Text::Xslate::PP::State object

=head1 DESCRIPTION

This module is a pure Perl engine, which is much faster than
Text::Xslate::PP::Opcode, but might be less stable.

The motivation to implement this engine is the performance.
You know the default pure Perl engine was really slow. For example:

    $ XSLATE=pp=opcode perl -Mblib benchmark/others.pl
    Perl/5.10.1 i686-linux
    Text::Xslate/0.1025
    Text::MicroTemplate/0.11
    Template/2.22
    Text::ClearSilver/0.10.5.4
    HTML::Template::Pro/0.94
    ...
    Benchmarks with 'list' (datasize=100)
             Rate Xslate     TT     MT    TCS     HT
    Xslate  155/s     --   -52%   -83%   -94%   -95%
    TT      324/s   109%     --   -64%   -88%   -90%
    MT      906/s   486%   180%     --   -66%   -73%
    TCS    2634/s  1604%   713%   191%     --   -21%
    HT     3326/s  2051%   927%   267%    26%     --


All right, it is slower than Template-Toolkit!
But now Text::Xslate::PP::Booster is available, and is as fast as Text::MicroTemplate:

    $ XSLATE=pp perl -Mblib benchmark/others.pl
    ...
    Benchmarks with 'list' (datasize=100)
             Rate     TT Xslate     MT    TCS     HT
    TT      330/s     --   -63%   -65%   -87%   -90%
    Xslate  896/s   172%     --    -5%   -65%   -73%
    MT      941/s   185%     5%     --   -63%   -72%
    TCS    2543/s   671%   184%   170%     --   -24%
    HT     3338/s   912%   272%   255%    31%     --

Text::Xslate::PP becomes much faster than the default pure Perl engine!

The engine is enabled by default, and disabled by C<< $ENV{ENV}='pp=opcode' >>.

=head1 APIs

=head2 new

Constructor.

    $booster = Text::Xslate::PP::Booster->new();

=head2 opcode_to_perlcode

Takes a virtual machine code created by L<Text::Xslate::Compiler>,
and returns a code reference.

  $coderef = $booster->opcode_to_perlcode( $ops );

The code reference takes C<Text::Xslate::PP::State> object in Xslate runtime processes.
Don't execute this code reference directly.

=head2 opcode_to_perlcode_string

Takes a virtual machine code created by C<Text::Xslate::Compiler>,
and returns a perl subroutine code text.

  $str = $booster->opcode_to_perlcode_string( $ops );

=head1 ABOUT BOOST CODE

C<Text::Xslate::PP::Booster> creates a code reference from a virtual machine code.

    $tx->render_string( <<'CODE', {} );
    : macro foo -> $arg {
        Hello <:= $arg :>!
    : }
    : foo($value)
    CODE

Firstly the template data is converted to opcodes:

    pushmark
    fetch_s "value"
    push
    macro "foo"
    macrocall
    print
    end
    macro_begin "foo"
    print_raw_s "    Hello "
    fetch_lvar 0
    print
    print_raw_s "!\n"
    macro_end

And the booster converted them into a perl subroutine code (you can get that
code by C<< XSLATE=dump=pp >>).

    sub {
        no warnings 'recursion';
        my ( $st ) = @_;
        my ( $sv, $pad, %macro, $depth );
        my $output = q{};
        my $vars   = $st->{ vars };

        $pad = [ [ ] ];

        # macro

        $macro{"foo"} = $st->{ booster_macro }->{"foo"} ||= sub {
            my ( $st, $pad ) = @_;
            my $vars = $st->{ vars };
            my $output = q{};

            Carp::croak('Macro call is too deep (> 100) on "foo"') if ++$depth > 100;

            # print_raw_s
            $output .= "        Hello ";


            # print
            $sv = $pad->[ -1 ]->[ 0 ];
            if ( ref($sv) eq 'Text::Xslate::EscapedString' ) {
                $output .= $sv;
            }
            elsif ( defined $sv ) {
                $sv =~ s/($html_unsafe_chars)/$html_escape{$1}/xmsgeo;
                $output .= $sv;
            }
            else {
                _warn( $st, "foo", 10, "Use of nil to print" );
            }

            # print_raw_s
            $output .= "!\n";


            $depth--;
            pop( @$pad );

            $output;
        };


        # process start

        # ex_print_raw
        $output .= $macro{ "foo" }->( $st, push_pad( $pad, [ $vars->{ "value" } ] ) );


        # process end

        return $output;
    }

So it makes the runtime speed much faster.
Of course, its initial converting process costs time and memory.

=head1 SEE ALSO

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
