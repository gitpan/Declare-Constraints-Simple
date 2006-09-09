#!/usr/bin/perl
use warnings;
use strict;

use Test::More;

use Declare::Constraints::Simple-All;

my $profile = And( IsHashRef,
                   HasAllKeys( qw(foo bar baz) ),
                   OnHashKeys( foo => IsArrayRef( IsInt ),
                               bar => Message('Definition Error', IsDefined),
                               baz => IsHashRef( -values => Matches(qr/oo/) )));

our $data = {
    foo => [1, 2, 3],
    bar => "Fnord!",
    baz => { 
        23 => 'foobar',
        5  => 'Foo Fighters',
        12 => 'boolean rockz',
    },
};

my @test_sets = (
    [sub {
        push @{$data->{foo}}, 'Hooray';
        my $e = $profile->($data);
        ok(!$e, 'array ref fails');
        is($e->path, 'And.OnHashKeys[foo].IsArrayRef[3].IsInt', 'correct path');
        pop @{$data->{foo}};
    }, 2],
    [sub {
        $data->{baz}{42} = 'Not as hot as 23';
        my $e = $profile->($data);
        ok(!$e, 'value match on hoh fails');
        is($e->path, 'And.OnHashKeys[baz].IsHashRef[val 42].Matches', 'correct path');
        delete $data->{baz}{42};
    }, 2],
    [sub {
        undef $data->{bar};
        my $e = $profile->($data);
        ok(!$e, 'defined fails');
        is($e->path, 'And.OnHashKeys[bar].Message.IsDefined', 'correct path');
        is($e->message, 'Definition Error', 'correct message');
        $data->{bar} = "Fnord again!";
    }, 3],
    [sub {
        my $e = $profile->($data);
        ok($e, 'complex structure passes');
    }, 1],
);

#@test_sets = ($test_sets[3]);

my @counts = map { $_->[1] } @test_sets;
my $count;
$count += $_ for @counts;

plan tests => $count;

$_->[0]->() for @test_sets;

