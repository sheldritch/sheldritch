#!/usr/bin/perl -p
use warnings;
use strict;
use Term::ANSIColor;
use List::Util qw/shuffle/;
use Getopt::Long;

our %colorCode;
our @colors;
our @matches;

BEGIN {
	our @matches;

	GetOptions("match=s" => \@matches)
		or die("Error in command line arguments\n");

	if (!@matches) {
		@matches[0] = shift(@ARGV);
	}

	our @colors = (
		8 .. 16, # 16-color bold set
		1 .. 7, # default 8 colours (minus black (0))
		# if we run out, generate a random palette using 256 color support
		shuffle(map(
				4*$_+23, 1 .. ((255 - 24) / 4) # color space is 0-255, first 24 colors are too dark
			)));
	our %colorCode = (); # string -> color
}

sub colorMatch {
	my ($str) = @_;
	my $color = $colorCode{$str};
	if (!$color) {
		$color = $colorCode{$str} = shift(@colors);
	}
	return colored( $str, "ansi$color");
}

foreach my $match ( @matches ) {
	my $re = qr/$match/;
	s/($re)/colorMatch($1)/ge
}

