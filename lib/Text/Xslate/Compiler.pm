package Text::Xslate::Compiler;
use 5.010;
use Mouse;

use Text::Xslate;
use Scalar::Util ();

use constant _DUMP_ASM => ($Text::Xslate::DEBUG =~ /\b dump=asm \b/xms);
use constant _OPTIMIZE => ($Text::Xslate::DEBUG =~ /\b optimize=(\d+) \b/xms);

extends qw(Text::Xslate::Parser);

our @CARP_NOT = qw(Text::Xslate);

my %bin = (
    '==' => 'eq',
    '!=' => 'ne',
    '<'  => 'lt',
    '<=' => 'le',
    '>'  => 'gt',
    '>=' => 'ge',

    '+'  => 'add',
    '-'  => 'sub',
    '*'  => 'mul',
    '/'  => 'div',
    '%'  => 'mod',

    '~'  => 'concat',

    '|'  => 'filt',

    '['  => 'fetch_field',
);
my %bin_r = (
    '&&' => 'and',
    '||' => 'or',
    '//' => 'dor',
);

has lvar_id => ( # local varialbe id
    is  => 'rw',
    isa => 'Int',

    traits  => [qw(Counter)],
    handles => {
        _lvar_id_inc => 'inc',
        _lvar_id_dec => 'dec',
    },

    default => 0,
);

has lvar => ( # local varialbe table
    is  => 'rw',
    isa => 'HashRef[Int]',

    default => sub{ {} },
);

sub compile_str {
    my($self, $str) = @_;

    return Text::Xslate->new(
        protocode    => $self->compile($str),

        # "in-place" mode
        path  => [],
        cache => 0,
    );
}

sub compile {
    my($self, $str, $optimize) = @_;

    my $ast = $self->parse($str);

    my @code = $self->_compile_ast($ast);

    $self->_optimize(\@code) if $optimize // _OPTIMIZE // 1;

    print $self->as_assembly(\@code) if _DUMP_ASM;
    return \@code;
}

sub _compile_ast {
    my($self, $ast) = @_;
    my @code;

    return unless defined $ast;

    confess("Not an ARRAY reference: $ast") if ref($ast) ne 'ARRAY';
    foreach my $node(@{$ast}) {
        my $generator = $self->can('_generate_' . $node->arity)
            || Carp::croak("Cannot generate codes for " . $node->dump);

        push @code, $self->$generator($node);
    }

    return @code;
}

sub _generate_command {
    my($self, $node) = @_;

    my @code;

    my $proc = $node->id;
    foreach my $arg(@{ $node->first }){
        if($arg->arity eq 'literal'){
            my $value = $self->_literal_to_value($arg);
            push @code, [ $proc . '_s' => $value, $node->line ];
        }
        else {
            push @code,
                $self->_generate_expr($arg),
                [ $proc => undef, $node->line ];
        }
    }
    return @code;
}

sub _generate_proc {
    my($self, $node) = @_;
    my $expr     = $node->first;
    my $iter_var = $node->second;
    my $block    = $node->third;

    my @code;

    given($node->id) {
        when("for") {

        push @code, $self->_generate_expr($expr);

        my $lvar_id   = $self->lvar_id;
        my $lvar_name = $iter_var->id;

        local $self->lvar->{$lvar_name} = $lvar_id;

        my $for_start = scalar @code;
        push @code, [ for_start => $lvar_id, $expr->line, $lvar_name ];

        # a for statement uses three local variables (container, iterator, and item)
        $self->_lvar_id_inc(3);
        my @block_code = $self->_compile_ast($block);
        $self->_lvar_id_dec(3);

        push @code,
            [ literal_i => $lvar_id, $expr->line, $lvar_name ],
            [ for_iter  => scalar(@block_code) + 2 ],
            @block_code,
            [ goto      => -(scalar(@block_code) + 2), undef, "end for" ];
        }
        default {
            confess("Not yet implemented: '$node'");
        }
    }
    return @code;
}


sub _generate_if {
    my($self, $node) = @_;

    my @expr  = $self->_generate_expr($node->first);
    my @then  = $self->_compile_ast($node->second);

    my $other = $node->third;
    my @else = blessed($other)
        ? $self->_generate_if($other)
        : $self->_compile_ast($other);

    return(
        @expr,
        [ and  => scalar(@then) + 2, undef, 'if' ],
        @then,
        [ goto => scalar(@else) + 1 ],
        @else,
    );
}

sub _generate_expr {
    my($self, $node) = @_;
    my @ast = ($node);

    return $self->_compile_ast(\@ast);
}

sub _generate_variable {
    my($self, $node) = @_;

    if(defined(my $lvar_id = $self->lvar->{$node->id})) {
        return [ fetch_lvar => $lvar_id, $node->line, $node->id ];
    }
    else {
        return [ fetch_s => $self->_variable_to_value($node), $node->line ];
    }
}

sub _generate_literal {
    my($self, $node) = @_;

    my $value = $self->_literal_to_value($node);
    if(Mouse::Util::TypeConstraints::Int($value)) {
        return [ literal_i => $value ];
    }
    elsif(defined $value){
        return [ literal => $value ];
    }
    else {
        return [ nil => undef ];
    }
}

sub _generate_unary {
    my($self, $node) = @_;

    given($node->id) {
        when('!') {
            return
                $self->_generate_expr($node->first),
                [ not => () ];
        }
        default {
            Carp::croak("Unary operator $_ is not yet implemented");
        }
    }
}

sub _generate_binary {
    my($self, $node) = @_;

    given($node->id) {
        when('.') {
            return
                $self->_generate_expr($node->first),
                [ fetch_field_s => $node->second->id ];
        }
        when(%bin) {
            my $lvar = $self->lvar_id;
            my @code = (
                $self->_generate_expr($node->first),
                [ store_to_lvar => $lvar ],
            );

            $self->_lvar_id_inc(1);
            push @code, $self->_generate_expr($node->second);
            $self->_lvar_id_dec(1);

            push @code,
                [ load_lvar_to_sb => $lvar ],
                [ $bin{$_}   => undef ];
            return @code;
        }
        when(%bin_r) {
            my @right = $self->_generate_expr($node->second);
            return
                $self->_generate_expr($node->first),
                [ $bin_r{$_} => scalar(@right) + 1 ],
                @right;
        }
        default {
            Carp::croak("Binary operator $_ is not yet implemented");
        }
    }
    return;
}

sub _generate_ternary { # the conditional operator
    my($self, $node) = @_;

    my @expr = $self->_generate_expr($node->first);
    my @then = $self->_generate_expr($node->second);

    my @else = $self->_generate_expr($node->third);

    return(
        @expr,
        [ and  => scalar(@then) + 2, $node->line, 'ternary' ],
        @then,
        [ goto => scalar(@else) + 1 ],
        @else,
    );
}

sub _generate_call {
    my($self, $node) = @_;
    my $function = $node->first;
    my $args     = $node->second;

    return(
        [ pushmark => () ],
        ( map { $self->_generate_expr($_), [ 'push' ] } @{$args} ),
        $self->_generate_expr($function),
        [ call => undef, $node->line ],
    );
}

sub _generate_function {
    my($self, $node) = @_;

    return [ function => $node->value ];
}

sub _variable_to_value {
    my($self, $arg) = @_;

    my $name = $arg->value;
    $name =~ s/\$//;
    return $name;
}


sub _literal_to_value {
    my($self, $arg) = @_;

    my $value = $arg->value // return undef;

    if($value =~ s/"(.*)"/$1/){
        $value =~ s/\\n/\n/g;
        $value =~ s/\\t/\t/g;
        $value =~ s/\\(.)/$1/g;
    }
    elsif($value =~ s/'(.*)'/$1/) {
        $value =~ s/\\(['\\])/$1/g; # ' for poor editors
    }
    return $value;
}

#my %goto;
#@goto{qw(
#    for_next
#    and
#    or
#    dor
#    goto
#)} = ();

sub _optimize {
    my($self, $cr) = @_;

    for(my $i = 0; $i < @{$cr}; $i++) {
        given($cr->[$i][0]) {
            when('print_raw_s') {
                # merge a set of print_raw_s into single command
                for(my $j = $i + 1;
                    $j < @{$cr} && $cr->[$j][0] eq 'print_raw_s';
                    $j++) {

                    my $op = $cr->[$j];
                    $cr->[$i][1] .= $op->[1];
                    @{$op} = (noop => undef, undef, 'optimized away');
                }
            }
            when('store_to_lvar') {
                # use registers, instead of local variables
                #
                # given:
                #   store_to_lvar $n
                #   blah blah blah
                #   load_lvar_to_sb $n
                # convert into:
                #   move_sa_to_sb
                #   blah blah blah
                my $it = $cr->[$i];
                my $nn = $cr->[$i+2]; # next next
                if(defined($nn)
                    && $nn->[0] eq 'load_lvar_to_sb'
                    && $nn->[1] == $it->[1]) {
                    @{$it} = ('move_sa_to_sb', undef, undef, 'optimized from store_to_lvar');

                    # replace to noop, need to adjust goto address
                    @{$cr->[$i+2]} = (noop => undef, undef, 'optimized away');
                }
            }
        }
    }

    # TODO: recalculate goto address
#    my @goto_addr;
#    for(my $i = 0; $i < @{$cr}; $i++) {
#        if(exists $goto{ $cr->[$i][0] }) { # goto family
#            my $addr = $cr->[$i][1]; # relational addr
#
#            my @range = $addr > 0
#                ? ($i .. ($i+$addr))
#                : (($i+$addr) .. $i);
#            foreach my $j(@range) {
#                push @{$goto_addr[$j] //= []}, $cr->[$i];
#            }
#        }
#    }
    return;
}


sub as_assembly {
    my($self, $code_ref) = @_;

    my $as = "";
    foreach my $op(@{$code_ref}) {
        my($opname, $arg, $line, $comment) = @{$op};
        $as .= $opname;
        if(defined $arg) {
            $as .= " ";

            if(Scalar::Util::looks_like_number($arg)){
                $as .= $arg;
            }
            else {
                $arg =~ s/\\/\\\\/g;
                $arg =~ s/\n/\\n/g;
                $arg =~ s/"/\\"/g;
                $as .= qq{"$arg"};
            }
        }
        if(defined $line) {
            $as .= " #$line";
        }
        if(defined $comment) {
            $as .= " // $comment";
        }
        $as .= "\n";
    }
    return $as;
}

no Mouse;
__PACKAGE__->meta->make_immutable;
