#!/usr/bin/env perl
use strict;
use warnings;
use inc::Module::Install;

perl_version '5.008';
license 'gpl';
all_from 'lib/Test/More/Fork.pm';

requires (
    'Test::More' => 0,
);

test_requires (
    'Test::More' => 0,
    'Test::Exception' => 0,
);

WriteAll;

