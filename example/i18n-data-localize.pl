#!perl
use strict;
use warnings;
use utf8;

use Text::Xslate;
use Text::Xslate::Util qw(html_escape html_builder);
use Data::Localize;
use Data::Localize::Gettext;
use FindBin qw($Bin);
use Encode ();

my $i18n = Data::Localize->new(
    auto      => 1,
    languages => ['ja'],
);
$i18n->add_localizer(
    class => 'Gettext',
    path  => "$Bin/locale/*.po",
);

my $xslate = Text::Xslate->new(
    syntax   => 'TTerse',
    function => {
        l => sub {
            return $i18n->localize(@_);
        },
        l_raw => html_builder {
            my $format = shift;
            my @args = map { html_escape($_) } @_;
            return $i18n->localize($format, @args);
        },
    },
);

my %param = (location => '<Tokyo>'); # user inputs
my $body = $xslate->render_string(<<'TEMPLATE', \%param);
[% l_raw('Hello!<br />') %]
[% l_raw('I am in %1<br />', $location) %]
TEMPLATE

print Encode::encode_utf8($body);

