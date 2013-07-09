#!perl -wT

use strict;
use Test::More;

use Text::Xslate;
use File::Path;
use Scalar::Util qw(tainted);
use Cwd qw(getcwd);

my $cwd;
my $cache_dir;
tainted($cwd) and die "cwd is tainted";

BEGIN{
    $cwd = getcwd();
    if ($cwd =~ /(.+)/) {
        $cwd = $1;
    }
    $cache_dir = $cwd . '/xxx_test_taint_issue84';
}
END{ rmtree($cache_dir) }

tainted($cache_dir) and die "cache_dir is tainted";


for (1 .. 2) {
    my $tx = Text::Xslate->new(
        path => [$cwd . '/t/template'],
        cache_dir => $cache_dir,
        cache     => 1,
    );

    for(1 .. 2) {
        is $tx->render('hello.tx', { lang => 'Xslate'}),
            "Hello, Xslate world!\n";
        utime time()+rand(100), time()+rand(100), "$cwd/t/template/hello.tx";
    }
}

done_testing;
