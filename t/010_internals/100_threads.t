#!perl -w

use strict;
use constant HAS_THREADS => eval { require threads };
use if !HAS_THREADS, 'Test::More', skip_all => 'multi-threading tests';
use Test::More;
use Text::Xslate;

eval {
    my $tx = Text::Xslate->new(string => "Hello, world!");

    threads->create(sub{ })->join();

    is $tx->render({}), "Hello, world!";
};

is $@, '';

eval {
    my $tx = Text::Xslate->new(string => "Hello, world!");

    threads->create(sub{
        is $tx->render({}), "Hello, world!", 'in a child';
    })->join();

    is $tx->render({}), "Hello, world!", 'in the main';
};

is $@, '';

done_testing;
