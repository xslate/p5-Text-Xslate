#!perl -w
use strict;

use Text::Xslate;
use Text::ClearSilver;
use Text::MicroTemplate;

use Benchmark qw(:all);

my $x = Text::Xslate->new([
    [ fetch         => "books"],
    [ for_start     => 0      ], # 0:$item
    [ print_raw_s   => "* "   ],
    [ fetch_iter    => 0      ], # fetch the iterator variable(0:$item)
    [ fetch_field_s => "title"],
    [ print         => 0      ],
    [ print_raw_s   => "\n"   ],
    [ literal       => 0      ], # 0:$item
    [ for_next      => -6     ], # to the loop start
]);

#? for $books ->($item) {
#* <?= $item.title ?>
#? } # for

my $tcs = Text::ClearSilver->new(VarEscapeMode => 'html');
my $mt  = Text::MicroTemplate::build_mt(<<'MT_END');
? for my $item(@{$_[0]->{books}}) {
* <?= $item->{title} ?>
? }
MT_END

my %vars = (
     books => [
        { title => 'Islands in the stream' },
        { title => 'Beautiful code' },
        { title => 'Introduction to Psychology' },
        { title => 'Programming Perl' },
        { title => 'Compilers: Principles, Techniques, and Tools' },
     ],
);

$x->render(\%vars) eq $mt->(\%vars) or die $x->render(\%vars);
#die $x->render(\%vars);

cmpthese -1 => {
    xslate => sub {
        # suppose PSGI response body
        my $body = [$x->render(\%vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->(\%vars)];
        return;
    },
    clearsilver => sub {
        my $body = [];
        $tcs->process(\<<'CS', \%vars, \$body->[0]);
<?cs each:item = books ?>
* <?cs var:item.title ?>
<?cs /each ?>
CS
        return;
    },
};
