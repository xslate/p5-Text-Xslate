#!perl
# https://gist.github.com/3890412
use strict;
use warnings;

use Fatal qw(open close);
use File::Temp qw(tempdir);
use Test::More skip_all => 'deal with memorycache-filecache-original model more effectively';

use Text::Xslate;

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

    write_file("$service/main.tx", $content_main);
    write_file("$service/base.tx", $content_base);

    # emulate fork() (tow instances with the same options)
    my $tx1  = MyXslate->new(
        cache_dir => "$service/cache",
        path      => [$service],
    );
    my $tx2  = MyXslate->new(
        cache_dir => "$service/cache",
        path      => [$service],
    );

    note 'first time';
    is $tx1->render("main.tx"), $content_base;
    is $tx2->render("main.tx"), $content_base;

    is $tx1->{_load_source_count}{"$service/main.tx"} => 1;
    is $tx2->{_load_source_count}{"$service/main.tx"} => undef;

    sleep 1; # time goes
    note 'template was modified and time went';

    $content_base .= '2';
    write_file("$service/base.tx", $content_base);

    is $tx1->render("main.tx"), $content_base;
    is $tx1->{_load_source_count}{"$service/main.tx"} => 2;

    # render() should use cache without recompiling
    is $tx2->render("main.tx"), $content_base;
    is $tx2->{_load_source_count}{"$service/main.tx"} => undef, 'did not re-compile';
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

