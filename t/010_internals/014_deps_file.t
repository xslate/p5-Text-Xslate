#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Copy qw(copy move);
use File::Path qw(rmtree);

use t::lib::Util;

my $base    = path . "/myapp/base.tx";
my $derived = path . "/myapp/derived.tx";
rmtree cache_dir;
END{
    move "$base.save" => $base if -e "$base.save";

    rmtree cache_dir;
}

note 'for files';

utime $^T - 120, $^T - 120, $base, $derived;

my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

#use Data::Dumper; print Dumper $tx;

is $tx->render('myapp/derived.tx', {lang => 'Xslate'}), <<'T', 'original' for 1 .. 2;
HEAD
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
FOOT
T

move $base => "$base.save";
copy "$base.mod" => $base;

utime $^T+60, $^T+60, $base;
note "modify $base";

is $tx->render('myapp/derived.tx', {lang => 'Foo'}), <<'T', 'modified' for 1 .. 2;
HEAD
    D-BEFORE
    Modified version of base.tx
    D-AFTER
FOOT
T

move "$base.save" => $base;
utime $^T+120, $^T+120, $base;
note "modify $base again";

is $tx->render('myapp/derived.tx', {lang => 'Perl'}), <<'T', 'again' for 1 .. 2;
HEAD
    D-BEFORE
    Hello, Perl world!
    D-AFTER
FOOT
T

done_testing;
