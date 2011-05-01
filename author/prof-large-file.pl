#!perl -w
use strict;
use File::Temp;
use File::Basename;

my $N   = 500;

my $tmp = File::Temp->new(
    UNLINK  => 0,
    DIR     => 'author',
    SUFFIX  => '.tt',
);
$tmp->unlink_on_destroy(1);

my $tmpl = <<'XML';
    <foo>
        <bar>[% aaa %]</bar>
        <baz>[% bbb %]</baz>
    </foo>
XML

print $tmp "<root>\n";

for my $i(1 .. $N) {
   print $tmp $tmpl;
}

print $tmp "</root>\n";
close $tmp;

system($^X, 'author/large.pl', basename($tmp)) == 0
    or die "Failed to exec"; # wake up

system($^X, '-d:NYTProf', 'author/large.pl', basename($tmp)) == 0
    or die "Failed to exec";


