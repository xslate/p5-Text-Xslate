#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw();
use File::Path;
use t::lib::Util;

rmtree(cache_dir);
END{ rmtree(cache_dir) }

package FooOverloadingObjectDir;
use overload
    q{""}    => sub { return ${shift()} },
    fallback => 1,
;
sub new { bless \"$_[1]" => $_[0] }

package main;


{
    my $tx1 = Text::Xslate->new(
        path      => [FooOverloadingObjectDir->new(path), { 'foo.tx' => 'Hello' } ],
        cache_dir => cache_dir,
        cache     => 2,
    );
    my $tx2 = Text::Xslate->new(
        path      => [FooOverloadingObjectDir->new(path . '/other'), { 'foo.tx' => 'Hello' } ],
        cache_dir => cache_dir,
        cache     => 2,
    );

    # different path's cachepath is different too
    isnt $tx1->find_file('hello.tx')->{cachepath},
         $tx2->find_file('hello.tx')->{cachepath};
}


done_testing;
