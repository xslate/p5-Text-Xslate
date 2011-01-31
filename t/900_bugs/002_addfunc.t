#!perl -w
use strict;
use warnings;
use Test::More;

use File::Path qw(rmtree);
use constant CACHE => '.900-02';
use Text::Xslate;

my %vpath = (
    'foo.tx' => <<'T',
%% foo()
T
);

BEGIN {
    rmtree(CACHE);
    mkdir(CACHE);
}
END { rmtree(CACHE) }

{
    my $tx = Text::Xslate->new(
        syntax => 'TTerse',
        path => \%vpath,
        cache_dir => CACHE,
        verbose => 0,
    );
    is $tx->render('foo.tx'), '';
}
{
    my $tx = Text::Xslate->new(
        syntax => 'TTerse',
        path => \%vpath,
        cache_dir => CACHE,
        verbose => 0,
        function => { foo => sub { 'OK' } },
    );
    is $tx->render('foo.tx'), 'OK';
}

done_testing;

