#!/usr/bin/perl

use strict;
use Imager;
use Data::Dumper;

use constant ORIENTATIONS => {
	6 => 90,
	8 => 270
};

use constant WATERMARK_PATH => '/home/alex/Share/Photo/sign.bmp';

use constant COMMAND_SMALL  => 'small';
use constant COMMAND_MARK   => 'mark';
use constant COMMAND_ROTATE => 'rotate';

sub change_image {
	my $path    = shift;
	my $command = shift;

	my $img = Imager->new();
	$img->open(file=>$path);

	my $thumb;
	if ($command eq &COMMAND_SMALL){
		$thumb = change_size($img, 320);
	} elsif ($command eq &COMMAND_MARK) {
		$thumb = put_watermark($img, &WATERMARK_PATH);
	} elsif ($command eq &COMMAND_ROTATE) {
		$thumb = rotate($img);
	}


	unless ($thumb->write(file=>$path)) {
		print STDERR "$path - ",$img->errstr(),"\n";
		next;
	}
	print uc($command) . ' ' . $path . " OK\n";
}

sub get_tag_data {
	my $tags     = shift;
	my $tag_name = shift;

	return unless $tags;

	foreach (@{$tags}){
		return $_->[1] if $_->[0] eq $tag_name
	}
}

sub rotate {
	my $img = shift;

	my @tags = $img->tags();
	my $orientation = get_tag_data(\@tags, 'exif_orientation');
	my $grad = &ORIENTATIONS->{$orientation};

	my $pic;

	if ($grad){
		print "Rotate $grad\n";
		$pic = $img->rotate(right => $grad);
	} else {
		$pic = $img;
	}

	return $pic
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

	my $pic = $img->scale(scalefactor => $s);

	return $pic;
}

sub put_watermark {
	my $img                  = shift;
	my $watermark_image_path = shift;

	my $watermark_image = Imager->new();
	unless ($watermark_image->open(file => $watermark_image_path)) {
		print STDERR "$watermark_image_path - ",$watermark_image->errstr(),"\n";
	}

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

my $command       = $ARGV[0];
my $source_folder = $ARGV[1];

print `cp -r $source_folder ${source_folder}.back`;

my @files = split("\n", `find $source_folder -type f`);

foreach my $file (@files){
	if ($file =~ /(^.+\/)([^\/]+)\.JPG$/gi ){
##		print "Found file $1\n";
		change_image($file, $command);
	}
}



