#!perl

use strict;
use warnings;

BEGIN{
#    $ENV{XSLATE} = ' dump=ast '; # @@@ @@@
}
use Text::Xslate;

use Test::More;
use File::Temp qw(tempdir);

my %vpath = (
    ascii => "あ<: foo('i') :>う",
    utf   => "あ<: foo('い') :>う",
);

my $tmpdir = tempdir(DIR => ".", CLEANUP => 1);

my %opts = (
    path      => \%vpath,
    cache     => 1,
    cache_dir => $tmpdir,
    type => 'html', # enable auto escape
    input_layer => ':bytes',
    function => {
        foo => sub {
            my $s = shift;
#            warn "[$s][", (utf8::is_utf8($s) ? 'utf' : 'binary'), "]\n";
            Text::Xslate::mark_raw($s);
        },
    },
);

my $tx = Text::Xslate->new(\%opts);

foreach my $type ('original', 'cached'){
    my $tx = Text::Xslate->new(%opts);

    foreach my $try (1, 2){
        is($tx->render('ascii'), q{あiう},  "$type $try ascii");
        is($tx->render('utf'),   q{あいう},  "$type $try utf");
    }
}

$tmpdir = tempdir(DIR => ".", CLEANUP => 1);

done_testing;

