package Text::Xslate::Util;
use 5.010_000;
use strict;
use warnings;

use Scalar::Util ();

use parent qw(Exporter);
our @EXPORT_OK = qw(
    literal_to_value find_file
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

sub find_file {
    my($file, $path) = @_;

    my $fullpath;
    my $orig_mtime;
    my $cache_mtime;
    my $is_compiled;

    foreach my $p(@{$path}) {
        $fullpath = "$p/${file}";
        $orig_mtime = (stat($fullpath))[9] // next; # does not exist

        if(-f "${fullpath}c") {
            $cache_mtime = (stat(_))[9]; # compiled
            if($cache_mtime >= $orig_mtime) {
                $is_compiled   = 1;
            }
            else {
                $is_compiled = 0;
            }
            last;
        }
        else {
            $is_compiled = 0;
        }
    }

    if(defined $orig_mtime) {
        return {
            fullpath    => $fullpath,
            orig_mtime  => $orig_mtime,
            cache_mtime => $cache_mtime,
            is_compiled => $is_compiled,
        };
    }
    else {
        return undef;
    }
}

1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=cut
