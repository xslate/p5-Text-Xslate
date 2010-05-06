#!perl -w

use strict;
use constant HAS_THREADS => eval { require threads };
use if !HAS_THREADS, 'Test::More', skip_all => 'multi-threading tests';

use Test::More tests => 8;

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
        #XXX: see the value attribute of T::X::Symbol
        is $tx->render('hello.tx', {lang => 'Thread'}),
            "Hello, Thread world!\n", "in a child thread"
                for 1 .. 2;
    })->join();

    is $tx->render('hello.tx', {lang => 'Perl'}), "Hello, Perl world!\n";
};

is $@, '';

