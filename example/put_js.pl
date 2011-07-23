#!perl -w
use strict;
use Text::Xslate;

my $tx = Text::Xslate->new(
    module => ['JavaScript::Value::Escape' => [qw(js)]],
);

my %params = (
    user_input => '</script><script>alert("XSS")</script>',
);

print $tx->render_string(<<'T', \%params);
<script>
document.write('<: $user_input | html | js :>');
var user_input = '<: $user_input | js :>';
</script>
T

