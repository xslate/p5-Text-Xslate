#!perl -w
# re-number test files
use strict;

my $dir = shift(@ARGV) or die "Usage: $0 test-dir\n";
$dir =~ s{/$}{};
-d $dir or die "No such directory: $dir\n";

my $i = 0;
foreach my $dir (sort { ($a =~ /(\d+)_\w+\.t$/)[0] <=> ($b =~ /(\d+)_\w+\.t$/)[0] } <$dir/*.t>) {
    my $n = ($dir =~ /(\d+)_\w+\.t$/)[0];
    last if $n >= 100;

    (my $newdir = $dir) =~ s/(\d+)(_\w+\.t)$/ sprintf '%03d%s', ++$i, $2 /xmse;

    next if $dir eq $newdir;

    printf "%-36s => %-36s\n", $dir, $newdir;
    rename $dir => $newdir or die "Cannot rename $dir to $newdir: $!";
}
