package Homyaki::Task_Manager::Task::Gallery_Update;

use strict;

use DateTime;
use Storable qw(freeze thaw);
use Data::Dumper;
use XML::Code;
use Net::FTP;
use List::Util qw[min max];
use Imager;

use Homyaki::Gallery::Image;
use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;

#use Homyaki::Gallery::Sitemap;
use Homyaki::Gallery::Group_Processing;
use Geo::Converter::dms2dd qw { dms2dd };

use Homyaki::Sender;
use Homyaki::Logger;

use Homyaki::Apache_Log;

use constant ORIENTATIONS => {
	6 => 90,
	8 => 270
};


use constant SITE_URL      => 'media.homyaki.info';
use constant SITE_LOGIN    => 'alex';
use constant SITE_PASSWORD => '458973';



use constant RESUME_PATH     => '/media/MEIZU M8/Gallery/';

use constant GALLERY_PATH    => '/home/alex/tmp/gfgallery/';
use constant RESUME_PIC_PATH => &GALLERY_PATH . '/resume/';
use constant THUMB_PATH      => &GALLERY_PATH . 'images/thumbs/';
use constant PIC_PATH        => &GALLERY_PATH . 'images/big/';
use constant XML_PATH        => &GALLERY_PATH . 'gallery.xml';
use constant OBJ_PATH        => &GALLERY_PATH . 'gallery.obj';

use constant THUMB_FTP_PATH => '/images/thumbs/';
use constant PIC_FTP_PATH   => '/images/big/';

use constant VIA_SYN_CE      => 0;
use constant VIA_RSYNC       => 1;

use constant LOCAL_APACHE         => 1;
use constant HTTP_LOG_PATH        => '/var/log/apache2/';
use constant HTTP_LOG_BACKUP_PATH => '/var/log/apache2/backup/';

use constant BASE_IMAGE_PATH  => '/home/alex/Share/Photo/';
use constant RESUME_FILENAME  => 'resume.txt';
use constant BASE_RESUME_PATH => &BASE_IMAGE_PATH . &RESUME_FILENAME;

use constant TITLE         => 'Pics on: akosarev.info';
use constant UPDATE        => 1;
use constant UPLOAD        => 1;
use constant POINT_NEW_PIC => 0;
use constant RESUME_THUMBS => 1;
use constant SIGNED_AS_NEW => 1;

use constant WATERMARK_PATH       => &BASE_IMAGE_PATH . 'sign.bmp';

sub get_album_name{
	my $dir_name = shift;

	my @splitted_name = split('/', $dir_name);
	my $name = pop @splitted_name;

	$name =~ s/^\w+_//;
	$name =~ s/-/ /g;

	return $name;
}

sub copy_resume_to_base {

	my $base_path = &BASE_IMAGE_PATH;
	$base_path =~ s/ /\\ /g;

	my $resume_file = &RESUME_FILENAME;
	$resume_file =~ s/ /\\ /g;

	my $resume_path = &RESUME_PATH  . '/' . &RESUME_FILENAME;
	$resume_path =~ s/ /\\ /g;

	my $error;
	Homyaki::Logger::print_log( "Gallery_Update: cp -f $base_path/$resume_file $base_path/${resume_file}.bak 2>&1; cd $base_path 2>&1; cp $resume_path 2>&1");

	if (&VIA_SYN_CE) {
		$error = `cp -f $base_path/$resume_file $base_path/${resume_file}.bak 2>&1; cd $base_path 2>&1; pcp $resume_path 2>&1`;
	} else {
		$error = `cp -f $base_path/$resume_file $base_path/${resume_file}.bak 2>&1; cd $base_path 2>&1; cp $resume_path . 2>&1`;
	}

	if ($error !~ /File copy of \d+ bytes took|File copy took less than one second!/) {
		Homyaki::Logger::print_log( "Gallery_Update: Error: $error");
		return 0;
	} else {
		return 1;
	}

}

sub get_files_count{
	my $dir_name = shift;

	my @files = `find $dir_name -name '*_w.*' -printf '%f\n'`;

	return scalar(@files);
}


sub add_xml_string {
	my $xml    = shift;
	my $string = shift;

	my $xml_string       = new XML::Code ('string');
	$xml_string->{id}    = $string;
	$xml_string->{value} = ucfirst($string);
	$xml->add_child($xml_string);
}

sub add_xml_text {
	my $xml  = shift;
	my $name = shift;
	my $text = shift;

	my $xml_value = new XML::Code ($name);
	$xml_value->set_text($text);
	$xml->add_child($xml_value);
}

sub add_xml_config {
	my $xml = shift;

	my $config = new XML::Code ('config');

	add_xml_text($config, 'title'                   , "Hamsters Photos");
	add_xml_text($config, 'thumbnail_dir'           , "images/thumbs/");
	add_xml_text($config, 'image_dir'               , "images/big/");
	add_xml_text($config, 'slideshow_interval'      , "8");
	add_xml_text($config, 'pause_slideshow'         , "true");
	add_xml_text($config, 'rss_scale_images'        , "true");
	add_xml_text($config, 'background_music'        , "gallery1.mp3");
	add_xml_text($config, 'background_music_volume' , "50");
	add_xml_text($config, 'link_images'             , "true");
	add_xml_text($config, 'disable_printscreen'     , "");

	$xml->add_child($config);
}

sub get_watermark_image{
	my $watermark_image;

	if (-f &WATERMARK_PATH){
		$watermark_image = Imager->new();
		unless ($watermark_image->open(file => &WATERMARK_PATH)) {
			print STDERR &WATERMARK_PATH . " - ",$watermark_image->errstr(),"\n";
			Homyaki::Logger::print_log("Gallery_Update: Get Watermark: Error: (" . &WATERMARK_PATH . ") ". $watermark_image->errstr());
		}
	}

	return $watermark_image;
}

sub update_list {
	my @files = @_;
	my @result;

	for my $file_path (@files){
		$file_path =~ s/\n//;
		if (!(-f &PIC_PATH . $file_path)) {
			push (@result, $file_path);
		} else {
			my $img = Imager->new();
			if ($img->open( file => &PIC_PATH . $file_path )){
				my $w  = $img->getwidth();
				my $h  = $img->getheight();
				if (min($w,$h) < 800){
					push (@result, $file_path);
				}
			}
                                       
		}
	}

	return @result;
}


sub upload_file {
	my $source_path = shift;
	my $dest_path   = shift;
	my $ftp         = shift;
	my $index       = 1;
	
	if ($dest_path && $dest_path ne '/') {
#		$ftp->delete($dest_path)
#			if $ftp->size($dest_path);
		$ftp->put($source_path, $dest_path)
			or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot put $source_path to $dest_path) " . $ftp->message);
	} else {
		$ftp->put($source_path)
			or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot put $source_path to $dest_path) " . $ftp->message);
	}
#	while (!$ftp->put($source_path, $dest_path) && $index < 10) {
#	    $ftp->quit();

#		`mount /dev/sdb1 /mnt/usb/`;

#	    $ftp = Net::FTP->new($web_path, Debug => 0)
#			or die "Cannot connect to some.host.name: $@";
	
#	    $ftp->login($web_login, $web_password)
#			or die "Cannot login ", $ftp->message;

#		$ftp->binary()
#			or die "Cannot set binary mode ", $ftp->message;

#		print $ftp->message . "\n try# $index\n" if $ftp->message;
#		$index++;
#	}
}

sub upload_files{
	my %h = @_;
	my @up_files = @{$h{up_files}};
	my $task     = $h{task};
	

	my $up_index = 0;

	my $error = '';
	if ($#up_files > -1){

		my $ftp = Net::FTP->new(&SITE_URL, Debug => 0)
			or $error = "Cannot connect to some.host.name: $@";
	
		unless($error){
			$ftp->login(&SITE_LOGIN, &SITE_PASSWORD)
				or $error = "Cannot login ", $ftp->message;
		}

		unless($error){
			$ftp->binary()
				or $error = "Cannot set binary mode ", $ftp->message;
		}

		unless($error){
			foreach my $file_name (@up_files) {

				upload_file(&THUMB_PATH . "/${file_name}", &THUMB_FTP_PATH . "/${file_name}", $ftp);

				upload_file(&PIC_PATH . "/${file_name}", &PIC_FTP_PATH . "/${file_name}", $ftp);

				$up_index++;
			
				my $percent = $up_index * 100 / ($#up_files+1);
	                        $task->set('progress', "uploading: $percent");
        	                $task->update();
	
				print "uploading: " . sprintf('%d', $percent) . "% uploaded for current dir\n";
				Homyaki::Logger::print_log("Gallery_Update: uploading: " . sprintf('%d', $percent) . "% uploaded for current dir");
			}
		}

		if ($error){
			 Homyaki::Logger::print_log("Gallery_Update: Error: (Upload files) $error");
		}
	    	$ftp->quit
			if $ftp;
	}
}

sub set_resume_thumb {
	my $file_path = shift;
	my $picture   = shift;

	my $image_path   = &BASE_IMAGE_PATH;
	my $gallery_path = &GALLERY_PATH;

	$file_path =~ s/$gallery_path//;

	if ($file_path =~ /([\w \\(\)'&-]+)\/([\w-]+)\/(acoll_\d{7}_[\w \\\(\)'&]+\.jpg)$/i){
		unless (-d "$gallery_path/resume"){
			`mkdir $gallery_path/resume`
		}

		unless (-d "$gallery_path/resume/$1"){
			`mkdir $gallery_path/resume/$1`
		}

		unless (-d "$gallery_path/resume/$1/$2"){
			`mkdir $gallery_path/resume/$1/$2`
		}


		unless ($picture->write(file=>"$gallery_path/resume/$1/$2/$3")) {
			Homyaki::Logger::print_log("Gallery_Update: set_resume_thumb Error: $gallery_path/resume/$1/$2/$3 - " . $picture->errstr());
			print STDERR "$gallery_path/resume/$1/$2/$3 - ",$picture->errstr(),"\n";
			next;
		}
	}
}

sub put_watermark {
	my $img             = shift;
	my $watermark_image = shift;

	my $w  = $img->getwidth();
	my $h  = $img->getheight();

	my $pic = $img->filter(
		type    => "watermark",
		tx      => $w - $watermark_image->getwidth(),
		ty      => $h - $watermark_image->getheight(),
		wmark   => $watermark_image,
		pixdiff => 20
	) or die $img->errstr;

	return $img;
}

sub change_size {
	my $img  = shift;
	my $size = shift;

	my $w  = $img->getwidth();
	my $h  = $img->getheight();
	my $s;
	my $s  = $size / (($w < $h) ? $w : $h);
	$s = 1 if $s > 1;
	my $sw = $w * $s;
	my $sh = $h * $s;

	Homyaki::Logger::print_log("Gallery_Update: change_size Scalefactor: $s");
	print "\tScalefactor: $s\n\n";

	my $pic = $img->scale(scalefactor => $s);

	return $pic;
}

sub rotate {
	my $img = shift;

	my @tags = $img->tags();
	my $orientation = get_tag_data(\@tags, 'exif_orientation');
	my $grad = &ORIENTATIONS->{$orientation};

	my $pic;

	if ($grad){
		Homyaki::Logger::print_log("Gallery_Update: rotate: Rotate $grad");
		print "Rotate $grad\n";
		$pic = $img->rotate(right => $grad);
	} else {
		$pic = $img;
	}

	return $pic
}

sub get_tag_data {
	my $tags     = shift;
	my $tag_name = shift;

	return unless $tags;

	foreach (@{$tags}){
		return $_->[1] if $_->[0] eq $tag_name
	}
}

sub get_new_name {
	my $old_name  = shift;
	my $directory = shift;

	my $index = 0;
	my $text_index;
	my $new_name = $old_name;

	while (-f "$directory/$new_name"){
		$index++;
		$new_name =~ s/(\.)/_$index$1/ if $index;
	} 

	return $new_name;
}

sub load_images{
	my %h = @_;
	

	my $resume     = $h{resume};
	my $directory  = $h{directory};
	my $album_name = $h{album_name};
	my $image_data = $h{image_data};
	my $progress   = $h{progress};
	my $task       = $h{task};

	opendir( DIR, "$directory" ) || die qq{Cant open dir $directory $!};
	my @images = sort grep { /_w.jpg|_w.JPG/i } readdir(DIR);
	closedir(DIR);

	if (scalar(@images) == 0){
		Homyaki::Logger::print_log("Gallery_Update: The dir you specified ($directory) is empty or has no jpg\'s,\nexiting now.");
		print "The dir you specified ($directory) is empty or has no jpg\'s,\nexiting now.\n";
		return;
	}

	my @up_images;
	if (&UPDATE) {
		@up_images = update_list(@images);

		if ($#up_images == 0){
			Homyaki::Logger::print_log("Gallery_Update: The dir you specified ($directory) is empty or has no jpg\'s,\nexiting now.");
			print "The dir you specified ($directory) is empty or has no a new jpg\'s,\nexiting now.\n";
		}
	} else {
		@up_images = @images;
	}

	my @result;
	my @new_result;
        my $watermark_image = get_watermark_image();


	foreach my $image (@images){

		my $new_name;
		if (&UPDATE) {
			$new_name = $image;
		} else {
			$new_name = get_new_name($image, &PIC_PATH);
		}

		my $old = "$directory/$image";
		my $new = &THUMB_PATH . "$new_name";
		my $pic = &PIC_PATH . "$new_name";

		my $img;

		if ($resume->{"$new_name"}){# || $image_data->{$new_name}){

			my $exifTool  = new Image::ExifTool;
			my $ImageInfo = $exifTool->ImageInfo($old);
			$exifTool->ExtractInfo($old, $ImageInfo);
			$image_data->{$new_name}->{GPSLatitude}  = $ImageInfo->{GPSLatitude};
			$image_data->{$new_name}->{GPSLongitude} = $ImageInfo->{GPSLongitude};
			$image_data->{$new_name}->{GPSAltitude}  = $ImageInfo->{GPSAltitude};

			$image_data->{$new_name}->{GPSGoogleLink} = get_gps_google_link(
				GPSLatitude  => $ImageInfo->{GPSLatitude},
				GPSLongitude => $ImageInfo->{GPSLongitude},
				GPSAltitude  => $ImageInfo->{GPSAltitude}
			);

			my $google_link = '/engine/?interface=gallery&form=data&image=' . $new_name;#$image_data->{$new_name}->{GPSGoogleLink};
			my $new_image = new XML::Code ('image');
			$new_image->{title} = $album_name;
			
			my $new_flag;
			if ($image_data->{$new_name}->{resume} ne $resume->{"$new_name"}) {
				$image_data->{$new_name}->{resume} = $resume->{"$new_name"};
				if ($new_image->{resume} ne $new_name){
					push(@new_result, $new_image);
				} else {
					$new_flag = 1;
				}
			}

			$new_image->{thumbnail}   = $new_name;
			$new_image->{'link'}      = $google_link if $google_link;
			$new_image->{image}       = $new_name;
			$new_image->set_text ($resume->{"$new_name"} ? $resume->{"$new_name"} : "$new_name");

			my $image = Homyaki::Gallery::Image->find_or_create({
				name => $new_name
			},{fill_imade_data => 0});

			$image->set('resume', $resume->{"$new_name"});
			$image->set('path', $old);

			$image->update();

			if ($image_data->{$new_name}->{date} && !(grep {$_ eq $image} @up_images)){
				$new_image->{date} = $image_data->{$new_name}->{date};
			} else {
				$img = Imager->new();
				unless ($img->open(file=>$old)) {
					`mount /dev/sdb1 /mnt/usb/`;
					unless ($img->open(file=>$old)) {
						Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($old)" . $img->errstr());
						print STDERR "$old - ",$img->errstr(),"\n";
						next;
					}
				}  
	
#					$img = rotate_as_tag($img);
	
				my @tags = $img->tags();
	
				my $img_date = get_tag_data(\@tags, 'exif_date_time');
	
				$new_image->{date} = $img_date;
	
				$image_data->{$new_name}->{date} = $img_date;
			}
			push(@result, $new_image) unless $new_flag;

		} else {
			if  (!$image_data->{$new_name}->{date} || (grep {$_ eq $image} @up_images)){

				$img = Imager->new();
				unless ($img->open(file=>$old)) {
					`mount /dev/sdb1 /mnt/usb/`;
					unless ($img->open(file=>$old)) {
						Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($old)" . $img->errstr());
						print STDERR "$old - ",$img->errstr(),"\n";
						next;
					}
				}  
			}

		}

			if (grep {$_ eq $image} @up_images) {

				unless ($img) {
					$img = Imager->new();
					unless ($img->open(file=>$old)) {
                                                Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($old)" . $img->errstr());
                                                print STDERR "$old - ",$img->errstr(),"\n";
                                                next;
                                        }
				}
				$img = rotate($img);
				Homyaki::Logger::print_log("Gallery_Update: load_images: Change $pic size:");
				print "Change $pic size:\n";

				my $thumb = change_size($img, 64);
	
				unless ($thumb->write(file=>$new)) {
					Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($new)" . $img->errstr());
					print STDERR "$new - ",$img->errstr(),"\n";
					next;
				}
	
				my $fullpic = change_size($img, 800);

				my $backup_pic = $pic;
				$backup_pic =~ s/\/([^\/]*)\/([^\/]*)$/\/${1}.back\/$2/;
				unless ($fullpic->write(file=>$backup_pic)) {
					Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($backup_pic)" . $img->errstr());
					print STDERR "$backup_pic - ",$img->errstr(),"\n";
					next;
				}

				if ($watermark_image){
					$fullpic = put_watermark($fullpic, $watermark_image);
				}
	
				unless ($fullpic->write(file=>$pic)) {
					Homyaki::Logger::print_log("Gallery_Update: load_images: Error: ($pic)" . $img->errstr());
					print STDERR "$pic - ",$img->errstr(),"\n";
					next;
				}

#				my $percent = $index * 100 / $count;
#				print sprintf('%d', $percent) . "% finished\n";

				if (&RESUME_THUMBS) {
					my $resum_pic = change_size($img, 320);
		
					set_resume_thumb("$directory/$image", $resum_pic);
				}

#				push(@new_result, $new_image) if $point_new_pic;

			}

			$progress->{'index'}++;
		
			my $percent =  $progress->{'index'} * 100 /  $progress->{count};

			if ($progress->{old_percent} ne sprintf('%d', $percent)) {
				print sprintf('%d', $percent) . "% finished\n";

                                $task->set('progress', "$percent");
                                $task->update();
				
				$progress->{old_percent} = sprintf('%d', $percent);
			}

#		}
	}

	if (&UPLOAD){
		upload_files(
			up_files => \@up_images,
			task     => $task,
		);
	}



	return {
		images     => \@result,
		new_images => \@new_result,
		image_data => $image_data,
	};
}

sub get_gallery_xml {

	my %h = @_;

	my $task        = $h{task};
	my $image_data  = $h{image_data};

        my $all_new_images = [];
        my $all_albums     = [];

        opendir( DIR, &BASE_IMAGE_PATH ) || die "Can't open dir " . &BASE_IMAGE_PATH . " $!";
        my @directories = sort {$b cmp $a} map {&BASE_IMAGE_PATH . $_} grep { /\w/ && -d (&BASE_IMAGE_PATH . $_)} readdir(DIR);
        closedir(DIR);

	if (@directories == ""){
		Homyaki::Logger::print_log("Gallery_Update: The dir you specified (" . &BASE_IMAGE_PATH . ") is empty or has no photo\'s, directories. Exiting now.");
		exit;
	}

	my $progress = {
		count           => get_files_count(&BASE_IMAGE_PATH),
		'index'         => 0,
		current_percent => 0,
	};

        copy_resume_to_base();

        open (RESUME, '<' . &BASE_RESUME_PATH);
        my $resume = {};
        while (my $str = <RESUME>) {
                if ($str =~ /(.*)\|(.*).\n$/){
                        my $string = $2;
                        my $image_name = $1;
                        $string =~ s/\"/\'/g;
                        $resume->{$image_name} .= $string;
                }
        };
        close RESUME;


	foreach my $dir_name (@directories) {

		my $album_name = get_album_name($dir_name);

		Homyaki::Logger::print_log("Gallery_Update: Open dir $dir_name");
		opendir( DIR, "$dir_name" ) || die qq{Can't open dir $dir_name $!};

		my @sub_directories = sort map {"$dir_name/$_"} grep { /\w/ && -d "$dir_name/$_"} readdir(DIR);
		closedir(DIR);

		my $all_images;

		foreach my $sub_dir_name (@sub_directories){

			my $result = load_images(
				directory  => $sub_dir_name,
				album_name => $album_name,
				image_data => $image_data,
				progress   => $progress,
				resume     => $resume,
				task       => $task,
			);

			my $new_images = $result->{new_images};
			if ($new_images) {
				push (@{$all_new_images}, @{$new_images}) if &UPDATE;
			}

			my $images = $result->{images};

			if ($images) {
				push @{$all_images}, @{$images};
			}
		}

		if ($all_images) {

			## Add "Dummy" image at the end of album for stoping auto uploading next albums
			my $new_image = new XML::Code ('image');
			$new_image->{title}       = "The End";
	
			$new_image->{thumbnail}   = "dummy.jpg";
			$new_image->{image}       = "dummy.jpg";
	
			$new_image->set_text("'Black square' of Malevich");

			push(@{$all_images}, $new_image);

			my $album = new XML::Code ('album');

			$album->{title}       = $album_name;
			$album->{description} = $album_name;

			foreach (@{$all_images}) {
				$album->add_child ($_);
			}

			push (@{$all_albums}, $album);
		}
	}

	return {
		all_new_images => $all_new_images,
		all_albums     => $all_albums,
	};
}

sub add_xml_new_images {
	
	my $albums         = shift;
	my $all_new_images = shift;

	my @check_array = @{$all_new_images};

	if (&UPDATE && $#check_array > -1) {

		my $week_day_map = {
			1 => 'Monday',
			2 => 'Tuesday',
			3 => 'Wednesday',
			4 => 'Thursday',
			5 => 'Friday',
			6 => 'Saturday',
			7 => 'Sunday',
		};

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
		my $album = new XML::Code ('album');

		$wday = $week_day_map->{$wday};
		$year = 1900 + $year;
		$sec  = sprintf('%02d',$sec);
		$min  = sprintf('%02d',$min);
		$hour = sprintf('%02d',$hour);
		$mday = sprintf('%02d',$mday);
		$mon++;
		$mon  = sprintf('%02d',$mon);

		$album->{title}       = 'New pictures/comments';
		$album->{description} = "This pictures or comments was changed on $wday $mday.$mon.$year";

		foreach (@{$all_new_images}) {
			$album->add_child ($_);
		}

		$albums->add_child ($album);

	

		my $upload_pictures_name = &GALLERY_PATH . "${year}_${mon}_${mday}__${hour}_${min}_${sec}.xml";
		if (open (XML, ">$upload_pictures_name")){

			print XML $albums->code();
			close (XML);


			my $ftp = Net::FTP->new(&SITE_URL, Debug => 0)
				or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot connect to " . &SITE_URL . ") $@");
		
			$ftp->login(&SITE_LOGIN, &SITE_PASSWORD)
				or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot login to " . &SITE_URL . ") " . $ftp->message);
	
			upload_file($upload_pictures_name, '/', $ftp);
	
			$ftp->quit;
		} else {
			Homyaki::Logger::print_log("Gallery_Update: Error:  can't open $upload_pictures_name file $!");
		}
	}
}

sub copy_images_to_resume {

	my $resume_pic_path = &RESUME_PIC_PATH;
	$resume_pic_path =~ s/ /\\ /g;

	my $resume_path = &RESUME_PATH;
	$resume_path =~ s/ /\\ /g;

	if (&VIA_RSYNC) {
		print `rsync -rv --size-only $resume_pic_path $resume_path`;
	} else {
		my @files_list = `find $resume_pic_path -name *.jpg`;

		my $count   = scalar(@files_list);
		my $index   = 0;
		my $percent = 0;

		foreach my $file (@files_list){
			$index++;
			$file =~ s/ /\\ /g;
			$file =~ s/\n//g;
			my $source_file = $file;
			$file =~ s/$resume_pic_path/$resume_path/;
			my $error;

			if (check_file_date($source_file)) {
				unless (check_file($file)) {
					if (&VIA_SYN_CE) {
						$file =~ s/\\//g;
						$file =~ s/\//\\\\/g;
						$file =~ s/ /\\ /g;
						print "pcp $source_file $file \n";
						$error = `pcp $source_file $file 2>&1`;
						sleep 1;
						if ($error !~ /File copy of \d+ bytes took|File copy took less than one second!/) {
							print "Error: $error\n";
							return 0;
						}
					} else {
						print "cp $source_file $file \n";
						print `cp $source_file $file 2>&1`;
					}
				}
			}

			my $new_percent = sprintf("%d", $index * 100 / $count);
			if ($percent != $new_percent) {
				print "Export resume pictures $new_percent% done\n";
			}
			$percent = $new_percent;
			 
		}
	}

	return 1;
}

sub move_apache_logs {

	opendir(my $dh, &HTTP_LOG_PATH) || die "cant opend " . &HTTP_LOG_PATH . ": $!";
	my @logs = grep { /^access\.log(\.\d+)?(\.gz)?/i && -f &HTTP_LOG_PATH . "/$_" } readdir($dh);
	closedir $dh;

	opendir(my $dh, &HTTP_LOG_BACKUP_PATH) || die "cant opend " . &HTTP_LOG_BACKUP_PATH . ": $!";

	my $max_n = 0;

	foreach my $log_name (readdir($dh)){
		if ($log_name =~ /^access\.log\.n(\d+)(\.\d+)?(\.gz)?/i && -f &HTTP_LOG_BACKUP_PATH . "/$log_name"){
			if ($1 > $max_n) {
				$max_n = $1;
			}
		}
	}
	closedir $dh;

	$max_n++;
	my $is_log_error = 0;
	foreach my $log_source (@logs) {
		my $log_destantion = $log_source;
		$log_destantion =~ s/^(access\.log)(\.\d+)?(\.gz)?/$1.n$max_n$2$3/i;

		$log_source     = &HTTP_LOG_PATH . $log_source;
		$log_destantion = &HTTP_LOG_BACKUP_PATH . $log_destantion;

		Homyaki::Logger::print_log("Gallery_Update: sudo mv $log_source $log_destantion\n");
		my $mv_error = `sudo mv $log_source $log_destantion`;
		if ($mv_error) {
			Homyaki::Logger::print_log("Gallery_Update: Log: (sudo mv $log_source $log_destantion) $mv_error");
			$is_log_error = 1;
		}

		my $chmod_error = `sudo chmod 755 $log_destantion`;
		Homyaki::Logger::print_log("Gallery_Update: Log: (sudo chmod 755 $log_destantion) $chmod_error")
			if $chmod_error;
	}

	my $log_obj_source = &HTTP_LOG_PATH . 'hosts.obj';
	my $rm_error = `sudo rm -f $log_obj_source`
		unless $is_log_error;
	Homyaki::Logger::print_log("Gallery_Update: Log: (sudo rm -f $log_obj_source) $rm_error")
		if $rm_error;


	my $log_html = Homyaki::Apache_Log::get_html(&HTTP_LOG_BACKUP_PATH);
	
	if (open LOG, '>/var/www/stat_old.html') {
		print LOG $log_html;
	} else {
		Homyaki::Logger::print_log("Gallery_Update: Error:  can't open /var/www/stat_old.html file $!");
	}
	my $restart_result = `sudo service apache2 restart`;
	Homyaki::Logger::print_log("Gallery_Update: Log: (sudo service apache2 restart) $restart_result");
}

sub start_email_sending {
	print "Start E-Mail subscribtion processing\n";
	my $sendmail_result = `/home/alex/Scripts/gf_mail/photo_sender.pl whatsnew`;

	Homyaki::Logger::print_log("Gallery_Update: Log: (/home/alex/Scripts/gf_mail/photo_sender.pl whatsnew) $sendmail_result");
}

sub get_gps_google_link {
        my %h = @_;

        my $GPSLatitude  = $h{GPSLatitude};
        my $GPSLongitude = $h{GPSLongitude};
        my $GPSAltitude  = $h{GPSAltitude};

        my $google_link = '';

        if ($GPSLatitude && $GPSLongitude && $GPSAltitude) {
                my $GPSLatitude_dd  = dms2dd({value => $GPSLatitude});
                my $GPSLongitude_dd = dms2dd({value => $GPSLongitude});

                $google_link = qq{http://maps.google.com/maps?ll=$GPSLatitude_dd,$GPSLongitude_dd&z=$GPSAltitude&t=h&hl=en&ie=UTF8&q=$GPSLatitude_dd,$GPSLongitude_dd};
        }
#       print qq{link: $google_link\n};
        return $google_link;
}

sub put_sitemap {
    chdir '/var/www/';

#    Homyaki::Gallery::Sitemap->write_sitemap('sitemap.xml');
}

sub start {
	my $class = shift;
	my %h = @_;
	
	my $params = $h{params};
	my $task   = $h{task};

	my $index  = 0;
	my $old_percent;

	my $gallery_path = &GALLERY_PATH;
	$gallery_path =~ s/\/+$//;

	`cp -r $gallery_path $gallery_path.back`;

	# Files Processing

#	Homyaki::Gallery::Group_Processing->process(
#		handler => 'Homyaki::Processor::DigiCam_GPS_Marker',
#		params  => {
#			images_path   => &BASE_IMAGE_PATH,
#			build_gallery => 1,
#		},
#	);

	Homyaki::Gallery::Group_Processing->process(
		handler => 'Homyaki::Processor::Gallery_Unic_Name',
		params  => {
			images_path   => &BASE_IMAGE_PATH,
		},
	);

	my $watermark_image = get_watermark_image();

	unless (&UPDATE){
		my $picdir   = &PIC_PATH;
		my $thumbdir = &THUMB_PATH;

		`rm -f $picdir/*`;
		`rm -f $thumbdir/*`;
	}


	# Build XML

	my $gallery = new XML::Code ('gallery');
	$gallery->version ('1.0');
	$gallery->encoding ('UTF-8');

	add_xml_config($gallery);

	my $language = new XML::Code ('language');

	add_xml_string($language, "loading");
	add_xml_string($language, "previous page");
	add_xml_string($language, "page % of %");
	add_xml_string($language, "next page");

	my $exists_folders = {};


	copy_resume_to_base();

	open (RESUME, '<' . &BASE_RESUME_PATH);
	my $resume = {};
	while (my $str = <RESUME>) {
		if ($str =~ /(.*)\|(.*).\n$/){
			my $string = $2;
			my $image_name = $1;
			$string =~ s/\"/\'/g;
			$resume->{$image_name} .= $string;
		}
	};
	close RESUME;

	open (OBJ, '<' . &OBJ_PATH);
	my $str_obj;
	while (my $str = <OBJ>) {
		$str_obj .= $str;
	};
	close OBJ;
	my $image_data = thaw($str_obj);

	my $albums = new XML::Code ('albums');

        open (OBJ, '<' . &OBJ_PATH);
        my $str_obj;
        while (my $str = <OBJ>) {
                $str_obj .= $str;
        };
        close OBJ;
        my $image_data = thaw($str_obj);

	my $gallery_hash = get_gallery_xml(
		task       => $task,
		image_data => $image_data,
	);

	add_xml_new_images($albums, $gallery_hash->{all_new_images});

	
	foreach (@{$gallery_hash->{all_albums}}) {
		$albums->add_child ($_);
	}

	$gallery->add_child ($albums);
	$gallery->add_child ($language);

	#write to file


	my $ftp = Net::FTP->new(&SITE_URL, Debug => 0)
		or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot connect to " . &SITE_URL . ") $@");

	$ftp->login(&SITE_LOGIN, &SITE_PASSWORD)
		or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot login to " . &SITE_URL . ") " . $ftp->message);

	if (open (XML, '>' . &XML_PATH)){
	        print XML $gallery->code();
        	close (XML);


		if (scalar(@{$gallery_hash->{all_new_images}}) > 0) {
			upload_file(&XML_PATH, '/gallery.xml', $ftp);
		}
		upload_file(&BASE_RESUME_PATH, '/', $ftp);
	} else {
		Homyaki::Logger::print_log('cant open ' . &XML_PATH  . " $!");
	}

	if (open (OBJ, '>' . &OBJ_PATH)) {
		print OBJ freeze($image_data);
		close (OBJ);

		$ftp->binary()
			or Homyaki::Logger::print_log("Gallery_Update: Error: (Cannot set binary mode)" . $ftp->message);

		upload_file(&OBJ_PATH, '/', $ftp);
	} else {
		Homyaki::Logger::print_log('cant open ' . &OBJ_PATH  . " $!");
	}

	$ftp->quit;

	copy_images_to_resume();

	move_apache_logs() if &LOCAL_APACHE;

#	put_sitemap();

	start_email_sending();


#	if (scalar(@{$track_list_result->{track_list}}) > $track_list_count){
#		Homyaki::Sender::send_email(
#			emails  => $params->{emails},
#	}

	my $result = {
		result => 'Done',
	};


#	$result->{task} = {
#		retry => {
#			hours => 12,
#		},
#		params => $params,
#	};

	return $result;
}


1;

