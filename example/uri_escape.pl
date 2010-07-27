#!perl -w
use strict;

use Text::Xslate;

my $tx  = Text::Xslate->new(
    module    => ['URI::Escape'],
    cache_dir => '.eg_cache',
);

print $tx->render_string(<<'T', { app_param => "foo & bar" });
<a href="http://example.com/app/<:
    $app_param | uri_escape_utf8 :>">something</a>
T
