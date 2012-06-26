#!perl -w
BEGIN{ eval "use Test::Name::FromLine" }
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(
    cache => 0,
    module => ['Text::Xslate::Bridge::Star'],
    warn_handler => sub { die @_ },
    verbose => 2,
);

is $tx->render_string(': uc("foo")'), 'FOO';
is $tx->render_string(': uc(nil) // "ok"'), 'ok';
is $tx->render_string(': "foo".uc()'), 'FOO';

is $tx->render_string(': lc("FOO")'), 'foo';
is $tx->render_string(': lc(nil) // "ok"'), 'ok';
is $tx->render_string(': "FOO".lc()'), 'foo';

is $tx->render_string(': substr("foo", 1)'), 'oo';
is $tx->render_string(': substr("foo", 1, 1)'), 'o';
is $tx->render_string(': substr(nil, 1, 1) // "ok"'), 'ok';
is $tx->render_string(': "foo".substr(1)'), 'oo';

is $tx->render_string(': sprintf("a %d b", 3.14)'), 'a 3 b';
is $tx->render_string(': 3.1415 | sprintf("%.02f")'), '3.14';

is $tx->render_string(': match("foo", "o")       ? "T" : "F"'), 'T';
is $tx->render_string(': match("foo", "f..")     ? "T" : "F"'), 'F';
is $tx->render_string(': match("foo", rx("f..")) ? "T" : "F"'), 'T';
is $tx->render_string(': match(nil, rx("f.."))   ? "T" : "F"'), 'F';
is $tx->render_string(': "foo".match(rx("f.."))  ? "T" : "F"'), 'T';

is $tx->render_string(': replace("foo", "o", "x")'), 'fxx';
is $tx->render_string(<<'T'), 'fxx';
: "foo".replace("oo", "xx")
T

is $tx->render_string(<<'T'), 'fxx';
: "foo".replace(rx("o."), "xx")
T

is $tx->render_string(<<'T'), 'foo';
: "foo".replace("o.", "xx")
T

is $tx->render_string(': "foo::bar".split(rx("::")).join("/")'), 'foo/bar';
is $tx->render_string(': "foo[0-9]bar".split("[0-9]").join("/")'), 'foo/bar';
is $tx->render_string(': "foo3bar[0-9]".split(rx("[0-9]")).join("/")'), 'foo/bar[/-/]';
is $tx->render_string(': "foo/bar/baz".split("/", 2).join("--")'), 'foo--bar/baz';
is $tx->render_string(': "h o k".split(" ").join("-")'), 'h-o-k';
is $tx->render_string(': "h o k".split().join("-")'), 'h-o-k';

done_testing;

