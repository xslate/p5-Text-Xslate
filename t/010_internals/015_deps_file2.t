#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Copy qw(copy move);
use File::Path qw(rmtree);
use File::Spec;
use lib "t/lib";
use Util;

rmtree cache_dir;

my $base;
my $derived;
my $base_c;
my $derived_c;
BEGIN {
    my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

    my $fi  = $tx->find_file('myapp/base.tx');
    $base   = $fi->{fullpath};
    $base_c = $fi->{cachepath};

    $fi        = $tx->find_file('myapp/derived.tx');
    $derived   = $fi->{fullpath};
    $derived_c = $fi->{cachepath};
}

END{
    move "$base.save" => $base if -e "$base.save";

    rmtree cache_dir;
}


note 'for files';

utime $^T - 120, $^T - 120, $base, $derived;

{
    # compile and cache template files.
    my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);
    $tx->render($_, {lang => 'Perl'}) for 'myapp/derived.tx';
}

utime $^T - 60, $^T - 60, $base_c, $derived_c;
note " cache files have been created at 60 seconds ago.";

my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

move $base => "$base.save";
copy "$base.mod" => $base;

utime $^T, $^T, $base;
note "modify $base just now";

is $tx->render('myapp/derived.tx', {lang => 'Foo'}), <<'T', "modified($_)" for 1 .. 2;
HEAD
    D-BEFORE
    Modified version of base.tx
    D-AFTER
FOOT
T

done_testing;
