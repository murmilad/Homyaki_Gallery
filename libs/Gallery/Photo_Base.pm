package Homyaki::Gallery::Photo_Base;

use strict;

use File::Find;

use constant PHOTO_BASE_PATH => '/home/alex/Share/Photo/';

sub get_path {
	my $image_name = shift;

	my $file_list = [];
	find(
		{
			wanted => sub {
				my $image_path = $File::Find::name;
				if (-f $image_path && $image_path =~ /\/$image_name$/i){
					push(@{$file_list}, $image_path);
				}
			},
			follow => 1
		},
		&PHOTO_BASE_PATH
	);

	return scalar(@{$file_list}) > 0 ? $file_list->[0] : '';
}

1;