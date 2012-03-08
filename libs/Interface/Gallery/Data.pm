package Homyaki::Interface::Gallery::Data;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Gallery;
use Homyaki::HTML::Constants;

use Homyaki::Interface::Gallery::Blog;

use Homyaki::Gallery::Image;
use Homyaki::Gallery::Google_Map_Image;

use Homyaki::Interface;
use base 'Homyaki::Interface::Gallery';

use constant PARAMS_MAP  => {
	changed_comment         => {required => 0, name => 'New Comment'},
	changed_english_comment => {required => 0, name => 'New English Comment'},
};

use constant IMAGE_PATH => '/images/big/';
use constant GOOGLE_MAP_PATH => '/images/google_map/';

sub get_tag {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};
	my $errors = $h{errors};
	my $user   = $h{user};

	my $root = $self->SUPER::get_tag(
		params => $params,
		errors => $errors,
	);

	my $root_tag = $root->{root};
	my $body_tag = $root->{body};

	my $permissions = $user->{permissions};
	my $login_uri = '/engine/?interface=gallery&form=auth';

	if (check_image($params->{image})) {

	if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}){
		my $form_param = $body_tag->add_form_element(
			name   => 'current_user',
			type   => &INPUT_TYPE_LABEL,
			value  => $user->{login},
		);
	} else {
		my $form_param = $body_tag->add_form_element(
			name    => 'login',
			type    => &INPUT_TYPE_LINK,
			value   => '#',
			command => qq{
				document.getElementById('current_action').value = 'view';
				document.getElementById('main_form').action = '$login_uri';
				document.getElementById('main_form').submit();
			},
		);
	}

	my $form_body = $body_tag->add_form_element(
		name         => 'current_data_uri',
		type         => &INPUT_TYPE_HIDDEN,
		value        => $params->{current_uri},
	);

	$body_tag->add_form_element(
		name    => 'Gallery',
		type    => &INPUT_TYPE_LINK,
		value   => '/',
	);


	my $images_form = $body_tag->add_form_element(
		type   => &INPUT_TYPE_FORM,
	);

	my $form_param = $images_form->add_form_element(
		name   => 'image',
		type   => &INPUT_TYPE_HIDDEN,
		value  => $params->{image},
	);

	my $form_param = $images_form->add_form_element(
		name   => 'image_id',
		type   => &INPUT_TYPE_HIDDEN,
		value  => $params->{image_id},
	);

	$form_param = $images_form->add_form_element(
		name   => 'photo_image',
		type   => &INPUT_TYPE_IMAGE,
		value  => &IMAGE_PATH . $params->{image},
		'link' => '/',
		&PARAM_HEIGHT => 512
	);

	if (Homyaki::Gallery::Google_Map_Image::get_map_by_image(image_name => $params->{image})){
		my $link = Homyaki::Gallery::Google_Map_Image::get_link_by_image(image_name => $params->{image});
		$form_param = $form_param->add_form_element(
			name     => 'photo_image',
			type     => &INPUT_TYPE_IMAGE,
			location => &LOCATION_RIGHT,
			value    => &GOOGLE_MAP_PATH . $params->{image},
			'link'   => $link,
		);
	}

	$form_param = Homyaki::HTML::Gallery->add_resume_field(
		params      => $params,
		errors      => $errors,
		name        => 'comment',
		header      => 'Comment',
		body_tag    => $body_tag,
		permissions => $permissions,
	);

	$form_param = Homyaki::HTML::Gallery->add_resume_field(
		params      => $params,
		errors      => $errors,
		name        => 'english_comment',
		header      => 'English Comment',
		body_tag    => $body_tag,
		permissions => $permissions,
	);

	if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}){

		my $hidden = scalar(keys %{$errors}) > 0 ? 0 : 1;

	}

	my $blog_form = Homyaki::Interface::Gallery::Blog->get_form(
		user     => $user,
		params   => $params,
		errors   => $errors,
		body_tag => $body_tag->{parrent},
	);
	} else {
		$root_tag->add(
			type => &TAG_H1,
			body => 'Oops! :(  Image is not found. Sorry man.',
		);

		$root_tag->add(
			type       => &TAG_IMG,
			&PARAM_SRC => '/data/images/construction.jpg'
		);
	}

	return {
		root => $root_tag,
		body => $body_tag,
	};
}

sub get_params {
	my $self = shift;
	my %h = @_;

	my $params      = $h{params};
	my $user        = $h{user};
	my $permissions = $user->{permissions};

	my $result = $params;

	if (check_image($params->{image})) {
		my $image = Homyaki::Gallery::Image->find_or_create({
			name => $params->{image}
		});

		$result->{comment}         = $image->resume;
		$result->{changed_comment} = $image->new_resume;

		$result->{english_comment}         = $image->english_resume;
		$result->{changed_english_comment} = $image->new_english_resume;

		$result->{image_id} = $image->id;


		my $blog_data = Homyaki::Interface::Gallery::Blog->get_params(
			params      => $params,
			permissions => $permissions,
		);

		@{$result}{keys %{$blog_data}} = values %{$blog_data};
	}

	return $result;
}

sub set_params {
	my $self = shift;
	my %h = @_;

	my $params      = $h{params};
	my $user        = $h{user};
	my $permissions = $user->{permissions};

	my $result = $params;
	if ($params->{submit_button}){
		my $image = Homyaki::Gallery::Image->retrieve($params->{image_id});
		$image->set('new_resume', $params->{changed_comment});
		$image->set('new_english_resume', $params->{changed_english_comment});

		$image->update();
	}

	Homyaki::Interface::Gallery::Blog->set_params(
		params      => $params,
		permissions => $permissions,
	);

	return $result;
}

sub check_params {
	my $self = shift;
	my %h = @_;

	my $params      = $h{params};
	my $user        = $h{user};
	my $permissions = $user->{permissions};

	my $errors = {};
	if ($params->{submit_button}){
		$errors = $self->SUPER::check_params(
			params      => $params,
			permissions => $permissions,
		);
	}

	my $blog_errors = Homyaki::Interface::Gallery::Blog->check_params(
		params      => $params,
		permissions => $permissions,
	);

	@{$errors}{keys %{$blog_errors}} = values %{$blog_errors};

	return $errors;
}

sub check_image {
	my $image = shift;

	return (-f &WWW_PATH . &IMAGE_PATH . $image);
}
1;
