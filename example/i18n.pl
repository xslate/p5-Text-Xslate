#!perl
use strict;
use warnings;
use utf8;

use Text::Xslate;
use Encode ();

{
    package MyApp::I18N;
    use FindBin qw($Bin);
    use parent 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        '*'     => [Gettext => "$Bin/locale/*.po"],
        _auto   => 1,
        _decode => 1,
        _style  => 'gettext',
    };
}

my $i18n = MyApp::I18N->get_handle('ja');

my $xslate = Text::Xslate->new(
    syntax   => 'TTerse',
    function => {
        l => sub {
            return $i18n->maketext(@_);
        },
    },
);

print Encode::encode_utf8($xslate->render_string(<<'TEMPLATE'));
[% l('Hello!') %]
[% l('I am in %1', 'tokyo') %]
TEMPLATE

