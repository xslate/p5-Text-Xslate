#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/95
use strict;
use warnings;
use Fatal qw(open close);
use File::Path qw(remove_tree);
use Test::More;

use Text::Xslate;

use File::Temp qw(tempdir);

# here's some test template files
my $base_a = <<'EOF';
here is base A
: block body -> {}
EOF

my $sub_a = <<'EOF';
: cascade base
: override body {
this is sub A
: }
EOF

my $sub_b = <<'EOF';
: cascade base
: override body {
this is sub B
: }
EOF

# remove old directories if they exist and re-create
remove_tree('path_a', 'path_b');
END { remove_tree('path_a', 'path_b') }
mkdir 'path_a';
mkdir 'path_b';

write_file('path_a/base.tx', $base_a);
write_file('path_a/sub.tx', $sub_a);

my $tx = Text::Xslate->new(
    path => ['path_b', 'path_a'],

    cache => 1,
    cache_dir => tempdir(CLEANUP => 1),
);

my $out = $tx->render('sub.tx');

# expect both base and sub A since there is nothing in path B
is($out, "here is base A\nthis is sub A\n", "cascade with base in same directory");

# now a new path_b sub file, and render again
write_file('path_b/sub.tx', $sub_b);
my $out2 = $tx->render('sub.tx');

# we should get the A base (since there is no B base) with the B sub (since that is first in path)
{ local $TODO = 'not yet';
is($out2, "here is base A\nthis is sub B\n", "cascade with base in different directory");
}


$tx = Text::Xslate->new(
    path => ['path_b', 'path_a'],

    cache => 1,
    cache_dir => tempdir(CLEANUP => 1),
);

note 'after re-creating an Xslate instance';
my $out3 = $tx->render('sub.tx');
is($out3, "here is base A\nthis is sub B\n", "cascade with base in different directory");

done_testing;

sub write_file {
    my($path, $content) = @_;
    open my $fh, ">", $path;
    print $fh $content;
    close $fh;
}
