#!perl -w
use strict;
use File::Find;
use Fatal qw(open close);

sub wanted {
    return if not -f $_;

    print "$_\n";

    my $name = $_;

    open my $in, '<', $name;
    open my $out, '>', $name . ".tmp";
    while(<$in>) {
        s/^([ \t]*) \Q?/$1:/xms;
        s/\Q<?/<:/xmsg;
        s/\Q?>/:>/xmsg;
        print $out $_;
    }
    close $in;
    close $out;

    rename "$name.tmp" => $name;
}

find({
    wanted => \&wanted,
}, qw(t lib example benchmark));

