#!/usr/bin/perl -w
#

package Poetical::FormType::Encapsulators::Library::Satcom;


use strict;


use Poetical::FormType::Encapsulators::Library::Standard;


#t this breaks things inside web-lib.pl, do not know what exactly, do not know why.
#t difficult to debug, I did see many weird things while debugging this.
#t the 'net' module is imported in the subs that need it.
#t The mechanism in web-lib automatically tracks multiple inclusions.

# &::foreign_require("net", "net-lib.pl");


sub _decapsulate_active_interface_selector
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_name_service_selector
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _encapsulate_active_interface_selector
{
    my ($self, $path, $column_number, $content, $options) = @_;

    my $separator = $self->{separator} || '_';

    # prevent rendering the units

    delete $options->{gui_units};

    &::foreign_require("net", "net-lib.pl");

    my $interfaces = [ &net::active_interfaces(), ];

    my $interface_names = [ map { $_->{fullname}; } @$interfaces, ];

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field${separator}$path",
	     -default => $content,
	     -values => $interface_names,
	     -override => 1,
	    );
}


sub _encapsulate_name_service_selector
{
    my ($self, $path, $column_number, $content, $options) = @_;

    my $separator = $self->{separator} || '_';

    # prevent rendering the units

    delete $options->{gui_units};

    &::foreign_require("net", "net-lib.pl");

    my $dns = &net::get_dns_config();

    my $services = [ grep { /^(?!files)/ } split '\s+', $dns->{order}, ];

    return
	$self->{CGI}->popup_menu
	    (
	     -name => "field${separator}$path",
	     -default => $services->[0],
	     -values => [ "none", "dns", "nis", "nis+", ],
	     -override => 1,
	    );
}


Poetical::FormType::Encapsulators::Library::Standard::configure(__PACKAGE__);


