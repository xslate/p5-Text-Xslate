package Text::Xslate::PP::EscapedString;

package
    Text::Xslate::EscapedString;

use strict;
use warnings;

use Carp ();

use overload (
    '""' => sub { ${ $_[0] } }, # don't use 'as_string' or deep recursion.
    fallback => 1,
);

sub new {
    my ( $class, $str ) = @_;

    Carp::croak("Usage: Text::Xslate::EscapedString::new(klass, str)") if ( @_ != 2 );

    if ( ref $class ) {
        Carp::croak( sprintf( "You cannot call %s->new() as an instance method", __PACKAGE__ ) );
    }
    elsif ( $class ne __PACKAGE__ ) {
        Carp::croak( sprintf( "You cannot extend %s", __PACKAGE__ ) );
    }
    bless \$str, 'Text::Xslate::EscapedString';
}

sub as_string {
    unless ( $_[0] and ref $_[0] ) {
        Carp::croak( sprintf( "You cannot call %s->as_string() a class method", __PACKAGE__ ) );
    }
    return ${ $_[0] };
}



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
