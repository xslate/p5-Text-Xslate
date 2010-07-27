#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;
use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

my $tx = Text::Xslate->new(
    path      =>  path,
    cache_dir =>  cache_dir,
    escape    => 'none',
);

my @set = (
    [<<'T', { value => "<foo>" }, <<'X', 'escape => "none"'],
Hello, <: $value :>!
T
Hello, <foo>!
X
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}

is $tx->render('hello.tx', { lang => '<Xslate>' }),
    "Hello, <Xslate> world!\n";

$tx = Text::Xslate->new(
    path      =>  path,
    cache_dir =>  cache_dir,
    escape    => 'html',
);
is $tx->render('hello.tx', { lang => '<Xslate>' }),
    "Hello, &lt;Xslate&gt; world!\n", "magic number has the escape mode the cache compiled with";

done_testing;
