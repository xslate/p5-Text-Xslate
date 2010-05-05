package Text::Xslate::Util;
# utilities for internals, not for users
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(
    literal_to_value import_from
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

sub import_from {
    require 'Mouse.pm';
    my $meta = Mouse::Meta::Class->create_anon_class();

    my $anon = $meta->name;
    my $code = sprintf "package %s;\n", $anon;
    for(my $i = 0; $i < @_; $i++) {
        $code .= "use $_[$i]";
        if(ref $_[$i+1]){
            $code .= sprintf ' qw(%s)', join ' ', @{$_[++$i]};
        }
        $code .= ";\n";
    }

    my $e = do {
        local $@;
        eval $code;
        $@;
    };
    Carp::confess("Xslate: Failed to import:\n" . $code . $e) if $e;

    return map {
            my $c = Mouse::Util::get_code_ref($anon, $_);
            $_ ne 'meta' && $c ? ($_ => $c): ();
        } keys %{$meta->namespace};
}

1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=head1 DESCRIPTION

This module provides internal utilities.

=cut
