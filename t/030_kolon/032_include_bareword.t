#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my %vpath = (
    'hello.tx' => 'Hello, world!',
);

my $tx = Text::Xslate->new(
    path  => \%vpath,
    cache => 0,
);

is $tx->render('hello.tx'), 'Hello, world!';
is $tx->render_string(<<EOT), 'Hello, world!';
: include "hello.tx";
EOT

is $tx->render_string(<<EOT), 'Hello, world!', 'include bareword';
: include hello;
EOT

%vpath = (
    'hello.html' => 'Hello, world!',
);

$tx = Text::Xslate->new(
    path   => \%vpath,
    cache  => 0,
    suffix => '.html',
);

is $tx->render_string(<<EOT), 'Hello, world!', 'include bareword';
: include hello;
EOT

done_testing;

