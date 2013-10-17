use strict;
use warnings;

use Test::More;

{
    package MyCounter;
    sub new { my $class = shift;bless {@_} => $class }
    sub incr  { shift->{count}++ }
    sub decr  { shift->{count}-- }
    sub count { shift->{count} }
}

use Text::Xslate;
my $tx = Text::Xslate->new(
    cache  => 1,
    syntax => 'TTerse',
    path => {
        'recurse.tt' => q{
            [%- MACRO mymacro BLOCK -%]
                [%- CALL recurse_count.decr -%]
                [%- IF recurse_count.count -%]
                    [%- mymacro() -%]
                [%- END -%]
            [%- END -%]
            [%- mymacro() -%]
        },
    },
);

ok $tx->render('recurse.tt', { recurse_count => MyCounter->new(count => 101) });
eval {
    $tx->render('recurse.tt', { recurse_count => MyCounter->new(count => 102) });
};

ok $tx->render('recurse.tt', { recurse_count => MyCounter->new(count => 101) });

done_testing;
