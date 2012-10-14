#!perl
# https://gist.github.com/3499604
# reported by ktat
# modified by gfx

use strict;
use warnings;

use Test::More;

use Text::Xslate;

my %vpath;
$vpath{"test.tt"} = <<'_TMPL_';
[%- MACRO hoge1 (aaa) BLOCK -%]
[%- END -%]
[%- SET foo = 42 -%]
[%- MACRO hoge2 (bbb) BLOCK -%]
Calling this macro clobbered "foo".
[%- END -%]
[%- hoge2("a") -%]
[% hoge1("b") %]

[% foo %] should be 42.
_TMPL_

my $t = Text::Xslate->new(
    syntax => 'TTerse',
    cache  => 0,
    path => \%vpath
);

my $text = $t->render("test.tt");
note $text;
like $text, qr/^42 \s+ should \s+ be \s+ 42\.$/xms;

done_testing;

