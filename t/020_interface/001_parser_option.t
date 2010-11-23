#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Parser;


my $tx = Text::Xslate->new(
    line_start => '#',
);

is $tx->render_string(<<'T'), "Hello, Xslate world!", 'line_start';
# "Hello, Xslate world!"
T
is $tx->render_string(<<'T'), qq{: "Hello, Xslate world!"\n};
: "Hello, Xslate world!"
T

# https://github.com/gfx/p5-Text-Xslate/issues#issue/21
$tx = Text::Xslate->new(
    line_start => undef,
);

is $tx->render_string(<<'T'), qq{# "Hello, Xslate world!"\n}, 'line_start => undef';
# "Hello, Xslate world!"
T
is $tx->render_string(<<'T'), qq{: "Hello, Xslate world!"\n};
: "Hello, Xslate world!"
T

$tx = Text::Xslate->new(
    tag_start => '[%',
    tag_end   => '%]',
);

is $tx->render_string(<<'T', { foo => "Xslate"}), q{<: $foo :>Xslate<: $foo :>} . "\n", 'tag_start & tag_end';
<: $foo :>[% $foo %]<: $foo :>
T


$tx = Text::Xslate->new(
    syntax    => 'TTerse',
    tag_start => '<%',
    tag_end   => '%>',
);

is $tx->render_string(<<'T', { foo => "Xslate"}), q{[% $foo %]Xslate[% $foo %]} . "\n", 'tag_start & tag_end';
[% $foo %]<% $foo %>[% $foo %]
T

$tx = Text::Xslate->new(
    syntax     => 'TTerse',
    tag_start  => '{',
    tag_end    => '}',
);
is $tx->render_string('Hello, {lang} world!', { lang => 'Xslate' }), 'Hello, Xslate world!';


my $myparser = Text::Xslate::Parser->new(
    line_start => undef,
    tag_start  => '[%',
    tag_end    => '%]',
);

$tx = Text::Xslate->new(
    syntax => $myparser,
);
isa_ok $tx, 'Text::Xslate';

my @data = (
    ['Hello, [%= $lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [%= $foo %] world!' => 'Hello, &lt;bar&gt; world!'],
    [q{foo [%= $lang
        %] bar} => "foo Xslate bar"],

    # no default
    ['Hello, <: $lang :> world!' => 'Hello, <: $lang :> world!'],
    [":= \$lang\n", ":= \$lang\n"],

    # no line code
    ["%= \$lang\n", "%= \$lang\n"],
);

my %vars = (lang => 'Xslate', foo => "<bar>");
foreach my $pair(@data) {
    my($in, $out) = @$pair;

    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
