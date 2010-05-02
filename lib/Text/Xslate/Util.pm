package Text::Xslate::Util;
use 5.010_000;
use strict;
use warnings;

use Scalar::Util ();

use parent qw(Exporter);
our @EXPORT_OK = qw(
    literal_to_value
    $STRING $NUMBER $DEBUG
);

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
our $STRING  = qr/(?: $dquoted | $squoted )/xms;
our $NUMBER  = qr/(?: [+-]? [0-9][0-9_]* (?: \. [0-9_]+)? )/xms;

our $DEBUG;
$DEBUG = $ENV{XSLATE} // $DEBUG // '';

sub literal_to_value {
    my($value) = @_;
    return undef if not defined $value;

    return $value if Scalar::Util::looks_like_number($value);

    if($value =~ s/"(.*)"/$1/){
        $value =~ s/\\r/\r/g;
        $value =~ s/\\n/\n/g;
        $value =~ s/\\t/\t/g;
        $value =~ s/\\(.)/$1/g;
    }
    elsif($value =~ s/'(.*)'/$1/) {
        $value =~ s/\\(['\\])/$1/g; # ' for poor editors
    }

    return $value;
}

1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=cut
