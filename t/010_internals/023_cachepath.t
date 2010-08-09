#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw();
use File::Path;
use t::lib::Util;

rmtree(cache_dir);
END{ rmtree(cache_dir) }

package FooOverloadingObjectDir;
use overload q{""} => sub { return ${shift()} };
sub new { bless \"$_[1]" => $_[0] }

package main;

    { # string path
        my $tx = Text::Xslate->new(
            path      => [path, { 'foo.tx' => 'Hello' } ],
            cache_dir => cache_dir,
            cache     => 2,
        );

        is $tx->find_file('hello.tx')->{cachepath} => cache_dir . '/' . Text::Xslate::Util::uri_escape(path) . '/hello.txc';
    }

    { # overloading object
        my $tx = Text::Xslate->new(
            path      => [FooOverloadingObjectDir->new(path), { 'foo.tx' => 'Hello' } ],
            cache_dir => cache_dir,
            cache     => 2,
        );

        is $tx->find_file('hello.tx')->{cachepath} => cache_dir . '/' . Text::Xslate::Util::uri_escape(path) . '/hello.txc';
    }


done_testing;
