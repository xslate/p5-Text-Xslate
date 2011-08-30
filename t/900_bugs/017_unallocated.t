#!perl
use strict;
use warnings;
use Test::More skip_all => 'not yet';

use Test::Requires qw(Data::Section::Simple);
use List::Util ();
use Text::Xslate;


{
    package C;
    use strict;
    use warnings;


    sub new {
        my ($class) = @_;
        return bless { }, $class;
    }

    sub uri_for {
        my ($self, $path) = @_;
        return 'http://example.com' . $path;
    }

    sub in_production { 1 }
}

my $tx = Text::Xslate->new(
    cache => 0,
    path  => Data::Section::Simple->new->get_data_section,
    function  => {
        array => sub {
            return List::Util::reduce {
                return $a unless $b;
                push @$a, ref $b && ref $b eq 'ARRAY' ? @$b : $b;
                $a;
            } [], @_;
        },
        is_array => sub {
            my ($obj) = @_;
            return ref $obj && ref $obj eq 'ARRAY';
        },
    },
);

ok $tx->render('index.html', {
    c => C->new,
});

done_testing;
__DATA__

@@ _tx/macros.tx
:# common macros

: macro css_tag -> $css {
<link rel="stylesheet" href="<: $css :>" />
: }

: macro script_tag -> $js {
:   if is_array($js) {
<script type="text/javascript" src="<: $js.0 :>"<: for $js.1.kv() -> $p { :> <: $p.key :><: if defined $p.value { :>="<: $p.value :>"<: } } :>></script>
:   } else {
<script type="text/javascript" src="<: $js :>"></script>
:   }
: }

@@ _tx/wrapper/base.tx
: cascade with _tx::macros
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <title><: block title { :>title<: } :></title>
: for $css -> $i { css_tag($i) }
: for $js -> $i { script_tag($i) }
  </head>
  <body>
: block body { }
  </body>
</html>

@@ _tx/wrapper.tx
: my $jquery = 'https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery' ~ ($c.in_production ? '.min' : '') ~ '.js';

: cascade _tx::wrapper::base {
:#   js => [$jquery, [$c.uri_for('/js/site.js'), { charset => 'utf-8' }], @$js],
:   js => array(
:     $jquery,
:     [[$c.uri_for('/js/site.js'), { charset => 'utf-8' }]],
:     $js),
:#   css => [$c.uri_for('/css/site.css'), @$css],
:   css => array(
:     $c.uri_for('/css/site.css'), $css),
: }

: around body {
<header><h1>title</h1></header>
:   block content { }
: }

@@ index.html
: cascade _tx::wrapper {
:   js => [ ],
:   css => [ ],
: }

: around content {
content
: }

