#!perl -w

use strict;
use Test::Requires { 'Plack' => 0.99, 'Devel::StackTrace' => 1.30 };
use Test::More;

use HTTP::Request;
use Plack::Test;
use Plack::Response;
use Plack::Builder;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use lib "t/lib";
use Util;


my $tx = Text::Xslate->new(
    path  => path,
    cache => 0,
);

my $n = 2;

test_psgi
    app => sub {
        my($env) = @_;
        my $res = Plack::Response->new(200);
        $res->body( eval { $tx->render('hello.tx', { lang => 'Xslate' }) } || $@ );
        return $res->finalize();
    },
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/hello");
        for(1 .. $n) {
            my $res = $cb->($req);
            is $res->content, "Hello, Xslate world!\n", 'render';
        }
    },
;

test_psgi
    app => sub {
        my($env) = @_;
        my $res = Plack::Response->new(200);
        $res->body( eval { $tx->render_string(':include "no_such_file.tx"') } || $@ );
        return $res->finalize();
    },
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/hello");
        for(1 .. $n) {
            my $res = $cb->($req);
            like $res->content, qr/\b no_such_file\.tx \b/xms, 'fatal';
        }
    },
;

note 'with error handlers';

$tx = Text::Xslate->new(
    warn_handler => \&Carp::croak,
);

test_psgi
    app => builder {
        return sub {
            my($env) = @_;
            my $res = Plack::Response->new(200);
            $res->body( $tx->render_string('<: $lang.foobar() :>', { lang => 'Xslate' })  );
            return $res->finalize();
        };
    },
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/hello");
        for(1 .. $n) {
            my $res = $cb->($req);
            like $res->content, qr/\b foobar \b/xms, 'error handler';
        }
    },
;

test_psgi
    app => builder {
        enable 'StackTrace', no_print_errors =>1;

        return sub {
            my($env) = @_;
            my $res = Plack::Response->new(200);
            $res->body( $tx->render_string('<: $lang.foobar() :>', { lang => 'Xslate' })  );
            return $res->finalize();
        };
    },
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/hello");
        for(1 .. $n) {
            my $res = $cb->($req);
            like $res->content, qr/\b foobar \b/xms, 'error handler + StackTrace';
        }
    },
;

done_testing;
