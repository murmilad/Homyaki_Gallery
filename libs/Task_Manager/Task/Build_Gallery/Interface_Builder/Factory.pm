package Homyaki::Task_Manager::Task::Build_Gallery::Interface_Builder::Factory;

use strict;

use Exporter;

use base 'Homyaki::Factory';

use constant INTERFACE_BUILDER_MAP => {
	default     => 'Homyaki::Task_Manager::Task::Build_Gallery::Interface_Builder::DF_Gallery',
	df_gallery  => 'Homyaki::Task_Manager::Task::Build_Gallery::Interface_Builder::DF_Gallery',
	html_albums => 'Homyaki::Task_Manager::Task::Build_Gallery::Interface_Builder::HTML_Albums',
};

sub create_builder {
        my $this = shift;

	my %h      = @_;
	my $builder_name = $h{name} || 'default';
	my $params       = $h{params};
	my $interface_builder = $this->INTERFACE_BUILDER_MAP->{$builder_name};

	$this->require_handler($interface_builder);

	return $interface_builder;
}

1;
