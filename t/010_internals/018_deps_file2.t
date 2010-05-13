#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Copy qw(copy move);

use t::lib::Util;

my $base    = path . "/myapp/base.tx";
my $derived = path . "/myapp/derived.tx";
END{
    move "$base.save" => $base if -e "$base.save";

    unlink $base    . "c";
    unlink $derived . "c";
}

unlink $base    . "c";
unlink $derived . "c";

note 'for files';

utime $^T - 120, $^T - 120, $base, $derived;

{
    # compile and cache template files.
    my $tx = Text::Xslate->new(path => [path], cache_dir => path);
    $tx->render($_, {lang => 'Perl'}) for 'myapp/derived.tx';
}

utime $^T - 60, $^T - 60, $base."c", $derived."c";
note " cache files have been created at 60 seconds ago.";

my $tx = Text::Xslate->new(path => [path], cache_dir => path);

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

move "$base.save" => $base;

done_testing;
