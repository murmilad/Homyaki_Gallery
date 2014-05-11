package Homyaki::Interface::Task_Manager::Build_Gallery;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Constants;

use Homyaki::Logger;

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task;
use FreezeThaw qw(freeze thaw);
use Homyaki::Task_Manager::DB::Task_Type;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::Interface::Task_Manager;
use base 'Homyaki::Interface::Task_Manager';

use constant TASK_HANDLER => 'Homyaki::Task_Manager::Task::Build_Gallery';
use constant RESUME_PATH  => '/Gallery/';
use constant PARAMS_MAP  => {
	name         => {name => 'Name'             , required => 1, type  => &INPUT_TYPE_TEXT},
};

sub get_resume_usb_path {
	opendir(DIR , '/media/' );
	my ($path) = grep { (-d '/media/' . $_ .  &RESUME_PATH) } readdir(DIR);
	closedir(DIR);

	return '/media/' . $path;
}

sub get_form {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};
	my $errors = $h{errors};
	my $user   = $h{user};

	my $body_tag = $self->SUPER::get_form(%h);

	my $form = $body_tag->{body};

	if (
		(-d get_resume_usb_path())
		&& ref($user->{permissions}) eq 'ARRAY' && grep {$_ eq 'writer'} @{$user->{permissions}}
	) {
		$form->add_form_element(
			type   => &INPUT_TYPE_TEXT,
			name   => 'name',
			header => 'Name of task',
			value  => $params->{name},
			error  => $errors->{name},
		);

		$form->add_form_element(
			type   => &INPUT_TYPE_DIV,
			name   => 'result',
        	        value  => $params->{result},
		);
	
		$form->add_form_element(
			type   => &INPUT_TYPE_SUBMIT,
			name   => 'submit_button',
		);
	}

	return {
		root => $self,
		body => $form,
	};
}

sub get_helper {
	my $self = shift;
	my %h = @_;

	my $body   = $h{body};
	my $params = $h{params};
	my $errors = $h{errors};

	$body->add_form_element(
		type   => &INPUT_TYPE_LABEL,
		value  => 'This task builds http://akosarev.info gallery.',
	);

	return $body;
}


sub set_params {
        my $this = shift;
        my %h = @_;

        my $params      = $h{params};
        my $user        = $h{user};

	my $result = $params;
        if (
		$params->{submit_button} 
		&& (-d get_resume_usb_path())
		&& ref($user->{permissions}) eq 'ARRAY' && grep {$_ eq 'writer'} @{$user->{permissions}}
	){

		my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
			handler => &TASK_HANDLER
		);

		if (scalar(@task_types) > 0) {

			my $task = Homyaki::Task_Manager->create_task(
				task_type_id => $task_types[0]->id(),
				ip_address   => $params->{ip_address},
				name         => $params->{name},
				params => {
				}
			);

			$params->{task_id} = $task->id();
			$params->{task_id_find} = $task->id();
		}
	}

	my $parrent_result = $this->SUPER::set_params(
		params      => $params,
		user        => $user,
	);

        return $result;
}


sub get_params {
        my $self = shift;
        my %h = @_;

        my $params      = $h{params};
        my $user        = $h{user};
        my $result      = $params;

	if ($params->{task_id}){
		my $task = Homyaki::Task_Manager::DB::Task->retrieve($params->{task_id});

		if ($task){
			my ($task_params) = thaw($task->params());
			$result->{result} = "<br><br>Task started:<br>" . join("<br>", map {"$_ = $params->{$_}"} keys %{$task_params});
		}


	}

	$params->{task_handler} = &TASK_HANDLER;

	my $parrent_result = $self->SUPER::get_params(
		params      => $params,
		user        => $user,
	);

	@{$result}{keys %{$parrent_result}} = values %{$parrent_result};

        return $result;
}

sub check_params {
        my $self = shift;
        my %h = @_;

        my $params      = $h{params};
        my $user        = $h{user};

        my $errors = {};
	my $parrent_errors = {};
	my $parrent_errors = $self->SUPER::check_params(
		params      => $params,
		user        => $user,
	);

       @{$errors}{keys %{$parrent_errors}} = values %{$parrent_errors};

        return $errors;
}

1;
