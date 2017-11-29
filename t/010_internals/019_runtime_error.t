#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use lib "t/lib";
use Util;

my $perl_warnings = '';
local $SIG{__WARN__} = sub{ $perl_warnings .= "@_" };

my $warn = '';
sub my_warn { $warn .= "@_" }

my $tx = Text::Xslate->new(
    warn_handler => \&my_warn,

    function => { f => sub{ die "DIE" } },
);

my $FILE = quotemeta(__FILE__);

note 'default verbose';
foreach my $code(
    q{ nil },
    q{ nil.foo },
    q{ nil.foo() },
    q{ for nil -> ($item) { print "foobar"; } },
    q{ $h[nil] },
    q{ $a[nil] },
    q{ nil | raw },
    q{ nil | html },
    q{ 1 ? raw(nil)  : "UNLIKELY" },
    q{ 1 ? html(nil) : "UNLIKELY" },
    q{ $empty x 10 },
) {
    $warn = '';

    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo' }, a => [42] });
    };

    is $out,  '', $code;
    is $warn, '';
    is $@,  '';
}


$warn = '';
my $out = eval {
    $tx->render_string("<: f() :>");
};

is $out, '', 'nothing' or die "Oops: [$warn][$@]";
like $warn, qr/DIE/, $warn;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: constant FOO = 42; FOO[0] :>');
};

is $out, '', 'warn in render_string()';
like $warn, qr/not a container/;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';


$warn = '';
$out = eval {
    $tx->render_string('<: $a + $b :>', { a => 'foo', b => 'bar' });
};

is $out, '0', 'warn in render_string()';
like $warn, qr/"foo" isn't numeric/;
like $warn, qr/"bar" isn't numeric/;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: [].size(1) :>', { a => 'foo', b => 'bar' });
};

is $out, '', 'warn in render_string()';
like $warn, qr/Wrong number of arguments for size/, $warn;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: [].foo() :>', { a => 'foo', b => 'bar' });
};

is $out, '', 'warn in render_string()';
like $warn, qr/Undefined method/;
like $warn, qr/\b foo \b/xms;
like $warn, qr/\b ARRAY \b/xms;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: $o.foo() :>', { o => bless {}, 'MyObject' });
};

is $out, '', 'warn in render_string()';
like $warn, qr/Can't locate object method/;
like $warn, qr/\b foo \b/xms;
like $warn, qr/\b MyObject \b/xms;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: $o.bar :>', { o => bless {}, 'MyObject' });
};

is $out, '', 'warn in render_string()';
like $warn, qr/Can't locate object method/;
like $warn, qr/\b bar \b/xms;
like $warn, qr/\b MyObject \b/xms;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';

$warn = '';
$out = eval {
    $tx->render_string('<: $x % 0 :>', {x => 42});
};

is $out,  'NaN';
like $warn, qr/Illegal modulus zero/;
is $@,    '';

note 'verbose => 2';

$tx = Text::Xslate->new(
    verbose      => 2,
    warn_handler => \&my_warn,
);

foreach my $code(
    q{ nil },
    q{ nil.foo },
    q{ nil.foo() },
    q{ $h[nil] },
    q{ $a[nil] },
    q{ nil | raw },
    q{ nil | html },
    q{ 1 ? raw(nil)  : "UNLIKELY" },
    q{ 1 ? html(nil) : "UNLIKELY" },
    q{ $empty x 10 },
) {
    $warn = '';
    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo'}, a => [42] });
    };

    is $out,  '', $code;
    like $warn, qr/Use of nil/, $warn;
    like $warn, qr/at $FILE line \d+/;
    is $@,  '';
}

$warn = '';
$out = eval {
    $tx->render_string("<: defined(nil) ? 1 : 0 :>", {});
};

is $out,  '0';
is $warn, '';
is $@,    '';

$warn = '';
$out = eval {
    $tx->render_string("<: block main -> { include 'no_such_file' } :>", {});
};

is $out,  undef;
is $warn, '';
like $@, qr/no_such_file/;

is $perl_warnings, '', "Perl doesn't produce warnings";
done_testing;
