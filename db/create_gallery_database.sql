
CREATE TABLE `blog` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `image_id` int(11) NOT NULL,
  `user_name` char(255) DEFAULT NULL,
  `comment` char(255) DEFAULT NULL,
  `ip_address` char(15) DEFAULT NULL,
  `insert_date` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=76 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

CREATE TABLE `image` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(128) DEFAULT NULL,
  `path` char(255) DEFAULT NULL,
  `resume` char(255) DEFAULT NULL,
  `english_resume` char(255) DEFAULT NULL,
  `new_resume` char(255) DEFAULT NULL,
  `new_english_resume` char(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2905 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
