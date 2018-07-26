#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Time::HiRes qw/gettimeofday tv_interval/;

my $array_size = 10000;
my $sort_algs = "insertion";
my $verbose = 0;
my $summary = 1;

GetOptions (
	"array_size=i" => \$array_size,
	"sort_algs=s" => \$sort_algs,
	"verbose" => \$verbose,
	"summary" => \$summary,
	"help" => sub { print "Usage: --array_size <n> --sort_algs \"insertion,bubble\" --verbose\n"; exit; }
);

print "Building random array of size $array_size for sorting...\n";

my @list = build_array($array_size);
print "Unsorted array:\n" . (join ",", @list) . "\n------------\n" if $verbose;

my %stats;

foreach(split(",", $sort_algs)) {
	my $start = [ gettimeofday() ];
	my @sorted;

	if($_ eq "bubble") {
		print "Performing bubble sort...\n";
		@sorted = bubble_sort(@list);
	} elsif($_ eq "insertion") {
		print "Performing insertion sort...\n";
		@sorted = insertion_sort(@list);
	} else {
		print "Unknown or unsupported algorithm: $_\n";
		next;
	}
	
	print "Sorted array:\n" . (join ",", @sorted) . "\n" if $verbose;

	my $elapsed = tv_interval($start);

	$stats{$_} = $elapsed;

	print "Sort complete. Time taken: " . $elapsed . "\n";
	print "------------\n";
}

if($summary && %stats) {

	print "==========================\n";
	print "Results in ascending order\n";
	print "--------------------------\n";
	foreach (sort { $stats{$a} <=> $stats{$b} } keys %stats) {
		print "$_: " . $stats{$_} . "\n";
	}
	print "--------------------------\n";
}

sub build_array {
	my $size = shift;
	my @list;

	for(0 .. $size-1) {
		push @list, int(rand(1000));
	}

	return @list;
}

sub insertion_sort {
	my @list = @_;

	for(my $i=1; $i < scalar(@list); $i++) {
		my $j = $i;
		my $temp;

		while($j > 0 && $list[$j-1] > $list[$j]) {
			$temp = $list[$j-1];
			$list[$j-1] = $list[$j];
		        $list[$j] = $temp;	
			$j--;
		}
	}

	return @list;
}

sub bubble_sort {

	my @list = @_;

	my $swapped = 1;
	while($swapped) {
		$swapped = 0;
		for(my $i=1; $i < scalar(@list); $i++) {
			if($list[$i-1] > $list[$i]) {
				my $tmp = $list[$i-1];
				$list[$i-1] = $list[$i];
				$list[$i] = $tmp;
				$swapped = 1;	
			}
		}
	}


	return @list;
}
