#!/usr/bin/env perl  

#############################################################################
#CHECK_SENTRY_CDU	
#See --help for more information...
#
#
# ***************************************************************************
# *   Copyright (C) 2012 by Jeremy Falling except where noted.              *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
# ***************************************************************************
#TO DO:
# - check to see if both power strips are available, if user has both (check secondary_tower?)
#
#CHANGE LOG:
#
# 3-14-12: Jeremy Falling: First version.
# 3-16-12: Jeremy Falling: Fixed variables so that I can use strict. Also using /usr/bin/env perl
#
#
#############################################################################
use strict;
use utils;
use Getopt::Long;
use vars qw($opt_help $opt_warn $opt_crit $opt_type $opt_timeout $opt_host $opt_com $PROGNAME);
use utils qw(%ERRORS &print_revision &support &usage);

#############################################################################
#define/init a few things
# Define where our SNMP utilities are.
my $snmp_walk="/usr/bin/snmpwalk";
my $snmp_get="/usr/bin/snmpget";
my $PROGNAME = "check_sentry_cdu";

#define the oids
my $cduloadoid=".1.3.6.1.4.1.1718.3.2.2.1.7"; #add tower and feed integer. then divide by 100. load means amps.
my $cdutempoid=".1.3.6.1.4.1.1718.3.2.5.1.6.1"; #add sensor integer. then divide by 10
my $cduhumidoid=".1.3.6.1.4.1.1718.3.2.5.1.10.1"; #add sensor integer.
my $cdutempscaleoid=".1.3.6.1.4.1.1718.3.2.5.1.13.1.1"; #I assume that both sensors will have the same scale so I will just look at one of them. 0 is c 1 is f.

my $exit_code = ""; #declare $exit_code as an empty string so this script will default to an unknown error code if $exit_code was not re-defined
sub print_help (); #define this so we dont get a prototype error
#############################################################################

#get passed flags
Getopt::Long::Configure('bundling');
GetOptions
	("h"   => \$opt_help, "help"       => \$opt_help,
	 "w=s" => \$opt_warn, "warning=s"  => \$opt_warn,
	 "c=s" => \$opt_crit, "critical=s" => \$opt_crit,
	 "t=s" => \$opt_timeout, "timeout=s" => \$opt_timeout,
	 "T=s" => \$opt_type, "type=s" => \$opt_type,
	 "H=s" => \$opt_host, "hostname=s" => \$opt_host,
	 "C=s" => \$opt_com, "community=s" => \$opt_com);

#if help was requested, print help
if ($opt_help) {print_help (); exit_sub ();}

#check hostname
($opt_host) || usage("Host name/address not specified\n");
my $host = $1 if ($opt_host =~ /([-.A-Za-z0-9]+)/);
($host) || usage("Invalid host: $opt_host\n");

# if no community is passed, use public
($opt_com) || ($opt_com = "public") ; 

# if no timeout is passed, use 10 seconds as a default
($opt_timeout) || ($opt_timeout = "10") ; 

#check warn thresh
($opt_warn) || usage("Warning threshold not specified\n");
my $warning_thresh = $opt_warn;
($warning_thresh) || usage("Invalid warning threshold: $opt_warn\n");

#check crit thresh
($opt_crit) || usage("Critical threshold not specified\n");
my $critical_thresh = $opt_crit;
($critical_thresh) || usage("Invalid critical threshold: $opt_crit\n");

#check check type
($opt_type) || usage("Type of check not specified\n");

#check to see what check was requested. 

#if user requested amp check
my $numOfTowers;
my $current_val;
my $num_of_sensors;
my @sensor_val;
my $ba_load_val;
my $count;
my $temp_scale;
my $current_status;
if ($opt_type eq "amp") {
	# Walk to get the amp values.
	
	@sensor_val = `$snmp_walk -v 1 -O vesq -c $opt_com $host $cduloadoid`;
	chomp(@sensor_val);
	
	#check to see if ba is = -1, if so, the second tower is probably not present, so delete ba-bc from the array. 
	 $ba_load_val = $sensor_val[3];
	if ($ba_load_val == -1) {
		delete $sensor_val[3];
		delete $sensor_val[4];
		delete $sensor_val[5];
	}
	
	#get the number of items in the array +1
	$num_of_sensors = @sensor_val;
	$num_of_sensors = scalar (@sensor_val);
	$num_of_sensors = $#sensor_val + 1;
	
	#we need to the divide the load value by 100 so we get the actual value (the cdu reports the value * 100)
	$count = 0; 
	while ($count < $num_of_sensors) {
		$current_val = $sensor_val[$count];
		$current_val = $current_val / 100;
		$sensor_val[$count] = $current_val;

		$count ++
	}
		

	#check the number of towers, if 3 feeds, then there is only one tower
	if ($num_of_sensors == 3) {
		$numOfTowers = 1;
	
	}
	
	#if 6 feeds, then there are two towers
	elsif ($num_of_sensors == 6) {
		 $numOfTowers = 2;
	
	}
	
	#if the array size does not equal 3 or 6, something is wrong. lets run way, i mean exit...
	else {
		print "Invalid number of infeeds reported by device. A total of 3 or 6 infeeds expected, $num_of_sensors reported.";
		exit_sub ();; #exit since something unexpected happened....
	
	}
	#check if sensor values are ok
	check_sensor_values ();

	 
	#depending on the number of towers, give a different output and exit.
	if ($numOfTowers == 1) {
		print "AA:$sensor_val[0], AB:$sensor_val[1], AC:$sensor_val[2]";
		exit_sub ();
	
	}
	
	elsif ($numOfTowers == 2) {
		print "AA:$sensor_val[0], AB:$sensor_val[1], AC:$sensor_val[2], BA:$sensor_val[3], BB:$sensor_val[4], BC:$sensor_val[5]";
		exit_sub ();
	
	}
	
}

#if user wanted to check humidity
elsif ($opt_type eq "humid"){
	#get sensor values
	@sensor_val = `$snmp_walk -v 1 -O vesq -c $opt_com $host $cduhumidoid`;
	chomp(@sensor_val);
	
	#get the number of items in the array +1
	$num_of_sensors = @sensor_val;
	$num_of_sensors = scalar (@sensor_val);
	$num_of_sensors = $#sensor_val + 1;

	
	#check if sensor values are ok
	check_sensor_values ();
	
	print "Sensor1: $sensor_val[0] ,Sensor2: $sensor_val[1]";
	exit_sub ();

}

#if user wanted to check temperature 
elsif ($opt_type eq "temp"){
	#get temp scale
	$temp_scale = `$snmp_get -v 1 -O vesq -c $opt_com $host $cdutempscaleoid`;
	if ($temp_scale == 1){
	$temp_scale = "F";
	}
	else{
	$temp_scale = "C";
	}
	
	@sensor_val = `$snmp_walk -v 1 -O vesq -c $opt_com $host $cdutempoid`;
	chomp(@sensor_val);
	
	#get the number of items in the array +1
	$num_of_sensors = @sensor_val;
	$num_of_sensors = scalar (@sensor_val);
	$num_of_sensors = $#sensor_val + 1;


	#we need to the divide the sensor data by 100
	$count = 0; 
	while ($count < $num_of_sensors) {
		$current_val = $sensor_val[$count];
		$current_val = $current_val / 10;
		$sensor_val[$count] = $current_val;
		
		$count ++
	}
	
	#check if sensor values are ok
	check_sensor_values ();
	
	print "Sensor1: $sensor_val[0]$temp_scale ,Sensor1: $sensor_val[1]$temp_scale";
	exit_sub ();
}

#user wanted to check the fuse state
elsif ($opt_type eq "fuse"){
	print "fuse check not yet done.";
	exit_sub ();

}

else {
	usage("Invalid type of check: $opt_type\n");

}


#sub routines
#############################################################################
#this is used for checking the all of the sensors. 
sub check_sensor_values {

	#go through the array and see if any values are of concern.
	$count = 0; 
	$current_val = "";
	$current_status = "";
	while ($count < $num_of_sensors) {
		#put the current array val into a var
		$current_val = $sensor_val[$count];

		#check if value meets the crit thresh. do this first since this is higher then warning.
		if ( $current_val >= $critical_thresh) {
			$current_status = 2;
			
		}
		
		#check if value meets the warn thresh
		elsif ( $current_val >= $warning_thresh) {
			$current_status = 1;
			
		}

		#check if value is below warning, then things are ok
		elsif ( $current_val < $warning_thresh) {
			$current_status = 0;
			
		}
			
		#check if none of the above were met, throw an unknown and exit
		else {
			print "Invalid value reported by device";
			$current_status = 3;
			exit_sub ();
			
		}
		
		#check if the current exit status is higher then the existing status.
		if ( $current_status gt $exit_code) {
			$exit_code = $current_status;
			
		}

		$count++;

	}
	 

}


sub exit_sub {
	exit $ERRORS{'CRITICAL'} if ($exit_code == 2);
	exit $ERRORS{'WARNING'} if ($exit_code == 1);
	exit $ERRORS{'UNKNOWN'} if ($exit_code == 3);
	exit $ERRORS{'OK'} if ($exit_code == 0); 
	exit $ERRORS{'UNKNOWN'};  #I have unknown here a second time as a catch all. If none of the $exit_code was not defined with a valid exit code, something is wrong.
}





sub print_help () {
print "This plugin checks a Sentry CDU for current load (amp), fuse errors, temperature, and humidity levels. 
You will need to specify the check you want then the thresholds for the check you are requesting. 
Note, this program can only do one check type at a time. 

This was developed on the following models: Sentry cw-24vy-l30m, cx-24vyl30m (3phase). This plugin will auto-detect the number of towers.

";

	print "Usage: $PROGNAME -H <host> [-C community] -T <amp, humid, temp, fuse>  -t [timeout] -w <warn> -c <crit> \n";

	print "
-H, --hostname=HOST
   Name or IP address of host to check
-C, --community=community
   SNMPv1 community (default public)
-T, --type=<amp, humid, temp, fuse>
   The check type you want to run, please only specify one check at a time!
-t, --timeout=[timeout]
   The snmp timeout in seconds (default 10 seconds)
-w, --warning=INTEGER
   Interger that if >= will cause a WARNING status.
-c, --critical=INTEGER
   Interger that if >= will cause a CRITICAL status. 
   
";

exit_sub ();

}

