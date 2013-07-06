use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename;
use Carp ();
use File::Spec ();
use Text::Xslate 1.6001;
use Encode;

my $tmp = tempdir(CLEANUP => 1);

sub spew {
    my $fname = shift;
    open my $fh, '>', $fname
        or Carp::croak("Can't open '$fname' for writing: '$!'");
    print {$fh} $_[0];
}

sub make_view {
    my $view = Text::Xslate->new(+{
        path => [ $tmp ],
        cache_dir => $tmp,
        function => {
            foo => sub {
                my($args) = @_;
                Encode::is_utf8([keys %$args]->[0]) ? 1 : 0;
            }
        },
    });
    return $view;
}


spew("$tmp/index.tt", "<: foo({page => 1}) :>\n");
{
    my $p1 = make_view()->render('index.tt');
    my $p2 = make_view()->render('index.tt');

    is $p1, "1\n", 'p1';
    is $p2, "1\n", 'p2';
}
done_testing;

