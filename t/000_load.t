#!perl -w

use strict;
use Test::More tests => 4;
use B;

BEGIN { use_ok 'Text::Xslate' }
BEGIN { use_ok 'Text::Xslate::Compiler' }
BEGIN { use_ok 'Text::Xslate::Parser' }
BEGIN { use_ok 'Text::Xslate::EscapedString' }

diag "Testing Text::Xslate/$Text::Xslate::VERSION";

diag "Backend: ", B::svref_2object(Text::Xslate->can('render'))->XSUB ? "XS" : "PP";

