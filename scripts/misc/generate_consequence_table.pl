#! perl -w

# Script to dump out a table of variation sets that can be used in the documentation

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Bio::EnsEMBL::Variation::Utils::Config qw(@OVERLAP_CONSEQUENCES);


###############
### Options ###
###############
my ($web_colour_file, $web_mapping_colour, $output_file, $help);

usage() if (!scalar(@ARGV));
 
GetOptions(
	   'colour_file=s'  => \$web_colour_file,
	   'mapping_file=s' => \$web_mapping_colour,
		 'output_file=s'  => \$output_file,
	   'help!'          => \$help
);

if (!$output_file) {
	print "> Error! Please give an output file name using the option '-output_file'\n";
	usage();
}

usage() if ($help);

my %colour = (
	'Essential splice site'  => 'coral',
	'Stop gained'            => '#F00',
	'Stop lost'              => '#F00', 
	'Complex in/del'         => 'mediumspringgreen',
	'Frameshift coding'      => 'hotpink', 
	'Non synonymous coding'  => 'gold',
	'Splice site'            => 'coral',
	'Partial codon'          => 'magenta',
	'Synonymous coding'      => '#76EE00',
	'Coding unknown'         => '#458B00',
	'Within mature miRNA'    => '#458B00',
	'5prime UTR'             => '#7AC5CD',
	'3prime UTR'             => '#7AC5CD',
	'Intronic'               => '#02599C',
	'NMD transcript'         => 'orangered',
	'Within non coding gene' => 'limegreen',
	'Upstream'               => '#A2B5CD',
	'Downstream'             => '#A2B5CD',
	'Regulatory region'      => '#4DFEB8',
	'Intergenic'             => '#636363',
);

my $SO_BASE_LINK = 'http://www.sequenceontology.org/miso/current_release/term';


my %cons_rows;
my %consequences;
my %consequences_rank;


# If you want to use directly the colours from the web colours configuration file
# instead of the almost-up-to-date-colour-hash above.
# Usually, you can find the colour configuration file in:
# ensembl-webcode/conf/ini-files/COLOUR.ini
if (defined($web_colour_file)) {
	%colour = get_colours_from_web();
}


for my $cons_set (@OVERLAP_CONSEQUENCES) {

		my $display_term = $cons_set->{display_term};
    my $so_term      = $cons_set->{SO_term};
    my $so_acc       = $cons_set->{SO_accession};
    my $ens_label    = $cons_set->{label};
    my $so_desc      = $cons_set->{description};
    my $rank         = $cons_set->{rank};

		$display_term = $ens_label if (!defined($display_term));
		$display_term = display_term_for_web($display_term);
		
    $so_acc = qq{<a rel="external" href="$SO_BASE_LINK/$so_acc">$so_acc</a>};

    my $row = "$so_term|$so_desc|$so_acc";

    $cons_rows{$row} = $rank;
		
		push(@{$consequences{$display_term}},$row);
		
		if ($consequences_rank{$display_term}) {
			$consequences_rank{$display_term} = $rank if ($consequences_rank{$display_term} > $rank);
		}
		else {
			$consequences_rank{$display_term} = $rank;
		}	
}


my $cons_table = 
    qq{<table id="consequence_type_table" class="ss">\n<tr>\n\t<th style="width:5px">*</th>\n\t<th>}.
    (join qq{</th>\n\t<th>}, 'SO term', 'SO description', 'SO accession', 'Ensembl term').
    qq{</th>\n</tr>\n};

my $bg = '';

for my $d_term (sort {$consequences_rank{$a} <=> $consequences_rank{$b}} keys(%consequences)) {

	my $cons_list = $consequences{$d_term};
	my $count = scalar @$cons_list;
	my $rspan = ($count > 1) ? qq{ rowspan="$count"} : '';
	
	my $c = $colour{$d_term};
	my $first_col = (defined($c)) ? qq{\t<td $rspan style="padding:0px;margin:0px;background-color:$c"></td>} : qq{<td$rspan></td>};
	
	$cons_table .= qq{<tr$bg>\n$first_col\n};
	
	my $line = 1;
	
	for my $row (sort {$cons_rows{$a} <=> $cons_rows{$b}} @$cons_list) {
		$row =~ s/\|/<\/td>\n\t<td>/g;
		
		$cons_table .= qq{</tr>\n<tr$bg>\n} if ($line !=1 );
		$cons_table .= qq{\t<td>$row</td>\n};
		$cons_table .= qq{\t<td$rspan>$d_term</td>\n} if ($line == 1);
		$line ++;
	}
	$cons_table .= qq{</tr>\n};
	
	$bg = ($bg eq '') ? qq{ class="bg2"} : '';
	
}

$cons_table .= qq{</table>\n};
$cons_table .= qq{<p>* Corresponding colours for the Ensembl web displays.<p>\n};

open OUT, "> $output_file" or die $!;
print OUT $cons_table;
close(OUT);


# Retrieve the variation consequence colours from the COLOUR.ini file
sub get_colours_from_web {
	my %webcolours;
	my $var_flag = 0;
	open F, "$web_colour_file" or die $!;
	while(<F>) {
		chomp $_;
		if ($_ =~ /\[variation\]/) {
			$var_flag = 1;
			next;
		}
		next if ($var_flag == 0);
		
		if ($_ =~ /^(\S+)\s*=\s*(\S+)\s*/) {
			my $cons = display_term_for_web($1);
			my $c    = (split(';',$2))[0]; 
			
			# Convert the colour name into hexadecimal code
			if (-e $web_mapping_colour) {
				my $line = `grep -w "'$c'" $web_mapping_colour`;
				$c = '#'.$1 if ($line =~ /=>\s+'(\S+)'/);
			}
			
			$webcolours{$cons} = $c;
		}
		
		last if ($_ eq '');
	}
	close(F);
	return (scalar(keys(%webcolours))) ? %webcolours : %colour;
}

sub display_term_for_web {
	my $term = shift;
	$term = ucfirst(lc($term));
	$term =~ s/_/ /g;
	$term =~ s/Nmd /NMD /g;
	$term =~ s/ utr/ UTR/g;
	$term =~ s/rna/RNA/g;
	return $term;
}


sub usage {
	
  print qq{
  Usage: perl generate_consequence_table.pl [OPTION]
  
  Put all variation consequence information into an HTML table.
	
  Options:

    -help           Print this message
      
    -output_file    An HTML output file name (Required)			
    -colour_file    If you want to use directly the colours from the web colours configuration file
                    instead of the almost-up-to-date-colour-hash \%colour hash. (optional)
                    Usually, you can find the colour configuration file in:
                    ensembl-webcode/conf/ini-files/COLOUR.ini 
		
    -mapping_file   Web module to map the colour names to the corresponding hexadecimal code. (optional)
                    Useful because some colour names are internal to Ensembl and won't be displayed in the 
                    documentation pages (i.e. not using the perl modules).
                    The module ColourMap.pm can be find in:
                    ensembl-draw/modules/Sanger/Graphics/ColourMap.pm
  } . "\n";
  exit(0);
}
