
use strict;

use Getopt::Std;
use Data::Dumper;
use CXGN::DB::InsertDBH;
use CXGN::Genotype;

# -d database name
# -h hostname
# -U database username (postgres default)
# -p protocol_id

our($opt_d, $opt_h, $opt_U, $opt_p);
getopts('d:h:U:p:');

my $dbh = CXGN::DB::InsertDBH->new({
    dbhost => $opt_h,
    dbname => $opt_d,
    dbuser => $opt_U,
    });

print STDERR "Querying genotypes...\n";
my $q1 = "SELECT genotypeprop_id, value from nd_protocol JOIN nd_experiment_protocol USING (nd_protocol_id) JOIN nd_experiment_genotype USING(nd_experiment_id) JOIN genotypeprop USING(genotype_id) WHERE nd_protocol.nd_protocol_id=?";

my $h1 = $dbh->prepare($q1);

$h1->execute($opt_p);

while (my ($comparison_id, $json) = $h1->fetchrow_array()) { 
    my $c_gt = CXGN::Genotype->new();
    $c_gt->from_json($json);

    my $q2 = "SELECT genotypeprop_id, value from nd_protocol JOIN nd_experiment_protocol USING (nd_protocol_id) JOIN nd_experiment_genotype USING(nd_experiment_id) JOIN genotypeprop USING(genotype_id) WHERE nd_protocol.nd_protocol_id=?";
    my $h2 = $dbh->prepare($q2);
    $h2->execute($opt_p);

    while (my ($gtpid, $json) = $h2->fetchrow_array()) { 
	my $gt = CXGN::Genotype->new();
	$gt->from_json($json);
	#print STDERR Dumper($gt->markerscores());
	my $distance = $gt->calculate_distance($c_gt);
	print "$distance\t";
    }
    print "\n";
}

$dbh->disconnect();
    
