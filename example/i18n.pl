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
    Encoding => 'UTF-8',
    Path     => "$Bin/locale",
;

loc_lang('ja');

my $xslate = Text::Xslate->new(
    syntax   => 'TTerse',
    function => {
        l => sub {
            return Encode::decode_utf8( loc(@_) );
        },
    },
);

binmode STDOUT, ':utf8';
print $xslate->render_string(<<'TEMPLATE');
[% l('Hello!') %]
[% l('tokyo') %]
TEMPLATE

