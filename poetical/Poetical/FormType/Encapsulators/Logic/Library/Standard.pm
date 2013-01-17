#!/usr/bin/perl -w
#

package Poetical::FormType::Encapsulators::Logic::Library::Standard;


use strict;


#
# _logic_optional_textfield_disabler()
#
# Disables the textfield if its radio button is not checked.
#
# Another possibility is to automatically select the radio button of
# the textfield if its contents is changed.
#

sub _logic_optional_textfield_disabler
{
    my $self = shift;

    my $name = shift;

    my $label = shift;

    my $path = shift;

    # construct the name of all related HTML elements

    my $textfield = $path;

    my $default_radio = $path;

    $default_radio =~ s/^field/optional_textfield_radio_default/;

    my $textfield_radio = $path;

    $textfield_radio =~ s/^field/optional_textfield_radio_textfield/;

    #! note : form_path and $path must be the same string, form_path currently not used.

    my $java_script = "
function $name(form_name,sesa_path)
{
    var textfield = document.getElementById('$textfield');

    var default_radio = document.getElementById('$default_radio');

    var textfield_radio = document.getElementById('$textfield_radio');

    if (default_radio.checked)
    {
	textfield.disabled = true;
    }
    else
    {
	textfield.disabled = false;
    }

    return true;
}

";

    my $result
	= {
	   name => $name,
	   path => $path,
	   script => $java_script,
	   type => 'javascript',
	  };

    return $result;
}


sub configure
{
    my $result = 1;

    no strict "refs";

    my $package = shift;

    foreach my $sub (keys %{"${package}::"})
    {
	if ($sub =~ /^(_logic_)/)
	{
	    my $exported_sub = $sub;

	    $exported_sub =~ s/^(_logic_)//;

	    no strict "refs";

	    *{"Poetical::FormType::Encapsulators::Logic::$exported_sub"} = \&{"${package}::$sub"};
	}
    }

    return $result;
}


configure(__PACKAGE__);


