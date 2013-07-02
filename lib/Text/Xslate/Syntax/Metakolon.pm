package Text::Xslate::Syntax::Metakolon;
use Mouse;

extends qw(Text::Xslate::Parser);

# [% ... %] and %% ...
sub _build_line_start { '%%' }
sub _build_tag_start  { '[%' }
sub _build_tag_end    { '%]' }

no Mouse;
__PACKAGE__->meta->make_immutable();

__END__

=head1 NAME

Text::Xslate::Syntax::Metakolon - The same as Kolon but using [% ... %] tags

=head1 SYNOPSIS

    use Text::Xslate;
    my $tx = Text::Xslate->new(
        syntax => 'Metakolon',
    );

    print $tx->render_string(
        'Hello, [% $dialect %] world!',
        { dialect => 'Metakolon' }
    );

=head1 DESCRIPTION

Metakolon is the same as Kolon except for using C<< [% ... %] >> tags and
C<< %% ... >> line code, instead of C<< <: ... :> >> and C<< : ... >>.

This may be useful when you want to produce Xslate templates by itself.

See L<Text::Xslate::Syntax::Kolon> for details.

=head1 SEE ALSO

L<Text::Xslate>

=cut
