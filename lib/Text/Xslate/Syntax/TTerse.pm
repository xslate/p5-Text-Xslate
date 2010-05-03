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

    $parser->symbol('INCLUDE') ->set_std(\&_std_command);

    # operators
    $parser->infix('.', 100, \&_led_dot);
    $parser->define_basic_operators();

}

sub undefined_name {
    my($parser) = @_;
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

sub _std_command {
    my($parser, $symbol) = @_;
    my $command = $parser->SUPER::_std_command($symbol);
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

=head1 EXAMPLES

=head2 Variable access

Scalar access:

    [%  var %]
    [% $var %]

Field acces:

    [% var.0 %]
    [% var.field %]
    [% var.accessor %]

Variables may be HASH references, ARRAY references, or objects.

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

=head2 Expressions

(TODO)

=head2 Functions and filters

Not supported.

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
