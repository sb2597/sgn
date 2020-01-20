package CXGN::BrAPI::v1::Markerprofiles;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub markerprofiles_search {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @germplasm_ids = $inputs->{stock_ids} ? @{$inputs->{stock_ids}} : ();
    my @study_ids = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @extract_ids = $inputs->{extract_ids} ? @{$inputs->{extract_ids}} : ();
    my @sample_ids = $inputs->{sample_ids} ? @{$inputs->{sample_ids}} : ();
    my @methods = $inputs->{protocol_ids} ? @{$inputs->{protocol_ids}} : ();

    if (scalar(@extract_ids)>0){
        push @$status, { 'error' => 'Search parameter extractDbId not supported' };
    }
    if (scalar(@sample_ids)>0){
        push @$status, { 'error' => 'Search parameter sampleDbId not supported' };
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        accession_list=>\@germplasm_ids,
        trial_list=>\@study_ids,
        protocol_id_list=>\@methods,
        genotypeprop_hash_select=>['DS'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
        # offset=>$page_size*$page,
        # limit=>$page_size
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c, 1); #Metadata only returned
    my @data;

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    while( <$fh> ) {
        if ($counter >= $start_index && $counter <= $end_index) {
            my $gt = decode_json $_;
            push @data, {
                markerprofileDbId => qq|$gt->{markerProfileDbId}|,
                germplasmDbId => qq|$gt->{germplasmDbId}|,
                uniqueDisplayName => $gt->{genotypeUniquename},
                extractDbId => qq|$gt->{stock_id}|,
                sampleDbId => qq|$gt->{stock_id}|,
                analysisMethod => $gt->{analysisMethod},
                resultCount => $gt->{resultCount}
            };
        }
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles-search result constructed');
}

sub markerprofiles_detail {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $genotypeprop_id = $inputs->{markerprofile_id};
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, {'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased'};
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        markerprofile_id_list=>[$genotypeprop_id],
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c, 0);

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    my $gt_line = <$fh>;
    my $gt = decode_json $gt_line;
    my $genotype = $gt->{selected_genotype_hash};

    my @data;
    foreach my $m (sort keys %$genotype) {
        if ($counter >= $start_index && $counter <= $end_index) {
            my $geno = '';
            if (exists($genotype->{$m}->{'NT'}) && defined($genotype->{$m}->{'NT'})){
                $geno = $genotype->{$m}->{'NT'};
            }
            elsif (exists($genotype->{$m}->{'GT'}) && defined($genotype->{$m}->{'GT'})){
                $geno = $genotype->{$m}->{'GT'};
            }
            elsif (exists($genotype->{$m}->{'DS'}) && defined($genotype->{$m}->{'DS'})){
                $geno = $genotype->{$m}->{'DS'};
            }
            push @data, {$m => $geno};
        }
        $counter++;
    }

    my %result = (
        germplasmDbId=>qq|$gt->{germplasmDbId}|,
        uniqueDisplayName=>$gt->{genotypeUniquename},
        extractDbId=>qq|$gt->{stock_id}|,
        sampleDbId=>qq|$gt->{stock_id}|,
        markerprofileDbId=>qq|$gt->{markerProfileDbId}|,
        analysisMethod=>$gt->{analysisMethod},
        #encoding=>"AA,BB,AB",
        data => \@data
    );
    my $pagination;
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles detail result constructed');
}

sub markerprofiles_methods {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search({});
	my $total_count = $rs->count;
	my $rs_slice= $rs->slice($page_size*$page, $page_size*($page+1)-1);
	my @data;
	while (my $row = $rs_slice->next()) {
		push @data, {
			'analysisMethodDbId' => $row->nd_protocol_id(),
			'analysisMethod' => $row->name()
		};
	}
	my %result = (data => \@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles methods result constructed');
}

sub markerprofiles_allelematrix {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @markerprofile_ids = $inputs->{markerprofile_ids} ? @{$inputs->{markerprofile_ids}} : ();
    my @marker_ids = $inputs->{marker_ids} ? @{$inputs->{marker_ids}} : ();
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $data_format = $inputs->{format};
    my $file_path = $inputs->{file_path};
    my $uri = $inputs->{file_uri};

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
    }

    my @data_files;
    my %result;

    if ($data_format ne 'json' && $data_format ne 'tsv' && $data_format ne 'csv') {
        push @$status, { 'error' => 'Unsupported Format Given. Supported values are: json, tsv, csv' };
    }

    my $genotypes_search = CXGN::Genotype::Search->new( 
	{
	    bcs_schema=>$self->bcs_schema,
	    markerprofile_id_list=>\@markerprofile_ids,
	});

    my $total_count = $genotypes_search->init_genotype_iterator();

    #print STDERR Dumper $genotypes;

    my @data;
    my %marker_names_all;
    my @ordered_refmarkers;
#    for(my $i=0; $i<$total_count; $i++){
#       	my $genotype = $genotypes_search->get_next_genotype_info();
#        my $genotype_hash = $genotype->{selected_genotype_hash};
#        push @ordered_refmarkers, sort keys(%$genotype_hash);
#    }

    my @scores;
    foreach (my $i=0; $i<$total_count; $i++){
	my $genotype = $genotypes_search->get_next_genotype_info();
        my $genotype_hash = $genotype->{selected_genotype_hash};
	my @ordered_refmarkers = sort keys(%$genotype_hash);
        my $genotypeprop_id = $genotype->{markerProfileDbId};
        foreach my $m (@ordered_refmarkers) {
            my $score;
            if (exists($genotype_hash->{$m}->{'GT'})){
                $score = $genotype_hash->{$m}->{'GT'};
            }
            if (exists($genotype_hash->{$m}->{'DS'})){
                $score = $self->convert_dosage_to_genotype($genotype_hash->{$m}->{'DS'});
            }
            push @scores, [
                qq|$m|,
                qq|$genotypeprop_id|,
                $score
            ];
        }
    }
    #print STDERR Dumper \@scores;

    my @scores_seen;
    if (!$data_format || $data_format eq 'json' ){

        for (my $n = $page_size*$page; $n<= ($page_size*($page+1)-1); $n++) {
            if ($scores[$n]){
                push @scores_seen, $scores[$n];
            }
        }
        %result = (data=>\@scores_seen);

    } elsif ($data_format eq 'tsv' || $data_format eq 'csv' || $data_format eq 'xls') {

        my @header_row;
        push @header_row, 'markerprofileDbIds';
        foreach (@markerprofile_ids){
            push @header_row, $_;
        }

        my %markers;
        foreach (@scores){
            $markers{$_->[0]}->{$_->[1]} = $_->[2];
        }
        #print STDERR Dumper \%markers;

        my @data_out;
        push @data_out, \@header_row;
        foreach (keys %markers){
            my @data_row;
            push @data_row, $_;
            foreach my $profile_id (@markerprofile_ids) {
                push @data_row, $markers{$_}->{$profile_id};
            }
            push @data_out, \@data_row;
        }
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $file_path,
            absolute_file_uri => $inputs->{main_production_site_url}.$uri,
            format => $data_format,
            data => \@data_out
        });
        @data_files = $file_response->get_datafiles();
    }

    $total_count = scalar(@scores);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles allelematrix result constructed');
}


sub genosort {
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) {
	$a_chr = $1;
	$a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) {
	$b_chr = $1;
	$b_pos = $2;
    }

    if ($a_chr && $b_chr) {
      if ($a_chr == $b_chr) {
          return $a_pos <=> $b_pos;
      }
      return $a_chr <=> $b_chr;
    } else {
      return -1;
    }
}


sub convert_dosage_to_genotype {
    my $self = shift;
    my $dosage = shift;

    my $genotype;
    if ($dosage eq "NA") {
	return "NA";
    }
    if ($dosage == 1) {
	return "AA";
    }
    elsif ($dosage == 0) {
	return "BB";
    }
    elsif ($dosage == 2) {
	return "AB";
    }
    else {
	return "NA";
    }
}

1;
