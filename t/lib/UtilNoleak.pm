package UtilNoleak;
use strict;

use parent qw(Exporter);
our @EXPORT = qw(path cache_dir);

use FindBin qw($Bin);
use File::Basename qw(dirname);

use constant path => dirname($Bin) . "/template";
use constant cache_dir => ".xslate_cache/$0";
1;

