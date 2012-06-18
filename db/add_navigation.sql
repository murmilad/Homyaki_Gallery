USE `homyaki_web`;
INSERT INTO `navigation_items` (name, parrent_name, header, uri)
	VALUES
		('gallery'     , '', 'Photo Gallery'   , '/')
		,('blog_changes', '', 'All blog changes', '/engine/?interface=gallery&form=news');

