package Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor;

use strict;

sub new {
	my $this = shift;
	my %h = @_;

	my $params = $h{params};

	my $self = {};

	my $class = ref($this) || $this;
	bless $self, $class;

	map {$self->{$_} = $params->{$_}} keys %{$params}
		if ref($params) eq 'HASH';

	return $self;
}

1;
