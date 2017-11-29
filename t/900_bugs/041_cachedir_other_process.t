#!perl
use strict;
use warnings;
use Test::More;
use File::Path qw(rmtree);
use lib "t/lib";
use Util;
use File::Spec;
use Time::HiRes qw(sleep);
use Text::Xslate;

plan skip_all => 'fork emulation does not work' if $^O eq 'MSWin32';

rmtree(cache_dir);

my $tx = Text::Xslate->new(
 path      => [path],
 cache     => 1,
 cache_dir => cache_dir,
);

my $cache_dir = do {
    my $fi = $tx->find_file("hello.tx");
    my($volume, $dir) = File::Spec->splitpath($fi->{cachepath});
    File::Spec->catpath($volume, $dir, '');
};

my $mkpath = File::Path->can('mkpath');
no warnings 'redefine';
local *File::Path::mkpath = sub {
    my ($path) = @_;
    if ($path eq $cache_dir) {
        note 'waiting child process';
        sleep 0.2;
        ok $cache_dir, 'cache_dir seems created on child process';
        note 'mkpath on parent pwaiting child process';
    }
    $mkpath->(@_);
};

ok ! -e $cache_dir, 'cache directory does not exists';

my $pid = fork;

BAIL_OUT 'fork failed' unless defined $pid;

if ($pid) {
    my $fi = $tx->load_file("hello.tx");
    ok -e $cache_dir, 'cache directory exists';
    done_testing;
    rmtree(cache_dir);
} else {
    note 'waiting if(not -e $cachedir) {';
    sleep 0.1;
    note 'mkpath on child process';
    $mkpath->($cache_dir);
}
