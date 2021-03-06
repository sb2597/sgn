package CXGN::BrAPI::v2::Locations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
    my $params = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $abbreviations_arrayref = $params->{abbreviations} || ($params->{abbreviations} || ());
	my $altitude_max = $params->{altitudeMax}->[0] || undef;
	my $altitude_min = $params->{altitudeMin}->[0] || undef;
	my $coordinates = $params->{coordinates} || ($params->{coordinates} || ());
	my $country_codes_arrayref = $params->{countryCodes} || ($params->{countryCodes} || ());
	my $country_names_arrayref = $params->{countryNames} || ($params->{countryNames} || ());
	my $externalreference_ids_arrayref = $params->{externalReferenceID} || ($params->{externalReferenceIDs} || ());
	my $externalreference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());
	my $institute_addresses_arrayref = $params->{instituteAddresses} || ($params->{instituteAddresses} || ());
	my $institute_names_arrayref = $params->{instituteNames} || ($params->{instituteNames} || ());
	my $location_ids_arrayref = $params->{locationDbIds} || ($params->{locationDbIds} || ());
	my $location_names_arrayref  = $params->{locationNames } || ($params->{locationNames } || ());
	my $location_types_arrayref = $params->{locationType} || ($params->{locationTypes} || ());

    if (($institute_names_arrayref && scalar($institute_names_arrayref)>0) || ($coordinates && scalar($coordinates)>0 )|| ( $externalreference_sources_arrayref && scalar($externalreference_sources_arrayref)>0) || ($externalreference_ids_arrayref && scalar($externalreference_ids_arrayref)>0)){
        push @$status, { 'error' => 'The following search parameters are not implemented: instituteNames, coordinates, externalReferenceID, externalReferenceSource' };
    }

	my %location_ids_arrayref;
    if ($location_ids_arrayref && scalar(@$location_ids_arrayref)>0){
        %location_ids_arrayref = map { $_ => 1} @$location_ids_arrayref;
    }

    my %abbreviations_arrayref;
    if ($abbreviations_arrayref && scalar(@$abbreviations_arrayref)>0){
        %abbreviations_arrayref = map { $_ => 1} @$abbreviations_arrayref;
    }

    my %country_codes_arrayref;
    if ($country_codes_arrayref && scalar(@$country_codes_arrayref)>0){
        %country_codes_arrayref = map { $_ => 1} @$country_codes_arrayref;
    }

    my %country_names_arrayref;
    if ($country_names_arrayref && scalar(@$country_names_arrayref)>0){
        %country_names_arrayref = map { $_ => 1} @$country_names_arrayref;
    }

    my %institute_addresses_arrayref;
    if ($institute_addresses_arrayref && scalar(@$institute_addresses_arrayref)>0){
        %institute_addresses_arrayref = map { $_ => 1} @$institute_addresses_arrayref;
    }

    # my %institute_names_arrayref;
    # if ($institute_names_arrayref && scalar(@$institute_names_arrayref)>0){
    #     %institute_names_arrayref = map { $_ => 1} @$institute_names_arrayref;
    # }

    my %location_names_arrayref;
    if ($location_names_arrayref && scalar(@$location_names_arrayref)>0){
        %location_names_arrayref = map { $_ => 1} @$location_names_arrayref;
    }
        
    my %location_types_arrayref;
    if ($location_types_arrayref && scalar(@$location_types_arrayref)>0){
        %location_types_arrayref = map { $_ => 1} @$location_types_arrayref;
    }

	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema ); #, $location_id);
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($locations,$page_size,$page);
	my @data;
	
	foreach (@$data_window){
		if ( (%location_ids_arrayref && !exists($location_ids_arrayref{$_->[0]}))) { next; }
		if ( (%abbreviations_arrayref && !exists($abbreviations_arrayref{$_->[9]}))) { next; }
        if ( (%country_codes_arrayref && !exists($country_codes_arrayref{$_->[6]}))) { next; }
        if ( (%country_names_arrayref && !exists($country_names_arrayref{$_->[5]}))) { next; }
        if ( (%institute_addresses_arrayref && !exists($institute_addresses_arrayref{$_->[10]}))) { next; }
        # if ( (%institute_names_arrayref && !exists($institute_names_arrayref{$_->[]}))) { next; }
        if ( (%location_names_arrayref && !exists($location_names_arrayref{$_->[1]}))) { next; }
        if ( (%location_types_arrayref && !exists($location_types_arrayref{$_->[8]}))) { next; }
        if ( $altitude_max && $_->[4] > $altitude_max ) { next; } 
        if ( $altitude_min && $_->[4] < $altitude_min ) { next; } 

		my @coordinates;
		push @coordinates, {
            geometry=>{
            	coordinates=>[
	            	$_->[2], #latitude
					$_->[3], #longitude
					$_->[4], #altitude
            	],
            	type=>'Point'
            },
            type=>'Feature'
        };
		push @data, {
			locationDbId => qq|$_->[0]|,
			locationType=> $_->[8],
			locationName=> $_->[1],
			abbreviation=>$_->[9],
			countryCode=> $_->[6],
			countryName=> $_->[5],
            instituteName=>'',
            instituteAddress=>$_->[10],
			additionalInfo=> $_->[7],
			documentationURL=> undef,
			siteStatus => undef,
			exposure => undef,
			slope => undef,
			coordinateDescription => undef,
			environmentType => undef,
			coordinates=>\@coordinates,
			topography => undef,
			coordinateUncertainty => undef,
			externalReferences=> undef
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Locations list result constructed');
}

sub detail {
	my $self = shift;
	my $location_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema , $location_id);
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($locations,$page_size,$page);
	my @data;
	
	foreach (@$data_window){
		my @coordinates;
		push @coordinates, {
            geometry=>{
            	coordinates=>[
	            	$_->[2], #latitude
					$_->[3], #longitude
					$_->[4], #altitude
            	],
            	type=>'Point'
            },
            type=>'Feature'
        };
		push @data, {
			locationDbId => qq|$_->[0]|,
			locationType=> $_->[8],
			locationName=> $_->[1],
			abbreviation=>$_->[9],
			countryCode=> $_->[6],
			countryName=> $_->[5],
            instituteName=>'',
            instituteAddress=>$_->[10],
			additionalInfo=> $_->[7],
			documentationURL=> undef,
			siteStatus => undef,
			exposure => undef,
			slope => undef,
			coordinateDescription => undef,
			environmentType => undef,
			coordinates=>\@coordinates,
			topography => undef,
			coordinateUncertainty => undef,
			externalReferences=> undef
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Locations list result constructed');
}

1;
