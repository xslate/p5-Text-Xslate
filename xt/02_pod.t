#!perl -w

use strict;
use Test::More;
eval q{use Test::Pod 1.14};
plan skip_all => 'Test::Pod 1.14 required for testing POD'
	if $@;

all_pod_files_ok();
