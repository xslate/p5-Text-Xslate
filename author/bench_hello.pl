#!perl -w
use strict;

use Text::Xslate;
use Text::ClearSilver;
use Text::MicroTemplate;

use Benchmark qw(:all);

my $x = Text::Xslate->new([
    [ print_raw_s => "Hello, "  ],
    [ fetch      => "lang"      ],
    [ print       => undef      ],
    [ print_raw_s => " world!\n"],
]);

my $tcs = Text::ClearSilver->new();
my $mt  = Text::MicroTemplate::build_mt("Hello, <?= \$_[0]->{lang} ?> world!\n");
my $vars = {
    lang => 'Template',
};

$x->render($vars) eq $mt->($vars) or die $x->render($vars);

cmpthese -1 => {
    xslate => sub {
        # suppose PSGI response body
        my $body = [$x->render($vars)];
        return;
    },
    clearsilver => sub{
        my $body = [];
        $tcs->process(\qq{Hello, <?cs var:lang ?> world!\n}, $vars, \$body->[0]);
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
    sprintf => sub {
        my $body = [sprintf "Hello, %s world!\n", $vars->{lang}];
        return;
    },
};

