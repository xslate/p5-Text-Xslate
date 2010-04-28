package Text::Xslate::Util;
use 5.010_000;
use strict;
use warnings;

{
    package Text::Xslate;
    our $DEBUG;
    $DEBUG = $ENV{XSLATE} // $DEBUG // '';
}

sub find_file {
    my($file, $path) = @_;

    my $fullpath;
    my $mtime;
    my $is_compiled;

    foreach my $p(@{$path}) {
        $fullpath = "$p/${file}";
        $mtime = (stat($fullpath))[9] // next; # does not exist

        if(-f "${fullpath}c") {
            my $m2 = (stat(_))[9]; # compiled

            if($mtime == $m2) {
                $fullpath     .= 'c';
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

    if(defined $mtime) {
        return {
            fullpath    => $fullpath,
            mtime       => $mtime,
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
