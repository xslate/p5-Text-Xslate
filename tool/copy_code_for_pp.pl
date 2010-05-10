#!perl -w
use 5.008;
use strict;

our $VERSION = '0.001';

my $start;
my $skip;
my %exclude = map { ( $_ => 1 ) } qw( render _initialize escaped_string );
my $subname = '';


print <<HEAD;
package Text::Xslate::PP::Methods;

use strict;
use warnings;

our \$VERSION = '$VERSION';

package Text::Xslate::PP;

use strict;
use warnings;

HEAD


while(<>) {

    if ( /^__END__/ ) {
        print $_;
        last;
    }

    next if /^#/;

    if ( /\$VERSION\s*=\s*['"]([.0-9]+)['"]/ ) {
        print "our \$XS_COMAPT_VERSION = '$1';\n\n";
        print "# The below lines are copied from Text::Xslate $1 by $0.\n\n";
        next;
    }

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

Text::Xslate::PP::Methods - installer copying Text::Xslate code into PP

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

POD
