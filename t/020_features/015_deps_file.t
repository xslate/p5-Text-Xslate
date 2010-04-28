#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use FindBin qw($Bin);
use File::Copy qw(copy move);

use t::lib::Util;

my $original = "$Bin/../template/myapp/base.tx";
END{
    move "$original.save" => $original if -e "$original.save";
    unlink $original . "c";
    unlink "$Bin/../template/myapp/derived.txc";
}

unlink $original . "c";
unlink "$Bin/../template/myapp/derived.txc";

note 'for files';

utime $^T, $^T, $original;

my $tx = Text::Xslate->new(file => 'myapp/derived.tx', path => [path]);

#use Data::Dumper; print Dumper $tx;

is $tx->render('myapp/derived.tx', {}), <<'T';
HEAD
    D-BEFORE
    Hello, world!
    D-AFTER
FOOT
T

move $original => "$original.save";
copy "$original.mod" => $original;

utime $^T+10, $^T+10, $original;

is $tx->render('myapp/derived.tx', {}), <<'T' for 1 .. 2;
HEAD
    D-BEFORE
    Modified version of base.tx
    D-AFTER
FOOT
T

move "$original.save" => $original;

is $tx->render('myapp/derived.tx', {}), <<'T';
HEAD
    D-BEFORE
    Hello, world!
    D-AFTER
FOOT
T

done_testing;
