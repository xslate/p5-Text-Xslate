package Text::Xslate::Bridge::Star;
use strict;
use warnings;
use parent qw(Text::Xslate::Bridge);

BEGIN {
    if(my $code = re->can('is_regexp')) {
        *_is_rx = $code;
    }
    else {
        require Scalar::Util;
        *_is_rx = sub {
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
    if(@_) { # sprintf($fmt, ...)
        return sprintf $fmt, @_;
    }
    else { # $x | sprintf('%.02f')
        return sub {
            sprintf $fmt, @_;
        };
    }
}

sub rx {
    return defined($_[0]) ? qr/$_[0]/ : undef;
}

sub match {
    my($str, $pattern) = @_;
    return undef unless defined $str;
    return undef unless defined $pattern;

    $pattern = quotemeta($pattern) unless _is_rx($pattern);
    return scalar($str =~ m/$pattern/);
}

sub replace {
    my($str, $pattern, $replacement) = @_;
    return undef unless defined $str;
    return undef unless defined $pattern;

    $pattern = quotemeta($pattern) unless _is_rx($pattern);
    $str =~ s/$pattern/$replacement/g;
    return $str;
}

sub split {
    my($str,$pattern,$limit) = @_;
    if (!defined $pattern) {
        $pattern = ' ';
    }
    $pattern = quotemeta($pattern) unless _is_rx($pattern);
    if (defined $limit) {
        return [CORE::split($pattern, $str, $limit)];
    } else {
        return [CORE::split($pattern, $str)];
    }
}

my %scalar_methods = (
    lc      => \&lc,
    uc      => \&uc,
    substr  => \&substr,
    sprintf => \&sprintf,
    rx      => \&rx,
    match   => \&match,
    replace => \&replace,
    split   => \&split,
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

Returns a lower-cased version of I<$str>.
The same as C<CORE::lc()>, but returns undef if I<$str> is undef.

See L<perldoc/lc> for details.

=head2 C<uc($str)>

Returns a upper-cased version of I<$str>.
The same as C<CORE::uc()>, but returns undef if I<$str> is undef.

See L<perldoc/uc> for details.

=head2 C<substr($str, $offset, $len)>

Extracts a substring out of I<$str> and returns it.
The same as C<CORE::substr()>, but returns undef if I<$str> is undef.

See L<perldoc/substr> for details.

=head2 C<sprintf($fmt, args...)>

Returns a string formatted by the C<CORE::sprintf()>.
L<$fmt> must be a defined value.

See L<perldoc/sprintf> for details.

=head2 C<rx($regex_pattern)>

Compiles I<$regex_patter> as a regular expression and return the regex object. You can pass a regex object to C<match()> or C<replace()> described below.
The same as C<qr//> operator in Perl.

=head2 C<match($str, $pattern)>

Tests if I<$str> matches I<$pattern>. I<$pattern> may be a string or a regex object.

Like C<< $str =~ $pattern >> in Perl but you have to pass a regex object explicitly if you can use regular expressions.

Examples:

    : match("foo bar baz", "foo")     ? "true" : "false" # true
    : match("foo bar baz", "f..")     ? "true" : "false" # false
    : match("foo bar baz", rx("f..")) ? "true" : "false" # true

=head2 C<replace($str, $pattern, $replacement)>

Replaces all the I<$pattern>s in I<$str> with I<$replacement>s.
Like as C<< $str =~ s/$pattern/$replacement/g >> but you have to pass a regex object explicitly if you can use regular expressions.

=head2 C<split($str [, $pattern [, $limit]])>

Splits the string I<$str> into a list of strings and returns the list.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Bridge>

L<perlfunc>

=cut
