#!perl
#https://github.com/gfx/p5-Text-Xslate/issues/issue/28
use strict;
use warnings;
use utf8;
use Test::More;

use Text::Xslate;

my @warnings;
my $xslate = Text::Xslate->new(
    syntax        => 'TTerse',
    warn_handler => sub { push @warnings, @_ },
);
$xslate->render_string('[% IF others.size() > 0 %][% END %]', {});

like   "@warnings", qr/\b nil \b/xms;
unlike "@warnings", qr/Use of uninitialized value/;

done_testing;

