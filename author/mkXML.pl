#!perl -w
use strict;

my $tmpl = <<'XML';
    <foo>
        <bar><: $aaa :></bar>
        <baz><: $bbb :></baz>
    </foo>
XML

print "<root>\n";

for my $i(1 .. 500) {
   print $tmpl;
}

print "</root>\n";
