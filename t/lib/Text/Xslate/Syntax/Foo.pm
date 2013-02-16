package Text::Xslate::Syntax::Foo;
use Mouse;

extends qw(Text::Xslate::Parser);

sub _build_line_start { undef }
sub _build_tag_start  { '<%'  }
sub _build_tag_end    { '%>'  }

no Mouse;

__PACKAGE__->meta->make_immutable();
