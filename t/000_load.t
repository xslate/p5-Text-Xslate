#!perl -w

use strict;
use Test::More tests => 8;

BEGIN { use_ok 'Text::Xslate' }
BEGIN { use_ok 'Text::Xslate::Compiler' }
BEGIN { use_ok 'Text::Xslate::Parser' }
BEGIN { use_ok 'Text::Xslate::Syntax::Kolon' }
BEGIN { use_ok 'Text::Xslate::Syntax::Metakolon' }
BEGIN { use_ok 'Text::Xslate::Syntax::TTerse' }
BEGIN { use_ok 'Text::Xslate::Type::Raw' }
BEGIN { use_ok 'Any::Moose' }

diag "Testing Text::Xslate/$Text::Xslate::VERSION";
if(Text::Xslate->isa('Text::Xslate::PP')) {
    diag "Backend: PP";
}
else {
    diag "Backend: XS";
}
diag '$ENV{XSLATE}=', $ENV{XSLATE} || '';

diag "Any::Moose Backend: ", any_moose(), "/", any_moose()->VERSION;

