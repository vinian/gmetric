#!/usr/bin/perl

###########################################################################
# Author: Nianhua.Wei (willian.wnh@mgail.com)
# License: GNU Public License (http://www.gnu.org/copyleft/gpl.html)
# Collects sar statistic
###########################################################################

use strict;
use warnings;

use POSIX qw(locale_h strftime setlocale);

POSIX::setlocale( &POSIX::LC_ALL, "En_US" );

# NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf
my $gmetric_exec = "/usr/local/ganglia/bin/gmetric";
my $gmetric_options = " -d 180 ";

# You only need to grant usage privilege to the user getting the stats e.g.

my $start  = strftime("%H:%M:00", localtime);

if ( $start =~ /(\d+):(\d+):00/ ) {
    my ($hour, $min) = ($1, $2);

    if ( $min >= 50 ) {
        $min = 40;
    } elsif ( $min >= 40 ) {
        $min = 30;
    } elsif ( $min >= 30 ) {
        $min = 20;
    } elsif ( $min >= 20 ) {
        $min = 10;
    } elsif ( $min >= 10 ) {
        $min = '00';
    } else {
        $min = 50;
        if ( $hour == 0 ) { 
            $hour = 23;
        } else {
            $hour -= 1;    
        }
    }

    $start =~ s/\d+:\d+:/$hour. ':'. $min . ':'/ex;
}

my $sar_base = "sar -bBqrRu -vwW -n SOCK -I SUM ";
my $sarcmd   = "$sar_base -s $start";

open my $cmd_stat, "-|", $sarcmd
    or die "can't open cmd: $!";

my %sar;

while ( <$cmd_stat> ) {
    chomp;
    if ( /cswch/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{'intr and cswch'}}{cswch} = (split(/\s+/, $_))[1];
        }
    } elsif ( /INTR/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{'intr and cswch'}}{intr} = (split(/\s+/, $_))[2];
        }        
    } elsif ( /tps/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{"io and transfer"}}{"tps", "rtps", "wtps", "bread", "bwrtn"} = (split(/\s+/, $_))[1,2,3,4,5];
        }                
    } elsif ( /pgpgin/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{"paging"}}{"pgpgin", "pgpgout", "fault", "majflt"} = (split(/\s+/, $_))[1,2,3,4];
        }                
    } elsif ( /dentunusd/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{'inode, file and kernel table'}}{"dentunusd", "file-sz", "inode-sz", "super-sz"} = (split(/\s+/, $_))[1,2,3,4];
        }                        
    } elsif ( /totsck/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{"network"}}{"totsck", "tcpsck", "updsck"} = (split(/\s+/, $_))[1,2,3];
        }
    } elsif ( /runq-sz/ .. /Average/ ) {
        if ( /Average/ ) {
            @{$sar{"queue"}}{"runq-sz", "plist-sz"} = (split(/\s+/, $_))[1,2];
        }        
    }
}

open my $net_stat, "-|", "sar -n DEV -I SUM -s $start"
    or die "can't open cmd: $!";

my $net_flag = 0;
while ( <$net_stat> ) {
    chomp;
    $net_flag = 1 if /IFACE/;
    next unless $net_flag;
    if ( /Average/ ) {
        my ($netcard, $rxpck, $txpck, $rxbyt, $txbyt, $rxcmp, $txcmp, $rxmcst) =
            (split (/\s+/, $_))[1, 2, 3, 4, 5, 6, 7,8];
        if ( $netcard eq 'eth0' or $netcard eq 'eth1'
                 or $netcard eq 'em1' or $netcard eq 'em2'){
             @{$sar{"$netcard"}}{"$netcard rxpck","$netcard txpck","$netcard rxbyt",
                                 "$netcard txbyt","$netcard rxcmp","$netcard txcmp",
                                 "$netcard rxmcst"}
                 = ($rxpck, $txpck, $rxbyt, $txbyt, $rxcmp, $txcmp, $rxmcst);
        }
    }
}

foreach my $group ( keys %sar ) {
    foreach my $type (keys %{$sar{$group}}) {

        #    /usr/bin/gmetric -t uint16 -n NB_active_jobs -v$VALUEACTIVE -u '#'
        my $name = $type;
        my $value = $sar{$group}{$type};

        my $cmd =qq{$gmetric_exec -t float -n "$type" -v $value -g "$group"};
        ### $cmd
        my @ret = `$cmd`;
        if ( $? >> 8 ) {
            print "@ret";    
        }
    }
}

