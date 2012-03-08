package Homyaki::HTML::Gallery::Blog;

use strict;


use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::Converter qw{get_html};

use base 'Homyaki::HTML::Gallery';

use Homyaki::HTML::Constants;
use Homyaki::Interface::Captcha;

sub add_blog_comment {
	my $self = shift;
	my %h    = @_;

	my $permissions = $h{permissions};
	my $body_tag    = $h{body_tag};
	my $params      = $h{params};
	my $errors      = $h{errors};
	my $header      = $h{header};
	my $name        = $h{name};
	my $index       = $h{'index'};
	my $link        = $h{'link'};

	my $comment_id = 0;
	if ($name =~ /blog_\w+_(\d+)/){
		$comment_id = $1;
	}

        my $form_param = $body_tag->add_form_element(
                name   => "blog_data_$comment_id",
                type   => &INPUT_TYPE_LABEL,
                value  => $params->{"blog_user_$comment_id"}
			. '<br>(' . $params->{"blog_date_$comment_id"} . ')',
        );

	if ($index % 2 > 0) {
		$form_param->{parrent}->{parrent}->{&PARAM_CLASS} = 'list_1';
	} else {
		$form_param->{parrent}->{parrent}->{&PARAM_CLASS} = 'list_2';
	}

        $form_param->add_form_element(
                location => &LOCATION_RIGHT,
                name     => "blog_comment_$comment_id",
                value    => get_html($params->{"blog_comment_$comment_id"}),
                type     => &INPUT_TYPE_LABEL,
		'link'   => $link,
        );


        if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}) {

                my $button_column = $form_param->add_form_element(
                        location => &LOCATION_RIGHT,
                        type     => &INPUT_TYPE_DIV,
                );

                my $buttons = $button_column->add(
                        type         => &TAG_TABLE,
                        &PARAM_NAME  => "table_buttons_$comment_id",
                        &PARAM_ID    => "table_buttons_$comment_id",
                );

                $buttons->add_form_element(
                        name     => "blog_list_delete_$comment_id",
                        value    => "Delete",
                        type     => &INPUT_TYPE_SUBMIT,
                        &PARAM_STYLE => 'width: 5em;',
                );
        }

#        $form_param->add_form_element(
#                location => &LOCATION_RIGHT,
#                name     => "blog_comment_$comment_id",
#                value    => $params->{"blog_comment_$comment_id"},
#                type     => &INPUT_TYPE_TEXTAREA,
#                &PARAM_ROWS     => 5,
#                &PARAM_COLS     => 50,
#                &PARAM_READONLY => 'true',
#        );

	return $form_param;
}


1;
