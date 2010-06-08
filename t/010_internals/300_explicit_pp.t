#!perl
# Explicit use of PP version

use strict;
use Test::More tests => 5;

BEGIN {
    use_ok 'Text::Xslate::PP';
    use_ok 'Text::Xslate', qw(escaped_string);
}


use B;

ok( !B::svref_2object(Text::Xslate->can('render'))->XSUB, 'render() is not an xsub' );

eval {
    my $tx = Text::Xslate->new();

    is $tx->render_string('Hello, <: $lang :> world!', { lang => escaped_string('<Xslate>') }),
        "Hello, <Xslate> world!";
};
is $@, '';

done_testing;
