#!perl
use strict;
use warnings;
use Fatal qw(open close utime);
use Test::More;
use File::Basename qw(basename);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use File::stat qw(stat);
use Text::Xslate;

# problems on deploying
#
# 1. mtime of foo.tx@stage is 12:00
# 2. there's access to the service and then mtime of foo.txc@service gets 12:00
# 3. to deploy foo.tx, mtime of which@service is 12:00
# 4. there's access to the service; mtime of foo.tx and foo.txc is the same

my $content0 = <<'T';
Hello, world!
T

my $content1 = <<'T';
modified
T

{
    my $service = tempdir(CLEANUP => 1);

    my $tx  = Text::Xslate->new(
        cache_dir => "$service/cache",
        path      => [$service],
    );
    write_file("$service/foo.tx", $content0);

    sleep 1; # time goes

    is $tx->render("foo.tx"), $content0;

    write_file("$service/foo.tx", $content1);

    is $tx->render("foo.tx"), $content1;
}

done_testing;
exit;

sub write_file {
    my($file, $content) = @_;

    open my($fh), ">", $file;
    print $fh $content;
    close $fh;
    return;
}

