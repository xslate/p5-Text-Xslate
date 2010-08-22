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
    type      => 'text',
);

my @set = (
    [<<'T', { value => "<foo>" }, <<'X', 'type => "text"'],
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
    type      => 'html',
);
is $tx->render('hello.tx', { lang => '<Xslate>' }),
    "Hello, &lt;Xslate&gt; world!\n", "type => 'html'";

$tx = Text::Xslate->new(
    path      =>  path,
    cache_dir =>  cache_dir,
    type      => 'xml',
);
is $tx->render('hello.tx', { lang => '<Xslate>' }),
    "Hello, &lt;Xslate&gt; world!\n", "type => 'xml'";

done_testing;
