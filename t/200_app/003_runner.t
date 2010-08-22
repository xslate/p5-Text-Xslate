use strict;
use warnings;

use Test::More;
use SelectSaver;
use Text::Xslate::Runner;

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
    eval   => 'Hello, <: $lang :> world!',
    define => { lang => '<Xslate>' },
);
is capture { $app->run() }, "Hello, &lt;Xslate&gt; world!\n";

$app = Text::Xslate::Runner->new(
    eval   => 'Hello, <: $lang :> world!',
    define => { lang => '<Xslate>' },
    type   => 'text',
);
is capture { $app->run() }, "Hello, <Xslate> world!\n";

$app = Text::Xslate::Runner->new(
    eval   => 'Hello, [% $lang %] world!',
    define => { lang => '<Xslate>' },
    syntax => 'TTerse',
);
is capture { $app->run() }, "Hello, &lt;Xslate&gt; world!\n";

$app = Text::Xslate::Runner->new(
    eval   => 'Hello, [% $lang %] world!',
    define => { lang => '<Xslate>' },
    syntax => 'TTerse',
);
is capture { $app->run() }, "Hello, &lt;Xslate&gt; world!\n";


@ARGV = (
    '-e<: max(10, 20, 30, 25, 15) :>/<: min(10, 20, 30, 25, 15) :>',
    '-MList::Util=max,min',
);
$app = Text::Xslate::Runner->new_with_options();
is capture { $app->run() }, "30/10\n";

$app = Text::Xslate::Runner->new();
ok $app->version_info();

done_testing;
