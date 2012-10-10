package Homyaki::Interface::Gallery::Blog;

use strict;

use Data::Dumper;
use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Gallery;
use Homyaki::HTML::Gallery::Blog;
use Homyaki::Interface::Captcha;
use Homyaki::HTML::Constants;

use Homyaki::Gallery::Image;
use Homyaki::Gallery::Blog;

use Homyaki::Logger;

use Homyaki::Interface;
use base 'Homyaki::Interface::Gallery';

use constant PARAMS_MAP  => {
	blog_user    => {name => 'Author'},
	blog_comment => {name => 'Comment'},
};

sub get_form {
	my $self = shift;
	my %h = @_;

	my $params   = $h{params};
	my $errors   = $h{errors};
	my $user     = $h{user};
	my $body_tag = $h{body_tag};

	my $root = $self->SUPER::get_form(
		user     => $user,
		params   => $params,
		errors   => $errors,
		form_id  => 'blog_form',
		body_tag => $body_tag,
	);

	my $root_tag = $root->{root};
	my $body_tag = $root->{body};

	$body_tag->{&PARAM_WIDTH} = '800';
	$body_tag->{&PARAM_FRAME} = 'hsides';

	my $permissions = $user->{permissions};

	my $form_param = $body_tag->add_form_element(
		name   => 'blog_image_id',
		type   => &INPUT_TYPE_HIDDEN,
		value  => $params->{blog_image_id},
	);



        $form_param = $body_tag->add_form_element(
                name     => "label_user",
                type     => &INPUT_TYPE_LABEL,
                value    =>  "Author",
        );

        $form_param->add_form_element(
                name     => "label_comment",
                type     => &INPUT_TYPE_LABEL,
                value    =>  "Comment",
                location => &LOCATION_RIGHT,
        );

        $form_param = $body_tag->add_form_element(
                name   => "blog_user",
                type   => &INPUT_TYPE_TEXT,
                value  => $params->{"blog_user"},
                error  => $errors->{"blog_user"},
        );

        $form_param->add_form_element(
                name     => "blog_comment",
                type     => &INPUT_TYPE_TEXTAREA,
                value    => $params->{"blog_comment"},
                error    => $errors->{"blog_comment"},
                default_value => 'You can leave a few words here...',
                location => &LOCATION_RIGHT,
                &PARAM_ROWS => 3,
                &PARAM_COLS => 70,
        );

        my $captcha_param = $form_param->add_form_element(
                location => &LOCATION_RIGHT,
                type     => &INPUT_TYPE_DIV,
        );

        my $captcha_request = Homyaki::Interface::Captcha->get_form(
                user     => $user,
                params   => $params,
                errors   => $errors,
                body_tag => $captcha_param,
        );

	$form_param->add_form_element(
		type     => &INPUT_TYPE_SUBMIT,
		value    => 'Add comment',
		name     => 'blog_submit_button',
                location => &LOCATION_RIGHT,
	);


	my $index = 0;
	foreach my $blog_comment_param (sort {
		if ($a =~ /blog_comment_(\d+)/){
			my $a_id = $1;
			if ($b =~ /blog_comment_(\d+)/) {
				my $b_id = $1;
				return $b_id <=> $a_id;
			}
		}
	} grep {$_ =~ /^blog_comment_/} keys %{$params}){
		$index++;
		$form_param = Homyaki::HTML::Gallery::Blog->add_blog_comment(
			params      => $params,
			errors      => $errors,
			name        => $blog_comment_param,
			header      => 'Comment',
			body_tag    => $body_tag,
			permissions => $permissions,
			'index'     => $index,
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
	my $permissions = $h{permissions};

	my $result = $params;

	if ($params->{image}){
		my $image = Homyaki::Gallery::Image->find_or_create({
			name => $params->{image}
		});

		$result->{blog_image_id} = $image->id;
	}

	my @blog = Homyaki::Gallery::Blog->search({
		image_id => $result->{blog_image_id}
	});

	foreach my $blog (@blog) {
		$result->{'blog_user_' . $blog->id}    = $blog->user_name || '&nbsp';
		$result->{'blog_comment_' . $blog->id} = $blog->comment || '&nbsp';
		$result->{'blog_date_' . $blog->id}    = $blog->insert_date || '&nbsp';
	}

	return $result;
}

sub set_params {
	my $self = shift;
	my %h = @_;

	my $params      = $h{params};
	my $permissions = $h{permissions};

	if ($params->{blog_submit_button}) {
		my $blog = Homyaki::Gallery::Blog->insert({
			image_id   => $params->{blog_image_id},
			user_name  => $params->{blog_user},
			comment    => $params->{blog_comment},
			ip_address => $params->{ip_address},
		});

		$blog->update();
	}
Homyaki::Logger::print_log(Dumper($permissions));
        if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}) {

                foreach my $param (grep {$_ =~ /^blog_list_delete_\d+$/} keys %{$params}) {
                        if ($params->{$param} && $param =~ /^blog_list_delete_(\d+)$/) {
                                my $blog = Homyaki::Gallery::Blog->retrieve($1);

                                $blog->delete();
                        }
                }
	}

	return {};
}

sub check_params {
	my $self = shift;
	my %h = @_;

	my $params      = $h{params};
	my $permissions = $h{permissions};

	my $errors = {};

	if ($params->{blog_submit_button}) {

	        my $captcha_errors = Homyaki::Interface::Captcha->check_params(
        	        params      => $params,
                	permissions => $permissions,
	        );

        	@{$errors}{keys %{$captcha_errors}} = values %{$captcha_errors};

		$params->{blog_comment} = ''
			if $params->{blog_comment} eq 'You can leave a few words here...';

		foreach my $param_name (keys %{$self->PARAMS_MAP}){
			if (!$params->{$param_name} || !($params->{$param_name} =~ /\w|[А-Яа-я]/)){
				$errors->{$param_name}->{param_name} = &PARAMS_MAP->{$param_name}->{name};
				$errors->{$param_name}->{errors} = ["Please enter value"];
			}
		}
	}

	return $errors;
}
1;
