#!perl -w
use strict;
use Data::MessagePack;
use Data::Dumper;
use File::Slurp qw(slurp);

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Useqq  = 1;

foreach my $file(@ARGV) {
    my $data     = slurp($file);
    my $unpacker = Data::MessagePack::Unpacker->new();

    my $offset = $unpacker->execute($data);
    my $is_utf8 = $unpacker->data();
    $unpacker->reset();
    $unpacker->utf8($is_utf8);

    while($offset < length($data)) {
        $offset = $unpacker->execute($data, $offset);
        my $c = $unpacker->data();
        $unpacker->reset();
        print Dumper($c), "\n";
    }
}
