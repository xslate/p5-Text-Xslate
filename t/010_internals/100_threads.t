#!perl -w

use strict;
use Test::More skip_all => 'not yet done';
use constant HAS_THREADS => eval { require threads };
use Test::Requires qw(threads);
use Test::More;
use Text::Xslate;

eval {
    my $tx = Text::Xslate->new(string => "Hello, world!");

    threads->create(sub{ Text::Xslate->new })->join;

    is $tx->render({}), "Hello, world!";
};

is $@, '';

done_testing;
