package Homyaki::HTML::Gallery;

use strict;


use Homyaki::Tag;
use Homyaki::HTML;
use base 'Homyaki::HTML';

use Homyaki::HTML::Constants;

sub add_resume_field {
	my $self = shift;
	my %h    = @_;

	my $permissions = $h{permissions};
	my $body_tag    = $h{body_tag};
	my $params      = $h{params};
	my $errors      = $h{errors};
	my $header      = $h{header};
	my $name        = $h{name};

	my $form_param = $body_tag->add_form_element(
                name   => $name,
                type   => &INPUT_TYPE_HIDDEN,
                value  => $params->{$name},
        );


        if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}){
		$form_param = $body_tag->add_form_element(
			name   => "label_$name",
			type   => &INPUT_TYPE_LABEL,
			header => $header,
			value  => $params->{$name},
		);

                if ($params->{"changed_$name"}){
                        $form_param = $body_tag->add_form_element(
                                name   => "label_changed_$name",
                                type   => &INPUT_TYPE_LABEL,
                                header => "New $header",
                                value  => $params->{"changed_$name"},
                                &PARAM_CLASS => 'minor'
                        );
                }


                my $hidden = (scalar(keys %{$errors}) > 0 && $params->{submit_button}) ? 0 : 1;

                unless (scalar(keys %{$errors}) > 0 && $params->{submit_button}) {
                        my $change_button = $form_param->add_form_element(
                                type     => &INPUT_TYPE_BUTTON,
                                name     => "button_change_$name",
                                value    => 'Change',
                                location => &LOCATION_RIGHT,
                                command  => qq{
					current.style.display = 'none';
                                        if (document.getElementById("row_label_changed_$name") != null){
                                                document.getElementById("row_label_changed_$name").style.display='none';
                                        }
                                        if ((document.getElementById && !document.all) || window.opera){
                                    		if (document.getElementById("row_changed_$name") != null){
                                    			document.getElementById("row_changed_$name").style.display='table-row';
                                    		}
                                        } else {
                                    		if (document.getElementById("row_changed_$name") != null){
                                            		document.getElementById("row_changed_$name").style.display='inline';
                                                }
                                        }
                                },
                        );
                }

                $form_param = $body_tag->add_form_element(
                        name   => "changed_$name",
                        type   => &INPUT_TYPE_TEXT,
                        value  => $params->{"changed_$name"} || $params->{$name},
                        header => "Change $header",
                        error  => $errors->{"changed_$name"},
                        hidden => $hidden,
                        &PARAM_SIZE => 125,
                );


	        if (ref($permissions) eq 'ARRAY' && grep {$_ eq 'writer'} @{$permissions}){

			$form_param->add_form_element(
				name       => 'submit_button',
				type       => &INPUT_TYPE_SUBMIT,
				location   => &LOCATION_RIGHT,
	                        hidden     => $hidden,
	                        value      => 'Save'
			);
	        }


        } else {
		if ($params->{$name}) {
			$form_param = $body_tag->add_form_element(
				name   => "label_$name",
				type   => &INPUT_TYPE_LABEL,
				header => $header,
				value  => $params->{$name},
			) ;
		}
        }
	return $form_param;
}


1;
