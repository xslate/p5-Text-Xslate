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
    escape => 'none',
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

$app = Text::Xslate::Runner->new();
ok $app->version_info();

done_testing;
