#!perl -w
# test example/*.pl

use strict;
use Test::More;
use Test::Requires qw(
    Data::Section::Simple
    HTML::FillInForm
    HTML::FillInForm::Lite
    HTML::Shakan
    URI::Find
    Mojolicious
    MojoX::Renderer::Xslate
    JavaScript::Value::Escape
    Locale::Maketext::Lexicon
    Data::Localize
    File::Which
    Amon2::Lite
    Catalyst::View::Xslate
);

use IPC::Run qw(run timeout);
use File::Path qw(rmtree);
use Config;

use lib "t/lib";
use Util;

rmtree(cache_dir);
END{ rmtree(cache_dir) }

$ENV{PERL5LIB} = join $Config{path_sep}, @INC;

sub perl {
    # We cannot use IPC::Open3 simply.
    # See also http://d.hatena.ne.jp/kazuhooku/20100813/1281690025
    run [ $^X, @_ ],
        \my $in, \my $out, \my $err, timeout(5);

    foreach my $s($out, $err) { # for Win32
       $s =~ s/\r\n/\n/g;
    }

    return($out, $err);
}

EXAMPLE: while(defined(my $example = <example/*.pl>)) {
    my $expect = do {
        my $gold = $example . '.gold';

        -e $gold or note("skip $example because it has no $gold"), next;

        open my $g, '<', $gold or die "Cannot open '$gold' for reading: $!";
        local $/;
        <$g>;
    };

    foreach(1 .. 2) {
        my($out, $err) = perl($example);

        if($err) {
            fail("Error on $example because: $err");
            next EXAMPLE;
        }

        is $out, $expect, $example . " ($_)";
        is $err, '', 'no errors';
    }
}

done_testing;
