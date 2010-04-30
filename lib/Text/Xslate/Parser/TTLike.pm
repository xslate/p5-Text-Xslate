package Text::Xslate::Parser::TTLike;
use 5.010;
use Mouse;

extends qw(Text::Xslate::Parser);

sub symbol_class() { __PACKAGE__ . '::Symbol' }

# [% ... %]
sub _build_line_start { undef       }
sub _build_tag_start  { qr/\Q[%/xms }
sub _build_tag_end    { qr/\Q%]/xms }


sub grammer {

}

no Mouse;
__PACKAGE__->meta->make_immutable();

package Text::Xslate::Parser::TTLike::Symbol;
use Mouse;

extends qw(Text::Xslate::Symbol);

sub _nud_default {
    my($parser, $symbol) = @_;
    return $symbol;
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
