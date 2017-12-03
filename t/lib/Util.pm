package Util;
use strict;

use parent qw(Exporter);
our @EXPORT = qw(path cache_dir);

use File::Temp qw(tempdir);
use File::Find qw(find);

use Test::Requires "File::Copy::Recursive";
$File::Copy::Recursive::KeepMode = 0;

my $path;
my $cache_dir;

sub reinit {
    $path = tempdir CLEANUP => 1;
    File::Copy::Recursive::rcopy("t/template", $path) or die $!;
    if ($^O eq 'MSWin32') {
        # On windows, File::Copy::copy equals Win32::CopyFile, which preserves mtime.
        # In our case, we need to ensure that mtime of copied files are now
        my $wanted = sub {
            return unless -f;
            $_ = $1 if /(.+)/; # untaint
            utime $^T, $^T, $_;
        };
        find({wanted => $wanted, no_chdir => 1}, $path);
    }
    $cache_dir = tempdir CLEANUP => 1;
}

sub path () { $path }
sub cache_dir () { $cache_dir }

reinit();

1;
