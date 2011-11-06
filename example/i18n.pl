#!perl
use strict;
use warnings;
use utf8;
use Text::Xslate;
use FindBin qw($Bin);
use Encode ();
use Locale::Maketext::Lexicon;
use Locale::Maketext::Simple
    Style    => 'gettext',
    Path     => "$Bin/locale",
;

loc_lang('ja');

my $xslate = Text::Xslate->new(
    syntax   => 'TTerse',
    function => {
        l => sub {
            return Encode::decode_utf8(loc(map { Encode::encode_utf8($_) } @_));
        },
    },
);

binmode STDOUT, ':utf8';
print $xslate->render_string(<<'TEMPLATE');
[% l('Hello!') %]
[% l('I am in %1', 'tokyo') %]
TEMPLATE

