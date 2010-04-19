#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

my $tx = Text::Xslate->new(
    file  => 'list.tx',
    path  => ["$Bin/template"],
);

print $tx->render({data => [
    { title => 'Islands in the stream' },
    { title => 'Programming Perl'      },
    { title => 'River out of Eden'     },
    { title => 'Beautiful code'        },
]});

