#!perl
# https://gist.github.com/163168668d6a6418227a
# reported by woremacx
# modified by gfx

use strict;
use warnings;
use Test::More;

use File::Path;
use t::lib::Util ();
use Fatal qw(open close);

use Text::Xslate;

my @read_files;
{
    package My::Xslate;
    our @ISA = qw(Text::Xslate);

    sub slurp_template {
        my($self, $input_layer, $file) = @_;
        push @read_files, $file;
        return $self->SUPER::slurp_template($input_layer, $file);
    }
}

my $cache_dir = t::lib::Util::cache_dir;

my $tmplpath = "t/macrotmpl";
END{
    rmtree($tmplpath);
    rmtree($cache_dir);
}

mkpath("$tmplpath/includes");

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

my $t  = time() - 7200;
my $t2 = time() - 3600;
my $t3 = time() - 1800;
utime($t,  $t,  "$tmplpath/hello.tt");
utime($t2, $t2, "$tmplpath/includes/macro.inc");
utime($t,  $t,  "$tmplpath/hello2.tt");
utime($t3, $t3, "$tmplpath/includes/footer.inc");

{
    rmtree($cache_dir);
    my $tx_macro = My::Xslate->new(
        macro => [ 'macro.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    @read_files = ();
    is($tx_macro->render('hello.tt'), "hello, world");
    is(scalar(@read_files), 2, 'file read in the first time');

    @read_files = ();
    is($tx_macro->render('hello.tt'), "hello, world");
    is(scalar(@read_files), 0, 'no file read because cache is fresh enough');
}

{
    rmtree($cache_dir);
    my $tx_header = My::Xslate->new(
        header => [ 'macro.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    @read_files = ();
    is($tx_header->render('hello.tt'), "hello, world");
    is(scalar(@read_files), 2, 'file read in the first time');

    @read_files = ();
    is($tx_header->render('hello.tt'), "hello, world");
    is(scalar(@read_files), 0, 'no file read because cache is fresh enough');
}

{
    rmtree($cache_dir);
    my $tx_footer = My::Xslate->new(
        footer => [ 'footer.inc' ],
        syntax => 'TTerse',
        path => [ "$tmplpath/includes", $tmplpath ],
        cache_dir => $cache_dir,
        cache => 1,
        verbose => 1,
    );
    @read_files = ();
    is($tx_footer->render('hello2.tt'), "hello, world");
    is(scalar(@read_files), 2, 'file read in the first time');

    @read_files = ();
    is($tx_footer->render('hello2.tt'), "hello, world");
    is(scalar(@read_files), 0, 'no file read because cache is fresh enough');
}

done_testing;
