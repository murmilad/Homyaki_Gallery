package Homyaki::Gallery::Blog;

use DateTime;

use strict;
use base 'Homyaki::Gallery::DB';

__PACKAGE__->table('blog');
__PACKAGE__->columns(Primary   => qw/id/);
__PACKAGE__->columns(Essential => qw/image_id user_name comment insert_date ip_address/);

sub insert {
        my $class  = shift;
        my $params = shift;

	my $image_id   = $params->{image_id};
	my $user_name  = $params->{user_name};
	my $comment    = $params->{comment};
	my $ip_address = $params->{ip_address};

	my $current_date = DateTime->now();
        my $self = $class->SUPER::insert({
		comment     => $comment,
		image_id    => $image_id,
		user_name   => $user_name,
		insert_date => $current_date->ymd() . ' ' .  $current_date->hms(),
		ip_address  => $ip_address,
        });

	return $self;
}

1;
