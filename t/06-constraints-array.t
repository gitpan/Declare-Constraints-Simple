#!/usr/bin/perl
use warnings;
use strict;

use Test::More;

use Declare::Constraints::Simple
    Only => qw(HasArraySize);

my @test_sets = (
    [HasArraySize,      undef,          0,  'HasArraySize undef'],
    [HasArraySize,      'foo',          0,  'HasArraySize string'],
    [HasArraySize,      [],             0,  'HasArraySize default empty'],
    [HasArraySize,      [1],            1,  'HasArraySize default one element'],
    [HasArraySize,      [1,2],          1,  'HasArraySize default two elements'],
    [HasArraySize(2),   [1],            0,  'HasArraySize(2) one element'],
    [HasArraySize(2),   [1,2],          1,  'HasArraySize(2) two elements'],
    [HasArraySize(2),   [1,2,3],        1,  'HasArraySize(2) three elements'],
    [HasArraySize(2,3), [1,2],          1,  'HasArraySize(2,3) two elements'],
    [HasArraySize(2,3), [1,2,3],        1,  'HasArraySize(2,3) three elements'],
    [HasArraySize(2,3), [1,2,3,4],      0,  'HasArraySize(2,3) four elements'],
);

plan tests => scalar(@test_sets);

for (@test_sets) {
    my ($check, $value, $expect, $title) = @$_;
    my $result = $check->($value);
    is(($result ? 1 : 0), $expect, $title);
}
