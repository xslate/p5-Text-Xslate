#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/61

use strict;
use warnings;
use Fatal qw(open close);
use Test::More;
use File::Temp qw(tempdir);
use File::Spec ();
use Text::Xslate;

# problems on depend cache
#
# 1. main.tx cascade to base.tx
# 2. mtime of main.tx is 12:00
# 3. mtime of base.tx is 12:01(newer than main.tx)
# 4. render main.tx
# 5. render main.tx again, but don't use cache

{
    package MyXslate;
    use parent qw(Text::Xslate);

    sub _load_source {
        my ($self, $fi) = @_;
        my $fullpath  = $fi->{fullpath};

        $self->{_load_source_count}{$fullpath}++;

        $self->SUPER::_load_source($fi);
    }
}


my $content_main = <<'T';
: cascade base
T

my $content_base = <<'T';
I am base
T

{
    my $service = tempdir(CLEANUP => 1);

    my $tx  = MyXslate->new(
        cache_dir => "$service/cache",
        path      => [$service],
    );
    write_file("$service/main.tx", $content_main);
    sleep 2; # time goes
    write_file("$service/base.tx", $content_base);

    is $tx->render("main.tx"), $content_base;
    is $tx->render("main.tx"), $content_base;

    my $path = File::Spec->catfile($service, "main.tx");
    is $tx->{_load_source_count}{$path} => 1;

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
