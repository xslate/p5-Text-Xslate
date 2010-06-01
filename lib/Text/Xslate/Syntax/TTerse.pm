package Text::Xslate::Syntax::TTerse;
use Any::Moose;
use Text::Xslate::Util qw(p any_in);

extends qw(Text::Xslate::Parser);

# [% ... %]
sub _build_line_start { qr/%%/xms   }
sub _build_tag_start  { qr/\Q[%/xms }
sub _build_tag_end    { qr/\Q%]/xms }

around split => sub {
    my $super = shift;

    my $tokens_ref = $super->(@_);

    foreach my $t(@{$tokens_ref}) {
        my($type, $value) = @{$t};
        if($type eq 'code' && $value =~ /^#/) {
            $t->[1] = '';
        }
    }

    return $tokens_ref;
};

sub define_symbols {
    my($parser) = @_;

    $parser->symbol(']');
    $parser->symbol('}');

    $parser->define_basic_operators();
    $parser->infix('_', $parser->symbol('~')->lbp, \&led_concat);

    # defines both upper cased and lower cased

    $parser->symbol('END')  ->is_block_end(1);
    $parser->symbol('end')  ->is_block_end(1);
    $parser->symbol('ELSE') ->is_block_end(1);
    $parser->symbol('else') ->is_block_end(1);
    $parser->symbol('ELSIF')->is_block_end(1);
    $parser->symbol('elsif')->is_block_end(1);

    $parser->symbol('IN');
    $parser->symbol('in')->id('IN');

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
    $parser->symbol('with')->id('WITH');

    $parser->symbol('MACRO') ->set_std(\&std_macro);
    $parser->symbol('macro') ->set_std(\&std_macro);
    $parser->symbol('BLOCK');
    $parser->symbol('block')->id('BLOCK');

    return;
}

sub undefined_name {
    my($parser) = @_;
    # undefined names are always variables
    return $parser->symbol_table->{'(variable)'};
}

sub is_valid_field {
    my($parser, $token) = @_;
    if(!$parser->SUPER::is_valid_field($token)) {
        return $token->arity eq "variable"
            && scalar($token->id !~ /^\$/);
    }
    return 1;
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

    $parser->token->id eq "end"
        ? $parser->advance("end")
        : $parser->advance("END");
    return $top_if;
}

sub iterator_name {
    return 'loop'; # always 'loop'
}

sub std_foreach {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "for");

    my $t = $parser->token;
    if($t->arity ne "variable") {
        $parser->_error("Expected a variable name but $t");
    }

    my $var = $t;
    $parser->advance()
        ? $parser->advance("in")
        : $parser->advance("IN");

    $proc->first( $parser->expression(0) );
    $proc->second([$var]);

    $parser->new_scope();

    $parser->define_iterator($var);

    $proc->third( $parser->statements() );
    $parser->pop_scope();

    $parser->token->id eq "end"
        ? $parser->advance("end")
        : $parser->advance("END");

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
        return  $parser->set_list();
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
        id    => lc($symbol->id),
    );

    my $name = $parser->token;
    if($name->arity ne "variable") {
        $parser->_error("Expected a name but " . $name);
    }

    $parser->define_macro($name->id);

    $proc->first( $name->id );
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

Note that lower-cased keywords are also allowed.

=head2 Variable access

Scalar access:

    [%  var %]
    [% $var %]

Field access:

    [% var.0 %]
    [% var.field %]
    [% var.accessor %]

Variables may be HASH references, ARRAY references, or objects.

If I<$var> is an object instance, you can call its methods.

    [% $var.method() %]
    [% $var.method(1, 2, 3) %]
    [% $var.method(foo => [1, 2, 3]) %]
    [% $var.method({ foo => 'bar' }) %]

=head2 Expressions

Almost the same as L<Text::Xslate::Syntax::Kolon>.

=head2 Loops

    [% FOREACH item IN arrayref %]
        * [% item %]
    [% END %]

Loop iterators are partially supported.

    [% FOREACH item IN arrayref %]
        [%- IF loop.first -%]
        <first>
        [%- END -%]
        * [% loop.index %]
        * [% loop.count # loop.index + 1 %]
        * [% loop.body  # alias to arrayref %]
        * [% loop.size  # loop.body.size %]
        * [% loop.max   # loop.size - 1 %]
        [%- IF loop.last -%]
        <first>
        [%- END -%]
    [% END %]

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

    [% INCLUDE "file.tt" %]
    [% INCLUDE $var %]

C<< WITH variablies >> syntax is also supported:

    [% INCLUDE "file.tt" WITH foo = 42, bar = 3.14 %]
    [% INCLUDE "file.tt" WITH
        foo = 42
        bar = 3.14
    %]

=head2 Template cascading

Not supported.

=head2 Macro blocks

Not supported.

=head1 SEE ALSO

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

=cut
