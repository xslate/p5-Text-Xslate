#!perl -w
use 5.008;
use strict;

our $VERSION = '0.1000';

my @lines;

my $ThisModVersion;
my $COPIED_XS_VERSION;

while(<>) {

    if ( /\$VERSION\s*=\s*['"]([.0-9]+)['"]/ ) {
        $COPIED_XS_VERSION = $1;
        $ThisModVersion = "$COPIED_XS_VERSION$VERSION";
        $ThisModVersion =~ s/\.(\d+)$/$1/;
        next;
    }

    push @lines, $_;
}

my $start;
my $skip;
my %exclude = map { ( $_ => 1 ) } qw( render _initialize escaped_string );
my $subname = '';


print <<HEAD;
package Text::Xslate::PP::Methods;

use strict;
use warnings;
HEAD

print "our \$VERSION = $ThisModVersion;";

print <<HEAD;

package Text::Xslate::PP;

use strict;
use warnings;

HEAD

print "our \$COPIED_XS_VERSION = '$COPIED_XS_VERSION';\n\n";
print "# The below lines are copied from Text::Xslate $COPIED_XS_VERSION by $0.\n\n";


for (@lines) {

    if ( /^__END__/ ) {
        print $_;
        last;
    }

    next if /^#/;

    if ( /^if\(\$DEBUG\s+!~\s+\/\\b pp/ ) {
        $skip++;
    }
    elsif ( $skip and /^use/ ) {
        $skip = 0;
    }

    next if ( $skip );

    if ( /use Text::Xslate::Util/ ) {
        $start++;
        print $_;
        next;
    }

    my $line = $_;

    if ( /^\s*sub\s+(\w+)\s*(\W)/ ) {
        $subname = $1;
        next if ( $2 and $2 eq ';' );
    }

    next unless $start;

    print $line;
}




print <<POD

=pod

=head1 NAME

Text::Xslate::PP::Methods - install to copied Text::Xslate code into PP

=head1 DESCRIPTION

This module is called by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate::PP>,
L<Text::Xslate>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

POD
