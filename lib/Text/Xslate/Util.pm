package Text::Xslate::Util;
# utilities for internals, not for users
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(
    html_escape escaped_string
    literal_to_value value_to_literal
    import_from
    is_int any_in
    p
    $STRING $NUMBER $DEBUG
);

use Carp ();

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
our $STRING  = qr/(?: $dquoted | $squoted )/xms;

our $NUMBER  = qr/ [+-]? (?:
        (?: [0-9][0-9_]* (?: \. [0-9_]+)? \b) # decimal
        |
        (?: 0 (?:
            (?: [0-7_]+ )        # octal
            |
            (?: x [0-9a-fA-F_]+) # hex
            |
            (?: b [01_]+ )       # binary
        )?)
    )/xms;

our $DEBUG;
defined($DEBUG) or $DEBUG = $ENV{XSLATE} || '';

require Text::Xslate; # load XS stuff

sub html_escape;    # XS
sub escaped_string; # XS

sub is_int {
    my($s) = @_;
    my $i = do {
        no warnings;
        int($s);
    };
    return $s eq $i && $i !~ /[^-0-9]/;
}

sub any_in {
    my $value = shift;
    if(defined $value) {
        return scalar grep { defined($_) && $value eq $_ } @_;
    }
    else {
        return scalar grep { not defined($_) } @_;
    }
}

my %esc2char = (
    't' => "\t",
    'n' => "\n",
    'r' => "\r",
);

sub literal_to_value {
    my($value) = @_;
    return $value if not defined $value;

    if($value =~ s/"(.*)"/$1/xms){
        $value =~ s/\\(.)/$esc2char{$1} || $1/xmseg;
    }
    elsif($value =~ s/'(.*)'/$1/xms) {
        $value =~ s/\\(['\\])/$1/xmsg; # ' for poor editors
    }
    else { # number
        if($value =~ s/\A ([+-]?) (?= 0[0-7xb])//xms) {
            $value = ($1 eq '-' ? -1 : +1)
                * oct($value); # also grok hex and binary
        }
        else {
            $value =~ s/_//xmsg;
        }
    }

    return $value;
}

my %char2esc = (
    "\\" => '\\\\',
    "\n" => '\\n',
    "\r" => '\\r',
    '"'  => '\\"',
    '$'  => '\\$',
    '@'  => '\\@',
);
my $value_chars = join '|', map { quotemeta } keys %char2esc;

sub value_to_literal {
    my($value) = @_;
    return 'undef' if not defined $value;

    if(is_int($value)){
        return $value;
    }
    else {
        $value =~ s/($value_chars)/$char2esc{$1}/xmsgeo;
        return qq{"$value"};
    }
}

sub import_from {
    my $code = "# Text::Xslate::Util::import_from()\n"
             . "package " . "Text::Xslate::Util::_import;\n"
             . "use warnings FATAL => 'all';\n"
             . 'my @args;' . "\n";

    for(my $i = 0; $i < @_; $i++) {
        my $module = $_[$i];

        if($module =~ /[^a-zA-Z0-9_:]/) {
            Carp::croak("Invalid module name: $module");
        }

        my $commands;
        if(ref $_[$i+1]){
            $commands = p($_[++$i]);
        }

        $code .= "use $module ();\n" if !$module->can('export_into_xslate');

        if(!defined($commands) or $commands ne '') {
            $code .= sprintf <<'END_IMPORT', $module, $commands || '()';
    @args = %2$s;
    %1$s->can('export_into_xslate')
        ? %1$s->export_into_xslate(\@funcs, @args) # bridge modules
        : %1$s->import(@args);                     # function-based modules
END_IMPORT
        }
    }

    local $Text::Xslate::Util::{'_import::'};
    #print STDERR $code;
    my @funcs;
    my $e = do {
        local $@;
        eval  qq{package}
            . qq{ Text::Xslate::Util::_import;\n}
            . $code;
        $@;
    };
    Carp::confess("Xslate: Failed to import:\n" . $code . $e) if $e;
    push @funcs, map {
            my $glob_ref = \$Text::Xslate::Util::_import::{$_};
            my $c = ref($glob_ref) eq 'GLOB' ? *{$glob_ref}{CODE} : undef;
            defined($c) ? ($_ => $c) : ();
        } keys %Text::Xslate::Util::_import::;

    return @funcs;
}

sub p { # for debugging
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([@_ == 1 ? @_ : \@_], ['*data']);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    $dd->Quotekeys(0);
    $dd->Terse(1);
    return $dd->Dump() if defined wantarray;
    print $dd->Dump();
}


1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=head1 DESCRIPTION

This module provides utilities for Xslate.

=head1 INTERFACE

=head2 Exportable functions

=head3 C<escaped_string($str)>

This is the entity of the C<raw> filter.

=head3 C<html_escape($str)>

This is the entity of the C<html> filter.

=head3 C<p($any)>

This is the entity of the C<dump> filter.

=head1 SEE ALSO

L<Text::Xslate>

=cut
