#!perl -w
use strict;
use Test::More;
use Text::Xslate;
use lib "t/lib";
use Util;
use utf8;

binmode Test::More->builder->output, ":utf8";
binmode Test::More->builder->failure_output, ":utf8";
binmode Test::More->builder->todo_output, ":utf8";

my $warn = '';

my $tx = Text::Xslate->new(
    cache => 0,
    path  => [path],
    verbose => 2,
    warn_handler => sub {
        $warn .= "@_";
    },
);

like $tx->render('hello_utf8.tx'), qr/こんにちは/;
like $warn,                        qr/こんにちは/;

eval {
    $tx->render_string('<: こんにちは'); # syntax error
};
note $@;
like $@, qr/\<\: こんにちは/, 'wide characters in error messages';

done_testing;

