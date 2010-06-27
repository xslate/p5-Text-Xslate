#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my @files = qw(oi/bad_base.txc oi/bad_component.txc);
     unlink path . '/' . $_ for @files;
END{ unlink path . '/' . $_ for @files }

my $warn;

my $tx = Text::Xslate->new(
    verbose => 2,
    warn_handler => sub{ $warn .= join '', @_ },
    path      => path,
    cache_dir => path,
    cache     => 1,
);

$warn = '';
eval {
    $tx->render_string(<<'T');
    : cascade oi::bad_base
T
};
is $@,    '', 'exception';
like $warn, qr{ \b bad_base\.tx \b [^\n]+ \b bad_code_foo \b }xms, 'warn';

$warn = '';
eval {
    $tx->render_string(<<'T');
    : cascade oi::bad_base with oi::bad_component
T
};
is $@,    '', 'exception';
like $warn, qr{ \b bad_base\.tx \b [^\n]+ \b bad_code_foo \b }xms,      'warn (for base)';
like $warn, qr{ \b bad_component\.tx \b [^\n]+ \b bad_code_bar \b }xms, 'warn (for component)';

done_testing;
