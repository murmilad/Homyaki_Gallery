package Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor::Factory;

use strict;

use Exporter;

use base 'Homyaki::Factory';

use constant IMAGE_PROCESSOR_MAP => {
	default                => 'Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor::Resize_For_HTML',
	resize_for_html        => 'Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor::Resize_For_HTML',
	add_watermark          => 'Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor::Add_Watermark',
	resize_for_resume      => 'Homyaki::Task_Manager::Task::Build_Gallery::Image_Processor::Resize_For_Resume',
};

sub create_processor {
        my $this = shift;

	my %h      = @_;
	my $builder_name = $h{name} || 'default';
	my $params       = $h{params};

	my $image_processor = $this->IMAGE_PROCESSOR_MAP->{$builder_name};

	$this->require_handler($image_processor);

	return $image_processor->new(
		params => $params
	);
}

1;
