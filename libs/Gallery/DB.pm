package Homyaki::Gallery::DB;

use strict;
use Class::DBI ();
use base 'Class::DBI';

__PACKAGE__->set_db('Main', 'dbi:mysql:gallery', 'alex', '458973');

__PACKAGE__->set_sql(Retrieve_nocache => <<'', 0, 0);
SELECT __ESSENTIAL__
FROM   __TABLE__
WHERE  %s

__PACKAGE__->set_sql(Total => <<'');
SELECT count(*)
FROM   __TABLE__
WHERE  %s

__PACKAGE__->set_sql(LastID => <<'');
SELECT last_insert_id()

__PACKAGE__->set_sql(DeleteMe => <<"");
DELETE FROM  __TABLE__
WHERE  __IDENTIFIER__

__PACKAGE__->set_sql(FreeQuery => <<"");
%s

sub execute_free_query {
	my $class = shift;
	my %h = @_;

	my $query  = $h{query};
	my $params = $h{params};

	my $sth = $class->sql_FreeQuery($query);

	$params = []        unless defined $params;
	$params = [$params] unless ref $params;

	return undef unless $sth->execute(@$params);

	return $sth;
}

1;