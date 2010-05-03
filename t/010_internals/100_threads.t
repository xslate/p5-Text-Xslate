#!perl -w

use strict;
use constant HAS_THREADS => eval { require threads };
use if !HAS_THREADS, 'Test::More', skip_all => 'multi-threading tests';
use Test::More;
use Text::Xslate;
use t::lib::Util;

eval {
    my $tx = Text::Xslate->new(path => [path], cache => 0);
    is $tx->render('hello.tx', {lang => 'Xslate'}), "Hello, Xslate world!\n";

    threads->create(sub{ })->join();

    is $tx->render('hello.tx', {lang => 'Perl'}), "Hello, Perl world!\n";
};

is $@, '';

eval {
    my $tx = Text::Xslate->new(path => [path], cache => 0);
    is $tx->render('hello.tx', {lang => 'Xslate'}), "Hello, Xslate world!\n";

    threads->create(sub{
        is $tx->render('hello.tx', {lang => 'Thread'}), "Hello, Thread world!\n";
    })->join();

    is $tx->render('hello.tx', {lang => 'Perl'}), "Hello, Perl world!\n";
};

is $@, '';

done_testing;
