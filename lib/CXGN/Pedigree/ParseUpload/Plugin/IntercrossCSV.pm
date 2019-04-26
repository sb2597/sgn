package CXGN::Pedigree::ParseUpload::Plugin::IntercrossCSV;

use Moose::Role;
use JSON;
use Data::Dumper;
use Text::CSV;
use CXGN::List::Validate;
use SGN::Model::Cvterm;


sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $num_cols = scalar(@columns);
    if ($num_cols != 9){
        push @error_messages, 'Header row must contain: "cross_id","male","female","person","timestamp","location","cross_type","cross_count","cross_name"';
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ( $columns[0] ne "cross_id" &&
        $columns[1] ne "male" &&
        $columns[2] ne "female" &&
        $columns[3] ne "person" &&
        $columns[4] ne "timestamp" &&
        $columns[5] ne "location" &&
        $columns[6] ne "cross_type" &&
        $columns[7] ne "cross_count" &&
        $columns[8] ne "cross_name")
        {
            push @error_messages, 'Header row must contain: "cross_id","male","female","person","timestamp","location","cross_type","cross_count","cross_name"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

    my %seen_uniquename;
    my %seen_accessions;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            self->_set_parse_errors(\%errors);
            return;
        }

        if (!$columns[0] || $columns[0] eq ''){
            push @error_messages, 'The first column must contain a cross_id on row: '.$row;
        }

        if ($columns[1]){
            $columns[1] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accessions{$columns[1]}++;
        }

        if (!$columns[2] || $columns[2] eq ''){
            push @error_messages, 'The third column must contain a female on row: '.$row;
        } else {
            $columns[2] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accessions{$columns[2]}++;
        }

        if (!$columns[3] || $columns[3] eq ''){
            push @error_messages, 'The fourth column must contain a person on row: '.$row;
        }

        if (!$columns[4] || $columns[4] eq ''){
            push @error_messages, 'The fifth column must contain a timestamp on row: '.$row;
        }

        if (!$columns[6] || $columns[6] eq ''){
            push @error_messages, 'The seventh column must contain a cross_type on row: '.$row;
        }

        if (!$columns[8] || $columns[8] eq ''){
            push @error_messages, 'The ninth column must contain a cross_name on row: '.$row;
        } else {
            $columns[0] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $columns[8] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            my $cross_uniquename = join(':', $columns[0],$columns[8]);
            $seen_uniquename{$cross_uniquename}++;
        }
    }

    my @crosses = keys %seen_uniquename;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@crosses }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cross name already exists in database: ".$r->uniquename;
    }

    my @accessions = keys %seen_accessions;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my %parsed_result;
    my @error_messages;
    my %errors;
    my @pedigrees;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        $columns[0] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $columns[8] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        my $cross_uniquename = join(':', $columns[0],$columns[8]);

        my $cross_type = $columns[6];
        my $female_parent = $columns[2];
        my $male_parent = $columns[1];

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_uniquename, cross_type=>$cross_type);
        if ($female_parent) {
            my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_parent($female_parent_individual);
        }
        if ($male_parent) {
            my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
            $pedigree->set_male_parent($male_parent_individual);
        }

        push @pedigrees, $pedigree;

    }

    $parsed_result{'crosses'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}
