#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;
use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

my $warn;

my $tx = Text::Xslate->new(
    verbose => 2,
    warn_handler => sub{ $warn .= join '', @_ },
    path      => path,
    cache_dir => cache_dir,
    cache     => 1,
);

$warn = '';
eval {
    $tx->render_string(<<'T');
    : cascade oi::bad_base
T
};
is $@,    '', 'exception';
like $warn, qr{ \b bad_base\.tx \b }xms;
like $warn, qr{ \b bad_code_foo \b }xms;

$warn = '';
eval {
    $tx->render_string(<<'T');
    : cascade oi::bad_base with oi::bad_component
T
};
is $@,    '', 'exception';
like $warn, qr{  \b bad_code_foo \b .+ \b bad_base\.tx \b }xms,      'warn (for base)';
like $warn, qr{  \b bad_code_bar \b .+ \b bad_component\.tx \b }xms, 'warn (for component)';

done_testing;
