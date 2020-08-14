package Text::Xslate::Syntax::Foo;
use Moo;

extends qw(Text::Xslate::Parser);

sub _build_line_start { undef }
sub _build_tag_start  { '<%'  }
sub _build_tag_end    { '%>'  }

no Moo;

__PACKAGE__->meta->make_immutable();
