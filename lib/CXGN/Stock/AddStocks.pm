package CXGN::Stock::StockLookup;

=head1 NAME

CXGN::Stock::AddStocks - a module to add a list of stocks.

=head1 USAGE

 my $stock_add = CXGN::Stock::AddStock->new({ schema => $schema, stocks => \@stocks, species => $species} );
 my $validated = $stock_add->validate_accessions();
 $stock_add->add_accessions();

=head1 DESCRIPTION

Adds a list of stocks.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
has 'stocks' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_stock_name');
has 'species' => (isa => 'Str', is => 'rw', predicate => 'has_species');

sub add_accessions {
  my $self = shift;
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

  my $coderef = sub {

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")
      ->create_with({
		     name   => 'accession',
		     cv     => 'stock type',
		     db     => 'null',
		     dbxref => 'accession',
		    });
    my $organism = $schema->resultset("Organism::Organism")
      ->find({
	      species => $species,
	     });
    my $organism_id = $organism->organism_id();
    foreach my $accession_name (@stocks) {
      my $accession_stock = $schema->resultset("Stock::Stock")
	->create({
		  organism_id => $organism_id,
		  name       => $accession_name,
		  uniquename => $accession_name,
		  type_id     => $accession_cvterm->cvterm_id,
		 } );
    }
  };

  try {
    $schema->txn_do($coderef);
  } catch {
    $transaction_error =  $_;
  };
  if ($transaction_error) {
    print STDERR "Transaction error storing phenotypes: $transaction_error\n";
    return;
  }

}

sub verify_accessions {
  my $self = shift;
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

}

#######
1;
#######
