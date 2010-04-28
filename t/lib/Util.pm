package t::lib::Util;
use strict;

use parent qw(Exporter);
our @EXPORT = qw(path);

use FindBin qw($Bin);
use File::Basename qw(dirname);

use constant path => dirname($Bin) . "/template";

1;
