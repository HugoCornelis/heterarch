#!/usr/bin/perl -w
#

package Poetical::FormType::Encapsulators::Library::Sems;


use strict;


use Data::Dumper;

use Poetical::FormType::Encapsulators::Library::Standard;


my $sems_config = do "/var/sems/sems.config";

my $devices = $sems_config->{devices};

my $all_spectrum_analyzers = [ grep { /^SA/ } keys %$devices ];

my $all_matrices = [ grep { /^MATRIX/ } keys %$devices ];

my $all_monitoring_devices = [ grep { /^SA/ || /^BEACON/ } keys %$devices ];


sub _decapsulate_any_matrix
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_any_monitor_device
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_any_SA
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_license_key
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    # security first : protect single slashes

    my $result_path = $path;

    $result_path =~ s/'/\\'/g;

    my $separator = $self->{separator} || '_';

    $result_path =~ s/${separator}[1-8]$//;

    # construct the hash path leading to the license key

    my $hash_path = $result_path;

    $hash_path =~ s/([^${separator}]+)${separator}/->{'$1'}/g;
#     $hash_path =~ s/_//g;

    # construct an eval string to fetch already stored data

    my $fetch_data = "\$contents${hash_path}";

    # fetch already stored data

    print STDERR "_decapsulate_license_key: eval '$fetch_data'\n";

    my $stored_data = eval $fetch_data;

#     print STDERR Dumper($stored_data), "\n";

    if (!defined $stored_data)
    {
	#! note that split automatically removes empty strings, so 'empty' is
	#! a place-holder for an empty string.

	#t I could probably better replace this with a 'x' operator in list
	#t context.

	$stored_data = join ":", map 'empty', 1..8;
    }

#     print STDERR Dumper($stored_data), "\n";

    my @stored_parts = split /:/, $stored_data;

#     print STDERR Dumper(\@stored_parts), "\n";

    # figure out for which part of the key we were called

    $path =~ /${separator}([1-8])$/;

    # fill in the new value

    $stored_parts[$1 - 1] = $value;

    # compute the new (possibly partial) license key

#     print STDERR Dumper(\@stored_parts), "\n";

    my $result_value = join ":", @stored_parts;

    return($result_path, $result_value);
}


sub _decapsulate_session_modulator
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_session_ucc
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _encapsulate_any_SA
{
    my ($self, $path, $column_number, $content, $options) = @_;

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field_$path",
	     -default => $content,
	     -values => $all_spectrum_analyzers,
	     -override => 1,
	    );
}


sub _encapsulate_any_matrix
{
    my ($self, $path, $column_number, $content, $options) = @_;

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field_$path",
	     -default => $content,
	     -values => $all_matrices,
	     -override => 1,
	    );
}


sub _encapsulate_any_monitor_device
{
    my ($self, $path, $column_number, $content, $options) = @_;

    return
	$self->{CGI}->popup_menu
	    (
	     -default => $content,
	     -name => "field_$path",
	     -override => 1,
	     -values => $all_monitoring_devices,
	    );
}


sub _encapsulate_license_key
{
    my ($self, $path, $column, $contents, $options) = @_;

    #c I tested the combination of () and {} operators, but they do not nicely
    #c collaborate (matches only one () pair).  So I need to construct the
    #c matcher string here.

    my $separator = $self->{separator} || '_';

    my $matcher = "(?:([0-9a-f]{4}):)" x 7 . "([0-9a-f]{4})";

    if (defined $contents && $contents =~ /$matcher/i)
    {
	local $_;

	my $str
	    .= join ' : ',
		map
		{
		    # key is the n'th textfield of the current entry.

		    my $name = "field${separator}${path}${separator}${_}";

		    my $default;

		    # extract n'th field out of regex match

		    {
			no strict "refs";

			$default = ${${_}};
		    }

		    $self->{CGI}->textfield
			(
			 -default => $default,
			 -id => $name,
			 -maxlength => 4,
			 -name => $name,
			 -override => 1,
			 -size => 4,
			);
		}
		    1..8 ;

	$contents = $str;
    }

    return $contents;
}


#t probably the session_encapsulators should be moved to a specific package

my $transmit_calibration_channel_type;

sub _encapsulate_session_modulator
{
    my ($self, $path, $column, $contents, $options) = @_;

    if (!$transmit_calibration_channel_type)
    {
	$transmit_calibration_channel_type = do '/sems/lib/channel_types/TxCalibration';
    }

    my $separator = $self->{separator} || '_';

    my $query = $self->{CGI};

    my $values = $transmit_calibration_channel_type->{valid_values}->{ntcSeSessionModId};

    my $labels
	= {
	   map
	   {
	       $_ => "MOD_$_";
	   }
	   @$values,
	  };

    return
	$query->popup_menu
	    (
	     -default => defined $contents ? $contents : '',
	     -id => "field${separator}$path",
	     -labels => $labels,
	     -name => "field${separator}$path",
	     -override => 1,
	     -values => $values,
	     %$options,
	    );
}


sub _encapsulate_session_ucc
{
    my ($self, $path, $column, $contents, $options) = @_;

    if (!$transmit_calibration_channel_type)
    {
	$transmit_calibration_channel_type = do '/sems/lib/channel_types/TxCalibration';
    }

    my $separator = $self->{separator} || '_';

    my $query = $self->{CGI};

    my $values = $transmit_calibration_channel_type->{valid_values}->{ntcSeSessionUccId};

    my $labels
	= {
	   map
	   {
	       $_ => "UCC_$_";
	   }
	   @$values,
	  };

    return
	$query->popup_menu
	    (
	     -default => defined $contents ? $contents : '',
	     -id => "field${separator}$path",
	     -labels => $labels,
	     -name => "field${separator}$path",
	     -override => 1,
	     -values => $values,
	     %$options,
	    );
}


Poetical::FormType::Encapsulators::Library::Standard::configure(__PACKAGE__);


