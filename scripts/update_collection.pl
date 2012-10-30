#!/usr/bin/perl

use XML::Simple qw(XMLin);
use Data::Dumper;
use Image::ExifTool;
use File::Find;
use Imager;
use DateTime;
use POSIX qw(floor);
use DBI;
use Geo::Converter::dms2dd qw { dms2dd };
use Geo::Coordinates::DecimalDegrees;

use constant EXIF_GPS_DATA_MAP => {
		GPSLatitude         => 'GPS',
		GPSLatitudeRef      => 'GPS',
		GPSLongitude        => 'GPS',
		GPSLongitudeRef     => 'GPS',
		GPSAltitude         => 'GPS',
		GPSAltitudeRef      => 'GPS',
		GPSMapDatum         => 'GPS',
		GPSImgDirection     => 'GPS',
		GPSImgDirectionRef  => 'GPS',
		GPSDateTime         => 'XMP'
};

sub dd2dms {
	my $dd = shift;
	# print "$dd\n";
#	my $minutes = ($dd - floor($dd)) * 60.0;
#	my $seconds = ($minutes - floor($minutes)) * 60.0;
#	$minutes = floor($minutes);
#	my $degrees = floor($dd);
	my ($degrees, $minutes, $seconds, $sign) = decimal2dms($dd);
	print "$degrees, $minutes, $seconds, $sign\n";
	return sprintf(qq(%d deg %d' %.4f"), $degrees,$minutes,$seconds);
}
sub dt_to_DateTimeOriginal($)
{
	my ($dt) = @_;
	return undef unless defined $dt;

	my $DateTimeOriginal = $dt;
	$DateTimeOriginal =~ s/T/ /;
	$DateTimeOriginal =~ s/Z$//;
	$DateTimeOriginal =~ s/-/:/g;
	return $DateTimeOriginal;
}

sub create_time_gps_hash {
	my $gpx_path = shift;

	my $str_gpx;
	my $time_gps_hash = {};

	if (open (HOSTS, $gpx_path)){
		while (my $str = <HOSTS>) {
			$str_gpx .= $str;
		};
		close HOSTS;

		my $content_xml;
		eval {$content_xml = XMLin($str_gpx)};	
		if ($@){
			print $@;
		}
		if ($content_xml){
			my $time = DateTime->new(
			year   => 1964,
			month  => 10,
			day    => 16,
			hour   => 16,
			minute => 12,
			second => 47,
			);
			my $tracks = [];
			if ($content_xml->{trk}->{trkseg}) {
				$content_xml->{trk}->{'the_first'}->{trkseg} = $content_xml->{trk}->{trkseg};
			}
			foreach my $track (keys %{$content_xml->{trk}}){
				foreach my $track_point (keys %{$content_xml->{trk}->{$track}->{trkseg}->{trkpt}}){
					my $time_str  = $content_xml->{trk}->{$track}->{trkseg}->{trkpt}->{$track_point}->{'time'};
					my $ele_str   = $content_xml->{trk}->{$track}->{trkseg}->{trkpt}->{$track_point}->{'ele'};
					my $lat_str   = $content_xml->{trk}->{$track}->{trkseg}->{trkpt}->{$track_point}->{'lat'};
					my $lon_str   = $content_xml->{trk}->{$track}->{trkseg}->{trkpt}->{$track_point}->{'lon'};
					my $speed_str = $content_xml->{trk}->{$track}->{trkseg}->{trkpt}->{$track_point}->{'speed'};

					#2010-05-07T16:29:02Z
					if ($time_str =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z/) {
						$time->set(
							year   => $1,
							month  => $2,
							day    => $3,
							hour   => $4,
							minute => $5,
							second => $6,
						)->add( hours => 3 );

						$time_gps_hash->{$time->epoch()} = {
							ele   => $ele_str,
							lat   => $lat_str,
							lon   => $lon_str,
							speed => $speed_str,
							dt    => $time_str
						};
					}
				}
			}
			my $prev_time_epoch = 0;
			foreach my $time_epoch (sort {$a <=> $b} keys %{$time_gps_hash}){
				$prev_time_epoch = $time_epoch-1 unless $prev_time_epoch;

				if ($time_epoch != $prev_time_epoch + 1) {
					my $ele_str   = $time_gps_hash->{$prev_time_epoch}->{ele};
					my $lat_str   = $time_gps_hash->{$prev_time_epoch}->{lat};
					my $lon_str   = $time_gps_hash->{$prev_time_epoch}->{lon};
					my $speed_str = $time_gps_hash->{$prev_time_epoch}->{speed};
					my $dt_str    = $time_gps_hash->{$prev_time_epoch}->{dt};
					my $big_range_time_epoch = 0;
					if ($time_epoch - $prev_time_epoch > 86400*2){
						$big_range_time_epoch = $time_epoch;
						$time_epoch = $prev_time_epoch + 86400*2;
					}
					for (1; $time_epoch != $prev_time_epoch; $prev_time_epoch++){
						$time_gps_hash->{$prev_time_epoch}->{ele}   = $ele_str;
						$time_gps_hash->{$prev_time_epoch}->{lat}   = $lat_str;
						$time_gps_hash->{$prev_time_epoch}->{lon}   = $lon_str;
						$time_gps_hash->{$prev_time_epoch}->{speed} = $speed_str;
						$time_gps_hash->{$prev_time_epoch}->{dt}    = $dt_str;
					}
					if ($big_range_time_epoch) {
						$time_epoch = $big_range_time_epoch;
					}
					$prev_time_epoch = $time_epoch;

				}
			}
		}
	} else {
		print $@;
	}

	return $time_gps_hash;
}

sub copy_gps_tags {
	my $image_path   = shift;
	my $exifTool     = shift;
	my $nefExifTool  = shift;

	my $nef_path = $image_path;
	$nef_path =~ s/\.jpg$/\.NEF/i;
	$nef_path =~ s/acoll_\d{7}_//;

	if (-f $nef_path){
		my $ImageInfo = $exifTool->ImageInfo($image_path);
		$exifTool->ExtractInfo($image_path, $ImageInfo);

		my $nefInfo = $nefExifTool->ImageInfo($nef_path);
		$nefExifTool->ExtractInfo($nef_path, $nefImageInfo);
	
		my $updated = 0;
		foreach my $exif_param (keys %{&EXIF_GPS_DATA_MAP}) {
			if ($ImageInfo->{$exif_param}) {
				$updated = 1;
				print qq{write $nef_path EXIF $exif_param:} . $ImageInfo->{$exif_param} . qq{\n};
				$nefExifTool->SetNewValue(
					$exif_param,
					$ImageInfo->{$exif_param},
					&EXIF_GPS_DATA_MAP->{$exif_param}
				);
			}
		}
	
		if ($updated) {
			$nefExifTool->WriteInfo($nef_path);
		}
		
	}
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
		print 'lat ' . sprintf("%.4f", $gps_tags->{latitudeNumber}) . '=' . sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLatitude}})) . "\n" if $ImageInfo->{GPSLatitude};
		print 'info $image_path ' . $ImageInfo->{GPSLatitude}  . "\n";
		$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gps_tags->{latitudeNumber})),'GPS');
		if ($gps_tags->{latitudeNumber} > 0) {
			$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
		} else {
			$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
		}
		$updated = 1;

		print 'long ' . sprintf("%.4f", $gps_tags->{longitudeNumber}) . '=' . sprintf("%.4f",dms2dd({value => $ImageInfo->{GPSLongitude}})) . "\n" if $ImageInfo->{GPSLongitude};
		print 'info $image_path ' . $ImageInfo->{GPSLongitude}  . "\n";
		$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gps_tags->{longitudeNumber})),'GPS');
		if ($gps_tags->{longitudeNumber} > 0) {
			$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
		} else {
			$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
		}
	}
	if ($updated) {
		my $create_date = $ImageInfo->{CreateDate} =~ /\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/ ? $ImageInfo->{CreateDate} : '1989:01:01 12:00:00';
		print $create_date ; 
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
		print "$image_path updated\n";
	}
}

sub set_gps_tag_to_jpeg {
	my $gpx_data   = shift;
	my $image_path = shift;
	my $exifTool   = shift;

	if ($gpx_data && scalar(keys %{$gpx_data}) > 0) {

		my $ImageInfo = $exifTool->ImageInfo($image_path);
		$exifTool->ExtractInfo($image_path, $ImageInfo);
		
#		print Dumper($ImageInfo);

		my $img_date = $ImageInfo->{DateTimeOriginal};
		if ($img_date =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/) {
			my $time = DateTime->new(
				year   => $1,
				month  => $2,
				day    => $3,
				hour   => $4,
				minute => $5,
				second => $6,
			);

			my $gpx_image_data = $gpx_data->{$time->epoch()};

			if ($gpx_image_data) {
				print Dumper($gpx_image_data);

print $image_path  . " GPSLatitude: " . $ImageInfo->{GPSLatitude} . "\n";
				if (exists($ImageInfo->{GPSLatitude})){
					$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gpx_image_data->{lat})),'GPS');
					if ($gpx_image_data->{lat} > 0) {
						$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
					} else {
						$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
					}
				} else {
					$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gpx_image_data->{lat})),'GPS');
					if ($gpx_image_data->{lat} > 0) {
						$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
					} else {
						$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
					}
				}
print $image_path  . " GPSLongitude: " . $ImageInfo->{GPSLongitude} . "\n";
				if (exists($ImageInfo->{GPSLongitude})){
					$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gpx_image_data->{lon})),'GPS');
					if ($gpx_image_data->{lon} > 0) {
						$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
					} else {
						$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
					}
				} else {
					$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gpx_image_data->{lon})),'GPS');
					if ($gpx_image_data->{lon} > 0) {
						$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
					} else {
						$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
					}
				}
				$exifTool->SetNewValue('GPSDateTime', dt_to_DateTimeOriginal($gpx_image_data->{dt}) ,'XMP');
				$exifTool->SetNewValue('GPSAltitude', $gpx_image_data->{ele}, 'GPS');
				if ($gpx_image_data->{ele} > 0){
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
				print "Updated $image_path\n";
			} else {
				print "There are no GPX data for $image_path\n";
			}
		}
	}
}

sub get_images_list {
	my $source_path = shift;
	my $mask        = shift;

	print $source_path . "\n";

	my $file_list = [];
	find(
		{
			wanted => sub {
				my $image_path = $File::Find::name;
				if (-f $image_path && $image_path =~ /$mask/i) {
					push(@{$file_list}, $image_path);
				}
			},
			follow => 1
		},
		$source_path
	);

	return $file_list;
}

sub get_tag_data {
	my $tags     = shift;
	my $tag_name = shift;

	return unless $tags;

	foreach (@{$tags}){
		return $_->[1] if $_->[0] eq $tag_name
	}
}

sub update_images{
	my $gpx_data_path = shift;
	my $images_path   = shift;
	my $gpx_data    = create_time_gps_hash($gpx_data_path);
	my $images_list = get_images_list($images_path, '\.jpg$|\.nef$');
	my $exifTool    = new Image::ExifTool;

	foreach my $image_path (@{$images_list}) {
		print "begin $image_path\n";
		set_gps_tag_to_jpeg($gpx_data, $image_path, $exifTool);
	}
}

sub update_exif_gps_data {
	my $images_path   = shift;

	my $images_list = get_images_list($images_path, '\.jpg$');
	my $exifTool    = new Image::ExifTool;
	my $nefExifTool = new Image::ExifTool;

	foreach my $image_path (@{$images_list}) {
		copy_gps_tags($image_path, $exifTool, $nefExifTool);
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

sub copy_exif_data_from_digikam{
	my $images_path   = shift;
	my $command       = shift;

	my $regexp = '';
	if ($command eq 'w') {
		$regexp = '_w\.jpg$'
	} else {
		$regexp = '\.jpg$'
	}

	my $digi_gpstags = get_digi_gps_tags($images_path);
#	print Dumper($digi_gpstags);
	my $images_list = get_images_list($images_path, $regexp);
	my $images_hash = {};
	map {$images_hash->{$_} = 1} @{$images_list};

	my $exifTool    = new Image::ExifTool;

	foreach my $image_path (sort keys %{$digi_gpstags}){
		if ($images_hash->{$image_path}){
			set_gps_tags($image_path,$exifTool,$digi_gpstags->{$image_path});

			if ($command ne 'w'){
				my $nef_path = $image_path;
				$nef_path =~ s/\.jpg$/\.NEF/i;
				$nef_path =~ s/acoll_\d{7}_//;
				if  (-f $nef_path) {
					set_gps_tags($nef_path,$exifTool,$digi_gpstags->{$image_path});
				}
			}

		}
	}
#	print Dumper($images_list);
}

sub set_exif_data{
	my $images_path   = '/home/alex/Share/Photo';
	my $regexp        = '_w\.jpg$';

	my $images_list = get_images_list($images_path, $regexp);

	my $exifTool    = new Image::ExifTool;

	foreach my $image_path (@{$images_list}){
		my $image_path_web = $image_path;
		$image_path_web =~ s/.+\/([^\/]+)$/$1/;
		$image_path_web = "/var/www/akosarev.info/htdocs/images/big/$image_path_web";
#		print "$image_path_web\n";
		if (-f $image_path && -f $image_path_web){
			$exifTool->WriteInfo($image_path, $image_path_web);
			print "write = $image_path, $image_path_web\n";
		}
	}
#	print Dumper($images_list);
}

my $command     = $ARGV[0];

if ($command eq '-g'){

	my $gpx_path    = $ARGV[1];
	my $images_path = $ARGV[2];

	update_images($gpx_path, $images_path);
} elsif ($command eq '-u'){
	
	my $images_path = $ARGV[1];

	update_exif_gps_data($images_path);
} elsif ($command eq '-digigps') {
	my $images_path = $ARGV[1];
	copy_exif_data_from_digikam($images_path, $ARGV[2]);
} elsif ($command eq '-set-exif-gallery') {
	set_exif_data();
}

