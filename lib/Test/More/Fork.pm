package Test::More::Fork;
use strict;
use warnings;

#{{{ POD

=pod

=head1 NAME

Test::More::Fork - Test forking capabilities hacked on to Test::More

=head1 DESCRIPTION

Test::More::Fork allows you to run tests seperately. This is useful for
returning to a known or pristine state between tests. Test::Seperate seperates
tests into different forked processes. You can do whatever you want in a test
set without fear that something you do will effect a test in another set.

This is a better option than local when dealing with complex meta-structures
and testing class-construction in disperate conditions.

=head1 SYNOPSYS

    # Should be used in place of Test::More, will import all of the functions
    # from Test::More, and accept all the same arguments.
    use Test::More::Fork tests => 5;

    ok( 1, "Runs in the main process" );
    # ok 1 - Runs in the main process

    fork_tests {
        ok( 1, "Runs in a forked process"
    } "Forked tests were run", 1;
    # ok 2 - Runs in a forked process
    # ok 3 - Forked tests were run
    # ok 4 - verify test count

    #message and coutn are optional:
    fork_tests { ok( 1, "another test" )};
    # ok 5 - another test

    #create your own test that is safe to run in a forked process:
    fork_sub 'new_sub' => sub { ... };

=head1 EXPORTED FUNCTIONS

See the docs for L<Test::More>, all functions exported by Test::More are
exported by Test::More::Fork as well.

=over 4

=cut

#}}}

use base 'Test::More';
use Data::Dumper;

our @EXPORT = ( 'fork_tests', 'fork_sub', @Test::More::EXPORT );
our $VERSION = "0.006";
our $CHILD;
our $SEPERATOR = 'EODATA';

pipe( READ, WRITE ) || die( $! );

=item fork_sub $name => sub { ... }

Create a new sub defined in both the current package and Test::More::Fork. This
sub will be safe to run in a forked test.

=cut

sub fork_sub {
    my ( $sub, $code ) = @_;
    my $new = sub {
        no strict 'refs';
        goto &$code unless $CHILD;

        push @$CHILD => {
            'caller' => [ caller()],
            'sub' => $sub,
            'params' => [@_],
        };
        "$sub() delayed";
    };
    {
        no strict 'refs';
        *$sub = $new;
        my ( $caller ) = caller();
        return if $caller eq __PACKAGE__;
        *{ $caller . '::' . $sub } = $new;
    }
}

BEGIN {
    for my $sub ( @Test::More::EXPORT ) {
        no strict 'refs';
        fork_sub $sub => \&{'Test::More::' . $sub}
    }
}

=item fork_tests( sub { ... }, $message, $count )

Forks, then runs the provided sub in a child process.

$message and $count are optional, and each add an extra test to the count.

=cut

sub fork_tests(&;$$) {
    my ($sub, $message, $count) = @_;

    if ( my $pid = fork()) {
        my $data = _read();
        waitpid( $pid, 0 );
        my $out = !$?;
        my $tests = _run_tests( $data );
        Test::More::ok( $out, $message ) if $message;
        Test::More::is( @$tests, $count, "Verify test count" ) if $count;
    }
    else {
        $CHILD = [];
        eval { $sub->() };
        if ( $@ ) {
            _write( $@ . $SEPERATOR );
        }
        else {
            _write( Dumper( $CHILD ) . $SEPERATOR );
        }
        exit;
    }
}

sub _run_tests {
    my $data = shift;
    die( $data ) unless( $data =~ m/^\$VAR1/ );
    my $tests = _deserialize_data( $data );
    for my $test ( @$tests ) {
        my $caller = $test->{ 'caller' };
        my $sub = $test->{ 'sub' };
        my $params = $test->{ params };
        no strict 'refs';
        my $tb = Test::More->builder;
        my $number = $tb->current_test;
        eval { &$sub( @$params ) };
        my @summary = $tb->summary;
        if ( $tb->current_test != $number && !$summary[$number] ) {
            Test::More::diag( "Problem at: " . $caller->[1] . " line: " . $caller->[2] );
        }
        Test::More::diag $@ if $@;
    }
    return $tests;
}

sub _deserialize_data {
    my $data = shift;
    no strict;
    $data =~ s/$SEPERATOR//;
    return eval $data;
}

sub _read {
    local $/ = $SEPERATOR;
    my $data = <READ>;
    return $data;
}

sub _write {
    print WRITE $_ for @_;
}

1;

__END__

=back

=head1 SEE ALSO

L<Test::More>
L<Test::Fork>
L<Test::MultiFork>
L<Test::SharedFork>

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2009 Chad Granum

Test-Seperate is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version.

Test-Seperate is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
