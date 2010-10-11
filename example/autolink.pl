#!perl -w
use strict;
use Text::Xslate qw(html_builder html_escape);
use URI::Find 20100505;

my $text = <<'EOT';
<http://example.com/?a=10&b=20>
EOT

my $finder = URI::Find->new(sub {
    my($obj_uri, $orig_uri) = @_;
    my $safe_uri = html_escape($orig_uri);
    return qq|<a href="$safe_uri">$safe_uri</a>|;
});

my $tx = Text::Xslate->new(
    function => {
        autolink => html_builder {
            my($text) = @_;
            $finder->find(\$text, \&html_escape);
            return $text;
         },
    },
);

print $tx->render_string(<<'T', { text => $text });
: $text | autolink
T
