#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

use Test::More::Fork tests => 27;
use_ok( 'Test::More::Fork');

can_ok( 'main', @Test::More::Fork::EXPORT );
can_ok( 'Test::More::Fork', @Test::More::Fork::EXPORT );
can_ok( 'main', @Test::More::EXPORT );
can_ok( 'Test::More::Fork', @Test::More::EXPORT );

Test::More::is( \&ok, \&Test::More::Fork::ok, "Imported Test::More::Fork::ok" );
Test::More::ok( \&ok != \&Test::More::ok, "Did not import Test::More::ok" );

$Test::More::Fork::CHILD = [];

Test::More::is( is( 1, 1, "Test should be delayed" ), "is() delayed", "delayed call to is()" );

my $child = $Test::More::Fork::CHILD;
undef( $Test::More::Fork::CHILD );

Test::More::is_deeply(
    $child,
    [
        {
            'caller' => [ 'main', __FILE__, 20 ],
            'sub' => 'is',
            'params' => [ 1, 1, "Test should be delayed" ],
        },
    ],
    "Delayed test recorded properly"
);

Test::More::is_deeply(
    Test::More::Fork::_deserialize_data( Dumper( $child ) . $Test::More::Fork::SEPERATOR ),
    $child,
    "_deserialize_data gets the correct data"
);

Test::More::is_deeply(
    Test::More::Fork::_run_tests( Dumper( $child ) . $Test::More::Fork::SEPERATOR ),
    $child,
    "_run_tests gets the correct tests"
);

fork_sub newsub => sub { 'sub ran' };
can_ok( 'main', 'newsub' );
can_ok( 'Test::More::Fork', 'newsub' );
Test::More::is( newsub(), 'sub ran', "new sub runs fine" );

$Test::More::Fork::CHILD = [];
Test::More::is( newsub(), 'newsub() delayed', "new sub delays" );
undef( $Test::More::Fork::CHILD );

fork_tests {
    is( 1, 1, 'is Should pass' );
    ok( 1, 'ok should pass' );
} "formed some tests", 2;

{
    no warnings 'redefine';
    no warnings 'once';
    my $message;
    local *Test::More::Fork::fake = sub { 0 };
    local *Test::More::diag = sub { $message = shift };
    Test::More::Fork::_run_tests(
        Dumper([{
            'caller' => [ 'a', 'a', 10 ],
            'sub' => 'fake',
            'params' => [ 0 ],
        }]) .
        $Test::More::Fork::SEPERATOR
    );
    Test::More::like( $message, qr/Problem at: a line: 10/, "Diagnostics message" );
    Test::More::Fork::_run_tests(
        Dumper([{
            'caller' => [ 'a', 'a', 10 ],
            'sub' => 'fakef',
            'params' => [ 0 ],
        }]) .
        $Test::More::Fork::SEPERATOR
    );
    Test::More::like(
        $message,
        qr/Undefined subroutine &Test::More::Fork::fakef called at/,
        "Diagnostics error message"
    );
}

my $ran = 0;
fork_sub ran_forked => sub { $ran++; 1 };
ran_forked();
Test::More::ok( $ran, "Test Ran" );
$ran = 0;

fork_tests {
    ran_forked()
} "Run a test in a fork", 1;
ok( $ran, "forked test ran" );

fork_tests {
    ok( 1, "Placeholder" );
};
