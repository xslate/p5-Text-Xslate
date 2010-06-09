#!perl -w

use strict;
use Test::More;

use t::lib::TTSimple;

is render_file('include.tt', { lang => "Xslate" }),
    "include:\n" . "Hello, Xslate world!\n";

is render_file('include2.tt', { file => "hello.tt", lang => "Xslate" }),
    "include2:\n" . "Hello, Xslate world!\n";

is render_file('include2.tt', { file => "include.tt", lang => "Xslate" }),
    "include2:\n" . "include:\n" . "Hello, Xslate world!\n";

is render_str(<<'T', { lang => "Xslate" }), <<'X';
[% INCLUDE "hello.tt" WITH lang = "TTerse" -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
Hello, Xslate world!
X

is render_str(<<'T', { lang => "Xslate" }), <<'X';
[% INCLUDE "hello.tt" WITH
    pi   = 3.14
    lang = "TTerse" -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
Hello, Xslate world!
X

is render_str(<<'T', { lang => "Xslate" }), <<'X';
[% INCLUDE "hello.tt" WITH pi = 3.14, lang = "TTerse" -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
Hello, Xslate world!
X

is render_str(<<'T', { lang => "Xslate" }), <<'X', 'lower-cased';
[% include "hello.tt" with pi = 3.14, lang = "TTerse" -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
Hello, Xslate world!
X

#is render_str(<<'T', { lang => "Xslate" }), <<'X', 'WITH is optional';
#[% INCLUDE "hello.tt" pi = 3.14, lang = "TTerse" -%]
#Hello, [% lang %] world!
#T
#Hello, TTerse world!
#Hello, Xslate world!
#X

done_testing;
