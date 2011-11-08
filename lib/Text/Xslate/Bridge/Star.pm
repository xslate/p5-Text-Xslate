package Text::Xslate::Bridge::Star;
use strict;
use warnings;
use parent qw(Text::Xslate::Bridge);

use Scalar::Util ();
use Carp ();

sub _is_rx;
BEGIN {
    if(my $code = re->can('is_regexp')) {
        *_is_regexp = $code;
    }
    else {
        *_is_regexp = sub {
            return Scalar::Util::blessed($_[0])
                && $_[0]->isa('Regexp');
        };
    }
}

sub lc {
    return defined($_[0]) ? CORE::lc($_[0]) : undef;
}

sub uc {
    return defined($_[0]) ? CORE::uc($_[0]) : undef;
}

sub substr {
    my($str, $offset, $length) = @_;
    return undef unless defined $str;
    $offset = 0 unless defined $offset;
    $length = length($str) unless defined $length;
    return CORE::substr($str, $offset, $length);
}


sub sprintf {
    my $fmt = shift;
    return undef unless defined $fmt;
    return sprintf $fmt, @_;
}

sub rx {
    return defined($_[0]) ? qr/$_[0]/ : undef;
}

sub replace {
    my($str, $pattern, $replacement) = @_;
    return undef unless defined $pattern;
    if(_is_rx($pattern)) {
        $str =~ s/$pattern/$replacement/g;
    }
    else {
        $str =~ s/\Q$pattern\E/$replacement/g;
    }
    return $str;
}

my %scalar_methods = (
    lc      => \&lc,
    uc      => \&uc,
    substr  => \&substr,
    sprintf => \&sprintf,
    rx      => \&rx,
    replace => \&replace,
);

__PACKAGE__->bridge(
#    nil    => \%nil_methods,
    scalar => \%scalar_methods,
#    array  => \%array_methods,
#    hash   => \%hash_methods,

    function => \%scalar_methods,
);

1;
__END__

=head1 NAME

Text::Xslate::Bridge::Star - Selection of common utilities for templates

=head1 SYNOPSIS

    use Text::Xslate;

    my $tx = Text::Xslate->new(
        module => ['Text::Xslate::Bridge::Star'],
    );

=head1 DESCRIPTION

This module provides a selection of utilities for templates.

=head1 FUNCTIONS

=head2 C<lc($str)>

=head2 C<uc($str)>

=head2 C<substr($str, $offset, $len)>

=head2 C<sprintf($fmt, args...)>

=head2 C<rx($regex_pattern)>

=head2 C<replace($str, $pattern, $replacement)>


=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Bridge>

=cut
