
=head1 NAME

SGN::Controller::AJAX::GenotypesVCFUpload - a REST controller class to provide the
backend for uploading genotype VCF files

=head1 DESCRIPTION

Uploading Genotype VCF

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypesVCFUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::UploadFile;
use CXGN::Genotype::ParseUpload;
use CXGN::Genotype::StoreVCFGenotypes;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Genotype::Protocol;
use File::Basename qw | basename dirname|;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_genotype_verify :  Path('/ajax/genotype/upload') : ActionClass('REST') { }
sub upload_genotype_verify_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $transpose_vcf_for_loading = 1;
    my @error_status;
    my @success_status;

    #print STDERR Dumper $c->req->params();
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this VCF genotype info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this VCF genotype info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'submitter' && $user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to upload VCF genotypes! Please contact us.' };
        $c->detach();
    }

    #archive uploaded file
    my $upload_vcf = $c->req->upload('upload_genotype_vcf_file_input');
    my $upload_transposed_vcf = $c->req->upload('upload_genotype_transposed_vcf_file_input');
    my $upload_intertek_genotypes = $c->req->upload('upload_genotype_intertek_file_input');
    my $upload_inteterk_marker_info = $c->req->upload('upload_genotype_intertek_snp_file_input');

    if (defined($upload_vcf) && defined($upload_intertek_genotypes)) {
        $c->stash->{rest} = { error => 'Do not try to upload both VCF and Intertek at the same time!' };
        $c->detach();
    }
    if (defined($upload_intertek_genotypes) && !defined($upload_inteterk_marker_info)) {
        $c->stash->{rest} = { error => 'To upload Intertek genotype data please provide both the Grid Genotypes File and the Marker Info File.' };
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $upload_original_name;
    my $upload_tempfile;
    my $subdirectory;
    my $parser_plugin;
    my $include_lab_numbers;
    if ($upload_vcf) {
        $upload_original_name = $upload_vcf->filename();
        $upload_tempfile = $upload_vcf->tempname;
        $subdirectory = "genotype_vcf_upload";
        $parser_plugin = 'VCF';

        if ($transpose_vcf_for_loading) {
            my $dir = $c->tempfiles_subdir('/genotype_data_upload_transpose_VCF');
            my $temp_file_transposed = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_upload_transpose_VCF/fileXXXX');

            open (my $Fout, ">", $temp_file_transposed) || die "Can't open file $temp_file_transposed\n";
            open (my $F, "<", $upload_tempfile) or die "Can't open file $upload_tempfile \n";
            my @outline;
            my $lastcol;
            while (<$F>) {
                if ($_ =~ m/^\##/) {
                    print $Fout $_;
                } else {
                    chomp;
                    my @line = split /\t/;
                    my $oldlastcol = $lastcol;
                    $lastcol = $#line if $#line > $lastcol;
                    for (my $i=$oldlastcol; $i < $lastcol; $i++) {
                        if ($oldlastcol) {
                            $outline[$i] = "\t" x $oldlastcol;
                        }
                    }
                    for (my $i=0; $i <=$lastcol; $i++) {
                        $outline[$i] .= "$line[$i]\t"
                    }
                }
            }
            for (my $i=0; $i <= $lastcol; $i++) {
                $outline[$i] =~ s/\s*$//g;
                print $Fout $outline[$i]."\n";
            }
            close($F);
            close($Fout);
            $upload_tempfile = $temp_file_transposed;
            $upload_original_name = basename($temp_file_transposed);
            $parser_plugin = 'transposedVCF';
        }
    }
    if ($upload_transposed_vcf) {
        $upload_original_name = $upload_transposed_vcf->filename();
        $upload_tempfile = $upload_transposed_vcf->tempname;
        $subdirectory = "genotype_transpoed_vcf_upload";
        $parser_plugin = 'transposedVCF';
    }

    my $archived_intertek_marker_info_file;
    if ($upload_intertek_genotypes) {
        $upload_original_name = $upload_intertek_genotypes->filename();
        $upload_tempfile = $upload_intertek_genotypes->tempname;
        $subdirectory = "genotype_intertek_upload";
        $parser_plugin = 'IntertekCSV';

        my $upload_inteterk_marker_info_original_name = $upload_inteterk_marker_info->filename();
        my $upload_inteterk_marker_info_tempfile = $upload_inteterk_marker_info->tempname();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_inteterk_marker_info_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_inteterk_marker_info_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        $archived_intertek_marker_info_file = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_intertek_marker_info_file);
        if (!$archived_intertek_marker_info_file) {
            push @error_status, "Could not save file $upload_inteterk_marker_info_original_name in archive.";
            return (\@success_status, \@error_status);
        } else {
            push @success_status, "File $upload_inteterk_marker_info_original_name saved in archive.";
        }
        unlink $upload_inteterk_marker_info_tempfile;
    }

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $project_id = $c->req->param('upload_genotype_project_id') || undef;
    my $protocol_id = $c->req->param('upload_genotype_protocol_id') || undef;
    my $organism_species = $c->req->param('upload_genotypes_species_name_input');
    my $protocol_description = $c->req->param('upload_genotypes_protocol_description_input');
    my $project_name = $c->req->param('upload_genotype_vcf_project_name');
    my $location_id = $c->req->param('upload_genotype_location_select');
    my $year = $c->req->param('upload_genotype_year_select');
    my $breeding_program_id = $c->req->param('upload_genotype_breeding_program_select');
    my $obs_type = $c->req->param('upload_genotype_vcf_observation_type');
    my $genotyping_facility = $c->req->param('upload_genotype_vcf_facility_select');
    my $description = $c->req->param('upload_genotype_vcf_project_description');
    my $protocol_name = $c->req->param('upload_genotype_vcf_protocol_name');
    my $contains_igd = $c->req->param('upload_genotype_vcf_include_igd_numbers');
    my $reference_genome_name = $c->req->param('upload_genotype_vcf_reference_genome_name');
    my $add_new_accessions = $c->req->param('upload_genotype_add_new_accessions');
    my $add_accessions;
    if ($add_new_accessions){
        $add_accessions = 1;
        $obs_type = 'accession';
    }
    my $include_igd_numbers;
    if ($contains_igd){
        $include_igd_numbers = 1;
    }
    my $accept_warnings_input = $c->req->param('upload_genotype_accept_warnings');
    my $accept_warnings;
    if ($accept_warnings_input){
        $accept_warnings = 1;
    }

    #if protocol_id provided, a new one will not be created
    if ($protocol_id){
        my $protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id
        });
        $organism_species = $protocol->species_name;
        $obs_type = $protocol->sample_observation_unit_type_name;
    }

    my $organism_q = "SELECT organism_id FROM organism WHERE species = ?";
    my @found_organisms;
    my $h = $schema->storage->dbh()->prepare($organism_q);
    $h->execute($organism_species);
    while (my ($organism_id) = $h->fetchrow_array()){
        push @found_organisms, $organism_id;
    }
    if (scalar(@found_organisms) == 0){
        $c->stash->{rest} = { error => 'The organism species you provided is not in the database! Please contact us.' };
        $c->detach();
    }
    if (scalar(@found_organisms) > 1){
        $c->stash->{rest} = { error => 'The organism species you provided is not unique in the database! Please contact us.' };
        $c->detach();
    }
    my $organism_id = $found_organisms[0];

    my $parser = CXGN::Genotype::ParseUpload->new({
        chado_schema => $schema,
        filename => $archived_filename_with_path,
        filename_intertek_marker_info => $archived_intertek_marker_info_file,
        observation_unit_type_name => $obs_type,
        organism_id => $organism_id,
        create_missing_observation_units_as_accessions => $add_accessions,
        igd_numbers_included => $include_igd_numbers
    });
    $parser->load_plugin($parser_plugin);

    my $dir = $c->tempfiles_subdir('/genotype_data_upload_SQL_COPY');
    my $temp_file_sql_copy = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'genotype_data_upload_SQL_COPY/fileXXXX');

    my $store_args = {
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        observation_unit_type_name=>$obs_type,
        project_id=>$project_id,
        protocol_id=>$protocol_id,
        genotyping_facility=>$genotyping_facility, #projectprop
        breeding_program_id=>$breeding_program_id, #project_rel
        project_year=>$year, #projectprop
        project_location_id=>$location_id, #ndexperiment and projectprop
        project_name=>$project_name, #project_attr
        project_description=>$description, #project_attr
        protocol_name=>$protocol_name,
        protocol_description=>$protocol_description,
        organism_id=>$organism_id,
        igd_numbers_included=>$include_igd_numbers,
        lab_numbers_included=>$include_lab_numbers,
        user_id=>$user_id,
        archived_filename=>$archived_filename_with_path,
        archived_file_type=>'genotype_vcf', #can be 'genotype_vcf' or 'genotype_dosage' to disntiguish genotyprop between old dosage only format and more info vcf format
        temp_file_sql_copy=>$temp_file_sql_copy
    };

    my $return;
    #For VCF files, memory was an issue so we parse them with an iterator
    if ($parser_plugin eq 'VCF' || $parser_plugin eq 'transposedVCF') {
        my $parser_return = $parser->parse_with_iterator();

        if ($parser->get_parse_errors()) {
            my $return_error = '';
            my $parse_errors = $parser->get_parse_errors();
            print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
            $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
            $c->detach();
        }

        my $protocol = $parser->protocol_data();
        my $observation_unit_names_all = $parser->observation_unit_names();
        $store_args->{observation_unit_uniquenames} = $observation_unit_names_all;

        if ($parser_plugin eq 'VCF') {
            $store_args->{marker_by_marker_storage} = 1;
        }

        $protocol->{'reference_genome_name'} = $reference_genome_name;
        $protocol->{'species_name'} = $organism_species;
        my $store_genotypes;
        my ($observation_unit_names, $genotype_info) = $parser->next();
        if (scalar(keys %$genotype_info) > 0) {
            #print STDERR Dumper [$observation_unit_names, $genotype_info];
            print STDERR "Parsing first genotype and extracting protocol info... \n";

            $store_args->{protocol_info} = $protocol;
            $store_args->{genotype_info} = $genotype_info;

            $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
            my $verified_errors = $store_genotypes->validate();
            # print STDERR Dumper $verified_errors;
            if (scalar(@{$verified_errors->{error_messages}}) > 0){
                my $error_string = join ', ', @{$verified_errors->{error_messages}};
                $c->stash->{rest} = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks} };
                $c->detach();
            }
            if (scalar(@{$verified_errors->{warning_messages}}) > 0){
                #print STDERR Dumper $verified_errors->{warning_messages};
                my $warning_string = join ', ', @{$verified_errors->{warning_messages}};
                if (!$accept_warnings){
                    $c->stash->{rest} = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                    $c->detach();
                }
            }

            $store_genotypes->store_metadata();
            $store_genotypes->store_identifiers();
        }

        print STDERR "Done loading first line, moving on...\n";    

        my $continue_iterate = 1;
        while ($continue_iterate == 1) {
            my ($observation_unit_names, $genotype_info) = $parser->next();
            if (scalar(keys %$genotype_info) > 0) {
                $store_genotypes->genotype_info($genotype_info);
                $store_genotypes->observation_unit_uniquenames($observation_unit_names);
                $store_genotypes->store_identifiers();
            } else {
                $continue_iterate = 0;
                last;
            }
        }
        $return = $store_genotypes->store_genotypeprop_table();
    }
    #For smaller Intertek files, memory is not usually an issue so can parse them without iterator
    elsif ($parser_plugin eq 'GridFileIntertekCSV' || $parser_plugin eq 'IntertekCSV') {
        my $parsed_data = $parser->parse();
        my $parse_errors;
        if (!$parsed_data) {
            my $return_error = '';
            if (!$parser->has_parse_errors() ){
                $return_error = "Could not get parsing errors";
                $c->stash->{rest} = {error_string => $return_error,};
            } else {
                $parse_errors = $parser->get_parse_errors();
                #print STDERR Dumper $parse_errors;
                foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                    $return_error=$return_error.$error_string."<br>";
                }
            }
            $c->stash->{rest} = {error_string => $return_error, missing_stocks => $parse_errors->{'missing_stocks'}};
            $c->detach();
        }
        #print STDERR Dumper $parsed_data;
        my $observation_unit_uniquenames = $parsed_data->{observation_unit_uniquenames};
        my $genotype_info = $parsed_data->{genotypes_info};
        my $protocol_info = $parsed_data->{protocol_info};
        $protocol_info->{'reference_genome_name'} = $reference_genome_name;
        $protocol_info->{'species_name'} = $organism_species;

        $store_args->{protocol_info} = $protocol_info;
        $store_args->{genotype_info} = $genotype_info;
        $store_args->{observation_unit_uniquenames} = $observation_unit_uniquenames;

        my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
        my $verified_errors = $store_genotypes->validate();
        if (scalar(@{$verified_errors->{error_messages}}) > 0){
            my $error_string = join ', ', @{$verified_errors->{error_messages}};
            $c->stash->{rest} = { error => "There exist errors in your file. $error_string", missing_stocks => $verified_errors->{missing_stocks} };
            $c->detach();
        }
        if (scalar(@{$verified_errors->{warning_messages}}) > 0){
            #print STDERR Dumper $verified_errors->{warning_messages};
            my $warning_string = join ', ', @{$verified_errors->{warning_messages}};
            if (!$accept_warnings){
                $c->stash->{rest} = { warning => $warning_string, previous_genotypes_exist => $verified_errors->{previous_genotypes_exist} };
                $c->detach();
            }
        }
        $store_genotypes->store_metadata();
        $store_genotypes->store_identifiers();
        $return = $store_genotypes->store_genotypeprop_table();
    }
    else {
        print STDERR "Parser plugin $parser_plugin not recognized!\n";
        $c->stash->{rest} = { error => "Parser plugin $parser_plugin not recognized!" };
        $c->detach();
    }
    $c->stash->{rest} = $return;
}

1;
