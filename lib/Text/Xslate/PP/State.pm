package Text::Xslate::PP::State;

use Mouse; # we don't need Mouse for this module?
use Carp ();

our $VERSION = '0.001';

has tmpl => ( is => 'rw' );

has self => ( is => 'rw' );

has sa => ( is => 'rw' );

has sb => ( is => 'rw' );

has targ => ( is => 'rw' );

has frame => ( is => 'rw' );

has current_frame => ( is => 'rw' );

has pad => ( is => 'rw' );

has lines => ( is => 'rw' );

has code => ( is => 'rw' );

has code_len => ( is => 'rw' );

has vars => ( is => 'rw' );

has macro => ( is => 'rw' );

has function => ( is => 'rw' );


sub pc_arg {
    $_[0]->code->[ $_[0]->{ pc } ]->{ arg };
}

1;
__END__
