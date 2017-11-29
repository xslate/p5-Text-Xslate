#!perl -w

use strict;
use constant HAS_THREADS => eval { require threads };
use Test::More ();

use if !( HAS_THREADS && $] >= 5.008008),
    'Test::More', skip_all => 'multi-threading tests';

use if ( Test::More->VERSION >= 2.0 ),
    'Test::More', skip_all => 'Test::Builder 2.0 is not thread-safe';

use Test::More tests => 13;

use Text::Xslate;
use lib "t/lib";
use Util;

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

eval {
    my $tx = Text::Xslate->new(
        function => {
            'array::count' => sub {
                my($a, $cb) = @_;
                return scalar grep { $cb->($_) } @{$a};
            },
        },
    );

    is $tx->render_string(q{<: [10, 20].count(-> $a { true }) :>}), 2, 'high level functions';

    threads->create(sub{
        is $tx->render_string(q{<: [10, 20, 30].count(-> $a { true }) :>}), 3
                for 1 .. 2;
    })->join();

    is $tx->render_string(q{<: [10, 20, 30, 40].count(-> $a { true }) :>}), 4;
};
is $@, '';
