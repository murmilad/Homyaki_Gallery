package Homyaki::Interface::Gallery::News;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Gallery;
use Homyaki::HTML::Gallery::Blog;
use Homyaki::HTML::Constants;

use Homyaki::Gallery::Image;
use Homyaki::Gallery::Blog;

use Homyaki::Interface;
use base 'Homyaki::Interface::Gallery';

use constant PARAMS_MAP  => {
};

use constant IMAGE_THUMB_PATH => '/images/thumbs/';

sub get_form {
	my $self = shift;
	my %h = @_;

	my $params   = $h{params};
	my $errors   = $h{errors};
	my $user     = $h{user};
	my $body_tag = $h{body_tag};

	my $root = $self->SUPER::get_form(
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
		if ($blog_comment_param =~ /blog_comment_(\d+)/){
			my $comment_id = $1;

			my $link = '/engine/?interface=gallery&form=data&image=' . $params->{"blog_image_$comment_id"};

			#todo make uneversal news
			$link = 'http://akosarev.info/engine/?interface=&form=geo_maps'
				if $params->{"blog_image_id_$comment_id"} == 1;

			my $form_param = $body_tag->add_form_element(
				name   => "blog_image_$comment_id",
				type   => &INPUT_TYPE_IMAGE,
				value  => &IMAGE_THUMB_PATH . $params->{"blog_image_$comment_id"},
				'link' => $link,
			);

			$form_param = Homyaki::HTML::Gallery::Blog->add_blog_comment(
				params      => $params,
				errors      => $errors,
				name        => $blog_comment_param,
				header      => 'Comment',
				body_tag    => $body_tag,
				permissions => $permissions,
				'index'     => $index,
				'link'      => $link,
			);

#			$form_param = $form_param->add_form_element(
#				name   => "blog_image_$comment_id",
#				type   => &INPUT_TYPE_IMAGE,
#				value  => &IMAGE_THUMB_PATH . $params->{"blog_image_$comment_id"},
#				location => &LOCATION_RIGHT,
#				&PARAM_HEIGHT => 512
#			);
		}
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

	my @blog = Homyaki::Gallery::Blog->retrieve_all();

	foreach my $blog (@blog) {
		my $image = Homyaki::Gallery::Image->retrieve($blog->image_id);

		$result->{'blog_user_' . $blog->id}    = $blog->user_name || '&nbsp';
		$result->{'blog_comment_' . $blog->id} = $blog->comment || '&nbsp';
		$result->{'blog_date_' . $blog->id}    = $blog->insert_date || '&nbsp';
		$result->{'blog_image_' . $blog->id}   = $image->name || '' if $image;
		#todo make uneversal news
		$result->{'blog_image_id_' .  $blog->id}   = $image->id || '' if $image;
	}

	return $result;
}


1;
