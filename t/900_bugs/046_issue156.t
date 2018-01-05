use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $base = <<'EOF';
: if 0 {
   : my $var = [ ];
: }
: for ['default'] -> $t {
: }
: block content -> { }
Good
EOF

my $xslate1 = Text::Xslate->new(
    path => {
       'base.tx' => $base,
       'page.tx' => q{: cascade "base.tx"},
    },
    warn_handler => sub { die @_ },
    cache => 0,
);
my $res1 = $xslate1->render('page.tx', { });
is $res1, "Good\n";

done_testing;
