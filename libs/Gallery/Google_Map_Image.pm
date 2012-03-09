package Homyaki::Gallery::Google_Map_Image;

use strict;

use Homyaki::Gallery::Image;
use Geo::Converter::dms2dd qw { dms2dd };
use Homyaki::Logger;

use constant GOOGLE_MAPS_PATH => $ENV{DOCUMENT_ROOT} . '/images/google_map/';

sub get_map_by_image{
	my %h = @_;
	my $image_name = $h{image_name};


	unless (-f &GOOGLE_MAPS_PATH . $image_name){
		my $image = Homyaki::Gallery::Image->find_or_create({
			name => $image_name
		});

		my $exif_data = $image->get_exif_data();

#		Homyaki::Logger::print_log("Google_Map_Image: $exif_data->{GPSLatitude}  $exif_data->{GPSLongitude}");

		if ($exif_data->{GPSLatitude}
			&& $exif_data->{GPSLongitude}
#			&& $exif_data->{GPSAltitude}
		) {
			get_gps_google_image(
				GPSLatitude => $exif_data->{GPSLatitude},
				GPSLongitude => $exif_data->{GPSLongitude},
				GPSAltitude => $exif_data->{GPSAltitude},
				image_name => $image_name,
			);
		}
	}

	return (-f &GOOGLE_MAPS_PATH . $image_name);
}

sub get_link_by_image{
	my %h = @_;
	my $image_name = $h{image_name};

	my $image = Homyaki::Gallery::Image->find_or_create({
		name => $image_name
	});

	my $exif_data = $image->get_exif_data();
	my $link      = '';


#	Homyaki::Logger::print_log("Google_Map_Image: $exif_data->{GPSLatitude}  $exif_data->{GPSLongitude}");

	if ($exif_data->{GPSLatitude}
		&& $exif_data->{GPSLongitude}
#		&& $exif_data->{GPSAltitude}
	) {
		$link = get_gps_google_link(
			GPSLatitude => $exif_data->{GPSLatitude},
			GPSLongitude => $exif_data->{GPSLongitude},
			GPSAltitude => $exif_data->{GPSAltitude},
		);
	}

	return $link;
}

sub get_gps_google_link {
        my %h = @_;

        my $GPSLatitude  = $h{GPSLatitude};
        my $GPSLongitude = $h{GPSLongitude};
        my $GPSAltitude  = $h{GPSAltitude};

        my $google_link = '';

        if (
		$GPSLatitude 
		&& $GPSLongitude 
#		&& $GPSAltitude
	) {
                my $GPSLatitude_dd  = dms2dd({value => $GPSLatitude});
                my $GPSLongitude_dd = dms2dd({value => $GPSLongitude});

                $google_link = qq{http://maps.google.com/maps?ll=$GPSLatitude_dd,$GPSLongitude_dd&z=$GPSAltitude&t=h&hl=en&ie=UTF8&q=$GPSLatitude_dd,$GPSLongitude_dd};
        }

        return $google_link;
}

sub get_gps_google_image {
        my %h = @_;

        my $GPSLatitude  = $h{GPSLatitude};
        my $GPSLongitude = $h{GPSLongitude};
        my $GPSAltitude  = $h{GPSAltitude};
        my $image_name   = $h{image_name};

	my $path        = &GOOGLE_MAPS_PATH;
        my $google_link = '';

        if (
		$GPSLatitude 
		&& $GPSLongitude 
#		&& $GPSAltitude
	) {
                my $GPSLatitude_dd  = dms2dd({value => $GPSLatitude});
                my $GPSLongitude_dd = dms2dd({value => $GPSLongitude});

		$google_link = qq{http://maps.google.com/staticmap?center=$GPSLatitude_dd,$GPSLongitude_dd&zoom=14&size=256x512&maptype=mobile&markers=$GPSLatitude_dd,$GPSLongitude_dd,greeng&key=MAPS_API_KEY};

		`cd $path; wget -O $image_name '$google_link'; echo  '$google_link' > last_link.url;`;
        }

        return 1;
}

1;
