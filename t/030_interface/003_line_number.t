#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(
    string => <<'TX',
<?= $one ?>
<?= $two ?>
<?= $three ?>
TX
    loaded => "foo.tx",
);

my $warn;
$SIG{__WARN__} = sub{ $warn .= join '', @_ };

$warn = '';
eval {
    $tx->render({one => 1, two => 2});
};
like $warn, qr/at foo\.tx line 3\./;

$warn = '';
eval {
    $tx->render({one => 1, three => 3});
};

like $warn, qr/line 2\./;

$warn = '';
eval {
    $tx->render({two => 2, three => 3});
};

like $warn, qr/line 1\./;

$tx = Text::Xslate->new(
    string => <<'TX',
<?= $one ?>

<?= $three ?>

<?= $five ?>
TX
);

$warn = '';
eval {
    $tx->render({one => 1, three => 3});
};
like $warn, qr/line 5\./;

$warn = '';
eval {
    $tx->render({one => 1, five => 5});
};

like $warn, qr/line 3\./;


done_testing;
