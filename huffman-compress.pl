#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use MIME::Base64 qw/encode_base64 decode_base64/;
use POSIX;
use File::Slurp;
use Time::HiRes qw/usleep/;

use feature 'say';

my $compress_file;
my $decompress_file;
my $output_file;

GetOptions (
        "compress=s" => \$compress_file,
        "decompress=s" => \$decompress_file,
        "output=s" => \$output_file,
        "help" => sub { print "Usage: --compress <file> --decompress <file\n"; exit; }
);

if($compress_file && $decompress_file) {
	say "Please only specify one option!";
	exit;
}

if($compress_file) {
	my $data;

	open (FILE, $compress_file) || die "Can't find file $compress_file";
	while (my $line = <FILE> ) {
		 $data .= $line;
	}
 
	close FILE;
	chomp $data;

	#say "Compressing $compress_file";
	#say "Data to compress:";

	my $code_table = construct_frequency_table($data);
	my @code_tree = ();

	# Construct tree as array
	foreach (keys %{$code_table}) {
		push @code_tree, [$_, $code_table->{$_}];
	}

	@code_tree = sort { $a->[1] <=> $b->[1] } @code_tree;

	#say "Constructing tree...";

	construct_tree(\@code_tree);

	@code_tree = sort { $a->[1] <=> $b->[1] } @code_tree;

	#say Dumper \@code_tree;

	#say "Constructing binary code table...";

	my $max_code_len = 0;

	foreach my $code (sort keys %{$code_table}) {
		my $str = "";
		$str = traverse($code, $str, \@code_tree);
		$code_table->{$code} = "$str:";
	}

	#say "Code table complete...";

	my $output_file = $output_file . '.lz' || "compressed_$compress_file.lz";

	say "Writing to $output_file...";

	compress($data, $code_table, $output_file);

	say "Complete.";

}

if($decompress_file) {

	say "Inflating...";

	my $inflated = inflate($decompress_file, $output_file);

	say "Complete.";
}



sub construct_frequency_table {
	my $data = shift;

	my %code_table;

	foreach my $symbol (split("", $data)) {
		if(exists $code_table{$symbol}) {
			$code_table{$symbol}++;
		} else {
			$code_table{$symbol} = 1;
		}
	}

	return \%code_table;
}



sub construct_tree {
	my ($code_tree) = @_;
	unless (scalar @{$code_tree} <= 2) {
		@{$code_tree} = sort { $a->[1] <=> $b->[1] } @{$code_tree};

		my $first = shift @{$code_tree};
		my $second = shift @{$code_tree};

		my $concat = $first->[0] . $second->[0];
		my $sum = $first->[1] + $second->[1];

		my @new_tree = ( $first, $second );
		@new_tree = sort { $a->[1] <=> $b->[1] } @new_tree;
		unshift @{$code_tree}, ([ $concat, $sum, \@new_tree ]);

		construct_tree($code_tree);
	}
};

sub traverse {
	my ($code, $str, $tree) = @_;

	if($tree->[0][0] eq $code) {
		#say "Found in left leaf: $tree->[0][0]";
		$str .= "0";
	} elsif($tree->[1][0] eq $code) {
		#say "Found in right leaf: $tree->[1][0]";
                $str .= "1";
	} elsif(grep { $_ eq $code } split("", $tree->[0][0])) {
		#say "Found in left: $tree->[0][0]";
		$str .= "0";	
		traverse($code, $str, $tree->[0][2]);
	} elsif(grep { $_ eq $code } split("", $tree->[1][0])) {
		#		} elsif($tree->[1][0]=~/$search/) {
			#say "Found in right $tree->[1][0]";
		$str .= "1";
		traverse($code, $str, $tree->[1][2]);
	} 
}

sub decode_symbols {
	my ($code_table, $string) = @_;

	my $len = 1;
	my $inflated;

	while (length($string) > 0) {
		my $sym = substr($string, 0, $len); 
		
		if(exists $code_table->{"$sym:"}) {
			$inflated .= $code_table->{"$sym:"};
			$string=~s/^$sym//;
			$len=0;
		} else {
			$len++;
		}
	}

	return $inflated;
}

sub compress {
	my ($data, $code_table, $filename) = @_;

	open COMPRESS, ">$filename";

	binmode(COMPRESS);

	my $compressed_string;

	foreach my $d (split "", $data) {
		my $symbol = $code_table->{$d};
		chop $symbol;	
		$compressed_string .= $symbol;
	}

	my %lookup_table = reverse %{$code_table};

	my $dumped_code_table = Dumper \%lookup_table;
	$dumped_code_table =~ s/\$VAR1 = //g;
	$dumped_code_table = encode_base64($dumped_code_table);

	my $length_in_bits = length($compressed_string);
	
	print COMPRESS $length_in_bits . "L\n";

	print COMPRESS $dumped_code_table . "\n";

	print COMPRESS pack "B*", $compressed_string;

	close COMPRESS;
}

sub inflate {
	my ($filename, $out) = @_;

	my $data;

	open INFLATE, "<$filename";

	my $data_length_in_bits = <INFLATE>;

	$data_length_in_bits =~ s/L\n//g;

	my $code_table;

	while(my $line = <INFLATE>) {
		if($line ne "\n") {
			$code_table .= $line;
		} else {
			last;
		}
	}


	$code_table = eval( decode_base64($code_table) );

	binmode INFLATE;

	while(<INFLATE>) {
		$data = $_;
	}

	$data = unpack("B*", $data);	
	
	$data = substr($data, 0, $data_length_in_bits);

	my $inflated_data = decode_symbols($code_table, $data);

	open OUT, ">>$out";
	print OUT $inflated_data;
	close OUT;
}
