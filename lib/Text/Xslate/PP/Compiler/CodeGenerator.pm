package Text::Xslate::PP::Compiler::CodeGenerator;

use Any::Moose;
use Any::Moose '::Util::TypeConstraints';
use Text::Xslate::Util qw(
    value_to_literal
);

use Carp ();
use Scalar::Util ();

use Text::Xslate::Util qw(
    $DEBUG p neat
    value_to_literal
);
use Text::Xslate::PP::Const;
use Text::Xslate::PP::Booster;

use constant _DUMP_PP => scalar($DEBUG =~ /\b dump=pp \b/xms);

our($html_metachars, %html_escape);
BEGIN {
    *html_metachars = \$Text::Xslate::PP::html_metachars;
    *html_escape    = \%Text::Xslate::PP::html_escape;
}

my %CODE_MANIP = ();

our @CARP_NOT = qw(Text::Xslate Text::Xslate::PP::Method);

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

#
# public APIs
#
sub opcode_to_perlcode {
    my ( $self, $opcode ) = @_;

    my $perlcode = $self->opcode_to_perlcode_string( $opcode );
    return Text::Xslate::PP::Booster->compile($perlcode);
}


sub opcode_to_perlcode_string {
    my ( $self, $opcode, $opt ) = @_;

    $self->_convert_opcode( $opcode, undef, $opt );

#    my $output_size = $self->{ output_size } * 1000;
    my $perlcode = sprintf("#line %d %s\n", 1, __FILE__) . <<'CODE';
sub {
    no warnings 'recursion';
    my ( $st ) = @_;
    my ( $sv, $pad, %macro, $depth );
    my $output = q{};
    my $vars   = $st->{ vars };

    $st->{pad} = $pad = [ [ ] ];

CODE

#    $perlcode .= sprintf("    my \$output = pack 'x'.int(0+%s); \$output = '';\n", $output_size);

    if ( @{ $self->macro_lines } ) {
        $perlcode .= "    # macro\n\n";
        $perlcode .= join ( '', grep { defined } @{ $self->macro_lines } );
    }

    $perlcode .= "    # process start\n\n";
    $perlcode .= join( '', grep { defined } @{ $self->{lines} } );
    $perlcode .= "\n" . '    return $output;' . "\n}";

    print STDERR $perlcode, "\n" if _DUMP_PP;
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

    unless ( $op and $op->[0] =~ /^(?:print|and|or|dand|dor|push)$/ ) { # ...
        $self->write_lines( sprintf( '%s;', $v )  );
        # this save_to_lvar has nothing to do with macro args.
        $self->stash->{ exception_macro_args_num }->{ $self->framename }->{ $arg } = 1;
    }

};


$CODE_MANIP{ 'localize_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $key    = $arg;
    my $newval = $self->sa;

    $self->write_lines( sprintf( '$st->localize( %s => %s );', value_to_literal($key), $newval ) );
    $self->write_code( "\n" );
};


$CODE_MANIP{ 'load_lvar' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '$pad->[ -1 ]->[ %s ]', $arg ) );
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

            return if exists $self->stash->{ exception_macro_args_num }->{ $macro }->{ $arg };

            $self->write_lines(
                sprintf(
                    '$st->error( [%s, %s], "Too few arguments for %s" ) unless defined $pad->[ -1 ]->[ %s ];',
                    $self->frame_and_line, $self->stash->{ in_macro }, $arg
                )
            );
        }
    }

};


$CODE_MANIP{ 'fetch_field' } = sub {
    my ( $self, $arg, $line ) = @_;

    $self->sa( sprintf( '$st->fetch( %s, %s, %s, %s )', $self->sb(), $self->sa(), $self->frame_and_line ) );
};


$CODE_MANIP{ 'fetch_field_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();

    $self->sa( sprintf( '$st->fetch( %s, %s, %s, %s )', $sv, value_to_literal( $arg ), $self->frame_and_line ) );
};


$CODE_MANIP{ 'print_raw' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    my $err = sprintf( '$st->warn( [%s, %s], "Use of nil to print" );', $self->frame_and_line );

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
    $self->{ output_size } += length $arg;
    $self->write_lines( sprintf(<<'CODE', value_to_literal( $arg )) );
# print_raw_s
$output .= %s;
CODE
};


$CODE_MANIP{ 'print' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $sv = $self->sa();
    my $err;

    $err = sprintf( '$st->warn( [%s, %s], "Use of nil to print" );', $self->frame_and_line );

    $self->write_lines( sprintf( <<'CODE', $sv, $err, $err ) );
# print
$sv = %s;
if ( ref($sv) eq TXt_RAW ) {
    if(defined ${$sv}) {
        $output .= $sv;
    }
    else {
        %s
    }
}
elsif ( defined $sv ) {
    $sv =~ s/($html_metachars)/$html_escape{$1}/xmsgeo;
    $output .= $sv;
}
else {
    %s
}
CODE

};


$CODE_MANIP{ 'include' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( sprintf( <<'CODE', $self->sa, $self->current_line ) );
# include
{
    $st->{pc} = %2$s; # for error messages
    my $st2 = Text::Xslate::PP::tx_load_template( $st->engine, %1$s, 1 );
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

    my $item_var = sprintf '$pad->[-1][%s+TXfor_ITEM]',  $self->sa();
    my $iterator = sprintf '$pad->[-1][%s+TXfor_ITER]',  $self->sa();
    my $array    = sprintf '$pad->[-1][%s+TXfor_ARRAY]', $self->sa();

    $self->write_lines(
        sprintf( '%s = check_itr_ar( $st, %s, %s, %s );',
            $array, $ar,
            value_to_literal($self->framename), $self->stash->{ for_start_line } )
    );

#    $self->write_lines(sprintf <<'CODE', $iterator, $array);
#$itr_max = @{%2$s};
#for(%1$s = 0; %1$s < $itr_max; %1$s++) {
#CODE

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
    $self->sa( sprintf(<<'CODE', $self->sb(), $self->sa() ) );
    do {
        my $lhs = %s;
        my $rhs = %s;
        if($rhs == 0) {
            $st->error(undef, "Illegal modulus zero");
            'NaN';
        }
        else {
            $lhs %% $rhs;
        }
    }
CODE

    $self->optimize_to_print( 'num' );
};


$CODE_MANIP{ 'concat' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'Text::Xslate::PP::tx_concat( %s, %s )', $self->sb(), $self->sa() ) );
};

$CODE_MANIP{ 'repeat' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'Text::Xslate::PP::tx_repeat( %s, %s )', $self->sb(), $self->sa() ) );
};

$CODE_MANIP{ 'bitor' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( int(%s) | int(%s) )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'bitand' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( int(%s) & int(%s) )', $self->sb(), $self->sa() ) );
};

$CODE_MANIP{ 'bitxor' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( int(%s) ^ int(%s) )', $self->sb(), $self->sa() ) );
};


$CODE_MANIP{ 'bitneg' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( ~int(%s) )', $self->sa() ) );
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

$CODE_MANIP{ 'max_index' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '(scalar(@{%s}) - 1)', $self->sa ) );
};


$CODE_MANIP{ 'builtin_mark_raw' } = sub  {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'mark_raw( %s )', $self->sa ) );
    $self->optimize_to_print( 'raw' );
};


$CODE_MANIP{ 'builtin_unmark_raw' } = sub  {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'unmark_raw( %s )', $self->sa ) );
};


$CODE_MANIP{ 'builtin_html_escape' } = sub  {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'html_escape( %s )', $self->sa ) );
};

$CODE_MANIP{ 'builtin_uri' } = sub  {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'uri_escape( %s )', $self->sa ) );
};

$CODE_MANIP{ 'builtin_ref' } = sub  {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'ref( %s )', $self->sa ) );
};

$CODE_MANIP{ 'match' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'Text::Xslate::PP::tx_match( %s, %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'eq' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( 'Text::Xslate::PP::tx_sv_eq( %s, %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'ne' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '(!Text::Xslate::PP::tx_sv_eq( %s, %s ))', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
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


$CODE_MANIP{ 'ncmp' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s <=> %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};


$CODE_MANIP{ 'scmp' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->sa( sprintf( '( %s cmp %s )', _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) ) );
};

$CODE_MANIP{ 'range' } = sub {
    my ( $self, $arg, $line ) = @_;
    push @{ $self->SP->[ -1 ] }, sprintf('( %s .. %s )',
        _rm_tailed_lf( $self->sb() ), _rm_tailed_lf( $self->sa() ) );
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
        sprintf( 'push_pad( $pad, [ %s ] )', join( ', ', @{ pop @{ $self->SP } } )  ),
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

    $self->write_lines( 'my ( $st, $pad, $f_l ) = @_;' );
    $self->write_lines( 'my $vars = $st->{ vars };' );
    $self->write_lines( sprintf( 'my $mobj = $st->symbol->{ %s };', $name ) );
    $self->write_lines( sprintf( 'my $output = q{};' ) );
    $self->write_code( "\n" );

    my $error = sprintf(
        '$st->error( $f_l, _macro_args_error( $mobj, $pad ) )',
        $self->stash->{ in_macro }
    );

    $self->write_lines( sprintf( <<'CODE', $error ) );
if ( @{$pad->[-1]} != $mobj->nargs ) {
    %s;
    return '';
}
CODE

    $self->write_lines( sprintf( <<'CODE', $error ) );
if ( my $outer = $mobj->outer ) {
    my @temp = @{$pad->[-1]};
    @{$pad->[-1]}[ 0 .. $outer - 1 ] = @{$pad->[-2]}[ 0 .. $outer - 1 ];
    @{$pad->[-1]}[ $outer .. $outer + $mobj->nargs ] = @temp;
}
CODE


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
    $self->write_lines( sprintf( 'return mark_raw($output);' ) );

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


$CODE_MANIP{ 'fetch_symbol' } = sub {
    my ( $self, $arg, $line ) = @_;

    # macro
    if ( exists $self->stash->{ macro_names }->{ $arg } ) {
        my $next_op = $self->ops->[ $self->current_line + 1 ]; 
        if ( $next_op->[0] eq 'funcall' ) {
            $self->sa( $arg );
        }
        else {
            $self->sa( sprintf( '$st->symbol->{%s}', value_to_literal($arg) ) );
        }
        return;
    }

    $self->sa(
        sprintf('$st->fetch_symbol(%s, [%s, %s])', value_to_literal($arg), $self->frame_and_line )
    );
};


$CODE_MANIP{ 'funcall' } = sub {
    my ( $self, $arg, $line ) = @_;
    my $args_str = join( ', ', @{ pop @{ $self->SP } } );

    if ( exists $self->stash->{ macro_names }->{ $self->sa } ) { # this is optimization!
        $self->sa( sprintf( '$macro{ %s }->( $st, %s, [ %s ] )',
            value_to_literal( $self->sa() ),
            sprintf( 'push_pad( $pad, [ %s ] )', $args_str  ),
            join( ', ', $self->frame_and_line )
        ) );
        return;
    }

    $args_str = ', ' . $args_str if length $args_str;

    $self->sa(
        sprintf('call( $st, %s, %s, 0, %s%s )',
            $self->frame_and_line, $self->sa, $args_str
        )
    );
};


$CODE_MANIP{ 'methodcall_s' } = sub {
    my ( $self, $arg, $line ) = @_;
    require Text::Xslate::PP::Method;

    $self->sa(
        sprintf('Text::Xslate::PP::Method::tx_methodcall( $st, [%s, %s], %s, %s )', $self->frame_and_line,
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


$CODE_MANIP{ 'depend' } = $CODE_MANIP{'noop'};

$CODE_MANIP{ 'macro_nargs' } = $CODE_MANIP{'noop'};
$CODE_MANIP{ 'macro_outer' } = $CODE_MANIP{'noop'};
$CODE_MANIP{ 'set_opinfo'  } = $CODE_MANIP{'noop'};

$CODE_MANIP{ 'end' } = sub {
    my ( $self, $arg, $line ) = @_;
    $self->write_lines( "# process end" );
};
$CODE_MANIP{ 'perlcode_start'  } = $CODE_MANIP{'noop'};
$CODE_MANIP{ 'perlcode'  } = $CODE_MANIP{'noop'};
#
# Internal APIs
#

sub _spawn_child {
    my ( $self, $opts ) = @_;
    $opts ||= { stash => { macro_names => $self->stash->{ macro_names } } };

    ( ref $self )->new($opts);
}


sub _convert_opcode {
    my ( $self, $ops_orig ) = @_;

    my $ops  = [ map { [ @$_ ] } @$ops_orig ]; # this method is destructive to $ops. so need to copy.
    my $len  = scalar( @$ops );

    # check macro
    if ( not exists $self->stash->{ macro_names } ) {
        $self->stash->{ macro_names }
             = { map { ( $_->[1] => 1 ) } grep { $_->[0] eq 'macro_begin' } @$ops_orig };
    }

    # reset
    if ( $self->is_completed ) {
        my $macro_names = $self->stash->{ macro_names };
        $self->sa( undef );
        $self->sb( undef );
        $self->lvar( [] );
        $self->lines( [] );
        $self->SP( [] );
        $self->stash( {} );
        $self->stash->{ macro_names } = $macro_names; # inherit macro names
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

    my $ops = $self->ops;

    my $next_opname = $ops->[ $i + $addr ]->[ 0 ] || '';

    if ( $next_opname =~ /and|or/ ) { # &&, ||
        my $fmt = $type eq 'and'  ? '%s && %%s'
                : $type eq 'dand' ? $] < 5.010 ? 'cond_dand( %s, sub { %%s } )' : '%s // %%s'
                : $type eq 'or'   ? '%s || %%s '
                : $type eq 'dor'  ? $] < 5.010 ? 'cond_dor( %s, sub { %%s } )'  : '%s // %%s'
                : die $type;

        my $expr = sprintf( $fmt, $self->sa() );

        $self->exprs( sprintf( defined $self->exprs ? $self->exprs : '%s', $expr ) ); # store

        return;
    }

    my $opname = $ops->[ $i + $addr - 1 ]->[ 0 ]; # goto or ?
    my $oparg  = $ops->[ $i + $addr - 1 ]->[ 1 ];

    my $fmt = $type eq 'and'  ? '%s'
            : $type eq 'dand' ? 'defined( %s )'
            : $type eq 'or'   ? '!( %s )'
            : $type eq 'dor'  ? '!(defined( %s ))'
            : die $type;

    my $expr = $self->_cat_exprs; # concat $self->exprs and $self->sa, then clear $self->exprs

    if ( $opname eq 'goto' and $oparg > 0 ) { # if-else or ternary?
        my $if_block_start   = $i + 1;                   # open if block
        my $if_block_end     = $i + $addr - 2;           # close if block - subtract goto line
        my $else_block_start = $i + $addr;               # open else block
        my $else_block_end   = $i + $addr + $oparg - 2;  # close else block - subtract goto line

        my ( $sa_1st, $sa_2nd );

        $self->stash->{ proc }->{ $i + $addr - 1 }->{ skip } = 1; # skip goto

        for ( $if_block_start .. $if_block_end ) {
            $self->stash->{ proc }->{ $_ }->{ skip } = 1; # mark skip
        }

        my $has_else_block = ($else_block_end >= $else_block_start);

        my $st_1st = $self->_spawn_child->_convert_opcode(
            [ @{ $ops }[ $if_block_start .. $if_block_end ] ]
        );

        my $last_op = $ops->[ $i + $addr + $oparg - 1 ]; # check for ternary

        # treat as ternary
        if ( $has_else_block and $last_op and $last_op->[0] =~ /^(?:print|move_to_sb|push|d?and|d?or)$/ ) {

            for (  $else_block_start .. $else_block_end ) { # 2
                $self->stash->{ proc }->{ $_ }->{ skip } = 1; # skip
            }

            # add $last_code for nested ternary
            my $nested_ops = [ @{ $ops }[ $else_block_start .. $else_block_end ], $last_op ];
            # when last op is 'push', must add pushmark for avoiding to access non-creatable array value
            unshift @{ $nested_ops }, [ 'pushmark' ] if $last_op->[0] eq 'push';
            # last op is 'd?and' or 'd?or', that op must be removed for properly assign
            pop @{ $nested_ops } if $last_op->[0] =~ /^(?:d?and|d?or)$/;

            my $st_2nd = $self->_spawn_child->_convert_opcode( $nested_ops );

            if ( $last_op->[0] eq 'print' ) { # optimization
                return $self->sa(
                        sprintf( '( %s ? %s : %s )',
                        sprintf( $fmt, $expr ),
                        _rm_tailed_lf( $st_1st->sa ),
                        _rm_tailed_lf( $st_2nd->sa ),
                    )
                );
            }

            return $self->sa(
                sprintf( 'cond_ternary( %s, sub { %s; }, sub { %s; } )',
                    sprintf( $fmt, $expr ),
                    _rm_tailed_lf( $st_1st->sa ),
                    _rm_tailed_lf( $st_2nd->sa ),
                )
            );
        }

        my $code = $st_1st->get_code;

        if ( $code and $code !~ /^\n+$/ ) {
            $self->write_lines( sprintf( 'if ( %s ) {' , sprintf( $fmt, $expr ) ) );
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

            my $code = $st_2nd->get_code;
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

        $self->write_lines( sprintf( 'while ( %s ) {' , sprintf( $fmt, $expr ) ) );
        $self->write_lines( $st_wh->get_code );
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

        if ( _logic_is_sort( $ops, $i, $addr ) ) { # series of sort ops
            return $self->sa( sprintf( '( %s %s %s )', $expr, $type, $st_true->sa ) );
        }

        if ( my $code = $st_true->get_code ) { # Ah, if-style had gone..., but again write if-style!
            my $cond_type = $type eq 'and'  ? 'if ( %s )'
                          : $type eq 'or'   ? 'unless ( %s )'
                          : $type eq 'dand' ? 'if ( defined( %s ) )'
                          : $type eq 'dor'  ? 'unless ( defined( %s ) )'
                          : die "invalid logic type" # can't reache here
                          ;
            $self->write_lines( sprintf( "%s {\n%s\n}\n", sprintf( $cond_type, $expr ), $code ) );
        }
        elsif ( $st_true->sa ) {
            $self->sa( sprintf( 'cond_%s( %s, sub { %s } )', $type, $expr, _rm_tailed_lf( $st_true->sa ) ) );
        }
        else {
        }

    }

}


sub _logic_is_max_min {
    my ( $ops, $i, $arg ) = @_;
        $ops->[ $i     ]->[ 0 ] eq 'or'
    and $ops->[ $i + 1 ]->[ 0 ] eq 'load_lvar_to_sb'
    and $ops->[ $i + 2 ]->[ 0 ] eq 'move_from_sb'
    and $arg == 2
}


sub _logic_is_sort {
    my ( $ops, $i, $arg ) = @_;
        $ops->[ $i - 1  ]->[ 0 ]        =~ /[sn]cmp/
    and $ops->[ $i + $arg - 1 ]->[ 0 ]  =~ /[sn]cmp/
}


sub _rm_tailed_lf {
    my ( $str ) = @_;
    return unless defined $str;
    $str =~ s/\n+//;
    return $str;
}


sub _cat_exprs { # concat $self->exprs and $self->sa / clear $self->exprs
    my ( $self ) = @_;
    my $expr = $self->sa;
    $expr = sprintf( ( defined $self->exprs ?  $self->exprs : '%s' ), $expr ); # adding expr if exists
    $self->exprs( undef );
    return $expr;
}


#
# methods
#

sub indent {
    $_[0]->indent_space x $_[0]->indent_depth;
}


sub get_code {
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

    if ( $type eq 'num' ) {
        $ops->[0] = 'print_raw';
    }
    elsif ( $type eq 'raw' ) {
        $ops->[0] = 'print_raw';
    }
    elsif ( $type eq 'macro' ) { # extent op code for booster
        $ops->[0] = 'ex_print_raw';
    }

}



no Any::Moose;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::PP::Compiler::CodeGenerator - An Xslate code generator for PP::Booster

=head1 DESCRIPTION

This is the module to generate a perl code for Text::Xslate::PP::Booster.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

L<Text::Xslate::Compiler::PPBooster>

L<Text::Xslate::PP::Booster>

=cut
