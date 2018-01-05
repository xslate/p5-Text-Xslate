use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(
    path => {
        'body.tx' => ': block body | reverse -> { include text }',
        'text.tx' => 'Text::Xslate',
    },
    function => {
        reverse => sub { scalar reverse $_[0]; },
    },
    cache => 0,
);

{
    my $warnings = '';
    is($tx->render('body.tx'), 'etalsX::txeT');
    is($warnings, '');
}

done_testing;
