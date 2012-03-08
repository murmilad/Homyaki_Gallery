package Homyaki::Gallery::Sitemap;

use strict;

use WWW::Sitemap::XML;

use Homyaki::Gallery::Image;

use base 'Homyaki::Sitemap';

sub get_sitemap {
	my $class = shift;

	my $map          = $class->SUPER::get_sitemap();
	my $current_date = $class->get_current_date();

	my @images = Homyaki::Gallery::Image->retrieve_all();

	my $site_url = $class->get_site_url();

	$map->add(
		WWW::Sitemap::XML::URL->new(
			loc        => "$site_url/engine/?interface=gallery&amp;form=news",
			lastmod    => $current_date,
			changefreq => 'monthly',
			priority   => 1.0
		)
	);

	foreach my $image (@images){
		$map->add(
			WWW::Sitemap::XML::URL->new(
				loc        => "$site_url/engine/?interface=gallery&amp;form=data&amp;image=$image->{name}",
				lastmod    => $current_date,
				changefreq => 'monthly',
				priority   => 1.0
			)
		) if $image->{name};
	}

	return $map;
}

1;