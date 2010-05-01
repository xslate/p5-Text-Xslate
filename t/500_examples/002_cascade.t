#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

{
    package BlogEntry;
    use Mouse;
    has title => (is => 'rw');
    has body  => (is => 'rw');
}

my @blog_entries = map{ BlogEntry->new($_) } (
    {
        title => 'Entry one',
        body  => 'This is my first entry.',
    },
    {
        title => 'Entry two',
        body  => 'This is my second entry.',
    },
);

my $tx = Text::Xslate->new(
    cache => 0,
    path  => [path],
);

my $gold = <<'T';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <link rel="stylesheet" href="style.css" />
    <title>My amazing blog</title>
</head>

<body>
    <div id="sidebar">
        <ul>
            <li><a href="/">Home</a></li>
            <li><a href="/blog/">Blog</a></li>
        </ul>
    </div>

    <div id="content">
    <h2>Entry one</h2>
    <p>This is my first entry.</p>
    <h2>Entry two</h2>
    <p>This is my second entry.</p>
    </div>
</body>
</html>
T

is $tx->render('eg/child.tx', { blog_entries => \@blog_entries }), $gold, 'example/cascade.pl'
    for 1 .. 2;


done_testing;
