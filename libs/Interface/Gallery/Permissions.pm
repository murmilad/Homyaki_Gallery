package Homyaki::Interface::Gallery::Permissions;

use strict;

use Homyaki::User;
use Homyaki::Interface::Permissions;
use base 'Homyaki::Interface::Permissions';

sub get_user{
	my $self = shift;
	my %h = @_;

	my $user_id = $h{user_id};

	my $user = Homyaki::User->retrieve($user_id);

	unless ($user) {
		$user->{permissions} = [];
		push(@{$user->{permissions}}, 'guest');
	}

	return $user;
}

1;