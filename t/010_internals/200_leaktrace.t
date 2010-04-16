#!perl -w

use strict;
use Test::Requires qw(Test::LeakTrace);
use Test::More;
use Text::Xslate;

no_leaks_ok {
    my $x = Text::Xslate->new([
        [ print_raw_s => "Hello, "  ],
        [ fetch       => "lang"     ],
        [ print       => ()         ],
        [ print_raw_s => " world!\n"],
    ]);
} "new";

no_leaks_ok {
    my $x = Text::Xslate->new([
        [ print_raw_s => "Hello, "  ],
        [ fetch       => "my"       ],
        [ fetch_field => "lang"     ],
        [ print       => ()         ],
        [ print_raw_s => " world!\n"],
    ]);

    my $text = $x->render({ my => { lang => 'Xslate' } });
    $text eq "Hello, Xslate world!\n" or die "render() failed: $text";
} "render (interpolate)";

no_leaks_ok {
    my $x = Text::Xslate->new([
        [ fetch       => "books"],
        [ for_start   => 0      ], # 0:$item
        [ print_raw_s => "* "   ],
        [ fetch_iter  => 0      ], # fetch the iterator variable(0:$item)
        [ fetch_field => "title"],
        [ print       => 0      ],
        [ print_raw_s => "\n"   ],
        [ literal     => 0      ], # 0:$item
        [ for_next    => -6     ], # to the loop start
    ]);

    my $text = $x->render({ books => [ { title => 'foo' }, { title => 'bar' } ] });
    $text eq "* foo\n* bar\n" or die "render() failed: $text";
} "render (for)";


done_testing;
