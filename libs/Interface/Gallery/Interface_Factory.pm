package Homyaki::Interface::Gallery::Interface_Factory;

use strict;

use Exporter;

use base 'Homyaki::Interface::Interface_Factory';

use constant INTERFACE_MAP => {
	default => 'Homyaki::Interface::Gallery::News',
	base    => 'Homyaki::Interface::Gallery',
	data    => 'Homyaki::Interface::Gallery::Data',
	news    => 'Homyaki::Interface::Gallery::News',
	auth    => 'Homyaki::Interface::Gallery::Auth',
};

1;
