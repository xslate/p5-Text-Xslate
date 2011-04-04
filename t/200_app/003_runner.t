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

@ARGV = (
    '-e', '<: $foo :>/<: $bar :>',
    '-Dfoo=100',
    '-Dbar=200',
);
$app = Text::Xslate::Runner->new_with_options();
is capture { $app->run() }, "100/200\n";

@ARGV = (
    '-e', '<: $foo :>/<: $bar :>',
    '-D', 'foo=100',
    '-D', 'bar=200',
);
$app = Text::Xslate::Runner->new_with_options();
is capture { $app->run() }, "100/200\n";

#my $help = capture {
#    @ARGV = qw(--help);
#    Text::Xslate::Runner->new_with_options()->run();
#};
#like $help, qr/--help/;
#like $help, qr/--define/;
#like $help, qr/--eval/;


my $version_info = capture {
    @ARGV = qw(--version);
    Text::Xslate::Runner->new_with_options()->run();
};
like $version_info, qr/Text::Xslate::Runner/;

done_testing;

