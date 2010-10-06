#!perl
use strict;
use warnings;

use Test::More;
use Text::Xslate;
use File::Temp ();
note 'preparing...';
my $temp = File::Temp->new(DIR => '.');
$temp->unlink_on_destroy(1);

$temp->print("Hello, world!\n") for 1 .. 1024*5;
$temp->close();
note 'prepared';

foreach (1 .. 2) {
    note $_;
    my $tx = Text::Xslate->new(
        cache     => 1,
        cache_dir => '.xslate_cache',
   );
   eval {
       $tx->render($temp->filename);
   };
   ok !$@ or note $@;
}


done_testing;
