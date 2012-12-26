#!/usr/bin/perl -w
#

package FormLibrary::FormType::Encapsulators::Library::Satcom;


use strict;


use FormLibrary::FormType::Encapsulators::Library::Standard;


sub _decapsulate_downlink_local_oscillator
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_SA_resolution_bandwidth
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_satellite_band
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_SA_y_axis_scale
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _encapsulate_downlink_local_oscillator
{
    my ($self, $path, $column_number, $content, $options) = @_;

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field_$path",
	     -default => $content,
	     -values => [ 5150000000, 9750000000, 10000000000, 10600000000, 10750000000, 11600000000, ],
	     -labels => {
			 5150000000 => '5150 MHz (C-Band)',
			 9750000000 => '9750 MHz (Ku-Band)',
			 10000000000 => '10000 MHz (Ku-Band)',
			 10600000000 => '10600 MHz (Ku-Band)',
			 10750000000 => '10750 MHz (Ku-Band)',
			 11600000000 => '11600 MHz (Ku-Band)',
			},
	     -override => 1,
	    );
}


sub _encapsulate_SA_resolution_bandwidth
{
    my ($self, $path, $column_number, $content, $options) = @_;

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field_$path",
	     -default => $content,
	     -values => [ 300000, 100000, 30000, 10000, 3000, ],
	     -labels => {
			 300000 => '300 kHz',
			 100000 => '100 kHz',
			 30000 => '30 kHz',
			 10000 => '10 kHz',
			 3000 => '3 kHz',
			},
	     -override => 1,
	    );
}


sub _encapsulate_satellite_band
{
    my ($self, $path, $column_number, $content, $options) = @_;

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -default => $content,
	     -name => "field_$path",
	     -override => 1,
	     -values => [
			 'C-band',
			 'Ku-band',
			],
	    );
}


sub _encapsulate_SA_y_axis_scale
{
    my ($self, $path, $column_number, $content, $options) = @_;

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field_$path",
	     -default => $content,
	     -values => [ 100, 50, 20, ],
	     -labels => {
			 100 => '100 dB',
			 50 => '50 dB',
			 20 => '20 dB',
			},
	     -override => 1,
	    );
}


FormLibrary::FormType::Encapsulators::Library::Standard::configure(__PACKAGE__);


