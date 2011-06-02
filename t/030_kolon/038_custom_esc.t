#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(html_builder);


my $tx = Text::Xslate->new(
    cache   => 0,
    verbose => 2,
    warn_handler => sub { die @_ },

    function => {
        html => \&custom_html_escape
    },
);

is $tx->render_string(q{<div><: '<^_^>&hearts;' :></div>}),
    '<div>&lt;^_^&gt;&hearts;</div>';

is $tx->render_string(q{<div><: $foo :></div>}, { foo => '<^_^>&hearts;' }),
    '<div>&lt;^_^&gt;&hearts;</div>';

is $tx->render_string(q{<: '<div>' :>}),
    '&lt;div&gt;';

is $tx->render_string(q{<: '<div>' | raw :>}),
    '<div>';

is $tx->render_string(q{<: '<div>' | html :>}),
    '&lt;div&gt;';

my $tx_no_autoescape = Text::Xslate->new(
    cache   => 0,
    verbose => 2,
    warn_handler => sub { die @_ },
    type => 'text',

    function => {
        html => \&custom_html_escape
    },
);

is $tx_no_autoescape->render_string(q{<: '<div>' :>}),
    '<div>';

is $tx_no_autoescape->render_string(q{<: '<div>' | raw :>}),
    '<div>';

is $tx_no_autoescape->render_string(q{<: '<div>' | html :>}),
    '&lt;div&gt;';


done_testing;

sub custom_html_escape {
    my $s = shift;
    return $s if ref $s;
    my %h = (
        '<' => '&lt;',
        '>' => '&gt;',
        q{'} => '&#039;',
        q{"} => '&quot;',
        # '&' => '&amp;', # Don't espcae &. allowing to use character-entitfy-references(like '&#hearts)
    );

    $s =~ s/(.)/$h{$1} or $1/xmsge;
    Text::Xslate::Util::mark_raw($s);
}
