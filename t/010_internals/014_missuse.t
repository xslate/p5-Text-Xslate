#!perl -w
use strict;
use Test::More;

use Text::Xslate;

eval {
    Text::Xslate->render({});
};
like $@, qr/Invalid xslate object/;

my $tx = Text::Xslate->new();

eval {
    $tx->render([]);
};
like $@, qr/must be a HASH reference/;

eval {
    $tx->render();
};
ok $@, 'render() without argument';

eval {
    $tx->new();
};
ok $@, '$txinstance->new()';

done_testing;
