package Text::Xslate::Syntax::TTerse;
use Any::Moose;
use Text::Xslate::Util qw(p any_in);
use Scalar::Util ();

extends qw(Text::Xslate::Parser);

sub _build_identity_pattern {
    return qr/(?: [A-Za-z_] [A-Za-z0-9_]* )/xms;
}

# [% ... %] and %% ...
sub _build_line_start { '%%' }
sub _build_tag_start  { '[%' }
sub _build_tag_end    { '%]' }

around trim_code => sub {
    my($super, $self, $code) = @_;

    if($code =~ /^\#/) { # multiline comments
        return '';
    }

    return $super->($self, $code);
};

sub init_symbols {
    my($parser) = @_;
    my $s;

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

    $parser->symbol('SWITCH')   ->set_std(\&std_switch);
    $parser->symbol('switch')   ->set_std(\&std_switch);
    $s = $parser->symbol('CASE');
    $s->set_std(\&std_case);
    $s->is_block_end(1);
    $s = $parser->symbol('case');
    $s->set_std(\&std_case);
    $s->is_block_end(1);

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

around _build_iterator_element => sub {
    my($super, $parser) = @_;

    my $table = $super->($parser);

    # make aliases
    $table->{first} = $table->{is_first};
    $table->{last}  = $table->{is_last};
    $table->{next}  = $table->{peek_next};
    $table->{prev}  = $table->{peek_prev};
    $table->{max}   = $table->{max_index};

    return $table;
};

around advance => sub {
    my($super, $parser, $id) = @_;
    if(defined $id and $parser->token->id eq lc($id)) {
        $id = lc($id);
    }
    return $super->($parser, $id);
};

sub default_nud {
    my($parser, $symbol) = @_;
    return $symbol->clone(
        arity => 'variable',
    );
}

sub nud_dollar {
    my($parser, $symbol) = @_;
    my $expr;
    my $t = $parser->token;
    if($t->id eq "{") {
        $parser->advance("{");
        $expr = $parser->expression(0);
        $parser->advance("}");
    }
    else {
        if(!any_in($t->arity, qw(name variable))) {
            $parser->_unexpected("a name", $t);
        }
        $parser->advance();
        $expr = $t->clone( arity => 'variable' );
    }
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

    # special case: foo.$field, foo.${expr}
    if($parser->token->id eq '$') {
        return $symbol->clone(
            arity  => "field",
            first  => $left,
            second => $parser->expression( $symbol->lbp ),
        );
    }

    return $parser->SUPER::led_dot($symbol, $left);
}

sub led_concat {
    my($parser, $symbol, $left) = @_;

    return $parser->led_infix($symbol->clone(id => '~'), $left);
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

sub std_switch {
    my($parser, $symbol) = @_;

    $parser->new_scope();

    my $topic  = $parser->symbol('$_')->clone(arity => 'variable' );
    my $switch = $symbol->clone(
        arity  => 'given',
        first  => $parser->expression(0),
        second => [ $topic ],
    );

    local $parser->{in_given} = 1;

    my @cases;
    while(uc($parser->token->id) ne "END") {
        push @cases, $parser->statement();
    }
    $switch->third( \@cases );

    $parser->build_given_body($switch, "case");

    $parser->advance("END");
    $parser->pop_scope();
    return $switch;
}

sub std_case {
    my($parser, $symbol) = @_;
    if(!$parser->in_given) {
        $parser->_error("You cannot use $symbol statements outside switch statements");
    }
    my $case = $symbol->clone(arity => "case");

    if(uc($parser->token->id) ne "DEFAULT") {
        $case->first( $parser->expression(0) );
    }
    else {
        $parser->advance();
    }
    $case->second( $parser->statements() );
    return $case;
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
# cascade "foo.tt" { content => lambda@xxx() }
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

    my $call_content = $parser->call($content->first);

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
# : block filter_xxx | html -> {
#   ...
# : }
# in Kolon

sub std_filter {
    my($parser, $symbol) = @_;

    my $filter = $parser->expression(0);

    my $proc = $parser->lambda($symbol);

    $proc->second([]);
    $proc->third( $parser->statements() );
    $parser->advance("END");

    my $callmacro  = $parser->call($proc->first);

    if($filter->id eq 'html') {
        # for compatibility with TT2
        $filter = 'unmark_raw';
    }
    my $callfilter = $parser->call($filter, $callmacro);

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

    # PRE_PROCESS/POST_PROCESS
    $tx = Text::Xslate->new(
        syntax => 'TTerse',
        header => ['header.tt'],
        footer => ['footer.tt'],
    );

=head1 DESCRIPTION

TTerse is a subset of the Template-Toolkit 2 (and partially  3) syntax,
using C<< [% ... %] >> tags and C<< %% ... >> line code.

(TODO: I should concentrate on the difference between Template-Toolkit 2 and
TTerse)

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

Almost the same as L<Text::Xslate::Syntax::Kolon>, but C<< infix:<_> >> for
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

    [% IF logical_expression %]
        Case 1
    [% ELSIF logical_expression %]
        Case 2
    [% ELSE %]
        Case 3
    [% END %]

    [% UNLESS logical_expression %]
        Case 1
    [% ELSE %]
        Case 2
    [% END %]

    [% SWITCH expression %]
    [% CASE case1 %]
        Case 1
    [% CASE case2 %]
        Case 2
    [% CASE DEFAULT %]
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
        module => [qw(Text::Xslate::Bridge::TT2)],
    );

   print $tx->render_strig('[% "foo".length() %]'); # => 3

See L<Text::Xslate::Bridge>, or search for C<Text::Xslate::Bridge::*> on CPAN.

=head2 Misc.

CALL evaluates expressions, but does not print it.

    [% CALL expr %]

SET and assignments, although the use of them are strongly discouraged.

    [% SET var1 = expr1, var2 = expr2 %]
    [% var = expr %]

DEFAULT statements as a syntactic sugar to C<< SET var = var // expr >>:

    [% DEFAULT lang = "TTerse" %]

FILTER blocks:

    [% FILTER html -%]
    Hello, <Xslate> world!
    [% END -%]

=head1 CAVEAT

There are some differences between TTerse and Template-Toolkit.

=over

=item *

C<INCLUDE> of TTerse requires an expression for the file name, while
that of Template-Toolkit allows a bare token:

    [% INCLUDE  foo.tt  # doesn't work! %]
    [% INCLUDE "foo.tt" # OK %]

=item *

C<FOREACH item = list> is forbidden in TTerse. It must be C<FOREACH item IN list>.

=back

=head1 SEE ALSO

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

L<Text::Xslate::Bridge::TT2>

L<Text::Xslate::Bridge::TT2Like>

L<Text::Xslate::Bridge::Alloy>

=cut
