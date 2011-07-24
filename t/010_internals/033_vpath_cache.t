#!perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(rmtree);
use File::Basename;

use constant CACHE_DIR => basename(__FILE__);
BEGIN { rmtree(CACHE_DIR) }
END   { rmtree(CACHE_DIR) }

use Text::Xslate;

my $compile_called = 0;
{
    package MyEngine;
    our @ISA = qw(Text::Xslate);

    sub compile {
        my($self, @args) = @_;
        ::note 'compile!';
        $compile_called++;
        return $self->SUPER::compile(@args);
    }
}

my $phase = 0;
foreach my $i(0, 1) {
    my %vpath = (
        hello => 'hello#' . $i,
    );

    my $tx = MyEngine->new(
        cache_dir => CACHE_DIR,
        path      => [\%vpath],
    );
    foreach my $j(0, 1) {
        note "# $i-$j";

        is $tx->render('hello'), 'hello#' . $i;

        if($phase == 0) {
            is $compile_called, 1, 'compiling at first time';
        }
        elsif($phase == 1) {
            is $compile_called, 1, 'using cache, not compiled';
        }
        elsif($phase == 2) {
            is $compile_called, 2, 're-compiled because %vpath changed';
        }
        elsif($phase == 3) {
            is $compile_called, 2, 'using cache';
        }
        else {
            fail 'something failed';
        }
        $phase++;
    }
}

done_testing;

