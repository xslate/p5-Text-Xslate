#!perl -w

use strict;
use Test::More tests => 2;

BEGIN { use_ok 'Text::Xslate' }
BEGIN { use_ok 'Text::Xslate::Compiler' }

diag "Testing Text::Xslate/$Text::Xslate::VERSION";

