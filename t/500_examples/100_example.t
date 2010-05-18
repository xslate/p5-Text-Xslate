#!perl -w
# test example/*.pl

use strict;
use Test::More;

use Text::Xslate;
use IPC::Open3 qw(open3);

sub perl {
    local(*IN, *OUT, *ERR);
    my $pid = open3(\*IN, \*OUT, \*ERR, $^X,
        (map { "-I$_" } @INC),
        @_,
    );

    close IN;
    local $/;
    my $out = <OUT>;
    my $err = <ERR>;

    close OUT;
    close ERR;

    return($out, $err);
}


while(<example/*.pl>) {
    my($out, $err) = perl($_);

    my $gold = $_;
    $gold =~ s/\.pl$/.gold/;

    open my $o, '<', $gold or die "$gold: $!";
    local $/;

    is $out, scalar(<$o>), $_;
    is $err, '', 'no errors';
}

done_testing;
