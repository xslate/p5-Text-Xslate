#!perl -w

use strict;
use Test::More;

use Text::Xslate::Parser;

use Data::Dumper;
$Data::Dumper::Indent = 1;

my $parser = Text::Xslate::Parser->new();

isa_ok $parser, 'Text::Xslate::Parser';

my @data = (
    ['Hello, world!', qr/"Hello, world!"/],
    ['Hello, <?= $lang ?> world!', qr/ \$lang \b/xms, qr/"Hello, "/, qr/" world!"/],
    ['aaa <?= $bbb ?> ccc <?= $ddd ?>', qr/aaa/, qr/\$bbb/, qr/ccc/, qr/\$ddd/],

    ['<? for $data ->($item) { echo $item; } ?>', qr/\b for \b/xms, qr/\$data\b/, qr/\$item/ ],
);

foreach my $d(@data) {
    my($str, @patterns) = @{$d};

    my $code = Dumper($parser->parse($str));
    note($code);

    foreach my $pat(@patterns) {
        like $code, $pat, $str;
    }
}

done_testing;
