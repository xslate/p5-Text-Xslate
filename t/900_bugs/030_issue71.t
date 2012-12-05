#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/71
use strict;
use warnings;
use Text::Xslate;
use Test::More;

my $tx = Text::Xslate->new('syntax' => 'TTerse',);
my $CLEANUP_OK;

{
    package MyHandle;
    sub new { bless {}, shift }
    sub DESTROY {
        $CLEANUP_OK++;
    }
}

{
    my $dbh = MyHandle->new();
    my @book = (
        {title => "foo", dbh => $dbh},
        {title => "bar", dbh => $dbh},
    );
    my $template = q{
<h1>[% title %]</h1>
<ul>
[% FOREACH book IN books %]
[% SET test = book %]
  <li>[% book.title %]</li>
[% END %]
</ul>
};
    my $body = $tx->render_string($template, {
        books => \@book,
    });
    isnt $body, '', 'render_string() succeeded';
}

ok($CLEANUP_OK, '$dbh is released');

done_testing;
