package Text::Xslate::MakeError;
use Mouse::Role;
use Carp ();
use Text::Xslate::Constants qw(DEFAULT_DISPLAY_WIDTH);

our $DisplayWidth;

sub throw_error {
    die shift->make_error(@_);
}

sub log_prefix { ref($_[0]) }

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

sub make_error {
    my($self, $message, $file, $line, @extra) = @_;

    $DisplayWidth ||= DEFAULT_DISPLAY_WIDTH;
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
    my $class = ref($self) ? $self->log_prefix() : $self;
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

no Mouse::Role;

1;
