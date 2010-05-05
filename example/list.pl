#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

my $path = $Bin;
my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir =>  $path,
);

print $tx->render('list.tx', {data => [
    { title => 'Islands in the stream' },
    { title => 'Programming Perl'      },
    { title => 'River out of Eden'     },
    { title => 'Beautiful code'        },
]});

