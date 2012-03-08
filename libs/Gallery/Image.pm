package Homyaki::Gallery::Image;

use Homyaki::Gallery::Resume;
use Homyaki::Gallery::Photo_Base;

use Image::ExifTool;

use strict;
use base 'Homyaki::Gallery::DB';

__PACKAGE__->table('image');
__PACKAGE__->columns(Primary   => qw/id/);
__PACKAGE__->columns(Essential => qw/name path resume english_resume new_resume new_english_resume/);

sub find_or_create {
        my $class  = shift;
        my $params = shift;
        my $flags  = shift || {fill_imade_data => 1};

        my $self = $class->SUPER::find_or_create($params);

	if ($flags->{fill_imade_data}){
		$self->fill_image_data($params);
	}

	return $self;
}

sub get_exif_data {
	my $self = shift;

	my $exifTool  = new Image::ExifTool;
	my $ImageInfo = $exifTool->ImageInfo($self->path);

	return $ImageInfo;
}

sub fill_image_data {
	my $self = shift;
        my $params = shift;

	unless ($self->resume){
		my $resume  = Homyaki::Gallery::Resume::get_resume($params->{name});
		$self->set('resume', $resume);
		$self->update();
	}

	unless ($self->path){
		my $base_path = Homyaki::Gallery::Photo_Base::get_path($params->{name});
		$self->set('path', $base_path);
		$self->update();
	}
}
1;
