#!/usr/bin/env perl
#
# print the first set of consecutive lines that each match '$1'

use feature qw(say);
use strict;
use warnings;

my $match = shift(@ARGV);

#Iterate over all the lines, of all the files given as arguments
my $matchFound = 0;
while (my $line = <ARGV>) {
	if ($line =~ /$match/) {
		$matchFound = 1;
		print "$line";
	} elsif ($matchFound) {
		exit();
	}
}
