#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);
use File::Find;

my $path = $Bin;
my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir => '.eg_cache',
);

# preload templates
find sub {
    if(/\.tx$/) {
        my $file = $File::Find::name;
        $file =~ s/\Q$path\E .//xsm;
        $tx->load_file($file);
    }
}, $path;

print $tx->render('list.tx', {data => [
    { title => 'Islands in the stream' },
    { title => 'Programming Perl'      },
    { title => 'River out of Eden'     },
    { title => 'Beautiful code'        },
]});

