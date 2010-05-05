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

my $n = shift(@ARGV) || 10;

my $tx = Text::Xslate->new();
$tx->load_string(<<'TX_END');
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

my $mt  = build_mt(<<'MT_END');
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

my $ht = HTML::Template->new(scalarref => \<<'HT_END', case_sensitive => 1);
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

my %vars = (
     books => [(
        { title => 'Islands in the stream' },
        { title => 'Beautiful code' },
        { title => 'Introduction to Psychology' },
        { title => 'Programming Perl' },
        { title => 'Compilers: Principles, Techniques, and Tools' },
     ) x $n],
);

$tx->render(undef, \%vars) eq $mt->(\%vars) or die $tx->render(\%vars);

#$ht->param(\%vars);die $ht->output();

# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(undef, \%vars)];
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
