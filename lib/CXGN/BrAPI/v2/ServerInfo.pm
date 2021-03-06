package CXGN::BrAPI::v2::ServerInfo;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $c = shift;
	my $inputs = shift;
	my $datatype_param = $inputs->{datatype}->[0];
	my $page_size = $self->page_size;
	my $page = $self->page;

    $page_size = 1000;

	my $status = $self->status;
	my @available = (
		#core
		[['application/json'],['GET'],'serverinfo',['2.0']],
		[['application/json'],['GET'],'commoncropnames',['2.0']],
		[['application/json'],['GET'],'lists',['2.0']],
		[['application/json'],['GET'],'lists/{listDbId}',['2.0']],
		[['application/json'],['POST'],'search/lists',['2.0']],
		[['application/json'],['GET'],'search/lists/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'locations',['2.0']],
		[['application/json'],['GET'],'locations/{locationDbId}',['2.0']],
		[['application/json'],['POST'],'search/locations',['2.0']],
		[['application/json'],['GET'],'search/locations/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'people',['2.0']],
		[['application/json'],['GET'],'people/{peopleDbId}',['2.0']],
		[['application/json'],['POST'],'search/people',['2.0']],
		[['application/json'],['GET'],'search/people/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'programs',['2.0']],
		[['application/json'],['GET'],'programs/{programDbId}',['2.0']],
		[['application/json'],['POST'],'search/programs',['2.0']],
		[['application/json'],['GET'],'search/programs/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'seasons',['2.0']],
		[['application/json'],['GET'],'seasons/{seasonDbId}',['2.0']],
		[['application/json'],['POST'],'search/seasons',['2.0']],
		[['application/json'],['GET'],'search/seasons/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'studies',['2.0']],
		[['application/json'],['GET'],'studies/{studyDbId}',['2.0']],
		[['application/json'],['POST'],'search/studies',['2.0']],
		[['application/json'],['GET'],'search/studies/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'],'studytypes',['2.0']],
		[['application/json'],['GET'],'trials',['2.0']],
		[['application/json'],['GET'],'trials/{trialDbId}',['2.0']],
		[['application/json'],['POST'],'search/trials',['2.0']],
		[['application/json'],['GET'],'search/trials/{searchResultsDbId}',['2.0']],
		#phenotyping
		[['application/json'],['GET'], 'images',['2.0']],
		[['application/json'],['GET'], 'images/{imageDbId}',['2.0']],
		[['application/json'],['POST'],'search/images',['2.0']],
		[['application/json'],['GET'], 'search/images/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET','POST','PUT'], 'observations',['2.0']],
		[['application/json'],['GET','PUT'], 'observations/{observationDbId}',['2.0']],
		[['application/json'],['POST'],'search/observations',['2.0']],
		[['application/json'],['GET'], 'search/observations/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'observationlevels',['2.0']],
		[['application/json'],['GET'], 'observationunits',['2.0']],
		[['application/json'],['GET','PUT'], 'observationunits/{observationUnitDbId}',['2.0']],
		[['application/json'],['POST'],'search/observationunits',['2.0']],
		[['application/json'],['GET'], 'search/observationunits/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'ontologies',['2.0']],
		[['application/json'],['GET'], 'traits',['2.0']],
		[['application/json'],['GET'], 'traits/{traitDbId}',['2.0']],
		[['application/json'],['GET'], 'variables',['2.0']],
		[['application/json'],['GET'], 'variables/{observationVariableDbId}',['2.0']],
		[['application/json'],['POST'],'search/variables',['2.0']],
		[['application/json'],['GET'], 'search/variables/{searchResultsDbId}',['2.0']],
		#genotyping
		[['application/json'],['GET'], 'calls',['2.0']],
		[['application/json'],['POST'],'search/calls',['2.0']],
		[['application/json'],['GET'], 'search/calls/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'callsets',['2.0']],
		[['application/json'],['GET'], 'callsets/{callSetDbId}',['2.0']],
		[['application/json'],['GET'], 'callsets/{callSetDbId}/calls',['2.0']],
		[['application/json'],['POST'],'search/callsets',['2.0']],
		[['application/json'],['GET'], 'search/callsets/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'maps',['2.0']],
		[['application/json'],['GET'], 'maps/{mapDbId}',['2.0']],
		[['application/json'],['GET'], 'maps/{mapDbId}/linkagegroups',['2.0']],
		[['application/json'],['GET'], 'markerpositions',['2.0']],
		[['application/json'],['POST'],'search/markerpositions',['2.0']],
		[['application/json'],['GET'], 'search/markerpositions/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'references',['2.0']],
		[['application/json'],['GET'], 'references/{referenceDbId}',['2.0']],
		[['application/json'],['POST'],'search/references',['2.0']],
		[['application/json'],['GET'], 'search/references/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'referencesets',['2.0']],
		[['application/json'],['GET'], 'referencesets/{referenceSetDbId}',['2.0']],
		[['application/json'],['POST'],'search/referencesets',['2.0']],
		[['application/json'],['GET'], 'search/referencesets/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'samples',['2.0']],
		[['application/json'],['GET'], 'samples/{sampleDbId}',['2.0']],
		[['application/json'],['POST'],'search/samples',['2.0']],
		[['application/json'],['GET'], 'search/samples/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'variants',['2.0']],
		[['application/json'],['GET'], 'variants/{variantDbId}',['2.0']],
		[['application/json'],['GET'], 'variants/{variantDbId}/calls',['2.0']],
		[['application/json'],['POST'],'search/variants',['2.0']],
		[['application/json'],['GET'], 'search/variants/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET'], 'variantsets',['2.0']],
		[['application/json'],['GET'], 'variantsets/extract',['2.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}',['2.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/calls',['2.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/callsets',['2.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/variants',['2.0']],
		[['application/json'],['POST'],'search/variantsets',['2.0']],
		[['application/json'],['GET'], 'search/variantsets/{searchResultsDbId}',['2.0']],
		#Germplasm
		[['application/json'],['GET'], 'germplasm',['2.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}',['2.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}/pedigree',['2.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}/progeny',['2.0']],
		[['application/json'],['POST'],'search/germplasm',['2.0']],
		[['application/json'],['GET'], 'search/germplasm/{searchResultsDbId}',['2.0']],
		[['application/json'],['GET','POST'], 'crossingprojects',['2.0']],
		[['application/json'],['GET','PUT'], 'crossingprojects/{crossingProjectDbId}',['2.0']],
		[['application/json'],['GET','POST'], 'crosses',['2.0']],
		[['application/json'],['GET','POST'], 'seedlots',['2.0']],
		[['application/json'],['GET','POST'], 'seedlots/transactions',['2.0']],
		[['application/json'],['GET','PUT'], 'seedlots/{seedLotDbId}',['2.0']],
		[['application/json'],['GET'], 'seedlots/{seedLotDbId}/transactions',['2.0']],
	);

	my @call_search;
	if ($datatype_param){
		foreach my $a (@available){
			foreach (@{$a->[1]}){
				if ($_ eq $datatype_param){
					push @call_search, $a;
				}
			}
		}
	} else {
		@call_search = @available;
	}

	my @data;
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@call_search, $page_size, $page);
	foreach (@$data_window){
		push @data, {
			datatypes=>$_->[0],
			methods=>$_->[1],
			service=>$_->[2],
            versions=>$_->[3]
		};
		
	}
	my $permissions = info();
	my %result = (
		calls=>\@data,
		contactEmail=>"lam87\@cornell.edu",
		documentationURL=>"https://solgenomics.github.io/sgn/",
		location=>"USA",
		organizationName=>"Boyce Thompson Institute",
		organizationURL=>$c->request->{"base"},
		serverDescription=>"BrAPI v2.0 compliant server",
		serverName=>$c->config->{project_name},
		permissions=>$permissions,
	);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Calls result constructed');
}

sub info {
	my $permissions  = {
				'GET' => 'any',
				'POST' => 'curator',
				'PUT' => 'curator'
			};

	return $permissions;
}

1;
