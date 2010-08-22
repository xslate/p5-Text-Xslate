#!perl
use strict;
use Benchmark qw(:all);

BEGIN{ $ENV{PERL_JSON_BACKEND} = 'JSON::PP' }

use Data::Serializer::JSON;
use Data::Serializer::Storable;
use Data::Serializer::Data::Dumper;

use Test::More tests => 3;

my $asm = [
    map { [$_ => 42, undef, undef] } ('aa' .. 'zz')
];
print scalar @{$asm}, "\n";

my $j = Data::Serializer::JSON->serialize($asm);
my $s = Data::Serializer::Storable->serialize($asm);
my $d = Data::Serializer::Data::Dumper->serialize($asm);

{
    is_deeply(Data::Serializer::JSON->deserialize($j), $asm);
    is_deeply(Data::Serializer::Storable->deserialize($s), $asm);
    is_deeply(Data::Serializer::Data::Dumper->deserialize($d), $asm);
}

cmpthese timethese -1 => {
    json       => sub { Data::Serializer::JSON->deserialize($j) },
    storable   => sub { Data::Serializer::Storable->deserialize($s) },
    datadumper => sub { Data::Serializer::Data::Dumper->deserialize($d) },
};

