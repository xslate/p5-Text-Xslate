#!perl -w
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my %vpath = (
    'component.tx' => <<'T',
: around body -> {
<!doctype html>
<html>
  <head><title>Welcome</title></head>
  <body>
    : super
  </body>
</html>
: }
T

    'main.tx' => <<'T',
: cascade with component

: block body -> {
<h2><: $message :></h2>
This page was generated from the template
: }
T
);

my $tx = Text::Xslate->new(path => \%vpath, cache => 0);
my $out = $tx->render('main.tx', { message => 'OK'});
like $out, qr/<html>/;
like $out, qr/<h2>/;
like $out, qr/OK/;

done_testing;

