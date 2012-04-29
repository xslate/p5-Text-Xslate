package t::lib::Util;
use strict;

use parent qw(Exporter);
our @EXPORT = qw(path cache_dir);

use FindBin qw($Bin);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

use Test::Requires "File::Copy::Recursive";
$File::Copy::Recursive::KeepMode = 0;

my $cur;
sub path () {

    if ( (caller())[1] =~ 't/010_internals/028_taint.t') {
        $Bin = $1 if $Bin =~ /(.+)/;  # sigh... :(
    }

    unless ($cur) {
        $cur = tempdir(DIR =>  dirname($Bin) . "/.", CLEANUP => 1);
    }

    {
        my $template_path = dirname($Bin) . "/template";
        File::Copy::Recursive::rcopy($template_path, $cur) or die $!;
    }

    return $cur;
}

use constant cache_dir => ".xslate_cache/$0";
1;
