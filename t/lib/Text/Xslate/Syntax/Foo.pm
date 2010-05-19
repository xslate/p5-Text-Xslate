package Text::Xslate::Syntax::Foo;
use 5.010;
use Any::Moose;

extends qw(Text::Xslate::Parser);

sub _build_line_start { undef       }
sub _build_tag_start  { qr/\Q<%/xms }
sub _build_tag_end    { qr/\Q%>/xms }

no Any::Moose;

__PACKAGE__->meta->make_immutable();
