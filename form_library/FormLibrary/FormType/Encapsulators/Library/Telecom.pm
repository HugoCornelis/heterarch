#!/usr/bin/perl -w
#

package FormLibrary::FormType::Encapsulators::Library::Telecom;


use strict;


use Data::Dumper;

use FormLibrary::FormType::Encapsulators::Library::Standard;
use FormLibrary::FormType::Encapsulators::Validators::Library::Telecom;


sub _decapsulate_ip_address
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    # security first : protect single slashes

    my $result_path = $path;

    $result_path =~ s/'/\\'/g;

    my $separator = $self->{separator} || '_';

    $result_path =~ s/${separator}[1-8]$//;

    # construct the hash path leading to the ip address

    my $hash_path = $result_path;

    $hash_path =~ s/([^${separator}]+)${separator}/->{'$1'}/g;
#     $hash_path =~ s/_//g;

    # construct an eval string to fetch already stored data

    my $fetch_data = "\$contents${hash_path}";

    # fetch already stored data

    print STDERR "_decapsulate_ip_address: eval '$fetch_data'\n";

    my $stored_data = eval $fetch_data;

#     print STDERR Dumper($stored_data), "\n";

    if (!defined $stored_data)
    {
	#! note that split automatically removes empty strings, so 'empty' is
	#! a place-holder for an empty string.

	#t I could probably better replace this with a 'x' operator in list
	#t context.

	$stored_data = join ":", map 'empty', 1..4;
    }

#     print STDERR Dumper($stored_data), "\n";

    my @stored_parts = split /:/, $stored_data;

#     print STDERR Dumper(\@stored_parts), "\n";

    # figure out for which part of the key we were called

    $path =~ /${separator}([1-8])$/;

    # fill in the new value

    $stored_parts[$1 - 1] = $value;

    # compute the new (possibly partial) ip address

#     print STDERR Dumper(\@stored_parts), "\n";

    my $result_value = join ":", @stored_parts;

    return($result_path, $result_value);
}


sub _decapsulate_rf_frequency
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _encapsulate_ip_address
{
    my ($self, $path, $column, $contents, $options) = @_;

    print STDERR "_encapsulate_ip_address\n";

    my $separator = $self->{separator} || '_';

    if (defined $contents
	&& $contents =~ /([0-9]{0,3})\.([0-9]{0,3})\.([0-9]{0,3})\.([0-9]{0,3})/)
    {
	local $_;

	my $str
	    .= join ' . ',
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
			 -maxlength => 3,
			 -name => $name,
			 -override => 1,
			 -size => 3,
			);
		}
		    1..4 ;

	$contents = $str;
    }

    return $contents;
}


sub _encapsulate_rf_frequency
{
    my ($self, $path, $column, $contents, $options) = @_;

    print STDERR "_encapsulate_rf_frequency() options :\n", Dumper($options);

    if (!$options->{'-onchange'})
    {
	my $separator = $self->{separator} || '_';

	my $validator_name = "field_rf_frequency_validate__$path";

	$validator_name =~ s/-/_/g;
	$validator_name =~ s/\//_/g;

	my $validation_path = "field${separator}$path";

	$self->add_client_side_encapsulator_validator
	    (
	     {
	      label => $options->{label},
	      name => $validator_name,
	      path => $validation_path,
	      type => "rf_frequency",
	     },
	    );

	$options->{'-onchange'} = "javascript:$validator_name('$self->{name}','$validation_path')";
    }

    return $self->_encapsulate_number($path, $column, $contents, $options, @_);
}


sub _encapsulate_url
{
    my ($self, $path, $column, $contents, $options) = @_;

    return "<a href='" . $options->{url} . "'>$contents</a>";
}


FormLibrary::FormType::Encapsulators::Library::Standard::configure(__PACKAGE__);


