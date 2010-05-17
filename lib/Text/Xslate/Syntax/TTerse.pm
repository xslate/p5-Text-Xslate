package Text::Xslate::Syntax::TTerse;
use 5.010;
use Mouse;

extends qw(Text::Xslate::Parser);

# [% ... %]
sub _build_line_start { undef       }
sub _build_tag_start  { qr/\Q[%/xms }
sub _build_tag_end    { qr/\Q%]/xms }

sub define_symbols {
    my($parser) = @_;

    # both upper cased and lower cased

    $parser->symbol('END')  ->is_end(1);
    $parser->symbol('end')  ->is_end(1);
    $parser->symbol('ELSE') ->is_end(1);
    $parser->symbol('else') ->is_end(1);
    $parser->symbol('ELSIF')->is_end(1);
    $parser->symbol('elsif')->is_end(1);

    $parser->symbol('IN');
    $parser->symbol('in');

    $parser->symbol('IF')      ->set_std(\&std_if);
    $parser->symbol('if')      ->set_std(\&std_if);
    $parser->symbol('UNLESS')  ->set_std(\&std_if);
    $parser->symbol('unless')  ->set_std(\&std_if);
    $parser->symbol('FOREACH') ->set_std(\&std_foreach);
    $parser->symbol('foreach') ->set_std(\&std_foreach);

    $parser->symbol('INCLUDE') ->set_std(\&std_command);
    $parser->symbol('include') ->set_std(\&std_command);

    $parser->define_basic_operators();

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

sub std_foreach {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "for");

    my $t = $parser->token;
    if($t->arity ne "variable") {
        $parser->_error("Expected a variable name but $t");
    }

    my $var = $t;
    $parser->advance();
    $parser->token->id eq "in"
        ? $parser->advance("in")
        : $parser->advance("IN");

    $proc->first( $parser->expression(0) );
    $proc->second([$var]);
    $proc->third( $parser->statements() );

    $parser->token->id eq "end"
        ? $parser->advance("end")
        : $parser->advance("END");

    return $proc;
}

sub std_command {
    my($parser, $symbol) = @_;
    my $command = $parser->SUPER::std_command($symbol);
    $command->id( lc( $command->id ) );
    return $command;
}

no Mouse;
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

TTerse is a subset of the Template-Toolkit 2 syntax,
using C<< [% ... %] >> tags.

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

=head2 Expressions

Almost the same as L<Text::Xslate::Syntax::Kolon>.

=head2 Loops

    [% FOREACH item IN arrayref %]
        * [% item %]
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

=head2 Template cascading

Not supported.

=head2 Macro blocks

Not supported.

=head1 SEE ALSO

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

=cut
