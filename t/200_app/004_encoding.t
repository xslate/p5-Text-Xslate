#!perl
use strict;
use warnings;
use utf8;

use Test::More;
use SelectSaver;
use Text::Xslate::Runner;

use Encode qw(encode decode);

sub capture(&) {
    my($block) = @_;

    my $s = '';

    {
        open my $out, '>', \$s;
        my $saver = SelectSaver->new($out);
        $block->();
    }
    return $s;
}

my $app = Text::Xslate::Runner->new(
    define => { name => '<Xslate>' },
    cache_dir => '.xslate_cache/app3',
);
is capture { $app->run('t/template/hello_utf8.tx') },
    encode("UTF-8", "こんにちは！ &lt;Xslate&gt;！\n");

$app->output_encoding('Shift_JIS');
is capture { $app->run('t/template/hello_utf8.tx') },
    encode("Shift_JIS", "こんにちは！ &lt;Xslate&gt;！\n");

$app->input_encoding('Shift_JIS');
$app->output_encoding('utf-8');
is capture { $app->run('t/template/hello_sjis.tx') },
    encode("UTF-8", "こんにちは！ &lt;Xslate&gt;！\n");

$app->input_encoding('Shift_JIS');
$app->output_encoding('Shift_JIS');
is capture { $app->run('t/template/hello_sjis.tx') },
    encode("Shift_JIS", "こんにちは！ &lt;Xslate&gt;！\n");

done_testing;
