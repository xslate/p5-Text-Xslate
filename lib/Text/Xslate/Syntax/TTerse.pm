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

sub init_symbols {
    my($parser) = @_;

    $parser->symbol(']');
    $parser->symbol('}');

    $parser->init_basic_operators();
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

    $parser->symbol('INCLUDE') ->set_std(\&std_include);
    $parser->symbol('include') ->set_std(\&std_include);
    $parser->symbol('WITH');
    $parser->symbol('with');

    # macros

    $parser->symbol('MACRO') ->set_std(\&std_macro);
    $parser->symbol('macro') ->set_std(\&std_macro);
    $parser->symbol('BLOCK');
    $parser->symbol('block');

    $parser->symbol('WRAPPER')->set_std(\&std_wrapper);
    $parser->symbol('wrapper')->set_std(\&std_wrapper);
    $parser->symbol('INTO');
    $parser->symbol('into');

    return;
}

after init_iterator_elements => sub {
    my($parser) = @_;

    my $tab = $parser->iterator_element;

    $tab->{first} = $tab->{is_first};
    $tab->{last}  = $tab->{is_last};
    $tab->{next}  = $tab->{peek_next};
    $tab->{prev}  = $tab->{peek_prev};

    return;
};

around advance => sub {
    my($super, $parser, $id) = @_;
    if(defined $id and $parser->token->id eq lc($id)) {
        $id = lc($id);
    }
    return $super->($parser, $id);
};

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
    my $dot = $parser->SUPER::led_dot($symbol, $left);
    if($dot->second->id =~ /\A \$/xms) { # var.$field
        $dot->id('['); # var[ $field ]
        $dot->second->arity("variable");
    }
    return $dot;
}

sub led_concat {
    my($parser, $symbol, $left) = @_;

    return $parser->SUPER::led_infix($symbol->clone(id => '~'), $left);
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

        $t = $parser->token;
    }

    if(uc($t->id) eq "ELSE") {
        $parser->reserve($t);
        $t = $parser->advance(); # "ELSE"

        $if->third( uc($t->id) eq "IF"
            ? $parser->statement()
            : $parser->statements());
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
    $parser->pop_scope();

    $parser->advance("END");

    return $proc;
}

sub std_include {
    my($parser, $symbol) = @_;

    my $command = $parser->SUPER::std_include($symbol);
    $command->id( lc $command->id );
    return $command;
}

sub localize_vars {
    my($parser, $symbol) = @_;

    if(uc($parser->token->id) eq "WITH") {
        $parser->advance();
        return $parser->set_list();
    }
    return undef;
}

sub set_list {
    my($parser) = @_;
    my @args;
    while(1) {
        my $key = $parser->token;

        if(!($key->arity eq "literal" || $key->arity eq "variable")) {
            last;
        }
        $parser->advance();
        $parser->advance("=");

        my $value = $parser->expression(0);

        $key->arity("literal");
        push @args, $key => $value;

        if($parser->token->id eq ",") { # , is optional
            $parser->advance();
        }
    }

    return \@args;
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

    $parser->define_macro($name->id);

    $proc->first($name);
    $parser->advance();

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
    return $proc;
}


# WRAPPER "foo.tt" ...  END
# is
# cascade "foo.tt" { content => content@wrapper() }
# macro content@wrapper -> { ... }
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

    my $cascade = $symbol->clone(
        arity => 'cascade',
        first => $base,
    );

    my $internal_name = $symbol->clone(
        arity => 'macro',
        id    => 'content@wrapper',
    );

    my $into_name = $symbol->clone(
        arity => 'literal',
        id    => $into,
    );

    my $content = $symbol->clone(
        arity => 'proc',
        id    => 'macro',

        first  => $internal_name,
        second => [],
        third  => $body,
    );

    my $call_content = $symbol->clone(
        arity  => 'call',
        first  => $internal_name,
        second => [],
    );

    push @{$vars}, $into_name => $call_content;
    $cascade->third($vars);
    return( $cascade, $content );
}

# [% FILTER html %]
# ...
# [% END %]
# is
# : macro filter_xxx -> {
#   ...
# : } filter_001() | html
# in Kolon
#
#sub std_filter {
#    my($parser, $symbol) = @_;
#
#    my $t = $parser->token;
#    if($t->arity ne 'name') {
#        $parser->_error("Expected filter name, not $t");
#    }
#    my $filter = $t->nud($parser);
#    $parser->advance();
#
#    my $tmpname = $symbol->clone(
#        arity => 'macro',
#        id    => sprintf('%s@%d&0x%x', $symbol->id, $parser->line, Scalar::Util::refaddr($symbol)),
#    );
#
#    my $proc = $symbol->clone(
#        arity => 'proc',
#        id    => 'macro',
#    );
#
#    $proc->first($tmpname);
#    $proc->second([]);
#    $proc->third( $parser->statements() );
#    $parser->advance("END");
#
#    my $callmacro = $symbol->clone(
#        arity  => 'call',
#        first  => $tmpname, # name
#        second => [],       # args
#    );
#    my $callfilter  = $symbol->clone(
#        arity  => 'call',
#        first  => $filter,      # name
#        second => [$callmacro], # args
#    );
#    my $print = $parser->symbol('print')->clone(
#        arity => 'command',
#        first => [$callfilter],
#        line  => $symbol->line,
#    );
#
#    return( $proc, $print );
#}

no Any::Moose;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::Syntax::TTerse - An alternative syntax like Template-Toolkit 2

=head1 SYNOPSIS

    use Text::Xslate;
    my $tx = Text::Xslate->new(
        syntax => 'TTerse',
    );

    print $tx->render_string(
        'Hello, [% dialect %] world!',
        { dialect => 'TTerse' }
    );

=head1 DESCRIPTION

TTerse is a subset of the Template-Toolkit 2.0 (and partially  3.0) syntax,
using C<< [% ... %] >> tags and C<< %% ... >> line code.

=head1 SYNTAX

This support Template-Toolkit like syntax, but the details might be different.

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
        * [% loop.max       # loop.size - 1 %]
        * [% loop.peek_next # loop.body[ loop.index - 1 ]
        * [% loop.peek_prev # loop.body[ loop.index + 1 ]
        [%- IF loop.is_last -%]
        <last>
        [%- END -%]
    [% END %]

For compatibility with Template-Toolkit, C<first> for C<is_first>, C<last>
for C<is_last>, C<next> for C<peek_next>, C<prev> for C<peek_prev> are
supported, but the use of them is discouraged because they are hard
to understand.

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

=head2 Template cascading

Not supported.

=head1 SEE ALSO

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

=cut
