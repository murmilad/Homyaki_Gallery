package Homyaki::Processor::DigiCam_GPS_Marker;

use strict;

use Data::Dumper;
use Image::ExifTool;
use DateTime;
use POSIX qw(floor);
use DBI;
use Geo::Converter::dms2dd qw { dms2dd };
use Geo::Coordinates::DecimalDegrees;

use Homyaki::Logger;

use base 'Homyaki::Processor';

sub dd2dms {
	my $dd = shift;

	my ($degrees, $minutes, $seconds, $sign) = decimal2dms($dd);
	print "$degrees, $minutes, $seconds, $sign\n";
	return sprintf('%d deg %d\' %.4f', $degrees,$minutes,$seconds);
}

sub set_gps_tags {
	my $image_path   = shift;
	my $exifTool     = shift;
	my $gps_tags     = shift;

	my $updated = 0;
	my $ImageInfo = $exifTool->ImageInfo($image_path);
	$exifTool->ExtractInfo($image_path, $ImageInfo);

	if (
	    (!$ImageInfo->{GPSLatitude} || !(sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLatitude}})) >= (sprintf("%.4f", $gps_tags->{latitudeNumber}) - 0.0001) && sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLatitude}})) <= (sprintf("%.4f", $gps_tags->{latitudeNumber}) + 0.0001)))
	    ||(!$ImageInfo->{GPSLongitude} || !(sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLongitude}})) >= (sprintf("%.4f", $gps_tags->{longitudeNumber}) - 0.0001) && sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLongitude}})) <= (sprintf("%.4f", $gps_tags->{longitudeNumber}) + 0.0001)))
	) {
		Homyaki::Logger::print_log( 'lat ' . sprintf("%.4f", $gps_tags->{latitudeNumber}) . '=' . sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLatitude}}))) if $ImageInfo->{GPSLatitude};
		Homyaki::Logger::print_log( 'info $image_path ' . $ImageInfo->{GPSLatitude});
		$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gps_tags->{latitudeNumber})),'GPS');
		if ($gps_tags->{latitudeNumber} > 0) {
			$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
		} else {
			$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
		}
		$updated = 1;

		Homyaki::Logger::print_log( 'DigiCam_GPS_Marker: long ' . sprintf("%.4f", $gps_tags->{longitudeNumber}) . '=' . sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLongitude}}))) if $ImageInfo->{GPSLongitude};
		Homyaki::Logger::print_log( 'DigiCam_GPS_Marker: info $image_path ' . $ImageInfo->{GPSLongitude});
		$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gps_tags->{longitudeNumber})),'GPS');
		if ($gps_tags->{longitudeNumber} > 0) {
			$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
		} else {
			$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
		}
	}
	if ($updated) {
		my $create_date = $ImageInfo->{CreateDate} =~ /\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/ ? $ImageInfo->{CreateDate} : '1989:01:01 12:00:00';
		Homyaki::Logger::print_log( "DigiCam_GPS_Marker: $create_date" ); 
		$exifTool->SetNewValue('GPSDateTime',  $create_date ,'XMP');
		$exifTool->SetNewValue('GPSAltitude', $gps_tags->{altitude}, 'GPS');
		if ($gps_tags->{altitude} > 0){
			$exifTool->SetNewValue('GPSAltitudeRef', 'Above Sea Level', 'GPS');
		} else {
			$exifTool->SetNewValue('GPSAltitudeRef', 'Below Sea Level', 'GPS');
		}

		# Write map datum to WGS84.
		$exifTool->SetNewValue('GPSMapDatum','WGS-84','GPS');

		# Write destination bearing.
		$exifTool->SetNewValue('GPSImgDirection',0,'GPS');
		$exifTool->SetNewValue('GPSImgDirectionRef','T','GPS');

		$exifTool->WriteInfo($image_path);
		Homyaki::Logger::print_log( "DigiCam_GPS_Marker: $image_path updated");
	}
}


sub get_digi_gps_tags{
	my $images_path   = shift;
	my $dbh = DBI->connect('DBI:mysql:digicam', 'digicam', '215473')
		|| die "Could not connect to database: $DBI::errstr";

	my $sth = $dbh->prepare(q{
		select concat(a.relativePath,concat('/',i.name)) as path, latitudeNumber, longitudeNumber, altitude
		    from  ImagePositions ip 
			inner join Images i on ip.imageid = i.id
			inner join Albums a on i.album = a.id
	});

	$sth->execute();
	my $result = $sth->fetchall_arrayref();
	$images_path =~ s/\/$//;

	my $tags = {};
	if (ref($result) eq 'ARRAY' && scalar($result) > 0){
		map {$tags->{$images_path . $_->[0]} = {latitudeNumber => $_->[1], longitudeNumber => $_->[2], altitude => $_->[3]}} @{$result};
	}

	return $tags;
}


sub pre_process {
	my $self   = shift;
	my %h = @_;
	my $params = $h{params};

	my $images_path   = $params->{images_path};

	my $digi_gpstags = get_digi_gps_tags($images_path);
	my $exif_tool    = new Image::ExifTool;

	$self->{digi_gpstags} = $digi_gpstags;
	$self->{exif_tool}    = $exif_tool;
}

sub process {
	my $self = shift;
	my %h = @_;

	my $params       = $h{params};
	my $image_path   = $params->{image_path};
	my $exept_nef    = $params->{exept_nef};

	my $digi_gpstags = $self->{digi_gpstags};
	my $exif_tool    = $self->{exif_tool};

	if ($digi_gpstags->{$image_path}){
		set_gps_tags($image_path, $exif_tool, $digi_gpstags->{$image_path});

		unless ($exept_nef){
			my $nef_path = $image_path;
			$nef_path =~ s/\.jpg$/\.NEF/i;
			$nef_path =~ s/acoll_\d{7}_//;
			if  (-f $nef_path) {
				set_gps_tags($nef_path, $exif_tool, $digi_gpstags->{$image_path});
			}
		}
	}

}

1;