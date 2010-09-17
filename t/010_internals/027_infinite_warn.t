#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
    'runner.tx' => <<'T',
:include "test.tx";
T
    'test.tx' => <<'T',
: $test()[0];
T
);

my $err_buf = '';
close STDERR;
open STDERR, '>', \$err_buf;

my $tx = Text::Xslate->new(cache => 0, path => \%vpath);

is $tx->render('runner.tx', {test => sub {warn "WARNING";['OK'] }}), 'OK';
like $err_buf, qr/\b WARNING \b/xms;

done_testing;
