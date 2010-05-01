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

    $parser->symbol('END') ->is_end(1);
    $parser->symbol('ELSE')->is_end(1);
    $parser->symbol('ELSIF')->is_end(1);

    $parser->symbol('IN');

    $parser->symbol('IF')      ->set_std(\&_std_if);
    $parser->symbol('FOREACH') ->set_std(\&_std_foreach);

    $parser->infix('.', 100, \&_led_dot);

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

sub undefined_name {
    my($parser, $name) = @_;
    # undefined names are always variables
    return $parser->symbol_table->{'(variable)'};
}

sub _led_dot {
    my($parser, $symbol, $left) = @_;

    my $t = $parser->token;
    if($t->arity ne "variable") {
        if(!($t->arity eq "literal"
                && Mouse::Util::TypeConstraints::Int($t->id))) {
            $parser->_error("Expected a field name but $t");
        }
    }

    my $dot = $symbol->clone(arity => 'binary');

    $dot->first($left);
    $dot->second($t->clone(arity => 'literal'));

    $parser->advance();
    return $dot;
}

sub _std_if {
    my($parser, $symbol) = @_;
    my $if = $symbol->clone(arity => "if");

    $if->first(  $parser->expression(0) );
    $if->second( $parser->statements() );

    my $t = $parser->token;

    my $top_if = $if;

    while($t->id eq "ELSIF") {
        $parser->reserve($t);
        $parser->advance("ELSIF");

        my $elsif = $t->clone(arity => "if");
        $elsif->first(  $parser->expression(0) );
        $elsif->second( $parser->statements() );

        $if->third([$elsif]);

        $if = $elsif;

        $t = $parser->token;
    }

    if($t->id eq "ELSE") {
        $parser->reserve($t);
        $parser->advance("ELSE");

        $if->third( $parser->token->id eq "IF"
            ? $parser->statement()
            : $parser->statements());
    }

    $parser->advance("END");
    return $top_if;
}

sub _std_foreach {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "for");

    my $t = $parser->token;
    if($t->arity ne "variable") {
        $parser->_error("Expected a variable name but $t");
    }

    my $var = $t;
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
__END__

=head1 NAME

Text::Xslate::Syntax::TTerse - An alternative Xslate parser to Template-Toolkit-like syntax

=head1 DESCRIPTION

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

L<Text::Xslate>

L<Template::Toolkit>

L<Template::Tiny>

=cut
