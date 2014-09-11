#!/usr/bin/perl -w
#

package Poetical::TableFormType;


use strict;


use Data::Dumper;

use Poetical::StaticFormType;


our @ISA = ("Poetical::StaticFormType");


sub detransform
{
    my $self = shift;

    my $query_params = shift;

    my $result = {};

    my $separator = $self->{separator} || '_';

#     # if factory settings request

#     if ($self->parse_factory($result))
#     {
# 	# return without further processing

# 	return $result;
#     }

#     # figure out the submitted section

#     if ($self->parse_submits($result))
#     {
# 	return $result;
#     }

#     # figure out the pressed button

#     if ($self->parse_buttons($result))
#     {
# 	return $result;
#     }

#     # if there is nothing to parse for this document

#     #t consolidate 'cmd' with 'button' will remove the indirection on
#     #t the second key (ie. {$result->{cmd}->{action}}).

#     if ($result->{$result->{cmd}->{action}}->{request} !~ /^$self->{name}_/)
#     {
# 	return $result;
#     }

    # the keys that should be handled.

    my $keys_to_handle = [ keys %$query_params, ];

    # loop over the submitted fields

    my $decapsulated;

    #t unchecked checkboxes are not passed through by CGI, so are not
    #t in $query_params.  Perhaps this can be solved by using default
    #t default values ?

    #t loop over all fields from the table format
    #t   assign default value
    #t     perhaps only for certain field types like checkboxes.

    while (scalar @$keys_to_handle)
    {
	my $key = pop @$keys_to_handle;

	if ($key !~ /^field$separator/
	    && $key !~ /^checkbox$separator/)
	{
	    next;
	}

# 	$keys_to_handle++;

	# remove type indicator

# 	$key =~ s/^field$separator//;
	$key =~ s/^([^${separator}]*?)${separator}//;

	my $type = $1;

	# remove name of the document

	$key =~ s/^[^${separator}]*?${separator}//;

	# get name of the column and row

	$key =~ m/^([^${separator}]*?)${separator}(.*)$/;

	my $column_key = $1;

	my $row = $2;

	# find the column in the format

	my $column_number = 0;

	my $format_columns = $self->{format}->{columns};

	foreach my $format_column ( ( @$format_columns, ) )
	{
	    if ($format_column->{key_name})
	    {
		if ($format_column->{key_name} eq $column_key)
		{
		    # fetch the value from CGI

		    my $parameter_name = "${column_key}$separator${row}";

		    my $value = $self->parameter_path($type, $parameter_name, $query_params);

		    # if we have a valid value

		    #! we should not get here with 'undef' values.

		    if (defined $value)
		    {
			# start determining what decapsulator to use

			my $decapsulator;

			# start assembling options for the decapsulator

			my $format_decapsulator_options = $format_column->{encapsulator}->{options} || {};

			my $decapsulator_options
			    = {
			       %$format_decapsulator_options,
			      };

			#t need to do this in a derived class

			print STDERR "column_key is $column_key, columns is " . @{$self->{format}->{columns}} . "\n";

			if (
			    exists $self->{gui_units}->{$row}
			    && scalar @{$self->{format}->{columns}} == 2
			    && $column_number == 1
			   )
			{
			    $decapsulator_options->{gui_units} = $self->{gui_units}->{$row};
			}

			# if the document is not editable

			if (exists $self->{editable}
			    && !$self->{editable})
			{
			    # use the constant decapsulator

			    $decapsulator = "_decapsulate_constant";
			}

			# if there is a regex decapsulator

			my $regex_decapsulator
			    = $self->has_regex_encapsulator("$self->{name}${separator}${column_key}${separator}${row}", $value, );

			if (
			    $regex_decapsulator
			    && !$decapsulator
			   )
			{
			    # use the regex decapsulator with its options

			    my $regex_decapsulator_options = $regex_decapsulator->{encapsulator}->{options} || {};

			    $decapsulator_options
				= {
				   %$decapsulator_options,
				   %$regex_decapsulator_options,
				  };

			    if (exists $regex_decapsulator->{type})
			    {
				$decapsulator = "_encapsulate_$regex_decapsulator->{type}";
			    }
			    elsif (exists $regex_decapsulator->{code})
			    {
				$decapsulator = $regex_decapsulator->{code};
			    }
			}

			# if a type has been defined for this field

			if (
			    $self->{gui_encapsulators}->{$row}
			    && scalar @{$self->{format}->{columns}} == 2
			    && $column_number == 1
			    && !$decapsulator
			   )
			{
			    # use the type decapsulator with its options

			    my $gui_decapsulator = $self->{gui_encapsulators}->{$row};

			    my $gui_decapsulator_options = $gui_decapsulator->{options} || {};

			    $decapsulator_options
				= {
				   %$decapsulator_options,
				   %$gui_decapsulator_options,
				  };

			    if (exists $gui_decapsulator->{type})
			    {
				$decapsulator = "_decapsulate_$gui_decapsulator->{type}";
			    }
			    elsif (exists $gui_decapsulator->{code})
			    {
				$decapsulator = $gui_decapsulator->{code};
			    }

			}

			# default : the field has not been decapsulated yet

			my $is_decapsulated = 0;

			my ($decapsulated_key, $decapsulated_data);

			if ($decapsulator && !$decapsulated)
			{
			    if (!ref $decapsulator)
			    {
				($decapsulated_key, $decapsulated_data)
				    = $self->$decapsulator
					(
					 $key,
					 $row,
					 $column_number,
					 $decapsulated,
					 $value,
					 $decapsulator_options,
					);
			    }
			    elsif (ref $decapsulator eq 'CODE')
			    {
				($decapsulated_key, $decapsulated_data)
				    = $self->_decapsulate_constant
					(
					 $key,
					 $row,
					 $column_number,
					 $decapsulated,
					 $value,
					 $decapsulator_options,
					);
			    }

			    # register that the field has been decapsulated

			    $is_decapsulated = 1;
			}

			# else : do the default type based deapsulation

			if (!$is_decapsulated)
			{
			    # determine the type

			    local $_ = $format_column->{type} eq 'code' ? 'constant' : $format_column->{type};

			    my $decapsulator = "_decapsulate_$_";

			    print STDERR "Entry $row, $column_key == $_ : $decapsulator\n";

			    ($decapsulated_key, $decapsulated_data)
				= $self->$decapsulator
				    (
				     $key,
				     $row,
				     $column_number,
				     $decapsulated,
				     $value,
				     $decapsulator_options,
				    );
			}

			# fill in the entry in the data

			$decapsulated->{$row}->{$column_key} = $decapsulated_data;
		    }
		    else
		    {
			print STDERR "FormType error: CGI key $key does not have a defined value\n";

			$self->register_error("CGI key $key does not have a defined value");
		    }

# 		    # break search loop

# 		    last;
		}
	    }
	    elsif ($self->{format}->{hash_key} eq $column_key)
	    {
		#t not sure, not supported for the moment

		#t Should take the new hash and fill it in the original hash with this value as hash key.
		#t I think this is not possible in the general case.
	    }

	    $column_number++;
	}
    }

    #t apply detransformations

    # fill in the decapsulated data

    $result->{detransformed} = $decapsulated;

    return $result;
}


sub form_info_contents
{
    my $self = shift;

    my $query = $self->{CGI};

    my $str = '';

    my $row_count = 0;

    my $contents = $self->{contents};

    my $separator = $self->{separator} || '_';

    $str .= "<tbody>\n";

    # call the preprocessor

    if (exists $self->{preprocessor})
    {
	my $preprocessor = $self->{preprocessor};

	$contents = $preprocessor->transform($contents);
    }

    if (exists $self->{row_initialize})
    {
	$str .= &{$self->{row_initialize}};
    }

    if (("$contents" =~ /HASH/)
        or ("$contents" =~ /ARRAY/))
    {
	my $row_keys;

	if ("$contents" =~ /HASH/)
	{
	    $row_keys
		= [
		   sort
		   {
		       defined $self->{sort}
			   ? &{$self->{sort}}
			       ($a, $b, $contents->{$a}, $contents->{$b})
				   : -1;
		   }
		   keys %$contents,
		  ];
	}
	else
	{
	    $row_keys = $contents;
	}

	foreach my $row_key (@$row_keys)
	{
	    my $row;

	    if ("$contents" =~ /HASH/)
	    {
		$row = $contents->{$row_key};
	    }
	    else
	    {
		$row = $row_key;

		$row_key = "->[$row_count]";
	    }

	    my $filter_data = 1;

	    if (exists $self->{row_filter})
	    {
		$filter_data = &{$self->{row_filter}}($row_key, $row);
	    }

	    next if !$filter_data;

	    $self->set_not_empty();

	    # call the row inserter if any

	    if ($self->{'row_inserters'})
	    {
		$str .= $self->row_inserter($row_key, );
	    }

	    $str .= "<tr>" ;

	    my $column_number = 0;

	    foreach my $column (@{$self->{format}->{columns}})
	    {
		my $column_key = $column->{key_name};

		$str .= '<td  style="border-right-style: hidden"';

		if (exists $column->{alignment})
		{
		    $str .= "align='$column->{alignment}'";
		}
		else
		{
		    $str .= "align='center'";
		}

		$str .= ">";

		# if we don't have an entry in the hash (column is hashkey)

		my $format_hashkey
		    = exists $self->{format}->{hashkey}
			&& defined $self->{format}->{hashkey}
			    && exists $column->{header}
				&& defined $column->{header}
				    && $self->{format}->{hashkey} eq $column->{header};

		# or if the key must be defined and is present in the filter
		# data or hash

		my $data_defined
		    = (exists $column->{be_defined} && $column->{be_defined} eq 1)
			&& ((ref $row eq 'HASH' && $column_key && defined $row->{$column_key})
			    || ref $row eq 'ARRAY');

		my $filter_defined
		    = (exists $column->{filter_defined} && $column->{filter_defined} eq 1)
			&& ((ref $filter_data eq 'HASH' && defined $filter_data->{$column_key})
			    || ref $filter_data eq 'ARRAY');

		if ($format_hashkey || $data_defined || $filter_defined)
		{
		    # If the column key is undefined, it is the key of the hash
		    # being handled.  We replace this column_key with the string
		    # that is used as the hashkey.

		    my $column_label = defined $column_key ? $column_key : $self->{format}->{hashkey};

		    # construct a sensible default value for textfields and constants.

		    my $content
			= ($self->{format}->{hashkey}
			   && $self->{format}->{hashkey} eq $column->{header})
			    ? $row_key # $column->{header}
				: (defined $column_key
				   && ref $filter_data eq 'HASH'
				   && exists $filter_data->{$column_key})
				    ? $filter_data->{$column_key}
					: ref $row eq 'HASH'
					    ? $row->{$column_key}
						: $row->[$column_number];

		    # start determining what encapsulator to use

		    my $encapsulator;

		    # start assembling options for the encapsulator

		    my $format_encapsulator_options = $column->{encapsulator}->{options} || {};

		    my $encapsulator_options
			= {
			   %$format_encapsulator_options,
			  };

		    #t need to do this in a derived class

		    if (
			exists $self->{gui_units}->{$row_key}
			&& scalar @{$self->{format}->{columns}} == 2
			&& $column_number == 1
		       )
		    {
			$encapsulator_options->{gui_units} = $self->{gui_units}->{$row_key};
		    }

		    # if the document is not editable

		    if (exists $self->{editable}
			&& !$self->{editable})
		    {
			# use the constant encapsulator

			$encapsulator = "_encapsulate_constant";
		    }

		    # if there is a regex encapsulator that would like to encapsulate

		    my $regex_encapsulator
			= $self->has_regex_encapsulator("$self->{name}${separator}${column_label}${separator}${row_key}", $content, );

		    if (
			$regex_encapsulator
			&& !$encapsulator
		       )
		    {
			# use the regex encapsulator with its options

			my $regex_encapsulator_options = $regex_encapsulator->{encapsulator}->{options} || {};

			$encapsulator_options
			    = {
			       %$encapsulator_options,
			       %$regex_encapsulator_options,
			      };

			if (exists $regex_encapsulator->{type})
			{
			    $encapsulator = "_encapsulate_$regex_encapsulator->{type}";
			}
			elsif (exists $regex_encapsulator->{code})
			{
			    $encapsulator = $regex_encapsulator->{code};
			}
		    }

		    # if a type has been defined for this field

		    if (
			$self->{gui_encapsulators}->{$row_key}
			&& scalar @{$self->{format}->{columns}} == 2
			&& $column_number == 1
			&& !$encapsulator
		       )
		    {
			# use the type encapsulator with its options

			my $gui_encapsulator = $self->{gui_encapsulators}->{$row_key};

			my $gui_encapsulator_options = $gui_encapsulator->{options} || {};

			$encapsulator_options
			    = {
			       %$encapsulator_options,
			       %$gui_encapsulator_options,
			      };

			if (exists $gui_encapsulator->{type})
			{
			    $encapsulator = "_encapsulate_$gui_encapsulator->{type}";
			}
			elsif (exists $gui_encapsulator->{code})
			{
			    $encapsulator = $gui_encapsulator->{code};
			}
		    }

		    # default : the field has not been encapsulated yet

		    my $encapsulated = 0;

		    if ($encapsulator && !$encapsulated)
		    {
			$str
			    .= $self->encapsulate_start
				(
				 "$self->{name}${separator}${column_label}${separator}${row_key}",
				 $row_count,
				 $column_number,
				 $content,
				 $encapsulator_options,
				);

			if (!ref $encapsulator)
			{
			    $str
				.= $self->$encapsulator
				    (
				     "$self->{name}${separator}${column_label}${separator}${row_key}",
				     $row_count,
				     $column_number,
				     $content,
				     $encapsulator_options,
				    );
			}
			elsif (ref $encapsulator eq 'CODE')
			{
			    $str
				.= &$encapsulator
				    (
				     $self,
				     "$self->{name}${separator}${column_label}${separator}${row_key}",
				     $row_count,
				     $column_number,
				     $content,
				     $encapsulator_options,
				    );
			}

			$str
			    .= $self->encapsulate_end
				(
				 "$self->{name}${separator}${column_label}${separator}${row_key}",
				 $row_count,
				 $column_number,
				 $content,
				 $encapsulator_options,
				);

			# register that the field has been encapsulated

			$encapsulated = 1;
		    }

		    # else : do the default type based encapsulation

		    if (!$encapsulated)
		    {
			# determine the type

			local $_ = $column->{type};

		    TYPE:
			{
			    /^button$/
				|| /^checkbox$/
				    || /^constant$/
					|| /^ip_address$/
					    || /^number$/
						|| /^textarea$/
						    || /^textfield$/
							|| /^url$/
							    and do
				    {
					my $encapsulator = "_encapsulate_$_";

					$str
					    .= $self->encapsulate_start
						(
						 "$self->{name}${separator}${column_label}${separator}${row_key}",
						 $row_count,
						 $column_number,
						 $content,
						 $encapsulator_options,
						);

					$str
					    .= $self->$encapsulator
						(
						 "$self->{name}${separator}${column_label}${separator}${row_key}",
						 $row_count,
						 $column_number,
						 $content,
						 $encapsulator_options,
						);

					$str
					    .= $self->encapsulate_end
						(
						 "$self->{name}${separator}${column_label}${separator}${row_key}",
						 $row_count,
						 $column_number,
						 $content,
						 $encapsulator_options,
						);

					last TYPE;
				    };

			    /^hidden$/
				and do
				{
				    $str .= "<input type=\"hidden\" name=\"$self->{name}${separator}${column_label}${separator}${row_key}\" id=\"$self->{name}${separator}${column_label}${separator}${row_key}\" value=\"$content\" /><br />";

				    last TYPE;
				};

			    #		/^code$/ &&
			    # default : generate with sub.

			    $str
				.= $self->encapsulate_start
				    (
				     "$self->{name}${separator}${column_label}${separator}${row_key}",
				     $row_count,
				     $column_number,
				     $content,
				     $encapsulator_options,
				    );

			    $str .= &{$column->{code}}($self, $row_key, $row, $filter_data);

			    $str
				.= $self->encapsulate_end
				    (
				     "$self->{name}${separator}${column_label}${separator}${row_key}",
				     $row_count,
				     $column_number,
				     $content,
				     $encapsulator_options,
				    );
			}
		    }
		}
		else
		{
		    $str .= "&nbsp;</td><td style='border-left-style: hidden'>";
		}

		$str .= "</td>";

		$column_number++;
	    }

	    $str .= "</tr>\n";

	    $row_count++;
	}
    }
    elsif ("$contents" =~ /ARRAY/)
    {
    }
    else
    {
	die "*** Error: expecting a hash or an array for TableFormType content data.";
    }

    if (exists $self->{row_finalize})
    {
	$str .= &{$self->{row_finalize}}($self);
    }

    $str .= "</tbody>\n";

    $self->writer($str);
}


sub form_info_end
{
    my $self = shift;

    my $str = '';

    $str .= "</table>\n";

    $self->writer($str);
}


sub form_info_header
{
    my $self = shift;

    my $columns = $self->{format}->{columns};

    my $str = '';

    $str .= "<thead>\n";

    if (exists $self->{column_headers} && $self->{column_headers})
    {
	$str .= "<tr>" ;
	foreach my $item (@$columns)
	{
	    my $width = $item->{width} ? " width='" . $item->{width} . "'" : '';

	    my $align = $item->{align} ? " align='" . $item->{align} . "'" : '';

	    $str .= "<th" . $width . $align . ">" . $item->{header};

	    $str .= "</th><th style='border-left-style: hidden'></th>";
	}

	$str .= "</tr>" ;
    }

    $str .= "</thead>\n";

    $self->writer($str);
}


sub form_info_start
{
    my $self = shift;

    my $str = '';

    my $border_width = defined $self->{border_width} ? $self->{border_width} : 0;

    my $html_attributes_string = "";

    my $html_attributes = $self->{html_attributes};

    foreach my $html_attribute (keys %$html_attributes)
    {
	$html_attributes_string .= " $html_attribute='$html_attributes->{$html_attribute}'";
    }

    $str .= "<table$html_attributes_string border=\"$border_width\" cellpadding=\"4\" cellspacing=\"0\" style=\"border-collapse: collapse\">";

    $self->writer($str);
}


sub has_regex_encapsulator
{
    my $self = shift;

    my $position = shift;

    my $content = shift;

    my $regex_encapsulators = $self->{regex_encapsulators};

    my $result;

    # loop over all regex encapsulators

    foreach my $regex_encapsulator (@$regex_encapsulators)
    {
	my $name = $regex_encapsulator->{name};

	my $regex = $regex_encapsulator->{regex};

	my $match = '';

	# if we should be matching against the content

	if (exists $regex_encapsulator->{match_content}
	    && $regex_encapsulator->{match_content})
	{
	    # if match against content

	    if ($content =~ /$regex/)
	    {
		# set result : this encapsulator

		$result = $regex_encapsulator;

		# remember to break the regex loop

		$match = 1;
	    }
	}

	# else

	else
	{
	    # if match against position

	    if ($position =~ /$regex/)
	    {
		# set result : this encapsulator

		$result = $regex_encapsulator;

		# remember to break the regex loop

		$match = 1;
	    }
	}

	if ($match)
	{
	    # break the regex loop

	    last;
	}
    }

    # return result

    return $result;
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

    # call the reverse of the filter : merger

    my $merger = $self->{merger};

    if ($merger)
    {
	$data = &$merger($self, $data, @_);
    }

    # call superclass merger

    return $self->SUPER::merge_data($data, @_);
}


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new(
				  @_,
				 );
    bless ($self, $class);

    # process the persistency specification if any

    if ($self->{persistency_specification})
    {
	my $column_specification = $self->{persistency_specification};

	my $order
	    = {
	       map
	       {
		   $_ => $column_specification->{$_}->{order};
	       }
	       keys %$column_specification,
	      };

	$self->{sort} = sub { return $order->{$_[0]} <=> $order->{$_[1]}; };

	my $encapsulators
	    = {
	       map
	       {
		   my $result = {};

		   if (exists $column_specification->{$_}->{encapsulator})
		   {
		       if (!exists $column_specification->{$_}->{encapsulator}->{options}->{label})
		       {
			   $column_specification->{$_}->{encapsulator}->{options}->{label}
			       = $column_specification->{$_}->{label};
		       }

		       $result = { $_ => $column_specification->{$_}->{encapsulator}, };
		   }

		   %$result;
	       }
	       keys %$column_specification,
	      };

	$self->{gui_encapsulators} = $encapsulators;

    }
    else
    {
	my $column_specification = $self->{contents};

	if ("$column_specification" =~ /HASH/)
	{
	    my $units
		= {
		   map
		   {
		       exists $column_specification->{$_}->{units}
			   ? ($_ => $column_specification->{$_}->{units})
			       : ();
		   }
		   keys %$column_specification,
		  };

	    $self->{gui_units} = $units;
	}
    }

    return $self;
}


sub parse_input
{
    my $self = shift;

    my $result = {};

    my $separator = $self->{separator} || '_';

    my $query = $self->{CGI};

    # if factory settings request

    if ($self->parse_factory($result))
    {
	# return without further processing

	return $result;
    }

    # figure out the submitted section

    if ($self->parse_submits($result))
    {
	return $result;
    }

    # figure out the pressed button

    if ($self->parse_buttons($result))
    {
	return $result;
    }

    # if there is nothing to parse for this document

    #t consolidate 'cmd' with 'button' will remove the indirection on
    #t the second key (ie. {$result->{cmd}->{action}}).

    if ($result->{$result->{cmd}->{action}}->{request} !~ /^$self->{name}_/)
    {
	return $result;
    }

    # number of keys that should be handled.

    my $keys_to_handle = 0;

    # fetch CGI parameters

    my @query_params = $query->param();

    # loop over the submitted fields

    my $decapsulated;

    #t unchecked checkboxes are not passed through by CGI, so are not
    #t in @query_params.  Perhaps this can be solved by using default
    #t default values ?

    #t loop over all fields from the table format
    #t   assign default value
    #t     perhaps only for certain field types like checkboxes.

    while ($#query_params >= 0)
    {
	my $key = pop(@query_params) ;

	if ($key !~ /^field$separator/
	    && $key !~ /^checkbox$separator/)
	{
	    next;
	}

	$keys_to_handle++;

	# remove type indicator

# 	$key =~ s/^field$separator//;
	$key =~ s/^([^${separator}]*?)${separator}//;

	my $type = $1;

	# remove name of the document

	$key =~ s/^[^${separator}]*?${separator}//;

	# get name of the column and row

	$key =~ m/^([^${separator}]*?)${separator}(.*)$/;

	my $column_key = $1;

	my $row = $2;

	# find the column in the format

	my $column_number = 0;

	my $format_columns = $self->{format}->{columns};

	foreach my $format_column (@$format_columns)
	{
	    if ($format_column->{key_name})
	    {
		if ($format_column->{key_name} eq $column_key)
		{
		    # fetch the value from CGI

		    my $parameter_name = "${column_key}$separator${row}";

		    my $value = $self->parameter($type, $parameter_name);

		    # if we have a valid value

		    #! we should not get here with 'undef' values.

		    if (defined $value)
		    {
			# start determining what decapsulator to use

			my $decapsulator;

			# start assembling options for the decapsulator

			my $format_decapsulator_options = $format_column->{encapsulator}->{options} || {};

			my $decapsulator_options
			    = {
			       %$format_decapsulator_options,
			      };

			#t need to do this in a derived class

			print STDERR "column_key is $column_key, columns is " . @{$self->{format}->{columns}} . "\n";

			if (
			    exists $self->{gui_units}->{$row}
			    && scalar @{$self->{format}->{columns}} == 2
			    && $column_number == 1
			   )
			{
			    $decapsulator_options->{gui_units} = $self->{gui_units}->{$row};
			}

			# if the document is not editable

			if (exists $self->{editable}
			    && !$self->{editable})
			{
			    # use the constant decapsulator

			    $decapsulator = "_decapsulate_constant";
			}

			# if there is a regex decapsulator

			my $regex_decapsulator
			    = $self->has_regex_encapsulator("$self->{name}${separator}${column_key}${separator}${row}", $value, );

			if (
			    $regex_decapsulator
			    && !$decapsulator
			   )
			{
			    # use the regex decapsulator with its options

			    my $regex_decapsulator_options = $regex_decapsulator->{encapsulator}->{options} || {};

			    $decapsulator_options
				= {
				   %$decapsulator_options,
				   %$regex_decapsulator_options,
				  };

			    if (exists $regex_decapsulator->{type})
			    {
				$decapsulator = "_encapsulate_$regex_decapsulator->{type}";
			    }
			    elsif (exists $regex_decapsulator->{code})
			    {
				$decapsulator = $regex_decapsulator->{code};
			    }
			}

			# if a type has been defined for this field

			if (
			    $self->{gui_encapsulators}->{$row}
			    && scalar @{$self->{format}->{columns}} == 2
			    && $column_number == 1
			    && !$decapsulator
			   )
			{
			    # use the type decapsulator with its options

			    my $gui_decapsulator = $self->{gui_encapsulators}->{$row};

			    my $gui_decapsulator_options = $gui_decapsulator->{options} || {};

			    $decapsulator_options
				= {
				   %$decapsulator_options,
				   %$gui_decapsulator_options,
				  };

			    if (exists $gui_decapsulator->{type})
			    {
				$decapsulator = "_decapsulate_$gui_decapsulator->{type}";
			    }
			    elsif (exists $gui_decapsulator->{code})
			    {
				$decapsulator = $gui_decapsulator->{code};
			    }

			}

			# default : the field has not been decapsulated yet

			my $is_decapsulated = 0;

			my ($decapsulated_key, $decapsulated_data);

			if ($decapsulator && !$decapsulated)
			{
			    if (!ref $decapsulator)
			    {
				($decapsulated_key, $decapsulated_data)
				    = $self->$decapsulator
					(
					 $key,
					 $row,
					 $column_number,
					 $decapsulated,
					 $value,
					 $decapsulator_options,
					);
			    }
			    elsif (ref $decapsulator eq 'CODE')
			    {
				($decapsulated_key, $decapsulated_data)
				    = $self->_decapsulate_constant
					(
					 $key,
					 $row,
					 $column_number,
					 $decapsulated,
					 $value,
					 $decapsulator_options,
					);
			    }

			    # register that the field has been decapsulated

			    $is_decapsulated = 1;
			}

			# else : do the default type based deapsulation

			if (!$is_decapsulated)
			{
			    # determine the type

			    local $_ = $format_column->{type} eq 'code' ? 'constant' : $format_column->{type};

			    my $decapsulator = "_decapsulate_$_";

			    print STDERR "Entry $row, $column_key == $_ : $decapsulator\n";

			    ($decapsulated_key, $decapsulated_data)
				= $self->$decapsulator
				    (
				     $key,
				     $row,
				     $column_number,
				     $decapsulated,
				     $value,
				     $decapsulator_options,
				    );
			}

			# fill in the entry in the data

			$decapsulated->{$row}->{$column_key} = $decapsulated_data;
		    }
		    else
		    {
			print STDERR "FormType error: CGI key $key does not have a defined value\n";

			$self->register_error("CGI key $key does not have a defined value");
		    }

		    # break search loop

		    last;
		}
	    }
	    elsif ($self->{format}->{hash_key} eq $column_key)
	    {
		#t not sure, not supported for the moment

		#t Should take the new hash and fill it in the original hash with this value as hash key.
		#t I think this is not possible in the general case.
	    }

	    $column_number++;
	}
    }

    #t apply detransformations

    # fill in the decapsulated data

    $result->{detransformed} = $decapsulated;

    return $result;
}


sub row_inserter
{
    my $self = shift;

    my $row_key = shift;

    my $result = '';

    my $row_inserters = $self->{row_inserters};

    local $_ = ref $row_inserters;

 ROW_INSERTER:

    {
	/^ARRAY$/
	    and do
	    {
		foreach my $row_inserter (@{$self->{row_inserters}})
		{
		    $result .= &$row_inserter($self, $row_key, );
		}

		last ROW_INSERTER;
	    };

	/^HASH$/
	    and do
	    {
		if (exists $self->{row_inserters}->{$row_key})
		{
		    my $row_inserter = $self->{row_inserters}->{$row_key};

		    $result .= &$row_inserter($self, $row_key, );
		}

		last ROW_INSERTER;
	    };
    }

    return $result;
}


1;


