#!/usr/bin/perl -w
#


package Poetical::FormType::Encapsulators::Library::Standard;


use strict;


use Data::Dumper;

use Poetical::FormType::Encapsulators::Logic::Library::Standard;
use Poetical::FormType::Encapsulators::Validators::Library::Standard;

require Poetical::FormType::Encapsulators::Library::ACS;
require Poetical::FormType::Encapsulators::Library::Satcom;
require Poetical::FormType::Encapsulators::Library::Sems;
require Poetical::FormType::Encapsulators::Library::Telecom;
require Poetical::FormType::Encapsulators::Library::Webmin::Net;


sub _decapsulate_boolean_on_off
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_boolean_yes_no
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_checkbox
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    # CGI passes true values back as the empty string

    if ($value eq '')
    {
	# so we replace that with a perl true value

	$value = 1;
    }

    #t but unchecked checkboxes are not passed through at all
    #t so this code is never reached.

    else
    {
	$value = 0;
    }

    return($path, $value);
}


sub _decapsulate_constant
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_optional_textfield
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    #t do stuff to separate radios and textfield

    return($path, $value);
}


sub _decapsulate_radiogroup
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    die "This is not supported yet.";

    return($path, $value);
}


sub _decapsulate_textarea
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _decapsulate_textfield
{
    my ($self, $path, $column, $contents, $value, $options) = @_;

    return($path, $value);
}


sub _encapsulate_boolean_on_off
{
    my ($self, $path, $column_number, $content, $options) = @_;

    my $separator = $self->{separator} || '_';

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -default => $content,
	     -id => "field${separator}$path",
	     -name => "field${separator}$path",
	     -labels => {
			 1 => 'On',
			 0 => 'Off',
			},
	     -override => 1,
	     -values => [ 1, 0, ],
	    );
}


sub _encapsulate_boolean_yes_no
{
    my ($self, $path, $column_number, $content, $options) = @_;

    my $separator = $self->{separator} || '_';

    # prevent rendering the units

    delete $options->{gui_units};

    return
	$self->{CGI}->popup_menu
	    (
	     -default => $content,
	     -id => "field${separator}$path",
	     -name => "field${separator}$path",
	     -labels => {
			 1 => 'Yes',
			 0 => 'No',
			},
	     -override => 1,
	     -values => [
			 '1',
			 '0',
			],
	    );
}


sub _encapsulate_button
{
    my ($self, $path, $column, $contents, $options) = @_;

    my %arglist = (
		   -name => "button_$path",
		   -id => "button_$path",
		  );

    # for style

    if ($options->{style})
    {
	$arglist{'-style'} = $options->{style};
    }

    # for name

    if ($options->{value})
    {
	$arglist{'-value'} = $options->{value};
    }

    # for action

    if ($options->{action})
    {
	# pass on given value, '0' means same as content size.

	$arglist{'-action'} = $options->{action};
    }

    $contents = $self->{CGI}->submit(%arglist);

    if (defined $contents)
    {
	return $contents;
    }
    else
    {
	return '&nbsp;';
    }
}


sub _encapsulate_checkbox
{
    my ($self, $path, $column, $contents, $options) = @_;

    my $separator = $self->{separator} || '_';

    return
	$self->{CGI}->checkbox
	    (
	     -checked => $contents,
	     -id => "checkbox${separator}$path",
	     -label => '',
	     -name => "checkbox${separator}$path",
	     -value => '',
	    );
}


sub _encapsulate_constant
{
    my ($self, $path, $column, $contents, $options) = @_;

    if (defined $contents)
    {
	return $contents;
    }
    else
    {
	return '&nbsp;';
    }
}


sub _encapsulate_number
{
    my ($self, $path, $column, $contents, $options) = @_;

    print STDERR "_encapsulate_number() options :\n", Dumper($options);

    my $separator = $self->{separator} || '_';

    if (!%$options)
    {
	if ($contents =~ /^[-0-9\.eE]+$/)
	{
	    $contents = sprintf "%.1f", $contents;
	}
    }

    if (!$options->{'-onchange'})
    {
	my $validator_name = "field_number_validate__$path";

	$validator_name =~ s/-/_/g;
	$validator_name =~ s/\//_/g;

	my $validation_path = "field${separator}$path";

	$self->add_client_side_encapsulator_validator
	    (
	     {
	      label => $options->{label},
	      name => $validator_name,
	      path => $validation_path,
	      type => "number",
	     },
	    );

	$options->{'-onchange'} = "javascript:$validator_name('$self->{name}','$validation_path')";
    }

    $contents
	= $self->{CGI}->textfield
	    (
	     -default => $contents,
	     -id => "field${separator}$path",
	     -name => "field${separator}$path",
	     -override => 1,
	     %$options,
	    );

    if (defined $contents)
    {
	return $contents;
    }
    else
    {
	return '&nbsp;';
    }
}


sub _encapsulate_optional_textfield
{
    my ($self, $path, $column, $value, $options) = @_;

    my $separator = $self->{separator} || '_';

    print STDERR "_encapsulate_optional_textfield options :\n", Dumper($options);

    my $textfield_path = "field${separator}$path";

    if (!$options->{'-onchange'})
    {
	my $validator_name = "field_optional_textfield_validate__$path";

	$validator_name =~ s/-/_/g;
	$validator_name =~ s/\//_/g;

	$self->add_client_side_encapsulator_logic
	    (
	     {
	      label => $options->{label},
	      name => $validator_name,
	      path => $textfield_path,
	      type => "optional_textfield_disabler",
	     },
	    );

	$options->{'-onchange'} = "javascript:$validator_name('$self->{name}','$textfield_path')";
    }

    $options->{attributes}->{default}->{'id'} = "optional_textfield_radio_default${separator}$path";
    $options->{attributes}->{default}->{'onchange'} = $options->{'-onchange'};

    $options->{attributes}->{textfield}->{'id'} = "optional_textfield_radio_textfield${separator}$path";
    $options->{attributes}->{textfield}->{'onchange'} = $options->{'-onchange'};

    my $contents
	= $self->{CGI}->radio_group
	    (
	     -attributes => $options->{attributes},
	     -default => 'default',
	     -labels => $options->{labels} || { 'default' => 'Use default', textfield => 'Use this value :', },
	     -name => "optiongroup${separator}$path",
	     -values => [ 'default', 'textfield', ],
	    );

    $contents
	.= $self->{CGI}->textfield
	    (
	     -default => $value,
	     -id => $textfield_path,
	     -name => $textfield_path,
	     -override => 1,
# 	     %$options,
	    );

    return $contents;
}


sub _encapsulate_radiogroup
{
    my ($self, $path, $column, $value, $options) = @_;

    my $separator = $self->{separator} || '_';

    print STDERR "_encapsulate_radiogroup options :\n", Dumper($options);

    my $contents
	= $self->{CGI}->radio_group
	    (
	     -attributes => $options->{attributes},
	     -default => $value,
	     -id => "radiogroup${separator}$path",
	     -labels => $options->{labels},
	     -name => "radiogroup${separator}$path",
	     -values => $options->{values},
	    );

    return $contents;
}


sub _encapsulate_textarea
{
    my ($self, $path, $column, $contents, $options) = @_;

    my $separator = $self->{separator} || '_';

    print STDERR "_encapsulate_textarea options :\n", Dumper($options);

    $contents
	= $self->{CGI}->textarea
	    (
	     -default => $contents,
	     -id => "field${separator}$path",
	     -name => "field${separator}$path",
	     -override => 1,
	     %$options,
	    );

    return $contents;
}


sub _encapsulate_textfield
{
    my ($self, $path, $column, $contents, $options) = @_;

    my $separator = $self->{separator} || '_';

    my $size = length $contents;

    my %arglist = (
		   -default => $contents,
		   -id => "field${separator}$path",
		   -name => "field${separator}$path",
		   -override => 1,
		  );

    if (
	!$options->{'-onchange'}
        && $options->{validation}->{mandatory}
       )
    {
	my $validator_name = "field_textfield_validate__$path";

	$validator_name =~ s/-/_/g;
	$validator_name =~ s/\//_/g;

	my $validation_path = "field${separator}$path";

	$self->add_client_side_encapsulator_validator
	    (
	     {
	      label => $options->{label},
	      name => $validator_name,
	      path => $validation_path,
	      type => "mandatory_textfield",
	     },
	    );

	$options->{'-onchange'} = "javascript:$validator_name('$self->{name}','$validation_path')";

	delete $options->{validation};
    }

    # for maxlength

    if (exists $options->{maxlength})
    {
	# pass on given value, '0' means same as content size.

	if ($options->{maxlength})
	{
	    $arglist{'-maxlength'} = $options->{maxlength};
	}
	else
	{
	    $arglist{'-maxlength'} = $size;
	}
    }

    # or

    else
    {
	# the default is equal to the size or 30 as legacy from the old
	# TableFormType implementation.

	$arglist{'-maxlength'} = 30;
    }

    if (exists $options->{size})
    {
	if ($options->{size} == 0)
	{
	    $arglist{'-size'} = $size;
	}
	else
	{
	    $arglist{'-size'} = $options->{size};
	}
    }
    else
    {
	#t this default is legacy from the old implementation of the
	#t TableFormType.  It is repeated by the calibration/device variables
	#t (last row that allows to add new constants.)

	$arglist{'-size'} = 10;
    }

    %arglist = ( %arglist, %$options, );

    %arglist = map { $_ => $arglist{$_}; } grep { /^-/; } keys %arglist;

    print STDERR "Textfield options :\n", Dumper(\%arglist);

    $contents = $self->{CGI}->textfield(%arglist);

    return $contents;
}


sub configure
{
    my $result = 1;

    no strict "refs";

    my $package = shift;

    foreach my $sub (keys %{"${package}::"})
    {
	if ($sub =~ /^(_encapsulate|_decapsulate)/)
	{
	    no strict "refs";

	    *{"Poetical::FormType::Encapsulators::$sub"} = \&{"${package}::$sub"};
	}
    }

    return $result;
}


configure(__PACKAGE__);


