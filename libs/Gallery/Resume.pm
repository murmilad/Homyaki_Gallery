package Homyaki::Gallery::Resume;

use strict;

use constant RESUME_PATH => '/home/alex/Share/Photo/resume.txt';

sub get_resume {
	my $image_name = shift;

	open (RESUME, '<' . &RESUME_PATH);

	my $resume = {};
	while (my $str = <RESUME>) {
		if ($str =~ /(.*)\|(.*).\n$/){
			my $string = $2;
			my $image_name = $1;
			$string =~ s/"/'/g;
			$resume->{$image_name} .= $string;
		}
	};
	close RESUME;

	return $resume->{$image_name};
}

1;