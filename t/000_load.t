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
if(Text::Xslate->isa('Text::Xslate::PP')) {
    diag "Backend: PP::", Text::Xslate::PP::_PP_BACKEND();
}
else {
    diag "Backend: XS";
}
diag '$ENV{XSLATE}=', defined $ENV{XSLATE} ? $ENV{XSLATE} : '';

diag "Any::Moose Backend: ", any_moose(), "/", any_moose()->VERSION;

