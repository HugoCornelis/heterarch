#!/usr/bin/perl -w
#

package Poetical::FormType;


use strict;


use CGI;

use Data::Dumper;


#
# The document framework contains a set of modules to ease generation of forms
# (mostly HTML forms) with editable fields from a data set.
#
# This module gives the core of the document framework.  It gives the
# following separate services :
#
# 1. A set of method calls to encapsulate data with a chosen functionality,
# e.g. to encapsulate an IP address with four editable boxes.
#
# 2. A set of method calls that encapsulate the content of a single document
# with a form, and if needed, with buttons allowing to submit data, restore
# the factory settings, etc.
#
# 3. A set of method calls to process the input from a CGI submit
# post.  This processing basically falls apart in a parse of the
# input, a decapsulation (the opposite of encapsulation), a
# detransformation if any (the opposite of a transformation, see
# Poetical::Transform), and finally a merge of the resulting data
# into the original data.
#
# 4. A set of miscellaneous method calls.  A the time of writing only the
# .*empty.* set of calls.
#
# Modules on top of FormType are StaticFormType and LogFormType.  Application
# oriented modules using FormType are TableFormType and TreeFormType.
#


sub AUTOLOAD
{
    no strict;

    my $method = $AUTOLOAD;

    use Poetical::FormType::Encapsulators::Library::Standard;

    local ($1,$2);

    $method =~ /(.+)::([^:]+)$/;

    my ($package, $method_name) = ($1, $2);

    #! fixes obscure problems, taken over from autoload of CGI.

    $package =~ s/::SUPER$//;

    if ($method_name =~ /^(_encapsulate|_decapsulate)/)
    {
	my $sub = "Poetical::FormType::Encapsulators::$method_name";

	goto &$sub;
    }
}


sub add_client_side_encapsulator_logic
{
    my $self = shift;

    my $options = shift;

    my $logic_name = $options->{name};

    my $type = $options->{type};

    my $label = $options->{label} || $logic_name;

    my $path = $options->{path};

    my $logic_generator = "Poetical::FormType::Encapsulators::Logic::$type";

    my $logic;

    {
	no strict "refs";

	$logic = &$logic_generator($self, $logic_name, $label, $path, );
    }

    $self->encapsulator_logic_add
        (
	 {
	  $logic_name => $logic,
	 },
	);
}


sub add_client_side_encapsulator_validator
{
    my $self = shift;

    my $options = shift;

    my $validator_name = $options->{name};

    my $type = $options->{type};

    my $label = $options->{label} || $validator_name;

    my $path = $options->{path};

    my $validator_generator = "Poetical::FormType::Encapsulators::Validators::$type";

    my $validator;

    {
	no strict "refs";

	$validator = &$validator_generator($self, $validator_name, $label, $path, );
    }

    $self->encapsulator_validator_add
        (
	 {
	  $validator_name => $validator,
	 },
	);
}


sub add_client_side_application_validator
{
    my $self = shift;

    my $validator_template = shift;

    my $separator = $self->{separator} || '_';

    my $validator_name = "application_validator_$self->{name}_$validator_template->{name}";

    $validator_name =~ s/-/_/g;
    $validator_name =~ s/\//_/g;

    #t remove this writing into possibly private data (comes from the module)

    $validator_template->{validator_name} = $validator_name;

    my $positive_assertion = $validator_template->{positive_assertion};

    my $condition = $positive_assertion;

    # construct an if statement from the sesa script

    $condition =~ s/%%([^%]+)%%/document.getElementById('field${separator}$self->{name}${separator}$1').value/g;

    # get name of element that should receive the focus if the validation failed

    my $focus_element = "field${separator}$self->{name}${separator}" . ($validator_template->{focus_element} || $1);

    # construct a javascript function using the condition

#     var value1 = document.getElementById('field${separator}$self->{name}${separator}value/create_install').value;

#     var value2 = document.getElementById('field${separator}$self->{name}${separator}value/install_webmin').value;

#     var value3 = (!(value1 == 1)) && (value2 == 1);

#     alert('document.getElementById(field${separator}$self->{name}${separator}value/create_install.value)' + value1);

#     alert('document.getElementById(field${separator}$self->{name}${separator}value/install_webmin.value)' + value2);

#     alert('boolean 3 ' + value3);

    my $script = "
function $validator_name(form_name)
{
    if (!($condition))
    {
	alert('Application logic failed : $validator_template->{description}');

	var element = document.getElementById('$focus_element');

	element.focus();

	// if this input element has a select method

	//! this does not protect if there is an property .select with value true.

	if (element.select)
	{
	    // call the select method

	    element.select();
	}

	return false;
    }
    else
    {
	return true;
    }
}

";

# 	alert('Application logic succeeded for $validator_name');

    #t remove this writing into possibly private data (comes from the module)

    $validator_template->{script} = $script;
}


sub commands
{
    my $self = shift;

    my $parameters = shift;

    my $commands = [ grep { /^submit_[^_]*/ } keys %$parameters, ];

    if (@$commands > 1)
    {
	print STDERR "FormType error: more than one submit in CGI parameters\n";

	$self->register_error("more than one submit in CGI parameters");
    }

    foreach my $command (@$commands)
    {
	print STDERR "FormType command $command\n";

	# figure out the name of the form in case we are dealing with shared forms

	my $name = $command;

	$name =~ s/^submit_//;

	my $code = $self->{commands}->{$name};

	if ($code)
	{
	    &$code($self);
	}
    }

    # return : continue processing

    return 0;
}


sub encapsulate_end
{
    my ($self, $path, $row, $column, $contents, $options) = @_;

    my $separator = $self->{separator} || '_';

    my $result = "";

    $result .= '<td style="border-left-style: hidden">';

    if (exists $options->{gui_units}
	&& $options->{gui_units})
    {
	delete $options->{validation};

	my %arglist = (
		       -id => "units${separator}$path",
		       -name => "units${separator}$path",
		      );

	%arglist = ( %arglist, %$options, );

	%arglist = map { $_ => $arglist{$_}; } grep { /^-/; } keys %arglist;

	use Data::Dumper;

	print STDERR "Units options :\n", Dumper(\%arglist);

	$result .= $self->{CGI}->span($options, ' &nbsp;' . " ($options->{gui_units})");
    }

    $result .= '</td>';

#     if (exists $options->{center}
#         && $options->{center})
#     {
# 	$result .= '</center>';
#     }

#     $result .= " &nbsp;";

    return $result;
}


sub encapsulate_start
{
    my ($self, $path, $row, $column, $contents, $options) = @_;

    my $result = '';

#     my $result = ' &nbsp;';

#     if (exists $options->{center}
#         && $options->{center})
#     {
# 	$result .= '<center>';
#     }

    return $result;
}


sub encapsulator_logic_add
{
    my $self = shift;

    my $logicians = shift;

    if (!$self->{encapsulator_logicians})
    {
	$self->{encapsulator_logicians} = {};
    }

    $self->{encapsulator_logicians}
	= {
	   %$logicians,
	   %{$self->{encapsulator_logicians}},
	  };
}


sub encapsulator_validator_add
{
    my $self = shift;

    my $validators = shift;

    if (!$self->{encapsulator_validators})
    {
	$self->{encapsulator_validators} = {};
    }

    $self->{encapsulator_validators}
	= {
	   %$validators,
	   %{$self->{encapsulator_validators}},
	  };
}


sub formalize_content
{
    my $self = shift;

    my $str = '';

    if ($self->{registered_errors})
    {
	print STDERR "FormType $self->{name}: errors found\n";
    }
    else
    {
	print STDERR "FormType $self->{name}: no errors found\n";
    }

    if ($self->can('form_info_start'))
    {
	print STDERR "FormType formalize $self->{name} : start\n";
	$self->form_info_start();
    }

    if ($self->can('form_info_header'))
    {
	print STDERR "FormType formalize $self->{name} : header\n";
	$self->form_info_header();
    }

    if ($self->can('form_info_contents'))
    {
	print STDERR "FormType formalize $self->{name} : contents\n";
	$self->form_info_contents();
    }

    if ($self->can('form_info_end'))
    {
	print STDERR "FormType formalize $self->{name} : end\n";
	$self->form_info_end();
    }

    if ($self->{registered_errors})
    {
	print STDERR "FormType $self->{name}: writing errors\n";

	foreach (@{$self->{registered_errors}})
	{
	    print STDERR "Writing $_\n";

	    $self->writer($_);
	}
    }
}


# my $sems_config = do "/var/sems/sems.config";

# my $sesa_config = $sems_config->{sesa};


sub formalize
{
    my $self = shift;

    my $query = $self->{CGI};

    my $referer =  $ENV{HTTP_REFERER};

#     #t counterpart of Poetical::Workflow processing, centralized abstraction needed.

#     $referer =~ s/;/\\;/g;

#     my $document_history = $query->param("document_history");

#     if (!defined $document_history)
#     {
# 	$document_history = $referer;
#     }
#     else
#     {
# 	$document_history .= ";" . $referer;
#     }

    if (exists $self->{workflow})
    {
	my $workflow = $self->{workflow}->{actor};

	my $header_options = $self->{workflow}->{configuration}->{header};

	if ($header_options)
	{
# 	    my $str = $workflow->header($header_options, '', $document_history);

# 	    $self->writer($str);
	}
    }

    if ($self->{output_mode} =~ /html/)
    {
	$self->writer('<center>');

	if (exists $self->{header})
	{
	    # construct anchor for linking

	    my $header = "<a name='$self->{name}'>";

	    $header .= $query->h2($self->{header});

	    $header .= "</a>";

# 	    # add module site specific header configuration

# 	    my $module_name = "calibration";

# 	    my $module_config = $sesa_config->{module_config}->{$module_name};

# 	    my $site_headers = $module_config->{$self->{name}}->{header};

# 	    if ($site_headers)
# 	    {
# 		foreach my $site_header (@$site_headers)
# 		{
# 		    my $ref = ref $site_header;

# 		    if ($ref =~ /CODE/)
# 		    {
# 			#t calling conventions to be defined.

# 			$header = &$site_header($self, $header);
# 		    }
# 		    else
# 		    {
# 			$header .= $site_header;
# 		    }
# 		}
# 	    }

	    $self->writer($header);
	}

	my $action;

	if (exists $self->{action})
	{
	    $action = $self->{action};
	}
	else
	{
	    $action = '';
	}

	my $submit_logician = $self->logician_name_submit();

	my $submit_validator = $self->validator_name_submit();

	my $validator = "return ($submit_logician(this) && $submit_validator(this))";

	if ($self->{form} ne 'shared')
	{
	    $self->writer
		(
		 $query->start_form(
				    -action => $action,
				    -method => "post",
				    -name => $self->{name},
				    -onsubmit => $validator,
				   )
		);
	}
    }

    if ($self->{output_mode} =~ /html/)
    {
	# formalize the history

	my $separator = $self->{separator} || '_';

# 	$self->writer
# 	    (
# 	     $query->hidden
# 	     (
# 	      -name => "document_history",
# 	      -default => $document_history,
# 	      -override => 1,
# 	     )
# 	    );

	# formalize the hidden state information

	if (exists $self->{hidden})
	{
	    my $hidden_text = '';

	    foreach my $hidden (keys %{$self->{hidden}})
	    {
		$hidden_text
		    .= $query->hidden
			(
			 -name => $hidden,
			 -default => $self->{hidden}->{$hidden},
			 -override => 1,
			);
	    }

	    if ($hidden_text)
	    {
		$self->writer($hidden_text);
	    }
	}
    }

    if ($self->{output_mode} =~ /html/)
    {
	$self->writer("\n<p>");

	if ($self->{has_front_reset})
	{
	    $self->writer($query->reset() . ' &nbsp; ');
	}

	if ($self->{has_front_submit})
	{
	    $self->writer
		(
		 $query->submit(
				-name => "submit_$self->{name}",
				-value => ($self->{has_front_submit} ne '1' ? $self->{has_front_submit} : ' Submit Changes '),
			       )
		 . " &nbsp; "
		);
	}

	if ($self->{has_front_factory})
	{
	    $self->writer
		(
		 $query->submit(
				-name  => "factory_$self->{name}",
				-value => ' Restore Factory Settings ',
			       )
		 . " &nbsp; "
		);
	}

	if ($self->{has_front_factory_writer})
	{
	    $self->writer
		(
		 $query->submit(
				-name  => "factorywrite_$self->{name}",
				-value => ' Write Factory Settings ',
			       )
		 . " &nbsp; "
		);
	}

	$self->writer("\n<p>");
    }

    # formalize the real content

    $self->formalize_content();

    if ($self->{output_mode} =~ /html/)
    {
	$self->writer("\n<p>");

	if ($self->{has_reset})
	{
	    $self->writer($query->reset() . ' &nbsp; ');
	}

	if ($self->{has_submit})
	{
	    $self->writer
		(
		 $query->submit(
				-name => "submit_$self->{name}",
				-value => ($self->{has_submit} ne '1' ? $self->{has_submit} : ' Submit Changes '),
			       )
		 . " &nbsp; "
		);
	}

	if ($self->{has_factory})
	{
	    $self->writer
		(
		 $query->submit(
				-name  => "factory_$self->{name}",
				-value => ' Restore Factory Settings ',
			       )
		 . " &nbsp; "
		);
	}

	if ($self->{has_factory_writer})
	{
	    $self->writer
		(
		 $query->submit(
				-name  => "factorywrite_$self->{name}",
				-value => ' Write Factory Settings ',
			       )
		 . " &nbsp; "
		);
	}

	$self->writer("\n<p>");
    }

    if ($self->{output_mode} =~ /html/)
    {
	if ($self->{form} ne 'shared')
	{
	    $self->writer($query->end_form());
	}

	$self->writer('</center>');

	$self->logicians_write();

	$self->validators_write();
    }

    if (!$self->is_empty())
    {
	$self->flush();

	print STDERR "FormType Formalized $self->{name}\n";
    }
    else
    {
	print STDERR "Did not FormType formalize $self->{name} : empty\n";
    }

}


sub is_empty
{
    return($_[0]->{is_empty});
}


sub logician_name_submit
{
    my $self = shift;

    my $result = "form_logician_$self->{name}";

    # remove minus signs, not allowed by javascript

    $result =~ s/-/_/g;
    $result =~ s/\//_/g;

    return $result;
}


sub logicians_write
{
    my $self = shift;

    $self->writer("\n\n<script language='JavaScript'>\n\n");

    my $encapsulator_logicians = $self->{encapsulator_logicians};

    # write all the field logicians

    foreach my $logician (keys %$encapsulator_logicians)
    {
	$self->writer("\n//\n// Java script snippet for encapsulator logician $logician\n//\n\n");

	$self->writer($encapsulator_logicians->{$logician}->{script});
    }

    # write application specific logicians

    my $application_logicians = $self->{application_logicians};

    # generate / write all the application logicians

    foreach my $logician (@$application_logicians)
    {
	$self->writer("\n//\n// Java script snippet for application logician $logician\n//\n\n");

	$self->add_client_side_application_logician($logician);

	$self->writer($logician->{script});
    }

    # write the submit logician

    $self->writer("\n//\n// Java script submit logician for $self->{name}\n//\n\n");

    my $submit_logician_name = $self->logician_name_submit();

    my $submit_logician = '';

    $submit_logician .= "
function $submit_logician_name(form)
{
    var result = true;

";

    foreach my $logician (keys %$encapsulator_logicians)
    {
	my $logician_name = $encapsulator_logicians->{$logician}->{name};

	my $validation_path = $encapsulator_logicians->{$logician}->{path};

	$submit_logician .= "

    if (result)
    {
	result = $logician_name('$self->{name}','$validation_path');
    }
";
    }

    foreach my $logician (@$application_logicians)
    {
	my $logician_name = $logician->{logician_name};

	$submit_logician .= "

    if (result)
    {
	result = $logician_name('$self->{name}');
    }
";
    }

    $submit_logician .= "

    return result;

}";

    $self->writer($submit_logician);

    $self->writer("\n\n</script>\n\n");
}


#
# Merge data, constructed by ->parse_input(), into the contents of the
# document.  After this operation the document can be written to its
# persistent storage.
#

sub merge_data
{
    my $self = shift;

    my $data = shift;

    my $contents = $self->{contents};

    print STDERR "Merge data : \n";
    print STDERR Dumper($data);

    # if a submit for this document has been done.

#     if ($data->{cmd}->{action} eq 'submit'
#         && $data->{cmd}->{request} eq $self->{name})
    {
	# copy the detransformed values into the contents data.

	#
	# subs to merge two datastructures.
	#

	local $Poetical::FormType::data_merger_any
	    = sub
	      {
		  my $contents = shift;

		  my $data = shift;

		  # simply check what kind of data structure we are dealing
		  # with and forward to the right sub.

		  my $type = ref $contents;

		  if ($type eq 'HASH')
		  {
		      &$Poetical::FormType::data_merger_hash($contents, $data);
		  }
		  elsif ($type eq 'ARRAY')
		  {
		      &$Poetical::FormType::data_merger_array($contents, $data);
		  }
		  else
		  {
		      print STDERR "FormType error: data_merger_any encounters an unknown data type $type\n";

		      $self->register_error("data_merger_any encounters an unknown data type $type");
		  }
	      };

	local $Poetical::FormType::data_merger_hash
	    = sub
	      {
		  my $contents = shift;

		  my $data = shift;

		  # loop over all values in the contents hash.

		  foreach my $section (keys %$data)
		  {
		      if (exists $contents->{$section})
		      {
			  my $value = $data->{$section};

			  my $contents_type = ref $contents->{$section};
			  my $value_type = ref $value;

			  if ($contents_type && $value_type)
			  {
			      if ($contents_type eq $value_type)
			      {
				  # two references of the same type, go one
				  # level deeper.

				  &$Poetical::FormType::data_merger_any($contents->{$section}, $value);
			      }
			      else
			      {
				  print STDERR "FormType error: contents_type is '$contents_type' and does not match with value_type $value_type\n";

				  $self->register_error("contents_type is '$contents_type' and does not match with value_type $value_type");
			      }
			  }
			  elsif (!$contents_type && !$value_type)
			  {
			      # copy scalar value

			      $contents->{$section} = $value;
			  }
			  else
			  {
			      print STDERR "FormType error: contents_type is '$contents_type' and does not match with value_type $value_type\n";

			      $self->register_error("contents_type is '$contents_type' and does not match with value_type $value_type");
			  }
		      }
		      else
		      {
			  #t could be a new key being added.
		      }
		  }
	      };

	local $Poetical::FormType::data_merger_array
	    = sub
	      {
		  my $contents = shift;

		  my $data = shift;

		  # loop over all values in the contents array.

		  my $count = 0;

		  foreach my $section (@$data)
		  {
		      if (exists $contents->[$count])
		      {
			  my $value = $data->[$count];

			  my $contents_type = ref $contents->[$count];
			  my $value_type = ref $value;

			  if ($contents_type && $value_type)
			  {
			      if ($contents_type eq $value_type)
			      {
				  # two references of the same type, go one
				  # level deeper.

				  &$Poetical::FormType::data_merger_any($contents->{$section}, $value);
			      }
			      else
			      {
				  print STDERR "FormType error: contents_type is '$contents_type' and does not match with value_type $value_type\n";

				  $self->register_error("contents_type is '$contents_type' and does not match with value_type $value_type");
			      }
			  }
			  elsif (!$contents_type && !$value_type)
			  {
			      # copy scalar value

			      $contents->[$count] = $value;
			  }
			  else
			  {
			      print STDERR "FormType error: contents_type is '$contents_type' and does not match with value_type $value_type\n";

			      $self->register_error("contents_type is '$contents_type' and does not match with value_type $value_type");
			  }
		      }
		      else
		      {
			  #t could be a new key being added.
		      }

		      $count++;
		  }
	      };

	#t Should actually use a simple iterator over the detransformed data
	#t that keeps track of examined paths.  Then use the path to store
	#t encountered value in the original data.

	#t Note that the iterator is partly implemented in Poetical::Transform and
	#t Poetical::TreeFormType.  A further abstraction could be useful.

	# first inductive step : merge all data.

	&$Poetical::FormType::data_merger_hash($contents, $data->{detransformed});
    }

    # if a regular button has been pressed

    if ($data->{cmd}->{action} eq 'button')
    {
	# get a handle to the action to perform

	my $button_name = $data->{button}->{request};
	$button_name =~ s/^$self->{name}_//;
	my $action = $self->{button_actions}->{$button_name};

	# act on button

	print STDERR "FormType $self->{name}: calls button action for $button_name\n";

	if ($action)
	{
	    $contents = &$action($self, $data->{button}->{request}, $contents, );
	}
	else
	{
	    print STDERR "FormType $self->{name}: button action for $button_name is not defined\n";
	}
    }

    # if the factory button has been pressed

    if ($data->{cmd}->{action} eq 'factory')
    {
	# figure out section

	my $section = $data->{cmd}->{request};

	# get a handle to the action to perform

	my $action = $self->{factory_actions}->{$section};

	# act to restore factory settings

	print STDERR "FormType $self->{name}: calls factory settings restorer for $section\n";

	if ($action)
	{
	    $contents = &$action($self, $section, $contents, );
	}
	else
	{
	    print STDERR "FormType $self->{name}: factory action for $section is not defined\n";
	}
    }

    # if the regular submit button has been pressed

    if ($data->{cmd}->{action} eq 'submit')
    {
	# figure out section

	my $section = $data->{cmd}->{request};

	# get a handle to the action to perform

	my $action = $self->{submit_actions}->{$section};

	# act to submit new settings

	print STDERR "FormType $self->{name}: calls submit new settings for $section\n";

	if ($action)
	{
	    $contents = &$action($self, $section, $contents, );
	}
	else
	{
	    print STDERR "FormType $self->{name}: submit new settings for $section is not defined\n";
	}
    }

    print STDERR "FormType $self->{name} contents is now :\n";
    print STDERR Dumper($contents);

    $self->{contents} = $contents;
}


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %options = @_;
    my $self = {};

    foreach my $key (keys %options)
    {
	$self->{$key} = $options{$key};
    }

    if ($self->{name} =~ /_/
        or $self->{name} =~ m|/|)
    {
	print STDERR "FormType Error: FormType names must not contain an '_' or a '/'\n";

	my (
	    $package,
	    $filename,
	    $line,
	    $subroutine,
	    $hasargs,
	    $wantarray,
	    $evaltext,
	    $is_require,
	    $hints,
	    $bitmask
	   )
	    = caller(1);

	print STDERR "FormType Error: at $filename:$line, $subroutine\n";

	require Carp;

	Carp::cluck "FormType Error: at $filename:$line, $subroutine\n";
    }

    bless ($self, $class);

    $self->set_is_empty();

#     print STDERR Data::Dumper::Dumper($self);

    return $self;
}


#
# parameter()
#
# Basically a Poetical::FormType specific frontend to CGI::param().
#

sub parameter
{
    my $self = shift;

    my $type = shift;

    my $parameter_name = shift;

    my $document_name = $self->{name};

    my $separator = $self->{separator} || '_';

    $parameter_name = "${type}${separator}${document_name}${separator}${parameter_name}";

    my $value = $self->{CGI}->param($parameter_name);

    print STDERR "Obtained $parameter_name\n", Dumper($value);

    #t could do sanity checking here : numeric value for numeric type etc.

    return $value;
}


#
# parameter_path()
#
# Basically a Poetical::FormType specific frontend to CGI::param().
#

sub parameter_path
{
    my $self = shift;

    my $type = shift;

    my $parameter_name = shift;

    my $query_params = shift;

    my $document_name = $self->{name};

    my $separator = $self->{separator} || '_';

    $parameter_name = "${type}${separator}${document_name}${separator}${parameter_name}";

    my $value = $query_params->{$parameter_name};

    print STDERR "Obtained $parameter_name\n", Dumper($value);

    #t could do sanity checking here : numeric value for numeric type etc.

    return $value;
}


sub parse_buttons
{
    my $self = shift;

    my $result = shift;

    # fetch CGI parameters

    my $query = $self->{CGI};

    my @query_params = $query->param();

    # figure out the pressed button

    my @buttons = grep(/^button_[^_]*/, @query_params);

    if (@buttons > 1)
    {
	print STDERR "FormType error: more than one button in CGI parameters\n";

	$self->register_error("more than one button in CGI parameters");
    }

    foreach my $button (@buttons)
    {
	print STDERR "FormType button is $button\n";

	# fill in requested action

	$result->{cmd}->{action} = 'button';
	$result->{button} = {};
	$result->{button}->{request} = $button ;
	$result->{button}->{request} =~ s/^button_//;
    }

    # return : continue processing

    return 0;
}


sub parse_factory
{
    my $self = shift;

    my $result = shift;

    # fetch CGI parameters

    my $query = $self->{CGI};

    my @query_params = $query->param();

    # if factory settings request

    my @factory = grep(/^factory_[^_]*/, @query_params);

    if (@factory > 0)
    {
	my $factory_request = pop @factory;

	# fill in the requested action

	$result->{cmd} = {};
	$result->{cmd}->{action} = 'factory';
	$result->{cmd}->{request} = $factory_request;
	$result->{cmd}->{request} =~ s/^factory_//;

	# and return : factory button pressed

	return 1;
    }

    # return : no factory button pressed

    return 0;
}


sub parse_submits
{
    my $self = shift;

    my $result = shift;

    # fetch CGI parameters

    my $query = $self->{CGI};

    my @query_params = $query->param();

    # figure out the submitted section

    my @submit = grep(/^submit_[^_]*/, @query_params);

    if (@submit > 1)
    {
	print STDERR "FormType error: more than one submit in CGI parameters\n";

	$self->register_error("more than one submit in CGI parameters");
    }

    foreach my $key (@submit)
    {
	print STDERR "FormType request is $key\n";

	# fill in requested action

	$result->{cmd} = {};
	$result->{cmd}->{action} = 'submit';
	$result->{cmd}->{request} = $key ;
	$result->{cmd}->{request} =~ s/^submit_//;
    }

    # return : continue processing

    return 0;
}


sub register_error
{
    my $self = shift;

    my $error = shift;

    if (!$self->{registered_errors})
    {
	$self->{registered_errors} = [];
    }

    push @{$self->{registered_errors}}, $error;

    print STDERR "FormType $self->{name}: Registered errors are now ", Dumper($self->{registered_errors});
}


sub set_not_empty
{
    $_[0]->{is_empty} = 0;
}


sub set_is_empty
{
    $_[0]->{is_empty} = 1;
}


sub validator_name_submit
{
    my $self = shift;

    my $result = "form_validator_$self->{name}";

    # remove minus signs, not allowed by javascript

    $result =~ s/-/_/g;
    $result =~ s/\//_/g;

    return $result;
}


sub validators_write
{
    my $self = shift;

    $self->writer("\n\n<script language='JavaScript'>\n\n");

    my $encapsulator_validators = $self->{encapsulator_validators};

    # write all the field validators

    foreach my $validator (keys %$encapsulator_validators)
    {
	$self->writer("\n//\n// Java script snippet for encapsulator validator $validator\n//\n\n");

	$self->writer($encapsulator_validators->{$validator}->{script});
    }

    # write application specific validators

    my $application_validators = $self->{application_validators};

    # generate / write all the application validators

    foreach my $validator (@$application_validators)
    {
	$self->writer("\n//\n// Java script snippet for application validator $validator\n//\n\n");

	$self->add_client_side_application_validator($validator);

	$self->writer($validator->{script});
    }

    # write the submit validator

    $self->writer("\n//\n// Java script submit validator for $self->{name}\n//\n\n");

    my $submit_validator_name = $self->validator_name_submit();

    my $submit_validator = '';

    $submit_validator .= "
function $submit_validator_name(form)
{
    var result = true;

";

    foreach my $validator (keys %$encapsulator_validators)
    {
	my $validator_name = $encapsulator_validators->{$validator}->{name};

	my $validation_path = $encapsulator_validators->{$validator}->{path};

	$submit_validator .= "

    if (result)
    {
	result = $validator_name('$self->{name}','$validation_path');
    }
";
    }

    foreach my $validator (@$application_validators)
    {
	my $validator_name = $validator->{validator_name};

	$submit_validator .= "

    if (result)
    {
	result = $validator_name('$self->{name}');
    }
";
    }

    $submit_validator .= "

    return result;

}";

    $self->writer($submit_validator);

    $self->writer("\n\n</script>\n\n");
}


1;


