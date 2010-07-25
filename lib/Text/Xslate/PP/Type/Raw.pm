package Text::Xslate::PP::Type::Raw;

use strict;
use warnings;

use Carp ();

require Text::Xslate::Util;

use overload (
    '""'     => 'as_string',
    '.'      => 'concat',
    fallback => 1,
);

my $the_class = 'Text::Xslate::Type::Raw';

sub new {
    my ( $class, $str ) = @_;

    Carp::croak("Usage: $the_class->new(str)") if ( @_ != 2 );

    if ( ref $class ) {
        Carp::croak("You cannot call $the_class->new() as an instance method");
    }
    elsif ( $class ne $the_class ) {
        Carp::croak("You cannot extend $the_class");
    }
    $str = ${$str} if ref($str) eq $the_class; # unmark
    return bless \$str, $the_class;
}

sub as_string {
    unless ( ref $_[0] ) {
        Carp::croak("You cannot call $the_class->as_string() as a class method");
    }
    return ${ $_[0] };
}

sub concat {
    my($lhs, $rhs, $reversed) = @_;
    unless ( ref $lhs ) {
        Carp::croak("You cannot call $the_class->concat() as a class method");
    }

    $rhs = Text::Xslate::Util::html_escape($rhs);
    ($lhs, $rhs) = ($rhs, $lhs) if $reversed;
    return $the_class->new(
          (defined($lhs) ? ${ $lhs } : '')
        . (defined($rhs) ? ${ $rhs } : '')
    );
}

sub defined { 1 }

package
    Text::Xslate::Type::Raw;
our @ISA = qw(Text::Xslate::PP::Type::Raw);
1;
__END__

=head1 NAME

Text::Xslate::PP::Type::Raw - Text::Xslate raw string type in pure Perl

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
