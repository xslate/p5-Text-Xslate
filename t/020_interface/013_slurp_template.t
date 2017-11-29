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

{
    package MyTemplate;
    our @ISA = qw(Text::Xslate);

    sub slurp_template {
        my($self, $input_layer, $fullpath) = @_;

        my $content = $self->SUPER::slurp_template($input_layer, $fullpath);
        return Encode::encode('cp932', $content);
    }
}

my $p = Encode::encode('cp932', 'エクスレート');

for(1 .. 2) {
    my $tx =  MyTemplate->new(
        path => [path],
        cache_dir => cache_dir,
    );


    is $tx->render('hello_utf8.tx', { name => $p }),
        Encode::encode('cp932', "こんにちは！ エクスレート！\n");

    is $tx->render('hello_utf8.tx', { name => $p }),
        Encode::encode('cp932', "こんにちは！ エクスレート！\n");
}
done_testing;


