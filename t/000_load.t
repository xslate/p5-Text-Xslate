#!perl -w

use strict;
use Test::More tests => 5;
use B;

BEGIN { use_ok 'Text::Xslate' }
BEGIN { use_ok 'Text::Xslate::Compiler' }
BEGIN { use_ok 'Text::Xslate::Parser' }
BEGIN { use_ok 'Text::Xslate::EscapedString' }
BEGIN { use_ok 'Any::Moose' }

diag "Testing Text::Xslate/$Text::Xslate::VERSION";

diag "Backend: ", Text::Xslate->isa('Text::Xslate::PP') ? "PP" : "XS";

diag "Any::Moose Backend: ", any_moose(), "/", any_moose()->VERSION;

