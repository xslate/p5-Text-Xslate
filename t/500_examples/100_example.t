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

    foreach my $s($out, $err) {
        $s =~ s/\r\n/\n/g;
    }

    return($out, $err);
}

unlink <example/*.txc>;

while(defined(my $example = <example/*.pl>)) {
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

        is $out, $expect, $example . " ($_)";
        is $err, '', 'no errors';
    }
}

done_testing;
