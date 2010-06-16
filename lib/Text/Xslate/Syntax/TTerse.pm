package Text::Xslate::Syntax::TTerse;
use Any::Moose;
use Text::Xslate::Util qw(p any_in);
use Scalar::Util ();

extends qw(Text::Xslate::Parser);

# [% ... %] and %% ...
sub _build_line_start { qr/%%/xms   }
sub _build_tag_start  { qr/\Q[%/xms }
sub _build_tag_end    { qr/\Q%]/xms }

around split => sub {
    my $super = shift;

    my $tokens_ref = $super->(@_);

    foreach my $t(@{$tokens_ref}) {
        my($type, $value) = @{$t};
        if($type eq 'code' && $value =~ /^#/) { # multiline comments
            $t->[1] = '';
        }
    }

    return $tokens_ref;
};

around parse => sub {
    my $super = shift;
    my($parser, $input, %args) = @_;

    my $compiler = $parser->compiler or return $super->(@_);
    my $engine   = $parser->engine   or return $super->(@_);

    my $header = delete $compiler->{header};
    my $footer = delete $compiler->{footer};

    if($header) {
        my $s = '';
        foreach my $file(@{$header}) {
            my $fullpath = $engine->find_file($file)->{fullpath};
            $s .= $engine->slurp( $fullpath );
            $compiler->requires($fullpath);
        }
        substr $input, 0, 0, $s;
    }

    if($footer) {
        my $s = '';
        foreach my $file(@{$footer}) {
            my $fullpath = $engine->find_file($file)->{fullpath};
            $s .= $engine->slurp( $fullpath );
            $compiler->requires($fullpath);
        }
        $input .= $s;
    }
    my $ast = $super->($parser, $input, %args);

    return $ast;
};

sub init_symbols {
    my($parser) = @_;

    $parser->symbol(']');
    $parser->symbol('}');

    $parser->init_basic_operators();
    $parser->symbol('$')->set_nud(\&nud_dollar);
    $parser->infix('_', $parser->symbol('~')->lbp, \&led_concat);
    $parser->symbol('.')->set_led(\&led_dot); # redefine

    # defines both upper cased and lower cased

    $parser->symbol('END')  ->is_block_end(1);
    $parser->symbol('end')  ->is_block_end(1);
    $parser->symbol('ELSE') ->is_block_end(1);
    $parser->symbol('else') ->is_block_end(1);
    $parser->symbol('ELSIF')->is_block_end(1);
    $parser->symbol('elsif')->is_block_end(1);

    $parser->symbol('IN');
    $parser->symbol('in');

    $parser->symbol('IF')      ->set_std(\&std_if);
    $parser->symbol('if')      ->set_std(\&std_if);
    $parser->symbol('UNLESS')  ->set_std(\&std_if);
    $parser->symbol('unless')  ->set_std(\&std_if);
    $parser->symbol('FOREACH') ->set_std(\&std_foreach);
    $parser->symbol('foreach') ->set_std(\&std_foreach);
    $parser->symbol('FOR')     ->set_std(\&std_foreach);
    $parser->symbol('for')     ->set_std(\&std_foreach);
    $parser->symbol('WHILE')   ->set_std(\&std_while);
    $parser->symbol('while')   ->set_std(\&std_while);

    $parser->symbol('INCLUDE') ->set_std(\&std_include);
    $parser->symbol('include') ->set_std(\&std_include);
    $parser->symbol('WITH');
    $parser->symbol('with');

    $parser->symbol('SET')     ->set_std(\&std_set);
    $parser->symbol('set')     ->set_std(\&std_set);
    $parser->symbol('DEFAULT') ->set_std(\&std_set);
    $parser->symbol('default') ->set_std(\&std_set);
    $parser->symbol('CALL')    ->set_std(\&std_call);
    $parser->symbol('call')    ->set_std(\&std_call);

    # macros

    $parser->symbol('MACRO') ->set_std(\&std_macro);
    $parser->symbol('macro') ->set_std(\&std_macro);
    $parser->symbol('BLOCK');
    $parser->symbol('block');

    $parser->symbol('WRAPPER')->set_std(\&std_wrapper);
    $parser->symbol('wrapper')->set_std(\&std_wrapper);
    $parser->symbol('INTO');
    $parser->symbol('into');

    $parser->symbol('FILTER')->set_std(\&std_filter);
    $parser->symbol('filter')->set_std(\&std_filter);

    return;
}

after init_iterator_elements => sub {
    my($parser) = @_;

    my $tab = $parser->iterator_element;

    $tab->{first} = $tab->{is_first};
    $tab->{last}  = $tab->{is_last};
    $tab->{next}  = $tab->{peek_next};
    $tab->{prev}  = $tab->{peek_prev};
    $tab->{max}   = $tab->{max_index};

    return;
};

around advance => sub {
    my($super, $parser, $id) = @_;
    if(defined $id and $parser->token->id eq lc($id)) {
        $id = lc($id);
    }
    return $super->($parser, $id);
};

sub nud_dollar {
    my($self, $symbol) = @_;
    $self->advance("{");
    my $expr = $self->expression(0);
    $self->advance("}");
    return $expr;
}

sub undefined_name {
    my($parser) = @_;
    # undefined names are always variables
    return $parser->symbol_table->{'(variable)'};
}

sub is_valid_field {
    my($parser, $token) = @_;
    return $parser->SUPER::is_valid_field($token)
        || $token->arity eq "variable";
}

sub led_dot {
    my($parser, $symbol, $left) = @_;

    my $rhs_starts_dollar = ($parser->token->id =~ qr/\A \$/xms);

    my $rhs;

    if($rhs_starts_dollar) { # var.$foo, var.${foo}
        $rhs = $parser->expression( $symbol->lbp );
        return $parser->binary("[", $left, $rhs);
    }
    else { # var.foo
        $rhs = $parser->token->clone( arity => 'literal' );
        $parser->advance();
    }

    my $dot = $parser->binary($symbol, $left, $rhs);

    my $t = $parser->token();
    if($t->id eq "(") { # foo.method()
        $parser->advance(); # "("
        $dot->third( $parser->expression_list() );
        $parser->advance(")");
        $dot->arity("methodcall");
    }
    return $dot;
}

sub led_concat {
    my($parser, $symbol, $left) = @_;

    return $parser->SUPER::led_infix($symbol->clone(id => '~'), $left);
}

sub led_assignment {
    my($parser, $symbol, $left) = @_;

    my $assign = $parser->led_infixr($symbol, $left);
    $assign->arity('assign');
    $assign->is_statement(1);

    my $name = $assign->first;
    if(not $parser->find($name->id)->is_defined) {
        $parser->define($name);
        $assign->third('declare');
    }

    return $assign;
}

sub assignment {
    my($parser, $id, $bp) = @_;

    $parser->symbol($id, $bp)->set_led(\&led_assignment);
    return;
}

sub std_if {
    my($parser, $symbol) = @_;
    my $if = $symbol->clone(arity => "if");

    $if->first(  $parser->expression(0) );
    if(uc($symbol->id) eq 'UNLESS') {
        my $not_expr = $parser->symbol('not')->clone(
            arity  => 'unary',
            first  => $if->first,
        );
        $if->first($not_expr);
    }
    $if->second( $parser->statements() );

    my $t = $parser->token;

    my $top_if = $if;

    while(uc($t->id) eq "ELSIF") {
        $parser->reserve($t);
        $parser->advance(); # "ELSIF"

        my $elsif = $t->clone(arity => "if");
        $elsif->first(  $parser->expression(0) );
        $elsif->second( $parser->statements() );
        $if->third([$elsif]);
        $if = $elsif;
        $t  = $parser->token;
    }

    if(uc($t->id) eq "ELSE") {
        $parser->reserve($t);
        $t = $parser->advance(); # "ELSE"

        $if->third( uc($t->id) eq "IF"
            ? [$parser->statement()]
            :  $parser->statements());
    }


    $parser->advance("END");
    return $top_if;
}

sub iterator_name {
    return 'loop'; # always 'loop'
}

sub std_foreach {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "for");

    my $var = $parser->token;
    if($var->arity ne "variable") {
        $parser->_unexpected("a variable name", $var);
    }
    $parser->advance();
    $parser->advance("IN");
    $proc->first( $parser->expression(0) );
    $proc->second([$var]);
    $parser->new_scope();
    $parser->define_iterator($var);
    $proc->third( $parser->statements() );
    $parser->advance("END");
    $parser->pop_scope();
    return $proc;
}

sub std_while {
    my($parser, $symbol) = @_;

    my $while = $symbol->clone(arity => "while");

    $while->first( $parser->expression(0) );
    $while->second([]); # no vars
    $parser->new_scope();
    $while->third( $parser->statements() );
    $parser->advance("END");
    $parser->pop_scope();
    return $while;
}

sub std_include {
    my($parser, $symbol) = @_;

    my $command = $parser->SUPER::std_include($symbol);
    $command->id( lc $command->id );
    return $command;
}

sub localize_vars {
    my($parser, $symbol) = @_;

# should make 'WITH' optional?
#    my $t = $parser->token;
#    if(uc($t->id) eq "WITH" or $t->arity eq "variable") {
#        $parser->advance() if uc($t->id) eq "WITH";
    if(uc($parser->token->id) eq "WITH") {
        $parser->advance();
        $parser->new_scope();
        my $vars = $parser->set_list();
        $parser->pop_scope();
        return $vars;
    }
    return undef;
}

sub set_list {
    my($parser) = @_;
    my @args;
    while(1) {
        my $key = $parser->token;

        if($key->arity ne "variable") {
            last;
        }
        $parser->advance();
        $parser->advance("=");

        my $value = $parser->expression(0);

        push @args, $key => $value;

        if($parser->token->id eq ",") { # , is optional
            $parser->advance();
        }
    }

    return \@args;
}

sub std_set {
    my($parser, $symbol) = @_;

    my $is_default = (uc($symbol->id) eq 'DEFAULT');

    my $set_list = $parser->set_list();
    my @assigns;
    for(my $i = 0; $i < @{$set_list}; $i += 2) {
        my($name, $value) = @{$set_list}[$i, $i+1];

        if($is_default) {
            my $var = $parser->symbol('(variable)')->clone(
                id => $name->id,
            );

            $value = $parser->binary('//', $var, $value);
        }
        my $assign = $symbol->clone(
            id     => '=',
            arity  => 'assign',
            first  => $name,
            second => $value,
        );

        if(not $parser->find($name->id)->is_defined) {
            $parser->define($name);
            $assign->third('declare');
        }
        push @assigns, $assign;
    }
    return @assigns;
}

sub std_call {
    my($parser, $symbol) = @_;
    return $parser->expression(0);
}

sub std_macro {
    my($parser, $symbol) = @_;
    my $proc = $symbol->clone(
        arity => 'proc',
        id    => 'macro',
    );

    my $name = $parser->token;
    if($name->arity ne "variable") {
        $parser->_error("a name", $name);
    }

    $parser->define_function($name->id);

    $proc->first($name);
    $parser->advance();

    $parser->new_scope();

    my $paren = ($parser->token->id eq "(");

    $parser->advance("(") if $paren;

    my $t = $parser->token;
    my @vars;
    while($t->arity eq "variable") {
        push @vars, $t;
        $parser->define($t);

        $t = $parser->advance();

        if($t->id eq ",") {
            $t = $parser->advance(); # ","
        }
        else {
            last;
        }
    }
    $parser->advance(")") if $paren;

    $proc->second(\@vars);

    $parser->advance("BLOCK");
    $proc->third( $parser->statements() );
    $parser->advance("END");
    $parser->pop_scope();
    return $proc;
}


# WRAPPER "foo.tt" ...  END
# is
# cascade "foo.tt" { content => content@xxx() }
# macro content@xxx -> { ... }
sub std_wrapper {
    my($parser, $symbol) = @_;

    my $base  = $parser->barename();
    my $into;
    if(uc($parser->token->id) eq "INTO") {
        my $t = $parser->advance();
        if(!any_in($t->arity, qw(name variable))) {
            $parser->_unexpected("a variable name", $t);
        }
        $parser->advance();
        $into = $t->id;
    }
    else {
        $into = 'content';
    }
    my $vars  = $parser->localize_vars() || [];
    my $body  = $parser->statements();
    $parser->advance("END");

    return $parser->wrap(
        $symbol,
        $base,
        $into,
        $vars,
        $body,
    );
}

sub wrap {
    my($parser, $proto, $base, $into, $vars, $body) = @_;
    my $cascade = $proto->clone(
        arity => 'cascade',
        first => $base,
    );

    my $content = $parser->lambda($proto);
    $content->second([]); # args
    $content->third($body);

    my $call_content = $proto->clone(
        arity  => 'call',
        first  => $content->first, # name
        second => [],
    );

    my $into_name = $proto->clone(
        arity => 'literal',
        id    => $into,
    );

    push @{$vars}, $into_name => $call_content;
    $cascade->third($vars);
    return( $cascade, $content );
}

# [% FILTER html %]
# ...
# [% END %]
# is
# : __block filter_xxx -> {
#   ...
# : } filter_001() | html
# in Kolon

sub std_filter {
    my($parser, $symbol) = @_;

    my $t = $parser->token;
    if($t->arity ne 'name') {
        $parser->_error("Expected filter name, not $t");
    }
    my $filter = $t->nud($parser);
    $parser->advance();

    my $proc = $parser->lambda($symbol);
    $proc->id('block'); # to return values without marking as raw

    $proc->second([]);
    $proc->third( $parser->statements() );
    $parser->advance("END");

    # _immediate_block() | filter

    my $callmacro = $symbol->clone(
        arity  => 'call',
        first  => $proc->first, # name
        second => [],           # args
    );
    my $callfilter  = $symbol->clone(
        arity  => 'call',
        first  => $filter,      # name
        second => [$callmacro], # args
    );
    my $print = $parser->symbol('print')->clone(
        arity => 'command',
        first => [$callfilter],
        line  => $symbol->line,
    );

    return( $proc, $print );
}

no Any::Moose;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::Syntax::TTerse - An alternative syntax compatible with Template Toolkit 2

=head1 SYNOPSIS

    use Text::Xslate;
    my $tx = Text::Xslate->new(
        syntax => 'TTerse',
    );

    print $tx->render_string(
        'Hello, [% dialect %] world!',
        { dialect => 'TTerse' }
    );

    # PRE_PROCESS/POST_PROCESS/WRAPPER
    $tx = Text::Xslate->new(
        syntax => 'TTerse',

        # those options are passed directly to TTerse
        header  => ['header.tt'],
        footer  => ['footer.tt'],
        wrapper => ['wrapper.tt'],
    );

=head1 DESCRIPTION

TTerse is a subset of the Template-Toolkit 2 (and partially  3) syntax,
using C<< [% ... %] >> tags and C<< %% ... >> line code.

(TODO: I should concentrate on the difference between Template-Toolkit 2 and
TTerse)

=head1 OPTIONS

There are options which are specific to TTerse.

=head2 C<< header => \@templates >>

Specify the header template files, which are inserted to the head of each template.

This option corresponds to Template-Toolkit's C<PRE_PROCESS> option.

=head2 C<< footer => \@templates >>

Specify the footer template files, which are inserted to the head of each template.

This option corresponds to Template-Toolkit's C<POST_PROCESS> option.

=head1 SYNTAX

This supports a Template-Toolkit compatible syntax, although the details might be different.

Note that lower-cased keywords, which are inspired in Template-Toolkit 3,
are also allowed.

=head2 Variable access

Scalar access:

    [%  var %]
    [% $var %]

Field access:

    [% var.0 %]
    [% var.field %]
    [% var.accessor %]
    [% var.$field ]%
    [% var[$field] # TTerse specific %]

Variables may be HASH references, ARRAY references, or objects.

If I<$var> is an object instance, you can call its methods.

    [% $var.method() %]
    [% $var.method(1, 2, 3) %]
    [% $var.method(foo => [1, 2, 3]) %]
    [% $var.method({ foo => 'bar' }) %]

=head2 Expressions

Almost the same as L<Text::Xslate::Syntax::Kolon>, but the C<_> operator for
concatenation is supported for compatibility.

=head2 Loops

    [% FOREACH item IN arrayref %]
        * [% item %]
    [% END %]

Loop iterators are partially supported.

    [% FOREACH item IN arrayref %]
        [%- IF loop.is_first -%]
        <first>
        [%- END -%]
        * [% loop.index %]
        * [% loop.count     # loop.index + 1 %]
        * [% loop.body      # alias to arrayref %]
        * [% loop.size      # loop.body.size %]
        * [% loop.max_index # loop.size - 1 %]
        * [% loop.peek_next # loop.body[ loop.index - 1 ]
        * [% loop.peek_prev # loop.body[ loop.index + 1 ]
        [%- IF loop.is_last -%]
        <last>
        [%- END -%]
    [% END %]

Template-Toolkit compatible names are also supported, but the use of them is
discouraged because they are not easy to understand:

    loop.max   # for loop.max_index
    loop.next  # for loop.peek_next
    loop.prev  # for loop.peek_prev
    loop.first # for loop.is_first
    loop.last  # for loop.is_last

=head2 Conditional statements

    [% IF expression %]
        This is true
    [% ELSE %]
        Tis is false
    [% END %]

    [% IF expression %]
        Case 1
    [% ELSIF expression %]
        Case 2
    [% ELSE %]
        Case 3
    [% END %]

=head2 Functions and filters

    [% var | f %]
    [% f(var)  %]

=head2 Template inclusion

The C<INCLUDE> statement is supported.

    [% INCLUDE "file.tt" %]
    [% INCLUDE $var %]

C<< WITH variablies >> syntax is also supported, although
the C<WITH> keyword is optional in Template-Toolkit:

    [% INCLUDE "file.tt" WITH foo = 42, bar = 3.14 %]
    [% INCLUDE "file.tt" WITH
        foo = 42
        bar = 3.14
    %]

The C<WRAPPER> statement is also supported.
The argument of C<WRAPPER>, however, must be string literals, because
templates will be statically linked while compiling.

    [% WRAPPER "file.tt" %]
    Hello, world!
    [% END %]

    %%# with variable
    [% WRAPPER "file.tt" WITH title = "Foo!" %]
    Hello, world!
    [% END %]

The content will be set into C<content>, but you can specify its name with
the C<INTO> keyword.

    [% WRAPPER "foo.tt" INTO wrapped_content WITH title = "Foo!" %]
    ...
    [% END %]

This is a syntactic sugar to template cascading. Here is a counterpart of
the example in Kolon.

    : macro my_content -> {
        Hello, world!
    : }
    : cascade "file.tx" { content => my_content() }

=head2 Macro blocks

Definition:

    [% MACRO foo BLOCK -%]
        This is a macro.
    [% END -%]

    [% MACRO add(a, b) BLOCK -%]
    [%  a + b -%]
    [% END -%]

Call:

    [% foo()     %]
    [% add(1, 2) %]

Unlike Template-Toolkit, calling macros requires parens (C<()>).

=head2 Virtual methods

A few methods are supported in the Xslate core.

    %% any.defined()

    %% a.size();
    %% a.join(", ");
    %% a.reverse();

    %% h.size();
    %% h.keys();
    %% h.values();
    %% h.kv();

However, there is a bridge mechanism that allows you to use more methods.
For example, Text::Xslate::Bridge::TT2 provides the TT2 pseudo
methods (a.k.a virtual methods) for Xslate, which uses Template::VMethods
implementation.

    use Text::Xslate::Bridge::TT2;

    my $tx = Text::Xslate->new(
        module => [qw(Text::Xslate:*Bridge::TT2)],
    );

   print $tx->render_strig('[% "foo".length() %]'); # => 3

See L<Text::Xslate::Bridge>, L<Text::Xslate::Bridge::TT2>, and
L<Text::Xslate::Bridge::Alloy> for details.

=head2 Misc.

CALL evaluates expressions, but does not print it.

    [% CALL expr %]

SET and assignments are supported, although the use of them are strongly
discouraged.

    [% SET var1 = expr1, var2 = expr2 %]
    [% var = expr %]

DEFAULT statements are supported as a syntactic sugar to C<< SET var = var // expr >>:

    [% DEFAULT lang = "TTerse" %]

FILTER blocks are supported:

    [% FILTER html -%]
    Hello, <Xslate> world!
    [% END -%]

=head1 SEE ALSO

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

=cut
