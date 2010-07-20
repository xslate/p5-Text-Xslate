#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, [% lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [% foo %] world!'  => 'Hello, &lt;bar&gt; world!'],
    ['Hello, [% lang %] [% foo %] world!'
                                 => 'Hello, Xslate &lt;bar&gt; world!'],

    ['Hello, [% $lang %] world!'   => 'Hello, Xslate world!'],
    ['Hello, [% ${lang} %] world!' => 'Hello, Xslate world!'],
    ['Hello, [% ${ lang } %] world!' => 'Hello, Xslate world!'],

    ['Hello, [% $no_such_field %] world!' => 'Hello,  world!', 'nil as empty'],
    ['Hello, [% $no_such_field or "Default" %] world!' => 'Hello, Default world!', 'empty or default'],

    ['[% $IF %]', 'This is IF' ],
    ['[% +IF %]', 'This is IF' ],

    ['[% GET lang %]', 'Xslate'],
    ['[% get lang %]', 'Xslate'],
    ['[% get IF   %]', 'This is IF'],
);

my %vars = (
    lang    => 'Xslate',
    foo     => "<bar>",
    '$lang' => 'XXX',
    IF      => 'This is IF',
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
