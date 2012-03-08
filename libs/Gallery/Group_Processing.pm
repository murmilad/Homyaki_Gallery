package Homyaki::Gallery::Group_Processing;

use strict;

use File::Find;

use Homyaki::Processor::DigiCam_GPS_Marker;
use Homyaki::Processor::Gallery_Get_Max_Index;
use Homyaki::Processor::Gallery_Unic_Name;


sub get_images_list {
	my $source_path = shift;
	my $mask        = shift;

	print $source_path . "\n";

	my $file_list = [];
	find(
		{
			wanted => sub {
				my $image_path = $File::Find::name;
				if (-f $image_path && $image_path =~ /$mask/i) {
					push(@{$file_list}, $image_path);
				}
			},
			follow => 1
		},
		$source_path
	);

	return $file_list;
}

sub process {
	my $self = shift;
	my %h    = @_;

	my $handler = $h{handler};
	my $params  = $h{params};

	my $mask = '\.jpg$|\.nef$';
	if ($params->{build_gallery}){
		$mask = '\_w.jpg$';
	}

	my $images_list = get_images_list($params->{images_path}, '\.jpg$|\.nef$');

	my $processor = $handler->new();

	$processor->pre_process(
		params => $params,
	);

	foreach my $image_path (@{$images_list}) {
		$params->{image_path} = $image_path;

		$processor->process(
			params => $params,
		);
	}

	return $processor;
}

1;
