#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use utf8;

use t::lib::Util;
use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

my $tx = Text::Xslate->new(
    path      => [path],
    cache_dir =>  cache_dir,
);

note 'for strings';

is $tx->render_string(<<'T', { value => "エクスレート" }),
ようこそ <:= $value :> の世界へ！
T
    "ようこそ エクスレート の世界へ！\n", "utf8";

is $tx->render_string(<<'T', { value => "Xslate" }),
ようこそ <:= $value :> の世界へ！
T
    "ようこそ Xslate の世界へ！\n", "utf8";


is $tx->render_string(<<'T'), <<'X', 'macro';
: macro lang -> { "エクスレート" }
ようこそ <:= lang() :> の世界へ！
T
ようこそ エクスレート の世界へ！
X

is $tx->render_string(<<'T', { value => "<エクスレート>" }),
Hello, <:= $value :> world!
T
    "Hello, &lt;エクスレート&gt; world!\n";

is $tx->render_string(q{<: $value :>}, { value => "<エクスレート>" }),
    "&lt;エクスレート&gt;";

note 'for files';

is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
    "こんにちは！ エクスレート！\n", "in files" for 1 .. 2;

for(1 .. 2) {
    $tx = Text::Xslate->new(
        path        => [path],
        cache_dir   =>  cache_dir,
        input_layer => ":encoding(utf-8)",
    );

    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", ":encoding(utf-8)";
}

for(1 .. 2) {
    $tx = Text::Xslate->new(
        path        => [path],
        cache_dir   =>  cache_dir,
        input_layer => ":encoding(Shift_JIS)",
    );

    is $tx->render("hello_sjis.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", ":encoding(Shift_JIS)";
}


for(1 .. 2) {
    no utf8;
    $tx = Text::Xslate->new(
        path        => [path],
        cache_dir   =>  cache_dir,
        input_layer => ":bytes",
    );
    #use Devel::Peek; Dump($tx->render("hello_utf8.tx", { name => "エクスレート" }));
    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", ":bytes";
}

done_testing;
