#!perl -w
use 5.010_000;
use strict;

use Text::Xslate;
use Text::MicroTemplate qw(build_mt);
use HTML::Template::Pro;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate Text::MicroTemplate HTML::Template::Pro)){
    say $mod, '/', $mod->VERSION;
}

my($n, $m) = @ARGV;
$n //=  100;
$m //=  10;

my $x = Text::Xslate->new(string => <<'TX_END' x 4);
<ul>
: for $books ->($item) {
    <li><:= $item.title :></li>
    <li><:= $item.title :></li>
    <li><:= $item.title :></li>
    <li><:= $item.title :></li>
    <li><:= $item.title :></li>
: }
</ul>
TX_END

my $mt  = build_mt(<<'MT_END' x 4);
<ul>
? for my $item(@{$_[0]->{books}}) {
    <li><?= $item->{title} ?></li>
    <li><?= $item->{title} ?></li>
    <li><?= $item->{title} ?></li>
    <li><?= $item->{title} ?></li>
    <li><?= $item->{title} ?></li>
? }
</ul>
MT_END

my $ht = HTML::Template->new(scalarref => \(<<'HT_END' x 4), case_sensitive => 1);
<ul>
<tmpl_loop name="books">
    <li><tmpl_var name="title" escape="html"></li>
    <li><tmpl_var name="title" escape="html"></li>
    <li><tmpl_var name="title" escape="html"></li>
    <li><tmpl_var name="title" escape="html"></li>
    <li><tmpl_var name="title" escape="html"></li>
</tmpl_loop>
</ul>
HT_END

my @x_labels;
my %data;

for(my $i = 20; $i <= $n; $i += $m) {
    push @x_labels, $i;

    my %vars = (
         books => [(
            { title => 'Islands in the stream' },
         ) x $i],
    );

    $x->render(\%vars) eq $mt->(\%vars) or die $x->render(\%vars);

    #$ht->param(\%vars);die $ht->output();

    # suppose PSGI response body
    print "data x $i\n";
    my $r = timethese -1 => {
        xs => sub {
            my $body = [$x->render(\%vars)];
            return;
        },
        mt => sub {
            my $body = [$mt->(\%vars)];
            return;
        },
        ht => sub{
            $ht->param(\%vars);
            my $body = [$ht->output()];
            return;
        },
    };

    push @{ $data{ht} }, int($r->{ht}->iters / $r->{mt}->cpu_a);
    push @{ $data{mt} }, int($r->{mt}->iters / $r->{mt}->cpu_a);
    push @{ $data{xs} }, int($r->{xs}->iters / $r->{xs}->cpu_a);
}

# draw

use Imager;
use Imager::Font;
use Imager::Graph::Line;

my $g = Imager::Graph::Line->new();

$g->set_image_width(800);
$g->set_image_height(600);
$g->set_font(Imager::Font->new(file => "/usr/share/fonts/ja/TrueType/ipag.ttf"));
$g->set_title('Xslate vs. HTML::Template::Pro vs. Text::MicroTemplate');

$g->set_labels(\@x_labels);

$g->add_data_series($data{ht}, 'HTML::Template::Pro');
$g->add_data_series($data{mt}, 'Text::MicroTemplate');
$g->add_data_series($data{xs}, 'Text::Xslate');

my $image = $g->draw() or die Imager->errstr;
$image->write(file => 'xslate-vs-mt-vs-ht.png');
