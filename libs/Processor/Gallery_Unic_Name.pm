package Homyaki::Processor::Gallery_Unic_Name;

use strict;

use Homyaki::Logger;
use Homyaki::Gallery::Group_Processing;

use base 'Homyaki::Processor';

sub clean_path {
	my $old_path = shift;

	$old_path =~ s/ /\\ /g;
	$old_path =~ s/\(/\\\(/g;
	$old_path =~ s/\)/\\\)/g;
	$old_path =~ s/'/\\'/g;
	$old_path =~ s/&/\\&/g;

	return $old_path;
}

sub pre_process {
	my $self = shift;

	my %h = @_;
	my $params    = $h{params};

	$self->{'index'} = 0;

	my $processor = Homyaki::Gallery::Group_Processing->process(
		handler => 'Homyaki::Processor::Gallery_Get_Max_Index',
		params  => {
			images_path => $params->{images_path},
		},
	);

	$self->{'index'} = $processor->{'index'};
}

sub process {
	my $self = shift;

	my %h = @_;
	my $params    = $h{params};

	my $file_path = $params->{image_path};

	if ($file_path =~ /^(.*)acoll_\d{7}_([\w \\\(\)\'&]+)\.jpg$/i){
		my $nef_path = $1 . $2 . '.NEF';
		if (-f $nef_path) {
			my $nef_new_path = $file_path;
			$nef_new_path =~ s/\.jpg/.NEF/i;
			$nef_path      = clean_path($nef_path);
			$nef_new_path  = clean_path($nef_new_path);
			Homyaki::Logger::print_log("Gallery_Unic_Name: Change name from $nef_path to $nef_new_path");
			`sudo mv $nef_path $nef_new_path`;
		} 

	} elsif ($file_path =~ /^(.*)\.jpg$/i) {
		$self->{'index'} ++;
		my $print_index = sprintf('%07d', $self->{'index'});
		my $new_path = $file_path;
		my $nef_path = $file_path;
		$new_path =~ s/\/([\w \\\(\)\'&]+\.jpg)$/\/acoll_${print_index}_$1/i;

		$file_path = clean_path($file_path);
		$new_path  = clean_path($new_path);

		my $nef_old_path = $nef_path;
		$nef_old_path =~ s/\.jpg$/.NEF/i;
		if (-f $nef_old_path) {
			my $nef_new_path = $new_path;
			$nef_new_path =~ s/\.jpg$/.NEF/i;
			Homyaki::Logger::print_log("Gallery_Unic_Name: Change name from $nef_old_path to $nef_new_path");
			`sudo mv $nef_old_path $nef_new_path`;
		}
		Homyaki::Logger::print_log("Gallery_Unic_Name: Change name from $file_path to $new_path");
		`sudo mv $file_path $new_path`;
	}

}

1;
