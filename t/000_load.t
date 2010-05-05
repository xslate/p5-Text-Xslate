#!perl -w

use strict;
use Test::More tests => 4;

BEGIN { use_ok 'Text::Xslate' }
BEGIN { use_ok 'Text::Xslate::Compiler' }
BEGIN { use_ok 'Text::Xslate::Parser' }
BEGIN { use_ok 'Text::Xslate::EscapedString' }

diag "Testing Text::Xslate/$Text::Xslate::VERSION";

