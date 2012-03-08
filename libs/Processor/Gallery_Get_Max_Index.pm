package Homyaki::Processor::Gallery_Get_Max_Index;

use strict;

use Homyaki::Logger;

use base 'Homyaki::Processor';

sub pre_process {
	my $self = shift;

	my %h = @_;
	my $params    = $h{params};

	$self->{'index'} = 0;
}

sub process {
	my $self = shift;

	my %h = @_;
	my $params    = $h{params};

	if ($params->{image_path} =~ /acoll_(\d{7})_[\w \\\(\)\'&]+\.jpg$/i){
		$self->{'index'} = $1 if $self->{'index'} < $1;
	}
}

1;
