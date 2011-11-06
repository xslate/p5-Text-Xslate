#!perl
use strict;
use warnings;
use utf8;

use Text::Xslate;
use Text::Xslate::Util qw(html_escape html_builder);
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
        l_raw => html_builder {
            my $format = shift;
            my @args = map { html_escape($_) } @_;
            return $i18n->maketext($format, @args);
        },
    },
);

my %param = (location => '<Tokyo>'); # user inputs
my $body = $xslate->render_string(<<'TEMPLATE', \%param);
[% l_raw('Hello!<br />') %]
[% l_raw('I am in %1<br />', $location) %]
TEMPLATE

print Encode::encode_utf8($body);

