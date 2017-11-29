#!perl -w
use strict;
use utf8;
use Test::More;

use Text::Xslate;
use Encode ();

use File::Path qw(rmtree);
use lib "t/lib";
use Util;
rmtree(cache_dir);
END{ rmtree(cache_dir) }

my $p = Encode::encode('cp932', 'エクスレート');

for(1 .. 2) {
    my $tx =  Text::Xslate->new(
        path => [path],
        cache_dir => cache_dir,
        pre_process_handler => sub { Encode::encode('cp932', $_[0]) },
    );


    is $tx->render('hello_utf8.tx', { name => $p }),
        Encode::encode('cp932', "こんにちは！ エクスレート！\n");

    is $tx->render('hello_utf8.tx', { name => $p }),
        Encode::encode('cp932', "こんにちは！ エクスレート！\n");
}
done_testing;
