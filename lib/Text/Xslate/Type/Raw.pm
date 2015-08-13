package Text::Xslate::Type::Raw;
# the package is implemented intentionally in Text::Xslate
require Text::Xslate;
1
__END__

=head1 NAME

Text::Xslate::Type::Raw - The raw string representation

=head1 DESCRIPTION

This class represents raw strings so that Xslate does not escape them.

Note that you cannot extend this class.

=head1 METHODS

=head2 new

create a new instance

=head2 as_string

this method is overload to string.

    print Text::Xslate::Type::Raw->new('raw_string')->as_string
    print Text::Xslate::Type::Raw->new('raw_string') # the same, because of overload


=cut
