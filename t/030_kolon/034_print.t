#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(
    function => {
        myprint => sub { Text::Xslate->print(@_) },
        mysay   => sub { Text::Xslate->print(@_, "\n") },
    },

    warn_handler => sub { Text::Xslate->print(@_) },
    verbose      => 2,
);

is $tx->render_string('[<: myprint() :>]'), '[]';
is $tx->render_string('[<: myprint("<foo>") :>]'),
    '[&lt;foo&gt;]';
is $tx->render_string('[<: myprint("<foo>", "<bar>") :>]'),
    '[&lt;foo&gt;&lt;bar&gt;]';

is $tx->render_string('[<: mysay() :>]'), "[\n]";
is $tx->render_string('[<: mysay("<foo>") :>]'),
    "[&lt;foo&gt;\n]";
is $tx->render_string('[<: mysay("<foo>", "<bar>") :>]'),
    "[&lt;foo&gt;&lt;bar&gt;\n]";

like $tx->render_string("<: nil :>"), qr/nil/;
like $tx->render_string("<: nil :>"), qr/&lt;string&gt;/;

done_testing;

