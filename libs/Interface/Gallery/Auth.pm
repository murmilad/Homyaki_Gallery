package Homyaki::Interface::Gallery::Auth;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Constants;

use Homyaki::User;

use Homyaki::Interface::Gallery;
use base 'Homyaki::Interface::Gallery';

use constant PARAMS_MAP  => {
	login    => {required => 1, name => 'Login'},
	password => {required => 1, name => 'Password'},
};

sub get_tag {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};
	my $errors = $h{errors};
	my $user   = $h{user};

	my $permissions = $user->{permissions};

	my $root = $self->SUPER::get_tag(
		params => $params,
		errors => $errors,
		header => 'Homyaki Gallery',
	);

	my $root_tag = $root->{root};
	my $body_tag = $root->{body};


	if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'guest'} @{$permissions}){

		my $form_param = $body_tag->add_form_element(
			name         => 'current_data_uri',
			type         => &INPUT_TYPE_HIDDEN,
			value        => $params->{current_data_uri},
		);

		$form_param = $body_tag->add_form_element(
			name   => 'login',
			type   => &INPUT_TYPE_TEXT,
			value  => '',
			header => 'Login',
			error  => $errors->{login},
		);

		$form_param = $body_tag->add_form_element(
			name   => 'password',
			type   => &INPUT_TYPE_PASSWD,
			value  => '',
			header => 'Password',
			error  => $errors->{password},
		);

		$form_param = $body_tag->add_submit_button(
			header => 'Login',
		);
	} else {
		my $form_param = $body_tag->add_form_element(
			name   => 'logged_in',
			type   => &INPUT_TYPE_LABEL,
			value  => 'Logged in',
		);

		my $form_param = $body_tag->add_form_element(
			name   => 'prepare_redir',
			type   => &INPUT_TYPE_LABEL,
			value  => 'Prepare to be redirected!',
		);

		my $form_param = $body_tag->add_form_element(
			name   => 'If page will not be redirected, press this link please.',
			type   => &INPUT_TYPE_LINK,
			value  => $params->{current_data_uri},
		);

		$form_param = $body_tag->add(
			type => &TAG_JS,
			body => qq{
				function redirect(){
					window.location = "$params->{current_data_uri}";
				}

				function timer(interval){
					var timeout = setTimeout("redirect();", interval);
				}

				timer(5000);
			},
		);
	}

	return {
		root => $root_tag,
		body => $body_tag,
	};
}

sub check_params {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};

	my $errors = $self->SUPER::check_params(
		params => $params,
	);

	return $errors;
}

sub is_auth {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};

	return 1;
}

sub set_auth {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};

#ERACE/
use Data::Dumper;
open LOG, ">>/home/alex/tmp/homyaki.log";
print LOG "params = " . Dumper($params);
close LOG;
#ERACE\

	my $errors = $self->check_params(
		params => $params,
	);

	my $user = undef;

	unless (scalar(keys %{$errors}) > 0){
		$user = Homyaki::User->get_user_by_login(
			login    => $params->{login},
			password => $params->{password},
		);
		unless ($user){
			$errors->{base}->{errors} = ['Wrong User/Password'];
		}
	}

	return {
		errors  => $errors,
		user    => $user,
	};
}

1;
