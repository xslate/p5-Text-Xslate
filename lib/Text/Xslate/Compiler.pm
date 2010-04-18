package Text::Xslate::Compiler;
use 5.010;
use Mouse;

use Text::Xslate;
use Scalar::Util ();

use constant _DUMP_CODE => !!$ENV{XSLATE_DUMP_CODE};

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
        lvar_id_inc => 'inc',
        lvar_id_dec => 'dec',
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
        path         => [],
        auto_compile => 0,
    );
}

sub compile {
    my($self, $str) = @_;

    my $ast = $self->parse($str);

    my @code = $self->_compile_ast($ast);

    $self->_optimize(\@code);

    print STDERR $self->as_assembly(\@code) if _DUMP_CODE;
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

sub _generate_for {
    my($self, $node) = @_;
    my $expr     = $node->first;
    my $iter_var = $node->second;
    my $block    = $node->third;

    my @code;

    push @code, $self->_generate_expr($expr);

    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $iter_var->id;

    local $self->lvar->{$lvar_name} = $lvar_id;

    my $for_start = scalar @code;
    push @code, [ for_start => $lvar_id, undef, $lvar_name ];

    $self->lvar_id_inc;
    push @code, $self->_compile_ast($block);
    $self->lvar_id_dec;

    push @code,
        [ literal_i => $lvar_id, undef, $lvar_name ],
        [ for_next  => -(scalar(@code) - $for_start) ];

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
        [ and    => scalar(@then) + 2, undef, 'if' ],
        @then,
        [ pc_inc => scalar(@else) + 1 ],
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
        return [ fetch_iter => $lvar_id, $node->line, $node->id ];
    }
    else {
        return [ fetch => $self->_variable_to_value($node), $node->line ];
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
            return
                $self->_generate_expr($node->first),
                [ push      => () ],
                $self->_generate_expr($node->second),
                [ pop_to_sb => () ],
                [ $bin{$_}  => () ];
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
        [ and    => scalar(@then) + 2, $node->line, 'ternary' ],
        @then,
        [ pc_inc => scalar(@else) + 1 ],
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

sub _optimize {
    my($self, $code_ref) = @_;

    for(my $i = 0; $i < @{$code_ref}; $i++) {
        if($code_ref->[$i][0] eq 'print_raw_s') {
            # merge a list of print_raw_s into single command
            for(my $j = $i + 1;
                $j < @{$code_ref} && $code_ref->[$j][0] eq 'print_raw_s';
                $j++) {
                my($op) = splice @{$code_ref}, $j, 1;
                $code_ref->[$i][1] .= $op->[1];
            }
        }
    }
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
