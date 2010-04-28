package Text::Xslate::Compiler;
use 5.010;
use Mouse;

use Text::Xslate::Util;
use Text::Xslate::Parser;

use Scalar::Util ();

use constant _DUMP_ASM => ($Text::Xslate::DEBUG =~ /\b dump=asm \b/xms);
use constant _OPTIMIZE => ($Text::Xslate::DEBUG =~ /\b optimize=(\d+) \b/xms);

our @CARP_NOT = qw(Text::Xslate Text::Xslate::Parser);

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

my %unary = (
    '!' => 'not',
    '+' => 'plus',
    '-' => 'minus',
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

has lvar => ( # local varialbe id table
    is  => 'rw',
    isa => 'HashRef[Int]',

    default => sub{ {} },
);

has macro_table => (
    is  => 'rw',
    isa => 'HashRef',

    clearer => 'clear_macro_table',

    lazy    => 1,
    default => sub{ {} },
);

has engine => (
    is  => 'ro',
    isa => 'Object', # Text::Xslate

    weak_ref => 1,

    required => 0,
);

has parser => (
    is  => 'ro',
    isa => 'Object', # Text::Xslate::Parser

    handles => [qw(file line define_constant define_function)],

    default => sub {
        return Text::Xslate::Parser->new();
    },

    required => 0,
);

has cascading => (
    is  => 'rw',
    isa => 'Maybe[Str]',

    required => 0,
);

sub compile_str {
    my($self, $str) = @_;

    require Text::Xslate;

    return Text::Xslate->new(
        protocode    => $self->compile($str),

        # "in-place" mode
        path  => [],
        cache => 0,
    );
}

sub compile {
    my($self, $str, %args) = @_;

    my $parser = $self->parser;

    $parser->file($args{file}) if defined $args{file};
    $parser->line(0);

    my $ast = $parser->parse($str);

    # main
    my @code = $self->_compile_ast($ast);

    my $mtable = $self->macro_table;
    my $main = delete $mtable->{'@main'}; # cascade

    if(defined $main) {
        # all the main code will be discarded
        foreach my $c(@code) {
            if(!($c->[0] eq 'print_raw_s' && $c->[1] =~ m{\A [ \t\r\n]* \z}xms)) {
                if($c->[0] eq 'print_raw_s') {
                    Carp::carp("Xslate: Uselses use of text '$c->[1]'");
                }
                else {
                    Carp::carp("Xslate: Useless use of $c->[0] " . ($c->[1] // 'undef'));
                }
            }
        }

        @code = $self->_compile_cascade($main);
    }
    else {
        push @code, ['exit'];
    }

    # macros
    foreach my $macros(values %{ $mtable }) {
        foreach my $macro(ref($macros) eq 'ARRAY' ? @{$macros} : $macros) {
            push @code, [ 'macro_begin', $macro->{name}, $macro->{line} ];
            push @code, @{ $macro->{body} };
            push @code, [ 'macro_end' ];
        }
    }
    $self->clear_macro_table();

    $self->_optimize(\@code) for 1 .. $args{optimize} // _OPTIMIZE // 2;

    print "// ", $self->file, "\n", $self->as_assembly(\@code) if _DUMP_ASM;

    $self->file("<input>"); # reset

    return \@code;
}

sub _compile_ast {
    my($self, $ast) = @_;
    my @code;

    return unless defined $ast;

    confess("Not an ARRAY reference: $ast") if ref($ast) ne 'ARRAY';
    foreach my $node(@{$ast}) {
        blessed($node) or Carp::confess("Not a node object: $node");
        my $generator = $self->can('_generate_' . $node->arity)
            || Carp::croak("Cannot generate codes for " . $node->arity . ": " . $node->dump);

        push @code, $self->$generator($node);
    }

    return @code;
}

sub _compile_cascade {
    my($self, $main) = @_;
    my $mtable = $self->macro_table;

    my @code = @{$main};
    for(my $i = 0; $i < @code; $i++) {
        my $c = $code[$i];
        if($c->[0] ne 'macro_begin') {
            next;
        }

        # macro
        my $name = $c->[1];
        #warn "macro ", $name, "\n";

        if(exists $mtable->{$name}) {
            Carp::croak(
                "Xslate($mtable->{$name}{line}): " .
                "$name is already defined in " . $self->cascading . "\n" .
                "(you must use before/around/after to override blocks)",
            );
        }

        my $before = delete $mtable->{$name . '@before'};
        my $around = delete $mtable->{$name . '@around'};
        my $after  = delete $mtable->{$name . '@after'};

        if(defined $before) {
            my $n = scalar @code;
            foreach my $m(@{$before}) {
                splice @code, $i+1, 0, @{$m->{body}};
            }
            $i += scalar(@code) - $n;
        }

        my $macro_start = $i+1;
        $i++ while($code[$i][0] ne 'macro_end'); # move to the end

        if(defined $around) {
            my @original = splice @code, $macro_start, ($i - $macro_start);
            $i = $macro_start;

            my @body;
            foreach my $m(@{$around}) {
                push @body, @{$m->{body}};
            }
            for(my $j = 0; $j < @body; $j++) {
                if($body[$j][0] eq 'super') {
                    splice @body, $j, 1, @original;
                }
            }
            splice @code, $macro_start, 0, @body;

            $i += scalar(@body);
        }

        if(defined $after) {
            foreach my $m(@{$after}) {
                splice @code, $i, 0, @{$m->{body}};
            }
        }
    }
    $self->cascading(undef);
    return @code;
}

{
    package Text::Xslate;
    our %OPS; # to avoid 'once' warnings;
}

sub _generate_command {
    my($self, $node) = @_;

    my @code;

    my $proc = $node->id;
    foreach my $arg(@{ $node->first }){
        if(exists $Text::Xslate::OPS{$proc . '_s'} && $arg->arity eq 'literal'){
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
sub _generate_bare_command {
    my($self, $node) = @_;

    my @code;

    if($node->id eq 'cascade') {
        my $engine         = $self->engine
            // Carp::croak("Cannot cascade without an Xslate engine");
        my $template_name  = $node->first;
        #my $components_ref = $node->second;

        my $file = $template_name . $engine->{suffix};
        $file =~ s{::}{/}g;

        my $c = $self->macro_table->{'@main'} = $engine->load_file($file);
        $self->cascading($template_name);

        unshift @{$c}, [depend => Text::Xslate::Util::find_file($file, $engine->{path})->{fullpath}];
    }
    else {
        Carp::croak("Unknown command $node");
    }
    return @code;
}

sub _generate_for {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;
    if(@{$vars} != 1) {
        Carp::croak("For-loop requires single variable for each items");
    }
    my($iter_var) = @{$vars};

    my @code = $self->_generate_expr($expr);

    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $iter_var->id;

    local $self->lvar->{$lvar_name} = [ fetch_lvar => $lvar_id, undef, $lvar_name ];

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

    return @code;
}

sub _generate_proc { # block, before, around, after
    my($self, $node) = @_;
    my $type   = $node->id;
    my $name   = $node->first;
    my @args   = map{ $_->id } @{$node->second};
    my $block  = $node->third;

    local @{ $self->lvar }{ @args };
    my $arg_ix = 0;
    foreach my $arg(@args) {
        # to fetch ST(ix)
        # note that ix must start 1, not 0
        $self->lvar->{$arg} = [ fetch_arg => ++$arg_ix ];
    }

    my %macro = (
        type   => $type,
        name   => $name,
        nargs  => $arg_ix,
        body   => [ $self->_compile_ast($block) ],
        line   => $node->line,
    );

    if($type ~~ [qw(macro block)]) {
        if(exists $self->macro_table->{$name}) {
            Carp::croak("Redefinition of $type $name is found.");
        }
        $self->macro_table->{$name} = \%macro;
        if($type eq 'block') {
            return(
                [ pushmark  => () ],
                [ macro     => $name ],
                [ macrocall => undef ],
            );
        }
    }
    else {
        my $fq_name = sprintf '%s@%s', $name, $type;
        $macro{name} = $fq_name;
        push @{ $self->macro_table->{ $fq_name } //= [] }, \%macro;
    }

    return; # no code, only definition
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

    my @fetch;
    if(defined(my $lvar_code = $self->lvar->{$node->id})) {
        @fetch = @{$lvar_code};
    }
    else {
        @fetch = ( fetch_s => $self->_variable_to_value($node) );
    }
    $fetch[2] = $node->line;
    return \@fetch;
}

sub _generate_name {
    my($self, $node) = @_;

    return [ $node->id => undef, $node->line ];
}

sub _generate_literal {
    my($self, $node) = @_;

    my $value = $self->_literal_to_value($node);
    if(defined $value){
        return [ literal => $value ];
    }
    else {
        return [ nil => undef ];
    }
}

sub _generate_unary {
    my($self, $node) = @_;

    given($node->id) {
        when(%unary) {
            return
                $self->_generate_expr($node->first),
                [ $unary{$_} => () ];
        }
        default {
            Carp::croak("Unary operator $_ is not implemented");
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
    my $callable = $node->first; # function or macro
    my $args     = $node->second;

    my @code = (
        [ pushmark => () ],
        (map { $self->_generate_expr($_), [ 'push' ] } @{$args}),
        $self->_generate_expr($callable),
    );

    if($code[-1][0] eq 'macro') {
        push @code, [ macrocall => undef, $node->line ];
    }
    else {
        push @code, [ funcall => undef, $node->line ];
    }
    return @code;
}

sub _generate_function {
    my($self, $node) = @_;

    return [ function => $node->value ];
}

sub _generate_macro {
    my($self, $node) = @_;

    return [ macro => $node->value ];
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

my %goto_family;
@goto_family{qw(
    for_iter
    and
    or
    dor
    goto
)} = ();

sub _noop {
    my($op) = @_;
    @{$op} = (noop => undef, undef, "ex-$op->[0]");
    return;
}

sub _optimize {
    my($self, $c) = @_;

    for(my $i = 0; $i < @{$c}; $i++) {
        given($c->[$i][0]) {
            when('print_raw_s') {
                # merge a set of print_raw_s into single command
                for(my $j = $i + 1;
                    $j < @{$c} && $c->[$j][0] eq 'print_raw_s';
                    $j++) {

                    $c->[$i][1] .= $c->[$j][1];

                    _noop($c->[$j]);
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
                my $it = $c->[$i];
                my $nn = $c->[$i+2]; # next next
                if(defined($nn)
                    && $nn->[0] eq 'load_lvar_to_sb'
                    && $nn->[1] == $it->[1]) {
                    @{$it} = ('move_sa_to_sb', undef, undef, "ex-$it->[0]");

                    _noop($nn);
                }
            }
            when('literal') {
                if(Mouse::Util::TypeConstraints::Int($c->[$i][1])) {
                    $c->[$i][0] = 'literal_i';
                }
            }
            when('fetch_field') {
                my $prev = $c->[$i-1];
                if($prev->[0] =~ /^literal/) { # literal or literal_i
                    $c->[$i][0] = 'fetch_field_s';
                    $c->[$i][1] = $prev->[1];

                    _noop($prev);
                }
            }
        }
    }

    # recalculate goto addresses
    # eg:
    #
    # goto +3
    # foo
    # noop
    # bar // goto destination
    #
    # to be:
    #
    # goto +2
    # foo
    # bar // goto destination

    my @goto_addr;
    for(my $i = 0; $i < @{$c}; $i++) {
        if(exists $goto_family{ $c->[$i][0] }) {
            my $addr = $c->[$i][1]; # relational addr

            # mark ragens that goto family have its effects
            my @range = $addr > 0
                ? ($i .. ($i+$addr-1))  # positive
                : (($i+$addr) .. $i); # negative

            foreach my $j(@range) {
                push @{$goto_addr[$j] //= []}, $c->[$i];
            }
        }
    }

    # remove noop
    for(my $i = 0; $i < @{$c}; $i++) {
        if($c->[$i][0] eq 'noop') {
            if(defined $goto_addr[$i]) {
                foreach my $goto(@{ $goto_addr[$i] }) {
                    # reduce its absolute value
                    $goto->[1] > 0
                        ? $goto->[1]--  # positive
                        : $goto->[1]++; # negative
                }
            }
            splice @{$c}, $i, 1;
            # adjust @goto_addr, but it may be empty
            splice @goto_addr, $i, 1 if @goto_addr > $i;
        }
    }
    return;
}

sub as_assembly {
    my($self, $code_ref) = @_;

    my $addix = ($Text::Xslate::DEBUG =~ /\b addix \b/xms);

    my $as = "";
    foreach my $ix(0 .. (@{$code_ref}-1)) {
        my($opname, $arg, $line, $comment) = @{$code_ref->[$ix]};
        $as .= "$ix:" if $addix;

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

=head1 NAME

Text::Xslate::Compiler - An Xslate compiler

=cut
