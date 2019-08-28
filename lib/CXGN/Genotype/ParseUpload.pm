package CXGN::Genotype::ParseUpload;

use Moose;
use Data::Dumper;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

with 'MooseX::Object::Pluggable';


has 'chado_schema' => (
    is => 'ro',
    isa => 'DBIx::Class::Schema',
    required => 1,
);

has 'filename' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'filename_intertek_marker_info' => (
    is => 'ro',
    isa => 'Str|Undef',
);

has 'nd_protocol_id' => (
    is => 'ro',
    isa => 'Int|Undef',
);

has 'observation_unit_type_name' => ( #Can be accession, plot, plant, tissue_sample
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has 'organism_id' => (
    isa => 'Int',
    is => 'ro',
    required => 0,
);

has 'create_missing_observation_units_as_accessions' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
);

has 'igd_numbers_included' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
);

has 'lab_numbers_included' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
);

has 'parse_errors' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parse_errors',
    reader => 'get_parse_errors',
    predicate => 'has_parse_errors',
);

has '_parsed_data' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parsed_data',
    predicate => '_has_parsed_data',
);

sub parse {
    my $self = shift;

    if (!$self->_validate_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not validate genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    }

    if (!$self->_parse_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not parse genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    }

    if (!$self->_has_parsed_data()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nNo parsed data for genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    } else {
        return $self->_parsed_data();
    }

    my $errors = $self->get_parse_errors();
    #print STDERR "\nError parsing genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
}

sub parse_with_iterator {
    my $self = shift;

    if (!$self->_validate_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not validate genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    }

    if (!$self->_parse_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not parse genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return 1;
    }
}

sub next {
    my $self = shift;

    return $self->next_genotype();
}

#CLASS method
sub sample_name_to_observation_unit_name {
    my $sample_name = shift;
    my $include_igd_numbers = shift;
    my $include_lab_numbers = shift;
    #print STDERR Dumper [$sample_name, $include_igd_numbers, $include_lab_numbers];
    my $return;
    my $observation_unit_name;
    if ($include_igd_numbers){
        my ($observation_unit_name_with_accession_name, $igd_number) = split(/:/, $sample_name, 2);
        $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
        my @observation_unit_name_and_accession_name = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        $observation_unit_name = $observation_unit_name_and_accession_name[0];
        $return = {
            observation_unit_name => $observation_unit_name,
            igd_number => $igd_number
        };
    }
    elsif ($include_lab_numbers){
        my ($observation_unit_name_with_accession_name, $lab_number) = split(/\./, $_, 2);
        $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
        my @observation_unit_name_and_accession_name = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        $observation_unit_name = $observation_unit_name_and_accession_name[0];
        $return = {
            observation_unit_name => $observation_unit_name,
            lab_number => $lab_number
        };
    }
    else {
        my @observation_unit_name_and_accession_name = split(/\|\|\|/, $_);
        $observation_unit_name = $observation_unit_name_and_accession_name[0];
        $return = {
            observation_unit_name => $observation_unit_name
        };
    }
    if (!$observation_unit_name) {
        $return->{warning} = "No observation unit name found for $sample_name! You can ignore this warning and skip this sample in the loading.";
    }
    #print STDERR Dumper $return;
    return $return;
}

1;
