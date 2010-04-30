package Text::Xslate::Parser::TTLike;
use 5.010;
use Mouse;

extends qw(Text::Xslate::Parser);

sub symbol_class() { __PACKAGE__ . '::Symbol' }

# [% ... %]
sub _build_line_start { undef       }
sub _build_tag_start  { qr/\Q[%/xms }
sub _build_tag_end    { qr/\Q%]/xms }

sub define_symbols {
    my($parser) = @_;

    $parser->symbol('END') ->is_end(1);
    $parser->symbol('ELSE')->is_end(1);
    $parser->symbol('IN');

    $parser->symbol('IF')      ->set_std(\&_std_if);
    $parser->symbol('FOREACH') ->set_std(\&_std_foreach);

    $parser->infix('.', 100, $parser->can('_led_dot'));

    # operators
    $parser->infix('*', 80);
    $parser->infix('/', 80);
    $parser->infix('%', 80);

    $parser->infix('+', 70);
    $parser->infix('-', 70);
    $parser->infix('~', 70); # connect

    $parser->infix('<',  60);
    $parser->infix('<=', 60);
    $parser->infix('>',  60);
    $parser->infix('>=', 60);

    $parser->infix('==', 50);
    $parser->infix('!=', 50);

    $parser->infix('|',  40); # filter

    $parser->infixr('&&', 35);
    $parser->infixr('||', 30);
    $parser->infixr('//', 30);

    $parser->prefix('!');
    $parser->prefix('+');
    $parser->prefix('-');

}

sub _std_if {
    my($parser, $symbol) = @_;
    my $if = $symbol->clone(arity => "if");

    $if->first(  $parser->expression(0) );
    $if->second( $parser->statements() );

    if($parser->token->id eq "ELSE") {
        $parser->reserve($parser->token);
        $parser->advance("ELSE");
        $if->third( $parser->token->id eq "IF"
            ? $parser->statement()
            : $parser->statements());
    }
    $parser->advance("END");
    return $if;
}

sub _std_foreach {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "for");

    if($parser->token->arity ne "name") {
        $parser->_error("Expected a variable name");
    }

    my $var = $parser->token;
    $parser->advance();
    $parser->advance("IN");

    $proc->first( $parser->expression(0) );
    $proc->second([$var]);
    $proc->third( $parser->statements() );

    $parser->advance("END");
    return $proc;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

package Text::Xslate::Parser::TTLike::Symbol;
use Mouse;

extends qw(Text::Xslate::Symbol);

sub _nud_default {
    my($parser, $symbol) = @_;

    # undefined symbols are considiered variables
    return $symbol->clone(arity => 'variable');
}

no Mouse;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::Parser::TTLike - An Xslate parser to Template-Toolkit-like syntax (STUB)

=head1 SUMMARY OF SYNTAX

This parser supports a subset of the Template-Tookit 2 syntax.

variables:

    [% value %]
    [% hashref.field %]
    [% arrayref.0 %]
    [% obj.method %]

loops:

    [% FOREACH item IN arrayref %]
        * [% item %]
    [% END %]

conditional statements:

    [% IF variable %]
        This is true
    [% ELSE %]
        Tis is false
    [% END %]

=head1 SEE ALSO

L<Template::Toolkit>

L<Template::Tiny>

=cut
