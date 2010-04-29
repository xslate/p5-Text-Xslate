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
}

note 'for strings';

utime $^T, $^T, $original;

my $tx = Text::Xslate->new(string => <<'T', path => [path]);
: cascade myapp::base
T

#use Data::Dumper; print Dumper $tx;

is $tx->render({lang => 'Xslate'}), <<'T';
HEAD
    Hello, Xslate world!
FOOT
T

move $original => "$original.save";
copy "$original.mod" => $original;

utime $^T+10, $^T+10, $original;
utime $^T+10, $^T+10, $original."c";

is $tx->render({}), <<'T';
HEAD
    Modified version of base.tx
FOOT
T

move "$original.save" => $original;

is $tx->render({lang => 'Perl'}), <<'T';
HEAD
    Hello, Perl world!
FOOT
T

done_testing;
