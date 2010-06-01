package Text::Xslate::PP::EscapedString;

use strict;
use warnings;

use Carp ();

use overload (
    '""'     => 'as_string',
    fallback => 1,
);

my $the_class = 'Text::Xslate::EscapedString';

sub new {
    my ( $class, $str ) = @_;

    Carp::croak("Usage: $the_class->new(str)") if ( @_ != 2 );

    if ( ref $class ) {
        Carp::croak("You cannot call $the_class->new() as an instance method");
    }
    elsif ( $class ne $the_class ) {
        Carp::croak("You cannot extend $the_class");
    }
    return bless \$str, $class;
}

sub as_string {
    unless ( ref $_[0] ) {
        Carp::croak("You cannot call $the_class->as_string() as a class method");
    }
    return ${ $_[0] };
}

package
    Text::Xslate::EscapedString;
our @ISA = qw(Text::Xslate::PP::EscapedString);
1;
__END__

=head1 NAME

Text::Xslate::PP::EscapedString - Text::Xslate EscapedString in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
