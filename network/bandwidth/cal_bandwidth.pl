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
my @net_card = qw(eth0 eth1 em1 em2 band0 band1);
my $data = get_netcard_band( \@net_card );

### $data

foreach my $interface ( keys %$data ) {
    #    /usr/bin/gmetric -t uint16 -n NB_active_jobs -v$VALUEACTIVE -u '#'
    my $tr_speed = $data->{$interface}{'tr_speed'};
    my $rx_speed = $data->{$interface}{'re_speed'};
    my $group = "network";
    my $rx_unit = $data->{$interface}{'re_unit'};
    my $tr_unit = $data->{$interface}{'tr_unit'};    
    
    my $i_cmd =qq{$gmetric_exec -t float -n "$interface in" -v $rx_speed -g "$group" -u "$rx_unit"};
    my $o_cmd =qq{$gmetric_exec -t float -n "$interface out" -v $tr_speed -g "$group" -u "$tr_unit"};
    ### $i_cmd
    ### $o_cmd

    my @ret = `$i_cmd`;
    if ( $? >> 8 ) {
        print "@ret";    
    }
    
    @ret = `$o_cmd`;
    if ( $? >> 8 ) {
        print "@ret";    
    }
}

sub get_netcard_band {
    my $netcard = shift;
    
    my $file = '/proc/net/dev';

    open my $fh, '<', $file
        or die "can't open file: $!";

    my %stat;
    while ( <$fh> ) {
        next if $. == 1;
        chomp;
### $_
        my ($tmp, $tr) = (split(/\s+/, $_))[1,9];

        my ($face, $re) = split(/:/, $tmp);
        ### $face
        ### $re
        ### $tr        

        if ( grep { /$face/ } @$netcard  ) {
            @{$stat{$face}}{'tr_old', 're_old'} = ($tr, $re);
        }
    }
    close $fh;
    sleep 10;

    open $fh, '<', $file
        or die "can't open file: $!";

    while ( <$fh> ) {
        next if $. == 1;
        chomp;

        my ($tmp, $tr) = (split(/\s+/, $_))[1,9];
        my ($face, $re) = split(/:/, $tmp);
        ### $face
        ### $re
        ### $tr
        if ( grep { /$face/ } @$netcard ) {
            @{$stat{$face}}{'tr_new', 're_new'} = ($tr, $re);
        }
    }
    
    close $fh;

    ### %stat
    my %bandwidth;
    foreach my $key ( keys %stat ) {
        my $tr = ( $stat{$key}{'tr_new'} - $stat{$key}{'tr_old'} ) * 8 / 10;
        my $rx = ( $stat{$key}{'re_new'} - $stat{$key}{'re_old'} ) * 8 / 10;

        @{$bandwidth{$key}}{'tr_speed', 'tr_unit'} = number_2_human_readable( $tr );
        @{$bandwidth{$key}}{'re_speed', 're_unit'} = number_2_human_readable( $rx );
    }

    return \%bandwidth;
}

sub number_2_human_readable {
    my $number = shift;

    # my $measure = {
    #     b => 1,
    #     k => 1024,
    #     M => 1024 * 1024,
    #     G => 1024 * 1024 * 1024,
    #     T => 1024 * 1024 * 1024 * 1024,
    # };

    my ($num, $unit);
    if ( $number < 1024 ) {
        $num = sprintf("%.2f", $number);
        $unit = 'bits/s';
        return ($num, $unit);
    }

    my $k = $number / 1024;
    if ( $k < 1024 ) {
        $num = sprintf("%.2f", $k);
        $unit = 'Kbit/s';
        return ($num, $unit);        
    }

    my $m = $k / 1024;
    if ( $m < 1024 ) {
        $num = sprintf("%.2f", $m);
        $unit = 'Mbit/s';
        return ($num, $unit);        
    }

    my $g = $m / 1024;
    if ( $g < 1024 ) {
        $num = sprintf("%.2f", $g);
        $unit = 'Gbit/s';
        return ($num, $unit);
    }

    my $t = $g / 1024;
    if ( $t < 1024 ) {
        $num = sprintf("%.2f", $g);
        $unit = 'Tbit/s';
        return ($num, $unit);        
    }

    return;
}
