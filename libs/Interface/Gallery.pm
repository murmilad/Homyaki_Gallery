package Homyaki::Interface::Gallery;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Constants;

use Homyaki::Interface;
use base 'Homyaki::Interface::Interface_Helper';

use constant INTERFACE  => 'gallery';

sub get_form {
	my $self = shift;
	my %h = @_;

	my $user     = $h{user};
	my $params   = $h{params};
	my $errors   = $h{errors};
	my $body_tag = $h{body_tag};
	my $form_id  = $h{form_id};


	my $form_body = $body_tag->add(
		type         => &TAG_TABLE,
		&PARAM_NAME  => "table_$form_id",
		&PARAM_ID    => "table_$form_id",
		&PARAM_WIDTH => '950',
	);

	return {
		root => $self,
		body => $form_body
	};
}

sub get_tag {
	my $self = shift;
	my %h = @_;

	my $user   = $h{user};
	my $params = $h{params};
	my $errors = $h{errors};
	my $header = $h{header} || 'Alexey Kosarev - Photo Gallery. Алексей Косарев - Фотоальбом.';

	my $root = $self->SUPER::get_tag(
		user   => $user,
		params => $params,
		errors => $errors,
		header => $header,
	);

	my $root_tag = $root->{root};
	my $body_tag = $root->{body};

	my $form = $body_tag->add_form(
		interface => $params->{interface},
		form_name => $params->{form},
		form_id   => 'main_form',
		form_uri  => {
			image => $params->{image},
		},
                contact_email => 'netalexinfo@hotbox.ru',
                contact_name  => 'Alexey Kosarev (Murmilad)',
	);

	my $table = $self->get_form(
		params   => $params,
		errors   => $errors,
		form_id  => 'main_form',
		body_tag => $form,
	);

	my $form_tag      = $table->{root};
	my $form_body_tag = $table->{body};

	return {
		root => $root_tag,
		body => $form_body_tag
	};
}

1;
