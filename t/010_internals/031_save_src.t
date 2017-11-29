#!perl -w
use strict;
use if exists $INC{'Text/Xslate.pm'},
    'Test::More', skip_all => 'Text::Xslate has been loaded';
use Test::More;
BEGIN{ $ENV{XSLATE} ||= ''; $ENV{XSLATE} .= ':save_src' }

use Text::Xslate;
use File::Spec;
use lib "t/lib";
use Util;

my $tx = Text::Xslate->new(
    path  => [{ foo => 'Hello, <: "" :>world!' }, path],
    cache => 0,
);

note 'from file';
is $tx->render('hello.tx', { lang => 'Xslate' } ), "Hello, Xslate world!\n";
is $tx->{source}{File::Spec->catfile(path, 'hello.tx')},
    "Hello, <:= \$lang :> world!\n"
    or diag(explain($tx->{source}));

note 'from hash';
is $tx->render('foo'), 'Hello, world!';
is $tx->{source}{foo}, 'Hello, <: "" :>world!'
    or diag(explain($tx->{source}));

note 'from <string>';
is $tx->render_string('<: 1 + 41 :>'), 42;
is $tx->{source}{'<string>'}, '<: 1 + 41 :>';

done_testing;
