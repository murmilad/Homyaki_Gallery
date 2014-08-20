package Homyaki::Task_Manager::Task::Auto_Build_Gallery;

use strict;

use File::stat;

use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::Gallery::Print;

use Homyaki::Logger;

use Image::Magick;
use DateTime;

use Homyaki::Task_Manager::DB::Task_Type;
use Homyaki::Task_Manager;


use constant BASE_IMAGE_PATH  => '/home/alex/Share/Photo/';
use constant RESUME_FILENAME  => 'resume.txt';
use constant BASE_RESUME_PATH => &BASE_IMAGE_PATH . &RESUME_FILENAME;

use constant GALLERY_PATH    => '/home/alex/tmp/gfgallery/';
use constant PIC_PATH        => &GALLERY_PATH . 'images/big/';
use constant RESUME_PIC_PATH => &GALLERY_PATH . '/resume/';
use constant NEW_RESUME_PATH => &RESUME_PIC_PATH . &RESUME_FILENAME;

use constant IMAGES_DIFF  => 20;
use constant RESUME_DIFF  => 30;

sub start {
	my $class = shift;
	my %h = @_;
	
	my $params = $h{params};
	my $task   = $h{task};

	my $result = {};

	my $resume_diff = 0;
print &BASE_RESUME_PATH;
	open (RESUME, '<' . &BASE_RESUME_PATH);
	my $old_resume = {};
	while (my $str = <RESUME>) {
		if ($str =~ /(.*)\|(.*).\n$/){
			my $string = $2;
			my $image_name = $1;
			$string =~ s/\"/\'/g;
			$old_resume->{$image_name} .= $string;
		}
	};

	close RESUME;
	open (RESUME, '<' . &NEW_RESUME_PATH);
	my $new_resume = {};
	while (my $str = <RESUME>) {
		if ($str =~ /(.*)\|(.*).\n$/){
			my $string = $2;
			my $image_name = $1;
			$string =~ s/\"/\'/g;
			$new_resume->{$image_name} .= $string;
			if ($new_resume->{$image_name} ne $old_resume->{$image_name}){
				$resume_diff++;
			}
		}
	}
	close RESUME;

	my $base_path = &BASE_IMAGE_PATH;
	my $gallery_path = &RESUME_PIC_PATH;

	my $gallery_images = {};
	map {$gallery_images->{lc($_)} = 1} split("\n", `find $gallery_path -iname "*_w.jpg" -type f -printf "%f\\n"`);
	my $new_images = {};
	map {$new_images->{lc($_)} = 1 if !$gallery_images->{lc($_)}} split("\n", `find $base_path -iname "*_w.jpg" -type f -printf "%f\\n"`);

	my $images_diff = scalar(keys %{$new_images});

	print $resume_diff . ' ' . $images_diff; 

	if (0 && $images_diff >= &IMAGES_DIFF && $resume_diff >= &RESUME_DIFF ) {
		my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
			handler => 'Homyaki::Task_Manager::Task::Build_Gallery'
		);

		if (scalar(@task_types) > 0) {

			my $task = Homyaki::Task_Manager->create_task(
				task_type_id => $task_types[0]->id(),
				ip_address   => '127.0.0.1',
				name         => "Auto start ($images_diff new images and $resume_diff new signs)",
				params => {
				}
			);

			$params->{task_id} = $task->id();
			$params->{task_id_find} = $task->id();
		}
		
	}

	$result->{task} = {
		retry => {
			days => 1,
		},
		params => $params,
		
	};
 

	return $result;
}

start();
1;

__END__

use Homyaki::Task_Manager::DB::Task_Type;
use Homyaki::Task_Manager;
		my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
			handler => 'Homyaki::Task_Manager::Task::Print_Image'
		);

		if (scalar(@task_types) > 0) {

			my $task = Homyaki::Task_Manager->create_task(
				task_type_id => $task_types[0]->id(),
				params => {
				}
			);

		}
1;
