
package CXGN::List::Validate;

use Moose;

use Module::Pluggable require => 1;

sub validate {
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $list = shift;
    my $exclude_obsolete = shift || 1;

    my $data;



    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $data = $p->validate($schema, $list, $self, $exclude_obsolete);
	}
    }
    return $data;
}

1;
