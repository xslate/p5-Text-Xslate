package Text::Xslate::Util;
# utilities for internals, not for users
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(
    literal_to_value import_from
    p
    $STRING $NUMBER $DEBUG
);

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
our $STRING  = qr/(?: $dquoted | $squoted )/xms;
our $NUMBER  = qr/(?: [+-]? [0-9][0-9_]* (?: \. [0-9_]+)? )/xms;

our $DEBUG;
$DEBUG //= $ENV{XSLATE} // '';

my %esc2char = (
    't' => "\t",
    'n' => "\n",
    'r' => "\r",
);

sub literal_to_value {
    my($value) = @_;
    return undef if not defined $value;

    if($value =~ s/"(.*)"/$1/){
        $value =~ s/\\(.)/$esc2char{$1} || $1/xmseg;
    }
    elsif($value =~ s/'(.*)'/$1/) {
        $value =~ s/\\(['\\])/$1/g; # ' for poor editors
    }

    return $value;
}

sub import_from {
    my $code = <<'T';
package
    Text::Xslate::Util::_import;
T

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

    require 'Mouse/Util.pm';

    my @funcs = map {
            my $c = Mouse::Util::get_code_ref('Text::Xslate::Util::_import', $_);
            $c ? ($_ => $c) : ();
        } keys %Text::Xslate::Util::_import::;

    delete $Text::Xslate::Util::{'_import::'};

    return @funcs;
}

sub p { # for debugging
    my($self) = @_;
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self]);
    $dd->Indent(1);
    return $dd->Dump() if defined wantarray;
    print $dd->Dump();
}


1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=head1 DESCRIPTION

This module provides internal utilities.

=head1 SEE ALSO

L<Text::Xslate>

=cut
