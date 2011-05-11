#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(html_builder);


my $tx = Text::Xslate->new(
    cache   => 0,
    verbose => 2,
    warn_handler => sub { die @_ },

    function => {
        html_escape => html_builder {
            my($s) = @_;
            $s =~ s/(.)/ '&#' . ord($1) . ';'/xmsge;
            return $s;
        },
    },
);

local $TODO = 'not yet implemented';

is $tx->render_string('<: "<foo>" :>'),
    join '', map { "&#$_;" } 60, 102, 111, 62;

done_testing;
