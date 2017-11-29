#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(mark_raw);
use utf8;

use lib "t/lib";
use Util;
use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

for my $type (qw(html xml text)) {
# intentionally no indents because it breaks here documents

my $tx = Text::Xslate->new(
    path      => [path],
    cache_dir =>  cache_dir,
    type      => $type,
);

note "for strings (type=$type)";

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

is $tx->render_string(<<'T', { value => "エクスレート" }),
Hello, <:= $value :> world!
T
    "Hello, エクスレート world!\n";

is $tx->render_string(q{<: $value :>}, { value => "エクスレート" }),
    "エクスレート";

is $tx->render_string(q{<: $value :> <: $value :>}, { value => "エクスレート" }),
    "エクスレート エクスレート";

is $tx->render_string(<<'T', { value => mark_raw("エクスレート") }),
Hello, <:= $value :> world!
T
    "Hello, エクスレート world!\n";

is $tx->render_string(q{<: $value :>}, { value => mark_raw("エクスレート") }),
    "エクスレート";

is $tx->render_string(q{<: $value :> <: $value :>}, { value => mark_raw("エクスレート") }),
    "エクスレート エクスレート";


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
        type        => $type,
    );
    #use Devel::Peek; Dump($tx->render("hello_utf8.tx", { name => "エクスレート" }));
    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", ":bytes";
}
} # escape mode
done_testing;
