package Text::Xslate::Util;
use strict;
use warnings;

use Carp ();

use parent qw(Exporter);
our @EXPORT_OK = qw(
    mark_raw unmark_raw
    html_escape escaped_string
    uri_escape
    p dump
    html_builder
    hash_with_default

    literal_to_value value_to_literal
    import_from
    neat
    is_int any_in
    read_around
    make_error
    $DEBUG
    $STRING $NUMBER
);

our $DEBUG;
defined($DEBUG) or $DEBUG = $ENV{XSLATE} || '';

our $DisplayWidth = 76;
if($DEBUG =~ /display_width=(\d+)/) {
    $DisplayWidth = $1;
}

# cf. http://swtch.com/~rsc/regexp/regexp1.html
my $dquoted = qr/"  [^"\\]* (?: \\. [^"\\]* )* "/xms;
my $squoted = qr/'  [^'\\]* (?: \\. [^'\\]* )* '/xms;
our $STRING  = qr/(?: $dquoted | $squoted )/xms;

our $NUMBER  = qr/ (?:
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

require Text::Xslate; # load XS stuff

sub mark_raw;    # XS
sub unmark_raw;  # XS
sub html_escape; # XS
sub uri_escape;  # XS
sub escaped_string; *escaped_string = \&mark_raw;
sub merge_hash;  # XS

sub html_builder (&){
    my($code_ref) = @_;
    return sub {
        my $ret = $code_ref->(@_);
        return ref($ret) eq 'CODE'
            ? html_builder(\&{$ret})
            : mark_raw($ret);
    };
}

sub hash_with_default {
    my($hash_ref, $default) = @_;
    ref($hash_ref) eq 'HASH'
        or Carp::croak('Usage: hash_with_default(\%vars, $default)');
    require 'Text/Xslate/HashWithDefault.pm';
    my %vars;
    tie %vars, 'Text::Xslate::HashWithDefault', $hash_ref, $default;
    return \%vars;
}


# for internals

sub neat {
    my($s) = @_;
    if ( defined $s ) {
        if ( ref($s) || Scalar::Util::looks_like_number($s) ) {
            return $s;
        }
        else {
            return "'$s'";
        }
    }
    else {
        return 'nil';
    }
}

sub is_int {
    my($s) = @_;
    # XXX: '+1', '1.0', '00',  must NOT be interpreted as an integer
    return defined($s)
        && $s =~ /\A -? [0-9]+ \z/xms
        && int($s) eq $s
        && abs(int($s)) < 0x7FFF_FFFF; # fits  int32_t
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

    if($value =~ s/\A "(.*)" \z/$1/xms){
        $value =~ s/\\(.)/$esc2char{$1} || $1/xmseg;
    }
    elsif($value =~ s/\A '(.*)' \z/$1/xms) {
        $value =~ s/\\(['\\])/$1/xmsg; # ' for poor editors
    }
    elsif($value =~ /\A [+-]? $NUMBER \z/xmso) {
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
            Carp::confess("Xslate: Invalid module name: $module");
        }

        my $commands;
        if(ref $_[$i+1]){
            require 'Data/Dumper.pm';
            my @args   = ($_[++$i]);
            my @protos = ('*data');
            $commands = Data::Dumper->new(\@args, \@protos)->Terse(1)->Dump();
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
    Carp::confess("Xslate: Failed to import:\n" . $e) if $e;
    push @funcs, map {
            my $entity_ref = \$Text::Xslate::Util::_import::{$_};
            my $c;
            if(ref($entity_ref) eq 'GLOB') { # normal symbols
                $c = *{$entity_ref}{CODE};
            }
            elsif(ref($entity_ref) eq 'REF') { # special constants
                no strict 'refs';
                $c = \&{ 'Text::Xslate::Util::_import::' . $_ };
            }
            defined($c) ? ($_ => $c) : ();
        } keys %Text::Xslate::Util::_import::;

    return {@funcs};
}

sub make_error {
    my($self, $message, $file, $line, @extra) = @_;
    if(ref $message eq 'SCALAR') { # re-thrown form virtual machines
        return ${$message};
    }

    my $lines = read_around($file, $line, 1, $self->input_layer);
    if($lines) {
        $lines .= "\n" if $lines !~ /\n\z/xms;
        $lines = '-' x $DisplayWidth . "\n"
               . $lines
               . '-' x $DisplayWidth . "\n";
    }

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    my $class = ref($self) || $self;
    $message =~ s/\A \Q$class: \E//xms and $message .= "\t...";

    if(defined $file) {
        if(defined $line) {
            unshift @extra, $line;
        }
        unshift @extra, ref($file) ? '<string>' : $file;
    }

    if(@extra) {
        $message = Carp::shortmess(sprintf '%s (%s)',
            $message, join(':', @extra));
    }
    else {
        $message = Carp::shortmess($message);
    }
    return sprintf "%s: %s%s",
        $class, $message, $lines;
}

sub read_around { # for error messages
    my($file, $line, $around, $input_layer) = @_;

    defined($file) && defined($line) or return '';

    if (ref $file) { # if $file is a scalar ref, it must contain text strings
        my $content = $$file;
        utf8::encode($content);
        $file = \$content;
    }

    $around      = 1  if not defined $around;
    $input_layer = '' if not defined $input_layer;

    open my $in, '<' . $input_layer, $file or return '';
    local $/ = "\n";
    local $. = 0;

    my $s = '';
    while(defined(my $l = <$in>)) {
        if($. >= ($line - $around)) {
            $s .= $l;
        }
        if($. >= ($line + $around)) {
            last;
        }
    }
    return $s;
}

sub p { # for debugging, the guts of dump()
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new(\@_);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    $dd->Quotekeys(0);
    $dd->Terse(1);
    return $dd->Dump() if defined wantarray;
    print $dd->Dump();
}

sub dump :method { goto &p }

1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=head1 SYNOPSIS

    use Text::Xslate::Util qw(
        mark_raw
        unmark_raw
        html_escape
        uri_escape
        p
        html_builder
        hash_with_default
    );

=head1 DESCRIPTION

This module provides utilities for Xslate.

=head1 INTERFACE

=head2 Exportable functions

=head3 C<mark_raw($str)>

This is the entity of the C<mark_raw> filter.

=head3 C<unmark_raw($str)>

This is the entity of the C<unmark_raw> filter.

=head3 C<html_escape($str)>

This is the entity of the C<html_escape> filter.

=head3 C<uri_escape($str)>

This is the entity of the C<uri> filter.

=head3 C<p($any)> / C<dump($any)>

Displays the contents of I<$any> using C<Data::Dumper>.

This is the entity of the C<dump> filter, useful for debugging.

=head3  C<< html_builder { block } | \&function :CodeRef >>

Wraps a block or I<&function> with C<mark_raw> so that the new subroutine will
return a raw string.

This function is the same as what Text::Xslate exports.

=head3 C<< hash_with_default \%hash, $default :Any >>

Set a default value I<$default> to I<%hash> and returns a HashRef.

This is provided for debugging.

=head1 SEE ALSO

L<Text::Xslate>

=cut
