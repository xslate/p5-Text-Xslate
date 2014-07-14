#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(html_escape html_builder mark_raw);
use Text::Xslate::Util qw(p);
use Data::Dumper;
use Time::localtime qw(localtime);
#use CGI qw(span);
use Digest::MD5 qw(md5 md5_hex);

sub span {
    return "<span>@_</span>";
}

$Data::Dumper::Sortkeys = 1;

my $tx = Text::Xslate->new(
    module => [
        'Data::Dumper',
        'Time::localtime' => [qw(localtime)],
        'Scalar::Util'    => [qw(blessed)],
        'Digest::MD5'     => [qw(md5 md5_hex)],
    ],
    function => {
        blessed => sub{ 42 }, # override
        span    => html_builder(\&span),
    },
);

my @set = (
    [
        '<: Dumper($d) :>',
        { d => { foo => 'bar', baz => [42] } },
        Dumper({ foo => 'bar', baz => [42] }),
        'Data::Dumper'
    ],
    [
        '<: localtime($t).mday :>',
        { t => $^T },
        localtime($^T)->mday,
        'Time::localtime',
    ],
    [
        '<: md5_hex($x) :>',
        { x => 'foo' },
        md5_hex('foo'),
        'Digest::MD5',
    ],
    [
        '<: blessed($x) :>',
        { x => bless {} },
        42,
        'function overrides the imported',
    ],
    [
        '<: dump($x) :>',
        { x => 42 },
        p(42),
        'builtins',
    ],
    [
        '<: span($x) :>',
        { x => 42 },
        mark_raw('<span>42</span>'),
        'html_builder',
    ],
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), html_escape($out), $msg;
}

done_testing;
