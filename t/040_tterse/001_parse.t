#!perl -w
use strict;
use Test::More;

use Text::Xslate::Syntax::TTerse;
use Text::Xslate::Util qw(p);

my $parser = Text::Xslate::Syntax::TTerse->new();

my @data = (
    ['Hello, world!' => qr/Hello, world!/],
    ['Hello, [% lang %] world!' => qr/Hello/, qr/\b lang \b/xms, qr/world/],
    ['Hello, [% foo %] world!'  => qr/\b foo \b/xms],
    ['Hello, [% lang %] [% foo %] world!', qr/\b lang \b/xms, qr/\b foo \b/xms],

    [<<'T', qr/\b foo \b/xms, qr/\b if \b/xms],
[% IF foo %]
    This is true
[% END %]
T
    [<<'T', qr/\b foo \b/xms, qr/\b if \b/xms],
[% IF foo %]
    This is true
[% ELSE %]
    This is false
[% END %]
T

    [<<'T', qr/\b item \b/xms, qr/\b foo \b/xms, qr/\b for \b/xms],
[% FOREACH item IN foo %]
    This is true
[% END %]
T

);

foreach my $d(@data) {
    my($str, @patterns) = @{$d};

    #note($str);
    my $code = p($parser->parse($str));
    #note($code);

    foreach my $pat(@patterns) {
        like $code, $pat;
    }
}

done_testing;
