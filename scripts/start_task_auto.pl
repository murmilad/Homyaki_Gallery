#!/usr/bin/perl 
#===============================================================================
#
#         FILE: start_task_autorename.pl
#
#        USAGE: ./start_task_autorename.pl  
#
#  DESCRIPTION: Starts Gallery autorename task
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Alexey Kosarev (murmilad), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 29.04.2012 21:29:15
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task_Type;

my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
	handler => 'Homyaki::Task_Manager::Task::Auto_Build_Gallery'
);

if (scalar(@task_types) > 0) {

	my $task = Homyaki::Task_Manager->create_task(
		task_type_id => $task_types[0]->id(),
	);
}
