#!perl -w
# test example/*.pl

use strict;
use Test::More;

use IPC::Open3 qw(open3);
use File::Path qw(rmtree);

rmtree '.eg_cache';
END{ rmtree '.eg_cache' }

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

    foreach my $s($out, $err) {
        $s =~ s/\r\n/\n/g;
    }

    return($out, $err);
}

EXAMPLE: while(defined(my $example = <example/*.pl>)) {
    my $expect = do {
        my $gold = $example;
        $gold =~ s/\.pl$/.gold/;

        -e $gold or note("skip $example because it has no $gold"), next;

        open my $g, '<', $gold or die "Cannot open '$gold' for reading: $!";
        local $/;
        <$g>;
    };

    foreach(1 .. 2) {
        my($out, $err) = perl($example);

        if($err =~ /Can't locate / # ' for poor editors
                or $err =~ /version \S+ required--this is only version /) {
            $err =~ s/ \(\@INC contains: [^\)]+\)//;
            diag("skip $example because: $err");
            next EXAMPLE;
        }

        is $out, $expect, $example . " ($_)";
        is $err, '', 'no errors';
    }
}

done_testing;
