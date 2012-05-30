USE `homyaki_web`;
INSERT INTO `form_handlers` (handler, name, description, interface_name)
	VALUES
		('Homyaki::Interface::Gallery::News' , 'news', 'News about blog changes form handler', 'gallery')
		,('Homyaki::Interface::Gallery::Auth', 'auth', 'Auth to gallery form handler'        , 'gallery')
		,('Homyaki::Interface::Gallery'      , 'base', 'Base gallery form handler'           , 'gallery')
		,('Homyaki::Interface::Gallery::Data', 'data', 'Image info form handler'             , 'gallery')

		,('Homyaki::Interface::Task_Manager::Gallery_Update_Task', 'gallery_update' , 'Gallery update form handler', 'task')
		,('Homyaki::Interface::Task_Manager::Build_Gallery', 'build_gallery' , 'Build gallery form handler', 'task');
