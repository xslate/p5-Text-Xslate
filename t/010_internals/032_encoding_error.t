#!perl -w
use strict;
use Test::More skip_all => 'TODO: the behaviours of PP and XS does not match';
use Text::Xslate;
use File::Path qw(rmtree);
use utf8;

use lib "t/lib";
use Util;
BEGIN{ rmtree(cache_dir) }
END  { rmtree(cache_dir) }

my $str = 'エクスレイト';
utf8::encode($str);

my $tx = Text::Xslate->new(
    path      => [path],
    cache_dir => cache_dir,
    cache     => 0,
);

diag $tx->render('hello_utf8.tx', { name => $str });
diag $tx->render('hello_utf8.tx', { name => $str });
pass;

done_testing;

