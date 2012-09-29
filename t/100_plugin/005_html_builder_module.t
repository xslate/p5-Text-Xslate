#!perl -w
use strict;
use Test::More;

use Text::Xslate;

{
    package My::HTML::Builder;
    use parent qw(Exporter);
    our @EXPORT = qw(foo);
    sub foo {
        return "<br />";

    }
    $INC{'My/HTML/Builder.pm'} = __FILE__;
}

my $tx = Text::Xslate->new(
    html_builder_module => [
        'My::HTML::Builder',
    ],
);

my @set = (
    [
        '<: foo() :>',
        { },
        "<br />",
        'My::HTML::Builder returns a aprt of HTML'
    ],
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg;
}

done_testing;
