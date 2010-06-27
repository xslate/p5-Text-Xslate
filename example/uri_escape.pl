#!perl -w
use strict;

use Text::Xslate;

my $tx  = Text::Xslate->new(
    cache  => 0,
    module => ['URI::Escape'],
);

print $tx->render_string(<<'T', { app_param => "foo & bar" });
<a href="http://example.com/app/<:
    $app_param | uri_escape_utf8 :>">something</a>
T
