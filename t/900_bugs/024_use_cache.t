#!perl -w
# https://gist.github.com/163168668d6a6418227a
# reported by woremacx

use strict;
use Test::More;

BEGIN { $ENV{XSLATE} = "dump=load"; }

use Text::Xslate;
use File::Path;
use Config;
use t::lib::Util ();

my @_note_buf;
{
    package Text::Xslate;
    sub note {
        my($self, @args) = @_;
        my $fmt = shift(@args);
        my $res = sprintf($fmt, @args);
        push(@_note_buf, $res);
    }
}

my $cache_dir = t::lib::Util::cache_dir;

my $tmplpath = "t/macrotmpl";
END{ rmtree($tmplpath); rmtree($cache_dir); }

system "mkdir -p $tmplpath/includes";
open my $fh, "> $tmplpath/hello.tt";
print $fh q{[% hello() %]};
close $fh;
open my $fh2, "> $tmplpath/includes/macro.inc";
print $fh2 q{[%- MACRO hello() BLOCK -%]hello, world[%- END -%]};
close $fh2;
open my $fh3, "> $tmplpath/hello2.tt";
print $fh3 q{hello, };
close $fh3;
open my $fh4, "> $tmplpath/footer.inc";
print $fh4 q{world};
close $fh4;

my $t = time() - 7200;
my $t2 = time() - 3600;
my $t3 = time() - 1800;
utime($t, $t, "$tmplpath/hello.tt");
utime($t2, $t2, "$tmplpath/includes/macro.inc");
utime($t, $t, "$tmplpath/hello2.tt");
utime($t3, $t3, "$tmplpath/includes/footer.inc");

{
    rmtree($cache_dir);
    my $tx_macro = Text::Xslate->new(
        module => [ 'Text::Xslate::Bridge::TT2Like' ],
        macro => [ 'macro.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    is($tx_macro->render('hello.tt'), "hello, world");

    @_note_buf = ();
    is($tx_macro->render('hello.tt'), "hello, world");
    #
    # キャッシュが効いてれば、メッセージが何も出力されないはず
    #
    is(scalar(@_note_buf), 0);
}

{
    rmtree($cache_dir);
    my $tx_header = Text::Xslate->new(
        module => [ 'Text::Xslate::Bridge::TT2Like' ],
        header => [ 'macro.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    is($tx_header->render('hello.tt'), "hello, world");

    @_note_buf = ();
    is($tx_header->render('hello.tt'), "hello, world");
    is(scalar(@_note_buf), 0);
}

{
    rmtree($cache_dir);
    my $tx_footer = Text::Xslate->new(
        module => [ 'Text::Xslate::Bridge::TT2Like' ],
        footer => [ 'footer.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    is($tx_footer->render('hello2.tt'), "hello, world");

    @_note_buf = ();
    is($tx_footer->render('hello2.tt'), "hello, world");
    is(scalar(@_note_buf), 0);
}

done_testing;
