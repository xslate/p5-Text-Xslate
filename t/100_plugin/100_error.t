#!perl -w
use strict;
use Test::More;

use Text::Xslate;

use warnings FATAL => 'all';

eval {
    Text::Xslate->new(
        module => [ 'Text::Xslate::No::Such::Module' ],
    );
};

like $@, qr/Failed to import/;
like $@, qr{Can't locate Text/Xslate/No/Such/Module.pm};

eval {
    Text::Xslate->new(
        module => [ '(^_^)' ],
    );
};

like $@, qr/Invalid module name/;

done_testing;
