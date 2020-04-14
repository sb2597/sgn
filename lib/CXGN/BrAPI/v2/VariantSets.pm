package CXGN::BrAPI::v2::VariantSets;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use List::Util qw(sum);

extends 'CXGN::BrAPI::v2::Common';



sub search {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @variantset_id = $inputs->{variantSetDbId} ? @{$inputs->{variantSetDbId}} : ();
    my @study_ids = $inputs->{studyDbId} ? @{$inputs->{studyDbId}} : ();
    my @study_names = $inputs->{studyName} ? @{$inputs->{studyName}} : ();
    my @variant_id = $inputs->{variantDbId} ? @{$inputs->{variantDbId}} : ();
    my @callset_id = $inputs->{callSetDbId} ? @{$inputs->{callSetDbId}} : ();

    if (scalar @variantset_id == 0){
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema=>$self->bcs_schema,
            trial_design_list=>['genotype_data_project']
        });
        my ($data, $total_count) = $trial_search->search(); 

        foreach (@$data){
            push @variantset_id, $_->{trial_id};
        }
    }

    my $genotype_search = CXGN::Genotype::Search->new({
            bcs_schema=>$self->bcs_schema,
            cache_root=>$c->config->{cache_file_path},
            trial_list=>\@variantset_id,
            genotypeprop_hash_select=>['DS'],
            protocolprop_top_key_select=>[],
            protocolprop_marker_hash_select=>[],
    });

    my %genotypingDataProjects;

    $genotype_search->init_genotype_iterator();

    while (my ($count, $gt) = $genotype_search->get_next_genotype_info) {

        my $project_id = $gt->{genotypingDataProjectDbId};

        if( ! $genotypingDataProjects{$project_id}{'analysisIds'} {$gt->{analysisMethodDbId}}) {
            my @analysis;
            push @analysis, {
                analysisDbId=> qq|$gt->{analysisMethodDbId}|, #protocolid
                analysisName=> $gt->{analysisMethod},
                created=>undef,
                description=>undef,
                software=>undef,
                type=>undef,
                updated=>undef,
            };
            
            push( @{ $genotypingDataProjects { $project_id  }{'analysisIds'} {$gt->{analysisMethodDbId}} }, 1 );
            push( @{ $genotypingDataProjects { $project_id  }{'markerCount'}}, $gt->{resultCount} );
            push( @{ $genotypingDataProjects { $project_id  }{'analysis'}  }, @analysis);
        }

        push( @{ $genotypingDataProjects { $project_id  } {'genotypes'} }, $gt->{genotypeDbId});
        $genotypingDataProjects { $project_id  } {'name'}  = $gt->{genotypingDataProjectName};
      
    }

    my @data;
    my $counter=0;
    
    foreach my $project (keys %genotypingDataProjects){

        my @availableFormats; 
 
        push @availableFormats,{
            dataFormat => "json",
            fileFormat => "json",
            fileURL => undef,
        };
        push @data, {
            additionalInfo=>{},
            analysis =>$genotypingDataProjects{$project} {'analysis'},
            availableFormats => \@availableFormats,
            callSetCount => scalar @{$genotypingDataProjects{$project}{'genotypes'}},
            referenceSetDbId => undef, #    from protocol           
            studyDbId => $project,          
            variantCount => _sum($genotypingDataProjects{$project}{'markerCount'}),
            variantSetDbId => qq|$project|,
            variantSetName => $genotypingDataProjects{$project} {'name'},
        };
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub detail { #returns triple, should be just one
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};

    my $genotype_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        trial_list=>[$variantset_id],
        genotypeprop_hash_select=>['DS'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
        # offset=>$page_size*$page,
        # limit=>$page_size
    });
    my $file_handle = $genotype_search->get_cached_file_search_json($c, 1); #Metadata only returned
    my @data;

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;
    my $callset_counter = 0;

    my %genotypingDataProjects;

    $genotype_search->init_genotype_iterator();

    while (my ($count, $gt) = $genotype_search->get_next_genotype_info) {

        my $project_id = $gt->{genotypingDataProjectDbId};

        if( ! $genotypingDataProjects{$project_id}{'analysisIds'} {$gt->{analysisMethodDbId}}) {
            my @analysis;
            push @analysis, {
                analysisDbId=> qq|$gt->{analysisMethodDbId}|, #protocolid
                analysisName=> $gt->{analysisMethod},
                created=>undef,
                description=>undef,
                software=>undef,
                type=>undef,
                updated=>undef,
            };
            
            push( @{ $genotypingDataProjects { $project_id  }{'analysisIds'} {$gt->{analysisMethodDbId}} }, 1 );
            push( @{ $genotypingDataProjects { $project_id  }{'markerCount'}}, $gt->{resultCount} );
            push( @{ $genotypingDataProjects { $project_id  }{'analysis'}  }, @analysis);
        }

        push( @{ $genotypingDataProjects { $project_id  } {'genotypes'} }, $gt->{genotypeDbId});
        $genotypingDataProjects { $project_id  } {'name'}  = $gt->{genotypingDataProjectName};
      
    }

   
    foreach my $project (keys %genotypingDataProjects){

        my @availableFormats; 
 
        push @availableFormats,{
            dataFormat => "json",
            fileFormat => "json",
            fileURL => undef,
        };
        push @data, {
            additionalInfo=>{},
            analysis =>$genotypingDataProjects{$project} {'analysis'},
            availableFormats => \@availableFormats,
            callSetCount => scalar @{$genotypingDataProjects{$project}{'genotypes'}},
            referenceSetDbId => undef, #    from protocol           
            studyDbId => $project,          
            variantCount => _sum($genotypingDataProjects{$project}{'markerCount'}),
            variantSetDbId => qq|$project|,
            variantSetName => $genotypingDataProjects{$project} {'name'},
        };
        $counter++;
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@data, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub callsets {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};
    my @callset_id = $inputs->{callSetDbId} ? @{$inputs->{callSetDbId}} : ();
    my @callset_name = $inputs->{callSetName} ? @{$inputs->{callSetName}} : ();

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        trial_list=>[$variantset_id],
        markerprofile_id_list=>\@callset_id,
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
    my $callset_counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;

    while( <$fh> ) {
        if ($counter >= $start_index && $counter <= $end_index) {
            my $gt = decode_json $_;
            my @analysis;
            my @additionalInfo;
            my @availableFormats;

            push @additionalInfo,{
            };
            push @data, {
                additionalInfo=>\@additionalInfo,
                callSetDbId=> qq|$gt->{markerProfileDbId}|,
                callSetName=> qq|$gt->{markerProfileDbName}|,
                created=>undef,
                sampleDbId=>qq|$gt->{stock_id}|,
                studyDbId=> $gt->{genotypingDataProjectDbId}, 
                updated=>undef,
                variantSetIds => [$gt->{genotypingDataProjectDbId}],
            };
        }
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub calls {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $file_path = $inputs->{file_path};
    my $uri = $inputs->{file_uri};

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
    }

    my @data_files;
    my %result;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        trial_list=>[$variantset_id],
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
    my $marker_objects = decode_json $header_line;

    my @data;

    while (my $gt_line = <$fh>) {
        my $gt = decode_json $gt_line;
        my $genotype = $gt->{selected_genotype_hash};
        my @ordered_refmarkers = sort keys(%$genotype);
        my $genotypeprop_id = $gt->{markerProfileDbId};

        foreach my $m (@ordered_refmarkers) {
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
                push @data, {
                    additionalInfo=>undef,
                    variantName=>qq|$m|,
                    variantDbId=>qq|$m|,
                    callSetDbId=>qq|$genotypeprop_id|,
                    callSetName=>qq|$genotypeprop_id|,
                    genotype=>{values=>$geno},
                    genotype_likelihood=>undef,
                    phaseSet=>undef,
                };
            }
            $counter++;
        }
    }

    %result = ( data=>\@data,
                expandHomozygotes=>undef, 
                sepPhased=>undef, 
                sepUnphased=>undef, 
                unknownString=>undef);



    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub _sum{
    my $array = shift;
    my $sum=0;

    foreach my $num (@$array){
        $sum += $num;
    }
    return $sum;
}

1;