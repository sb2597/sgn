#!/usr/bin/perl

=head1 NAME

delete_nd_experiment_entries.pl - script to delete nd_experiment entries. used during phenotpe deletion to move the slow process of deleting nd_experiment entries to an asynchronous process

=head1 DESCRIPTION

delete_nd_experiment_entries.pl -H [database handle] -D [database name] -U [database user] -P [database password] -i [nd_experiment_ids to delete. comma separated]

Options:

 -H database host
 -D database name
 -U database user
 -P database password
 -i nd_experiment_ids to delete. provided as comma separated list

=head1 AUTHOR


=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;
#use CXGN::DB::InsertDBH;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_i);
getopts('H:D:U:P:i:');

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";
my $dbh = DBI->connect($dsn, $opt_U, $opt_P);

eval {
    my @nd_experiment_ids = split ",", $opt_i;
    my $q = "DELETE FROM nd_experiment WHERE nd_experiment_id IN ($opt_i)";
    my $h = $dbh->prepare($q);
    $h->execute();
    print STDERR "DELETED ".scalar(@nd_experiment_ids)." Nd Experiment Entries\n";
};

if ($@) {
  $dbh->rollback();
  print STDERR $@;
} else {
  print STDERR "Done, exiting delete_nd_experiment_entries.pl \n";
}
