#!/usr/bin/perl -w
#

package Poetical::TreeFormType;


use strict;

use utf8;


use CGI qw(:cgi :html2 :html3 :form);
use Data::Dumper;


use Poetical::StaticFormType;


our @ISA = ("Poetical::StaticFormType");


my $debug_enabled = 1;

my $debug_context = 1;

my $debug_colspan = 0;

my $debug_indent = 0;

my $enable_grid_logic = 0;


#
# Documents (i.e. XML, data) can easily be visualized in a tree structure.
# The tree visualizer algorithm in this file has been developed with the
# following facts in mind :
#
# 1. The most common tree visualizers render a high, yet narrow tree.  Such a
#    narrow tree fits nicely into one panel of a two frame window i.e. windows
#    explorer and alike.
#
# 2. Webmin does not support frames (easily).  So for our purposes there is no
#    point in rendering the data in a high and narrow tree.
#
# 3. Conclusion : the algorithm needed has to render as much on one line as
#    possible.
#
# The first consequence is given by the observation that rendering a single
# line is impossible until the contents of the whole line is known.  In
# combination with a Depth First Traversal to examine the data, an unknown
# number of steps in the DFT (going deeper in the hierarchy) are needed to
# construct a single line of output.
#
# The second consequence is the observation that the view of a single line is
# influenced by the data following the rendered data (just as is the case in
# windows explorer, but here in many more cases than such algorithms).  As a
# net result, this algorithm cannot easily be combined with arbitrary
# transformations since they influence the data to be rendered.
# Transformations are possible but only a limited subset.  The current
# implementation supports renaming and removal, but I am not sure if that is
# really bugfree (actually I do not think so).
#
# The logic in the sub _formalize_context() forms the core of the algorithm.
# The rest of the subs implement a simple DFT using a custom stack.  A simple
# protection mechanism prevents infinite loops on self-referential structures,
# so the DFS computes a spanning tree in that case.
#
# Related to this, see
# http://www.usenix.org/publications/library/proceedings/lisa2000/full_papers/bernstein/bernstein_html/
# and references.
#

#
# '+' : split of current
# '|' : current continues below
#       current component is not last key in current element (hash).
# ' ' : no relationship (default)
# '-' : alignment only.
#

my $default_table_format;

$default_table_format->{ascii}->{structure}->{align} = " ----- ";

$default_table_format
    = {
       ascii => {
		 format_cell =>
		 sub
		 {
		     # center and chop contents.

		     my $max_length
			 = length
			     $default_table_format->{ascii}->{structure}->{align};

		     my $content = " " x $max_length . "$_[0]" . " " x $max_length;

		     my $length = length $content;

		     return
			 substr $content, ($length - $max_length) / 2, $max_length;

		 },
		 borders => {
			     left => ";",
			     left_centered => ";",
			     left_multicol => ";",
			     left_grid_align => ";",
			     right => "",
			     top => "\n",
			     bottom => "",
			    },
		 structure => {
			       split => "   +-- ",
			       start => " --+-- ",
			       stop => "   +-- ",
			       continue => "   |   ",
			       blank => "       ",
			       align => " ----- ",
			      },
		},
       html => {
		format_cell => sub { return($_[0]); },
		borders => {
			    left => "<td class='w' colspan='1'>",
			    left_centered => "<td class='w' align='center'>",
# 			    left_centered => "<td class='w' align='left'>",
			    left_multicol => "<td class='w' colspan='__COLSPAN__'>",
			    left_grid_align => "<td class='w' colspan='__GRID_COLSPAN__'>",
			    right => "</td>",
			    top => "\n<tr bgcolor=\"#cccccc\">",
			    bottom => "</tr>",
			   },
		structure => {
			      split => "<img width='18' height='100%' SRC='../images/sems_table_split4.gif' ALIGN='center' ALT='loading'>",
			      start => "<img width='18' height='100%' SRC='../images/sems_table_start4.gif' ALIGN='center' ALT='loading'>",
			      stop => "<img width='18' height='100%' SRC='../images/sems_table_stop4.gif' ALIGN='center' ALT='loading'>",
			      continue => "<img width='18' height='100%' SRC='../images/sems_table_continue4.gif' ALIGN='center' ALT='loading'>",
			      blank => "&nbsp;",
			      align => "<img width='18' height='100%' SRC='../images/sems_table_align4.gif' ALIGN='center' ALT='loading'>",
			     },
# 		structure => {
# 			      split => "+",
# 			      start => "+",
# 			      stop => "+",
# 			      continue => "&#124;",
# 			      blank => "&nbsp;",
# 			      align => " ----- ",
# 			     },
	       },
      };


my $separator = "/";

sub _context_create
{
    return
	(
	 {
	  array => [],
	  last_output_type => '__NONE__',
	  last_output => undef,
	  maximal_depth => 0,
	  current_incremental_colspan => 0,
	  maximal_incremental_colspan => 0,
	  path => shift,
	  type => 'root',
	  seen => {},
	 },
	);
}


sub _context_get_seen_info
{
    return($_[0]->{seen}->{$_[1]});
}


sub _context_has_seen
{
    return(exists $_[0]->{seen}->{$_[1]});
}


sub _context_pop
{
    my $context = shift;

    my $array = $context->{array};

    $context->{current_incremental_colspan}
	-= $array->[$#$array]->{colspan} || 0;

    if ($debug_colspan)
    {
	print STDERR "Removed $array->[$#$array]->{colspan} from colspan (has become $context->{current_incremental_colspan})\n";
    }

    pop @$array;

    $context->{path} =~ s/^(.*[^\\])$separator.*/$1/;

#     if ($#$array ne -1)
#     {
# 	$context->{datatype} = $array->[$#$array]->{type};
#     }

    if ($debug_context)
    {
	print STDERR "_context_pop ($context->{path})\n";
    }
}


sub _context_push
{
    my $context = shift;

    my $new = shift;

    push @{$context->{array}}, $new;

    $context->{path} .= "${separator}__NONE__";

    my $array = $context->{array};

#     $context->{datatype} = $array->[$#$array]->{type};

    if (scalar @{$context->{array}} > $context->{maximal_depth})
    {
	$context->{maximal_depth} = scalar @{$context->{array}};
    }

    if ($debug_context)
    {
	print STDERR "_context_push __NONE__ ($context->{path})\n";
    }
}


sub _context_register_current
{
    my $context = shift;

    my $document = shift;

    my $component_key = shift;

    my $component_key_type = shift;

    my $component = shift;

    my $count = shift;

    my $colspan = shift;

    my $array = $context->{array};

    #t actually I think I need an _context_unregister_current() sub
    #t that resets ->{string}, ->{display}, and possibly others.

    #t At least I would not need this weird line of code at two places.

    $context->{current_incremental_colspan}
	-= $array->[$#$array]->{colspan} || 0;

    if ($component_key)
    {
	# protect the component key for easy removal afterwards (see below)

	$component_key =~ s|$separator|\\${separator}|g;
    }

    $array->[$#$array]->{current} = $count;
    $array->[$#$array]->{display} = 1;
    $array->[$#$array]->{displayed} = 0;
    $array->[$#$array]->{name}
	= defined $component_key ? $component_key : '__UNDEF__';
    $array->[$#$array]->{string} = undef;
    $array->[$#$array]->{type} = $component_key_type; # ref $component || 'SCALAR';
    $array->[$#$array]->{colspan} = $colspan;

    $context->{current_incremental_colspan} += $array->[$#$array]->{colspan};

    if ($debug_colspan)
    {
	print STDERR "Incremental colspan is $context->{current_incremental_colspan} at depth $#$array\n";
	print STDERR "        max colspan is $context->{maximal_incremental_colspan} at depth $#$array\n";
    }

    if ($context->{current_incremental_colspan} > $context->{maximal_incremental_colspan})
    {
	$context->{maximal_incremental_colspan} = $context->{current_incremental_colspan};
    }

    if ($debug_enabled)
    {
	my $component_output
	    = defined $component ? $component : '__UNDEF__';

	print
	    STDERR
	    " " x (2 * $#$array)
		. "$array->[$#$array]->{type} : $component_output\n";
    }

    if ($debug_context)
    {
	print STDERR "context of $context->{path} with $array->[$#$array]->{name}\n";
    }

    # remove the last component from the stack

    $context->{path}
	=~ s|(.*[^\\]$separator).*|$1$array->[$#$array]->{name}|;

#     $context->{datatype} = $array->[$#$array]->{type};

    #! note that the algorithm used does not collaborate nicely with arbitrary
    #! transformations.  This can be removed at any time.

    if (exists $document->{component_transformator})
    {
	&{$document->{component_transformator}}
	    ($array->[$#$array], $context, $component);
    }

    if ($debug_context)
    {
	print STDERR "  results in $context->{path}\n";
    }
}


sub _context_set_seen_info
{
    $_[0]->{seen}->{$_[1]} = $_[2];
}


# This sub is called whenever a name has to be generated.  The name is given
# by $contents, the $context and $column disambiguate the occurence of the
# name.

sub _apply_user_formatting
{
    my ($self, $context, $column, $contents, $default, ) = @_;

    # default the value is not encapsulated

    my $encapsulated = 0;

    if (exists $self->{user_formats})
    {
	# default : no user formatter applied.

	my $formatted = 0;

	my $path = $context->{path};

# 	my $datatype = $context->{datatype};

	my $array = $context->{array};

	my $datatype = $array->[$column]->{type};

	# loop over all user formats

	foreach my $format (@{$self->{user_formats}})
	{
	    #t replace the format column with the option to count the
	    #t number of separators in the regex matched

	    my $format_matcher = $format->{matcher};
	    my $format_column = $format->{column} || undef;
	    my $format_datatype = $format->{datatype} || undef;
	    my $format_type = $format->{type};
	    my $format_name = $format->{name};

	    # if this user format path matches

	    if ($path =~ m|$format_matcher|

		# and the specified column matches

		&& (!defined $format_column || $column eq $format_column)

		# and the type is ok

		&& (!defined $format_datatype || $format_datatype eq $datatype))
	    {
		# apply the user format

		print STDERR "For path $path : applying user format $format_name\n";

		my $format_options;

		if (exists $format->{encapsulator}
		    && exists $format->{encapsulator}->{options})
		{
		    $format_options = $format->{encapsulator}->{options};

		    print STDERR "Format options are \n", Dumper($format_options);
		}

		#t synchronize with the types defined in Poetical::TableFormType.
		#t probably and simply put in Poetical::FormType ?

		my $encapsulator = "_encapsulate_$format_type";

		# synchronize name generation with table documents :
		# remove current (is last) path entry.

# 		$path =~ s|^(.*)/.*$|$1|;

		$path =~ s/$contents$//;

		# replace separators

		#t need to synchronize separators of the keys with separators
		#t in the tree documents.

		#t also need to synchronize the key generation again :
		#t
		#t first part is type.
		#t second part is form name.
		#t third part is path name.
		#t last optional part is field type subpart.

		if (!defined $self->{separator})
		{
		    $path =~ s|/|_|g;
		}

		$encapsulated = 1;

		$contents
		    = $self->$encapsulator
			($path, $column, $contents, $format_options);

		# remember : user formatting applied.

		$formatted = 1;
	    }
	}

	if (!$formatted)
	{
	    print STDERR "For path $path : no user format applied\n";
	}
    }

    if (exists $self->{user_formatter})
    {
	$encapsulated = 1;

	$contents
	    = &{$self->{user_formatter}}
		($self, $context->{path}, $column, $contents);
    }

    # if value has been formatted

    if ($encapsulated)
    {
	return $contents;
    }
    else
    {
	return $default;
    }
}


sub _formalize_any
{
    my $self = shift;

    my $context = shift;

    my $contents = shift;

    my $output_mode = $self->{output_mode};

    my $str = '';

    my $contents_output
	= defined $contents ? $contents : '__UNDEF__';

    if (_context_has_seen($context, $contents_output))
    {
	my $seen_info = _context_get_seen_info($context, $contents_output);

	$str .= $self->_formalize_constant($context, $seen_info);

	return $str;
    }

    _context_set_seen_info($context, $contents_output, $contents_output);

    if ($debug_enabled)
    {
	print
	    STDERR
		"Setting $self->{name} not empty because of "
		    . $contents_output
			. ".\n";
    }

    $self->set_not_empty();

    # figure out with what we are dealing.

    local $_ = ref($contents);

    if (!$_)
    {
	# a constant.

	if ($debug_enabled)
	{
	    print STDERR "$self->{name} : Constant ($contents_output)\n";
	}

	$str .= $self->_formalize_constant($context, $contents);
    }
    else
    {
    BASE_TYPE:
	{
	    # an array.

	    /^ARRAY$/ and do
	    {
		if ($debug_enabled)
		{
		    print STDERR "$self->{name} : Array ($contents_output)\n";
		}

		$str .= $self->_formalize_array($context, $contents);

		last BASE_TYPE;
	    };

	    # a hash.

	    /^HASH$/ and do
	    {
		if ($debug_enabled)
		{
		    print STDERR "$self->{name} : Hash ($contents_output)\n";
		}

		$str .= $self->_formalize_hash($context, $contents);

		last BASE_TYPE;
	    };

	    # a vardef object.

	    /^NTC::Vardef$/ and do
	    {
		if ($debug_enabled)
		{
		    print STDERR "$self->{name} : NTC::Vardef ($contents->{varname})\n";
		}

		# allow more meaningfull diags.

		_context_set_seen_info
		    ($context, $contents_output, "NTC::Vardef($contents->{varname})", );

		$str .= $self->_formalize_hash($context, $contents);

		last BASE_TYPE;
	    };

	    # an object.

	    if ($debug_enabled)
	    {
		print STDERR "$self->{name} : Object ($_)\n";
	    }

	    local $_ = $contents_output;

	OBJECT_TYPE:
	    {
		/=HASH/ and do
		{
		    if ($debug_enabled)
		    {
			print STDERR "$self->{name} : Object hash ($contents_output)\n";
		    }

		    $str .= $self->_formalize_hash($context, $contents);

		    last OBJECT_TYPE;
		};

		/=ARRAY/ and do
		{
		    if ($debug_enabled)
		    {
			print STDERR "$self->{name} : Object Array ($contents_output)\n";
		    }

		    $str .= $self->_formalize_array($context, $contents);

		    last OBJECT_TYPE;
		};

		#t implement.
		#t
		#t This is meant for easy extensibility.
		#t Probably it is the most convenient if we force the object to
		#t implement an agreed upon interface.
		#t
		#t use UNIVERSAL::isa() and perhaps UNIVERSAL::can() to check if
		#t the interface is implemented by the object.
		#t
		#t perform a default action for hashes and arrays if the object
		#t does not implement a suitable interface, allow the user to
		#t configure or change the default action.
		#t

		#$str .= $self->_formalize_object($context, $contents);
	    }
	}
    }

    return($str);
}


sub _formalize_array
{
    my $self = shift;

    my $context = shift;

    my $contents = shift;

    my $array = $context->{array};

    my $output_mode = $self->{output_mode};

    my $count = 0;

    my $str = '';

    #
    # component_transform modification values :
    #
    # string :
    #     use string as content to display (i.e. replaces component name).
    #     undef means default behaviour (display name).
    #
    # display :
    #     0 : do not display.
    #     1 : do display
    #
    # recurse :
    #     0 : return immediately.
    #     1 : process children.
    #

    my $transform_data = {
			  display => 1,
			  recurse => 1,
			  string => undef,
			 };

#     if (exists $self->{component_transformator})
#     {
# 	&{$self->{component_transformator}}($transform_data, $context, $contents);
#     }

#     if (!$transform_data->{recurse})
#     {
# 	return $str;
#     }

    _context_push(
		  $context,
		  {
		   contents => $contents,
		   current => 0,
		   name => '__NONE__',
		   size => scalar @$contents,
#		   type => undef,
		   %$transform_data,
		  },
		 );

    # the sort is quite useless in this form : has no clue of nesting
    # of $contents.

    #t given an array of (sort(), <regex>) tuples, match <regex> with
    #t current component, if matches, apply associated sorting
    #t function.
    #t
    #t this is quite close to transformations too.

    foreach my $component (sort
			   {
			       defined $self->{sort}
				   ? &{$self->{sort}}
				       (
					$a,
					$b,
# 					$contents->{$a},
# 					$contents->{$b},
					$context,
				       )
					   : -1;
			   }
			   @$contents)
    {
	# register the name and count of current column

	_context_register_current
	    (
	     $context,
	     $self,
	     '[' . $count . ']',
	     'INDEX',
	     $component,
	     $count,
	     $enable_grid_logic ? 5 : 1,
	    );

	# increment count (before applying filters)

	$count++;

	#
	# array_filter return values :
	#
	# 0 : do not display.
	# 1 : do display.
	#

	my $filter_data = 1;

	if (exists $self->{array_filter})
	{
	    $filter_data = &{$self->{array_filter}}($context, $component);
	}

	next if $filter_data eq 0;

	# formalize content of array

	$str .= $self->_formalize_any($context, $component);
    }

    # start a new table row

    $str .= $self->_formalize_context($context, 'empty');

    # remove this column

    _context_pop($context);

    # if this is an empty array

    if (!@$contents)
    {
	# formalize as an empty array

	$str .= $self->_formalize_any($context, '[]');
    }

    return($str);
}


#
# return a string with a cell containing the given constant.
#
# The string ends the current row, meaning it is newline terminated in ascii
# mode.
#

sub _formalize_constant
{
    my $self = shift;

    my $context = shift;

    my $contents = shift;

    my $output_mode = $self->{output_mode};

    my $str = '';

    my $transform_data = {
			  display => 1,
			  recurse => 1,
			  string => undef,
			 };

    _context_push(
		  $context,
		  {
		   contents => $contents,
		   current => 0,
		   name => '__NONE__',
		   size => 1,
#		   type => 'SCALAR',
		   %$transform_data,
		  },
		 );

    if ($debug_enabled)
    {
	print STDERR "    # register the name and count of current column\n";
    }

    # register the name and count of current column

    _context_register_current
	(
	 $context,
	 $self,
	 $contents,
	 'SCALAR',
	 $contents,
	 0,
	 $enable_grid_logic ? length $contents : 1,
	);

    #
    # component_transform modification values :
    #
    # string :
    #     use string as content to display (i.e. replaces component name).
    #     undef means default behaviour (display name).
    #
    # display :
    #     0 : do not display.
    #     1 : do display
    #
    # recurse :
    #     0 : return immediately.
    #     1 : process children.
    #

#     my $transform_data = {
# 			  display => 1,
# 			  recurse => 1,
# 			  string => undef,
# 			 };

#     if (exists $self->{component_transformator})
#     {
# 	&{$self->{component_transformator}}($transform_data, $context, $contents);
#     }

#     if (!$transform_data->{recurse})
#     {
# 	return $str;
#     }

    # do the dynamic indentation

    $str .= $self->_formalize_context($context, 'content');

#     # add leaf contents

    my $table_format = $self->{table_format};

#     $str
# 	.= $table_format->{$output_mode}->{borders}->{left}
# 	    . $contents
# 		. $table_format->{$output_mode}->{borders}->{right};

    # remove this column

    _context_pop($context);

    return($str);
}


sub _formalize_hash
{
    my $self = shift;

    my $context = shift;

    my $contents = shift;

    my $output_mode = $self->{output_mode};

    my $count = 0;

    my $str = '';

    #
    # component_transform modification values :
    #
    # string :
    #     use string as content to display (i.e. replaces component name).
    #     undef means default behaviour (display name).
    #
    # display :
    #     0 : do not display.
    #     1 : do display
    #
    # recurse :
    #     0 : return immediately.
    #     1 : process children.
    #

    my $transform_data = {
			  display => 1,
			  recurse => 1,
			  string => undef,
			 };

#     if (exists $self->{component_transformator})
#     {
# 	&{$self->{component_transformator}}($transform_data, $context, $contents);
#     }

#     if (!$transform_data->{recurse})
#     {
# 	return $str;
#     }

    _context_push(
		  $context,
		  {
		   contents => $contents,
		   current => 0,
		   name => '__NONE__',
		   size => scalar keys %$contents,
#		   type => 'HASH',
		   %$transform_data,
		  },
		 );

#     $str .= "\n\n<table cellpadding=\"4\" cellspacing=\"0\" frame=\"void\" summary=\"treeview of sems system functions.\">";

#     $str .= "\n<tr bgcolor=\"#cccccc\">";

    # the sort is quite useless in this form : has no clue of nesting
    # of $contents.

    #t given an array of (sort(), <regex>) tuples, match <regex> with
    #t current component, if matches, apply associated sorting
    #t function.
    #t
    #t this is quite close to transformations too.

    foreach my $component_key (sort
			       {
				   defined $self->{sort}
				       ? &{$self->{sort}}
					   (
					    $a,
					    $b,
					    $contents->{$a},
					    $contents->{$b},
					    $context,
					   )
					       : $a cmp $b;
			       }
			       keys %$contents)
    {
	my $component = $contents->{$component_key};

	# register name and count of current column

	_context_register_current
	    (
	     $context,
	     $self,
	     $component_key,
	     'KEY',
	     $component,
	     $count,
	     $enable_grid_logic ? length $component_key : 1,
	    );

	# increment count (before applying filters)

	$count++;

	#
	# hash_filter return values :
	#
	# 0 : do not display.
	# 1 : do display.
	#

	my $filter_data = 1;

	if (exists $self->{hash_filter})
	{
	    $filter_data
		= &{$self->{hash_filter}}($context, $component_key, $component);
	}

	next if $filter_data eq 0;

	# formalize component

	$str .= $self->_formalize_any($context, $component);
    }

    # start a new table row

    $str .= $self->_formalize_context($context, 'empty');

#     $str .= "\n</tr>";

#     $str .= "\n\n</table>";

    # remove this column

    _context_pop($context);

    # if this is an empty hash

    if (!keys %$contents)
    {
	# formalize as an empty array

	$str .= $self->_formalize_any($context, '{}');
    }

    return($str);
}


#
# sub _formalize_context :
#
# Return a string appropriate for the current context.
#
# $_[0] : self object.
# $_[1] : context object.
# $_[2] : output mode, i.e.
#         'empty' : an empty line splitting logical groups.
#         'content' : a line allowed to render labels and data.
#
# Constructs a string consisting of cells with splitters, continuations,
# alignments and blanks as needed for the current context.  This string is
# ended with a row terminator.
#

sub _formalize_context
{
    my $self = shift;

    my $context = shift;

    my $output_type = shift;

    my $array = $context->{array};

    if ($#$array == -1)
    {
	return '';
    }

    my $table_format = $self->{table_format};

    my $output_mode = $self->{output_mode};

    if ($debug_indent)
    {
	print STDERR "Indenting $self->{name} : context is $context->{path}, 0 .. $#$array columns\n";
    }

    my $str = '';

    # default : only output for empty lines (forced).

    my $output_enabled;

    if ($output_type eq 'empty')
    {
	$output_enabled = 1;
    }
    else
    {
	$output_enabled = 0;
    }

#     # register maximum width

#     if (! exists $context->{columns}
# 	|| $#$array > $context->{columns})
#     {
# 	$context->{columns} = $#$array;

# # 	if ($debug_enabled)
# # 	{
# # 	    print STDERR "  Indenting columns set to $context->{columns}\n";
# # 	}
#     }

    # do the dynamic indentation

    foreach my $indent (0 .. $#$array)
    {
	#a devices + MOD + type ntc2080
	#a         |     + bus  62
	#a         |
	#a         + ENC + type barco
	#a         |     + bus  72
	#a         |
	#a         + IRD + type ntc2079
	#a               + bus  82


	#a 	my $hash
	#a 	    = {
	#a 	       a => {
	#a 		     a1 => 'a1',
	#a 		     a2 => 'a2',
	#a 		    },
	#a 	       b => [
	#a 		     'b1',
	#a 		     'b2',
	#a 		     'b3',
	#a 		    ],
	#a 	       c => {
	#a 		     c1 => {
	#a 			    c11 => 'c11',
	#a 			   },
	#a 		     c2 => {
	#a 			    c21 => 'c21',
	#a 			   },
	#a 		    },
	#a 	      };

	#a a is embedded hash, contains literals.
	#a b is embedded array, contains literals.
	#a c is embedded embedded hash, contains strings.
	#a
	#a ;---;---;---;---;---;---;---;
	#a ; + ; a ; + ;a 1;a 1;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; | ;   ; + ;a 2;a 2;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; | ;   ;   ;   ;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; + ; b ; + ;b 1;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; | ;   ; + ;b 2;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; | ;   ; + ;b 3;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; | ;   ;   ;   ;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ; + ; c ; + ;c 1; - ;c11;c11;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;   ; | ;   ;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;   ; + ;c 2; - ;c21;c21;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;   ;   ;   ;   ;   ;   ;
	#a ;---;---;---;---;---;---;---;
	#a
	#a which is equivalent to
	#a
	#a ;---;---;---;---;---;
	#a ; + ; a ; + ;a 1;a 1;
	#a ;---;---;---;---;---;
	#a ; | ;   ; + ;a 2;a 2;
	#a ;---;---;---;---;---;
	#a ; | ;
	#a ;---;---;---;---;
	#a ; + ; b ; + ;b 1;
	#a ;---;---;---;---;
	#a ; | ;   ; + ;b 2;
	#a ;---;---;---;---;
	#a ; | ;   ; + ;b 3;
	#a ;---;---;---;---;
	#a ; | ;
	#a ;---;---;---;---;---;---;---;
	#a ; + ; c ; + ;c 1; - ;c11;c11;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;   ; | ;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;   ; + ;c 2; - ;c21;c21;
	#a ;---;---;---;---;---;---;---;
	#a ;   ;
	#a ;---;

	#a structure encoding :
	#a
	#a '+' : split of current
	#a '|' : current continues below
	#a       current component is not last key in current element (hash).
	#a ' ' : no relationship (default)
	#a '-' : alignment only.
	#a
	#a naming :
	#a
	#a <name> : name of current
	#a   ' '  : nothing (default)

	#a number columns (via indentation).
	#a info per column :
	#a     - to which component (-key) does the column belong ?
	#a     - number of encountered sub-components.
	#a     - total number of sub-components.

	my $filler_info = $array->[$indent];

	my $filler_info_previous = undef;

	if ($indent < $#$array)
	{
	    $filler_info_previous = $array->[$indent - 1];
	}

	# if a tranformator said do not display

	#t note that the second test is actually masking a bug : a removed
	#t entry can need a continuation, so we may not remove it from empty
	#t lines.
	#t This bug is still triggered when a removed column contains
	#t only one entry.

	my $filler;

	#1 structure encoding

#	if (!$filler_info_previous || $filler_info_previous->{display})
	if ($filler_info->{display})
	{
	    if ($debug_indent)
	    {
		print STDERR "    " x $indent . "    Structure for column $indent, depth $#$array ($filler_info->{type} $filler_info->{name})\n";
	    }

	    # for the last column

	    if ($indent == $#$array)
	    {
		# if structure encoding not switched off

		#! this feature is currently not used.  It can possibly
		#! confuse the layout algorithm.

		if ($filler_info->{current} >= 0)
		{
		    # if many components in current

		    if ($filler_info->{size} > 1)
		    {
			# split

			if ($output_type eq 'content')
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{split};

			    $output_enabled = 1;
			}
			elsif ($indent == 0 && 0)
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{continue};
			}
			else
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{blank};
			}
		    }

		    # for empties or singles

		    else
		    {
			# align

			if ($output_type eq 'content')
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{align};

			    $output_enabled = 1;
			}
			else
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{blank};
			}
		    }
		}
	    }

	    # for other columns

	    else
	    {
		my $filler_info_next = $array->[$indent + 1];

		# if last component, then perhaps needs a blank

		my $is_last = $filler_info->{current} + 1 >= $filler_info->{size} ? 1 : 0;

		my $needs_blank = 0;

		# ... if any of next columns is not first one ...

		#t this type of construct gives square complexity in
		#t the broadness of the table.  Try to invent a
		#t preprocessing numbering scheme that summarizes the
		#t structure of the tree.  Use the numbers to go back to
		#t a linear complexity.

		foreach my $columns ($indent + 1 .. $#$array)
		{
		    my $filler_info_more = $array->[$columns];

# 		    print STDERR "    " x $indent . "        Next current is $filler_info_more->{current}\n";

		    #t perhaps I need a check on ->{displayed} here.

		    if ($filler_info_more->{current} != 0)
		    {
			# ... does not need a blank

			$needs_blank = 1;

			last;
		    }
		}

		if ($debug_indent)
		{
		    print STDERR "    " x $indent . "        Indenting current $filler_info->{current}, size $filler_info->{size}, needs_blank : $needs_blank, is_last : $is_last";
		}

		# if needs blank

		if ($is_last && $needs_blank)
		{
		    # stop current

		    $filler
			= $table_format->{$output_mode}->{structure}->{blank};
		}

		# if next column is current

		elsif ($filler_info_next->{current} == 0)
		{
		    # if many components in current

		    if ($filler_info->{size} > 1)
		    {
			# split current

			if ($output_type eq 'content')
			{
			    # assume needs split

			    my $needs_split = 1;

			    # ... if any of next columns is not first one ...

			    #t this type of construct gives square complexity in
			    #t the broadness of the table.  Try to invent a
			    #t preprocessing numbering scheme that summarizes the
			    #t structure of the tree.  Use the numbers to go back to
			    #t a linear complexity.

			    foreach my $columns ($indent + 1 .. $#$array)
			    {
				my $filler_info_more = $array->[$columns];

				#t perhaps I need a check on ->{displayed} here.

				if ($filler_info_more->{current} != 0)
				{
				    # ... does not need split

				    $needs_split = 0;

				    last;
				}
			    }

			    if ($debug_indent)
			    {
				print STDERR ", needs_split : $needs_split";
			    }

			    if ($needs_split)
			    {
				my $is_first = $filler_info->{current} eq 0;
				my $is_last = $filler_info->{current} + 1 >= $filler_info->{size} ? 1 : 0;

				my $is_start = $is_first;
				my $is_stop = $is_last;

				if ($is_start)
				{
				    if ($debug_indent)
				    {
					print STDERR ", current is $filler_info->{current} ==> is_start";
				    }

				    $filler
					= $table_format->{$output_mode}->{structure}->{start};
				}
				elsif ($is_stop)
				{
				    if ($debug_indent)
				    {
					print STDERR ", current is $filler_info->{current}, size is $filler_info->{size} ==> is_stop";
				    }

				    $filler
					= $table_format->{$output_mode}->{structure}->{stop};
				}
				else
				{
				    if ($debug_indent)
				    {
					print STDERR ", current is $filler_info->{current}, size is $filler_info->{size} ==> is_split";
				    }

				    $filler
					= $table_format->{$output_mode}->{structure}->{split};
				}
			    }
			    else
			    {
				# two cases : last entry (does not continue) or
				# not (does continue).

# 				if ($debug_indent)
# 				{
# 				    print STDERR "    " x $indent . "---     Indenting current $filler_info->{current}, size $filler_info->{size}\n";
# 				    print STDERR "    " x $indent . "---     Next current is $filler_info_next->{current}\n";
# 				}

				$filler
				    = $table_format->{$output_mode}->{structure}->{continue};
			    }
			}
			elsif ($output_type eq 'empty'
			       && $filler_info->{current} + 1 < $filler_info->{size})
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{continue};
			}
			else
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{blank};
			}
		    }

		    # for empties or singles

		    else
		    {
			if ($output_type eq 'content')
			{
			    # assume needs align

			    my $needs_align = 1;

			    # ... if any of next columns is not first one ...

			    #t this type of construct gives square complexity in
			    #t the broadness of the table.  Try to invent a
			    #t preprocessing numbering scheme that summarizes the
			    #t structure of the tree.  Use the numbers to go back to
			    #t a linear complexity.

			    foreach my $columns ($indent + 1 .. $#$array)
			    {
				my $filler_info_more = $array->[$columns];

				#t perhaps I need a check on ->{displayed} here.

				if ($filler_info_more->{current} != 0)
				{
				    # ... does not need align, but a blank

				    $needs_align = 0;

				    last;
				}
			    }

			    if ($needs_align)
			    {
				$filler
				    = $table_format->{$output_mode}->{structure}->{align};
			    }
			    else
			    {
				$filler
				    = $table_format->{$output_mode}->{structure}->{blank};
			    }
			}
			else
			{
			    $filler
				= $table_format->{$output_mode}->{structure}->{blank};
			}
		    }
		}

		# else current component continues below

		else
		{
		    $filler
			= $table_format->{$output_mode}->{structure}->{continue};
		}

		if ($debug_indent)
		{
		    print STDERR "    " x $indent . "\n        Next current is $filler_info_next->{current}\n";
		}
	    }

	    $str
		.= $table_format->{$output_mode}->{borders}->{left_centered}
		    . $filler
			. $table_format->{$output_mode}->{borders}->{right};
	}

	#2 naming

	if ($filler_info->{display})
	{
	    if ($debug_indent)
	    {
		print STDERR "    " x $indent . "    Naming column $indent, depth $#$array ($filler_info->{type} $filler_info->{name})\n";
	    }

	    # last column ...

	    if ($indent == $#$array)
	    {
		# ... needs a name if content output ...

		if ($output_type eq 'content')
		{
		    $filler
			= $filler_info->{string}
			    || $filler_info->{name};

		    $output_enabled = 1;

		    # increment number of output columns of previous column

		    $array->[$indent - 1]->{displayed}++;

		    # remove chars inserted by the context engine.

		    $filler =~ s/\\$separator/$separator/g;

		    # format the cell according to user preferences.

		    $filler
			= $self->_apply_user_formatting
			    ($context, $indent, $filler, "'$filler'");
		}

		# ... or a blank

		else
		{
		    $filler
			= $table_format->{$output_mode}->{structure}->{blank};
		}
	    }

	    # other columns ...

	    else
	    {
		# for content output

		if ($output_type eq 'content')
		{
		    # assume needs a name, but ...

		    my $needs_name = 1;

		    # ... if any of next columns is not first one ...

		    #t this type of construct gives square complexity in
		    #t the broadness of the table.  Try to invent a
		    #t preprocessing numbering scheme that summarizes the
		    #t structure of the tree.  Use the numbers to go back to
		    #t a linear complexity.

		    foreach my $columns ($indent + 1 .. $#$array)
		    {
			my $filler_info_next = $array->[$columns];

			if ($filler_info_next->{current} != 0)
			{
			    # ... does not need a name

			    $needs_name = 0;

			    last;
			}
		    }

		    if ($needs_name)
		    {
			$filler
			    = $filler_info->{string}
				|| $filler_info->{name};

			$output_enabled = 1;

			# increment number of output columns of previous column

			$array->[$indent - 1]->{displayed}++;

			# remove chars inserted by the context engine.

			$filler =~ s/\\$separator/$separator/g;

			# format the cell according to user preferences.

			$filler
			    = $self->_apply_user_formatting
				($context, $indent, $filler, $filler);


			# default does not need to be centered

			my $center = 0;

			# if the filler is an array index

			if ($filler_info_previous && $filler_info_previous->{type} eq 'ARRAY')
			{
			    $center = 1;
			}

			# if needed, additionally center the item

			if ($center && $output_mode eq 'html')
			{
			    $filler = "<center>$filler</center>";
			}
			else
			{
			    if ($output_mode eq 'html')
			    {
				$filler = "&nbsp;$filler&nbsp;";
			    }
			}
		    }
		    else
		    {
			$filler
			    = $table_format->{$output_mode}->{structure}->{blank};
		    }
		}

		# for empty output

		else
		{
		    # output a blank

		    $filler
			= $table_format->{$output_mode}->{structure}->{blank};
		}
	    }

	    my $format_cell = $table_format->{$output_mode}->{format_cell};

	    $filler = &$format_cell($filler);

	    if ($indent == $#$array && $output_mode eq 'html')
	    {
		# we force a multicolumn entry

		#t I could add a marker here telling in which column this is set
		#t (i.e. $indent).  Mozilla auto recovers.

		my $format = "$table_format->{$output_mode}->{borders}->{left_multicol}";

		#	    my $colspan = $indent;

		my $colspan = $filler_info->{colspan};

		#t For some reason $colspan can be undef, probably this is related
		#t to forced empties.  It is a bug that needs fixing.
		#t the following is a temporary workaround.

		if ($colspan)
		{
		    if ($debug_colspan)
		    {
			print STDERR "At depth $indent, cell's colspan is $colspan\n";
		    }

		    $format =~ s/colspan='__COLSPAN__'/colspan='__COLSPAN__$colspan'/;
		}
		else
		{
		    $format =~ s/colspan='__COLSPAN__'/colspan='__COLSPAN__$indent'/;
		}

		$str .= $format;
	    }
	    else
	    {
		my $format = "$table_format->{$output_mode}->{borders}->{left}";

		if (exists $filler_info->{colspan})
		{
		    $format =~ s/colspan='1'/colspan='$filler_info->{colspan}'/;
		}

		$str .= $format;
	    }

	    $str
		.= $filler
		    . $table_format->{$output_mode}->{borders}->{right};
	}
    }

    # produce output for non-empty content lines and forced empty lines.

    if ($output_enabled)
    {
	# terminate possible output by starting a new table row

	$str .= $self->_terminate_pending_output($context);
	#.= $table_format->{$output_mode}->{borders}->{top};

	# for consecutive forced empties

	my $last_output_type = $context->{last_output_type};

	if ($output_type eq 'empty'
	    && $last_output_type eq 'empty')
	{
	    # overwrite last empty if shorter than current

	    if (length $context->{last_output} <= length $str)
	    {
		my $len_last = length $context->{last_output};
		my $len_current = length $str;

		if ($debug_enabled)
		{
		    print STDERR "	    # overwrite : last empty $len_last is shorter than current $len_current\n";
		}

		$context->{last_output} = $str;
	    }

	    # do not write any output

	    $str = '';
	}

	# for a forced empty last in list

	elsif ($last_output_type eq 'empty'
	       && $output_type eq 'content')
	{
	    # output last empty before current output

	    if ($debug_enabled)
	    {
		print STDERR "	    # output last empty before current output\n";
	    }

	    # output the shortest empty of a concat list.

	    $str = $context->{last_output} . $str;

	    # register output

	    $context->{last_output} = $str;
	}

	# for a first forced empty

	elsif ($output_type eq 'empty'
	       && $last_output_type eq 'content')
	{
	    # register current empty

	    if ($debug_enabled)
	    {
		print STDERR "	    # register current empty\n";
	    }

	    $context->{last_output} = $str;

	    # do not write any output

	    $str = '';
	}

	# for normal output

	else
	{
	    # register output

	    if ($debug_enabled)
	    {
		print STDERR "	    # register output\n";
	    }

	    $context->{last_output} = $str;
	}

	# register output type

	$context->{last_output_type} = $output_type;
    }

    # else this is a logical empty

    else
    {
	# logically nothing to output, equivalent to a forced empty

	$context->{last_output_type} = 'empty';
	$context->{last_output} = $table_format->{$output_mode}->{borders}->{top};

	# erase any pending output.

	return("");
    }

    # return result

    return($str);
}


sub _terminate_pending_output
{
    my $self = shift;

    my $context = shift;

    my $str = '';

    my $table_format = $self->{table_format};

    my $output_mode = $self->{output_mode};

    # add a grid left aligner.

    if ($enable_grid_logic)
    {
	my $format = $table_format->{$output_mode}->{borders}->{left_grid_align};

	my $colspan = $context->{current_incremental_colspan};

	$format =~ s/__GRID_COLSPAN__/__GRID_COLSPAN__$colspan/g;

	$str .= $format;
	$str .= $table_format->{$output_mode}->{borders}->{right};
    }

    $str .= $table_format->{$output_mode}->{borders}->{top};

    return $str;
}


sub form_info_contents
{
    my $self = shift;

    my $query = $self->{CGI};

    my $table_format = $self->{table_format};

    my $str = '';

    my $contents = $self->{contents};

    # call the preprocessor

    if (exists $self->{preprocessor})
    {
	my $preprocessor = $self->{preprocessor};

	$contents = $preprocessor->transform($contents);
    }

    # call custom initializer

    if (exists $self->{component_initialize})
    {
	$str .= "<tr $main::cb>" ;
	$str .= &{$self->{component_initialize}};
	$str .= "</tr>\n";
    }

    $str .= $table_format->{$self->{output_mode}}->{borders}->{top};

    my $context = _context_create($self->{name});

    my $table_body .= $self->_formalize_any($context, $contents);

    my $number_of_columns = $context->{maximal_depth} * 2;

    # recompute column spanning

    while ($table_body =~ /colspan='__COLSPAN__([0-9]+)'/)
    {
	my $colspan = ($number_of_columns - 2 * $1);

	if ($enable_grid_logic)
	{
	    #t this line of code can be inlined with the main loop.

	    $table_body =~ s/colspan='__COLSPAN__([0-9]+)'/colspan='$1'/;
	}
	else
	{
	    $table_body =~ s/colspan='__COLSPAN__([0-9]+)'/colspan='$colspan'/;
	}
    }

    if ($enable_grid_logic)
    {
	while ($table_body =~ /colspan='__GRID_COLSPAN__([0-9]+)'/)
	{
	    my $colspan = ($number_of_columns - $1);

	    $table_body =~ s/colspan='__GRID_COLSPAN__([0-9]+)'/colspan='$colspan'/;
	}
    }

    $str .= $table_body;

    $str .= "\n";

    if (exists $self->{component_finalize})
    {
	$str .= "<tr $main::cb>" ;
	$str .= &{$self->{component_finalize}};
	$str .= "</tr>\n";
    }

    if ($enable_grid_logic)
    {
	# compute cells for grid layout

	my @grid;

	my $grid_cell;

	#t internally, perl creates a list for the range, rather inefficient,
	#t more readable.

	my $grid_width = $context->{maximal_incremental_colspan} + $context->{maximal_depth};

	if ($debug_colspan)
	{
	    print STDERR "Creating grid of width $grid_width\n";
	}

	my $output_mode = $self->{output_mode};

	my $borders = $table_format->{$output_mode}->{borders};

	foreach $grid_cell (0 .. $grid_width)
	{
	    $grid[$grid_cell]
		= $borders->{left}
		    #		. "&nbsp;"
		    . $borders->{right};
	}

	if ($debug_colspan)
	{
	    #	print STDERR "Adding grid : ", @grid, "\n";
	}

	# encapsulate the table with the grid to force early alignment

	$str
	    = "<tr $main::cb>"
		. join("", @grid)
		    . "</tr>\n"
			. $str
			    . "<tr $main::cb>"
				. join("", @grid)
				    . "</tr>\n";
    }

    $self->writer($str);

    if ($debug_colspan)
    {
#	print STDERR "Final result is " . $str . "\n";
    }

}


sub form_info_end
{
    my $self = shift;

    my $str = '';

    if ($self->{output_mode} =~ 'html')
    {
	$str .= "</table>\n";
    }

    $self->writer($str);
}


sub form_info_header
{
    my $self = shift;

    my $str = '';

    $self->writer($str);
}


sub form_info_start
{
    my $self = shift;

    my $str = '';

    if ($self->{output_mode} =~ 'html')
    {
	$str .= "<table cellpadding=\"0\" cellspacing=\"0\" frame=\"box\" summary=\"structured view of $self->{name}.\">";
    }

    $self->writer($str);
}


sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(
				@_,
			       );

  # get a table format if none given

  if (!exists $self->{table_format})
  {
      $self->{table_format} = $default_table_format;
  }

  bless ($self, $class);

  return $self;
}


#
# Parse the input from the CGI object in the document.  Apply any
# detransformation and decapsulation if needed.
#
# Result is put in the field ->{parsed_input}.  Probably more processing is
# needed afterwards using a call to ->merge_data().
#

sub parse_input
{
    my $self = shift;

    my %result;

    my $separator = $self->{separator} || '_';

    my $query = $self->{CGI};

#     # if there is a postprocessor

#     if ($self->{postprocessor})
#     {
# 	print STDERR "FormType $self->{name}: calls postprocessor\n";

# 	my $postprocessor = $self->{postprocessor};

# 	$contents = &$postprocessor($self, $contents, );
#     }

    # if factory settings request

    if ($self->parse_factory(\%result))
    {
	# return without further processing

	return \%result;
    }

    # figure out the submitted section

    if ($self->parse_submits(\%result))
    {
	return \%result;
    }

    # figure out the pressed button

    if ($self->parse_buttons(\%result))
    {
	return \%result;
    }

    # hash with used decapsulators

    my $used_decapsulators;

    # hash with decapsulated CGI keys

    my $decapsulated_keys;

    # number of keys that should be handled.

    my $keys_to_handle = 0;

    # fetch CGI parameters

    my @query_params = $query->param();

    # loop over all submitted fields

    #! so the assumption is that everything is constant except for things
    #! that are encapsulated with a user format.

    my $decapsulated;

    while ($#query_params >= 0)
    {
	my $key = pop(@query_params) ;

	next if $key !~ /^field${separator}/;

	# the field indication was not used for matching

	$key =~ s/^field${separator}//;

	$keys_to_handle++;

	# apply decapsulation : loop over user formats

	if (exists $self->{user_formats})
	{
	    my $user_formats = $self->{user_formats};

	    foreach my $user_format (@$user_formats)
	    {
		# if the user format matches with the CGI key and the datatypes correspond

		my $matcher = $user_format->{matcher};

		my $datatype = $user_format->{datatype};

# 		print STDERR "format matcher is $matcher\n";

		if ($matcher =~ /\$$/)
		{
		    #t figure out how this can be removed from the code.

		    my $match_terminator = quotemeta "/[^/]*\$";

		    $matcher =~ s|$match_terminator$||;
		}

# 		print STDERR "format matcher is $matcher\n";

		# convert separators : replace the document slashes with CGI's
		# underscores.

		#t synchronize separators : use XPath, meaning slashes.

# 		$matcher = "field${separator}$matcher";

		#t the key is always a scalar, the datatype can be different

		if ($key =~ /$matcher/
		    && (!defined $datatype
			|| (!ref $key && $datatype eq 'SCALAR')))
		{
		    print STDERR "CGI key '$key' will be handled by decapsulator $user_format->{name}\n";
# 		    print STDERR "'$key' matches with $matcher\n";

		    # register the handling/use of the key/decapsulator

		    $decapsulated_keys->{$key}->{$user_format->{name}}++;

		    $used_decapsulators->{$user_format->{name}}->{$key}++;

		    # fetch the value from CGI

		    my $value = $query->param("field" . $separator . $key);

		    if (!defined $value)
		    {
			print STDERR "FormType error: CGI key $key does not have a defined value\n";

			$self->register_error("CGI key $key does not have a defined value");

			last;
		    }

# 		    # remove the field indication from the CGI key

# 		    $key =~ s/^field${separator}//;

		    # remove the name of the document from the key

		    $key =~ s|^[^${separator}]*${separator}||;

		    # apply decapsulation

		    my $decapsulator = "_decapsulate_$user_format->{type}";

		    my ($decapsulated_key, $decapsulated_data)
			= $self->$decapsulator
			    (
			     $key,
			     $user_format->{column},
			     $decapsulated,
			     $value,

			     #! I assume that this operation does not create
			     #! any hash entry.  I guess it would at most
			     #! initialize $user_format as an empty hash
			     #! reference (which it is already).

			     ($user_format->{decapsulator}
			      && $user_format->{decapsulator}->{options})
			     || {},
			    );

		    # if the decapsulator says to store the data

		    if (defined $decapsulated_key)
		    {
			# construct the place in the decapsulated data hash

			my $store_data = $decapsulated_key;

			# security first : protect single quotes

			$store_data =~ s/'/\\'/g;

			# compute array paths

			$store_data =~ s/\[([0-9]+)\]${separator}/->[$1]/g;

			# compute hash paths

			$store_data =~ s/([^${separator}]+)${separator}/->{'$1'}/g;

			# store the data

			$store_data = "\$decapsulated${store_data} = '$decapsulated_data'";

			print STDERR "parse_input: eval '$store_data'\n";

			eval $store_data;
		    }

		    # stop the decapsulator loop

		    last;
		}
		else
		{
# 		    print STDERR "'$key' does not match with '$matcher'\n";
		}
	    }
	}
    }

    # give diagnostics on the computed new data

    print STDERR "Decapsulated data is \n", Dumper($decapsulated);

    if ($keys_to_handle != scalar keys %$decapsulated_keys)
    {
	print STDERR "FormType error: CGI keys to be handled does not number to the handled keys.\n";

	print STDERR "Decapsulated keys are \n", Dumper($decapsulated_keys);
	print STDERR "Used decapsulators are \n", Dumper($used_decapsulators);

	$self->register_error("CGI keys to be handled does not number to the handled keys.");
    }
    else
    {
	print STDERR "Number of CGI keys to be handled matches with the number of handled keys.\n";
    }

    # loop over all decapsulated values

    my $detransformed;

 DETRANSFORM:
    while (my ($key, $value) = each %$decapsulated)
    {
	# apply detransformation

	if (exists $self->{preprocessor})
	{
	    print STDERR "Applying detransformation for $key.\n";

	    my $transformation = $self->{preprocessor};

	    foreach my $transformator (@{$transformation->{simple_transformators}})
	    {
		# if transformator key does not match with decapsulated data
		# key

		if (!$transformator->{key}
		    || $transformator->{key} ne $key)
		{
		    # try next transformator

		    next;
		}

		# examine the matcher of the transformation

		my $matcher = $transformator->{matcher};

		# if it is not anchored at the end

		if ($matcher !~ /\$$/)
		{
		    # cannot be detransformed

		    print STDERR "Transformator $transformator->{name} cannot be detransformed.  It is not \$ anchored at the end.\n";

		    last;
		}

		print STDERR "Using detransformation $transformator->{name} for $key.\n";

		# remove path leading to the key

		my $starter = quotemeta '^[^/]*';

		$matcher =~ s|$starter||;
		$matcher =~ s|.*/||;

		my $ending = quotemeta '$';

		$matcher =~ s|$ending$||;
		$matcher =~ s|/*$||;

		# compute path entries leading to this entry

		my @matcher_keys = split '/', $matcher;

		# compute storage command with path

		my $store_data = join '', map { "->{'$_'}"; } @matcher_keys;

		# store the result

		$store_data = "\$detransformed${store_data} = \$value";

		print STDERR "eval '$store_data'\n";

		eval $store_data;

		# at most apply one detransformation for any one entry.

		next DETRANSFORM;
	    }
	}

	# if no transformation applied

	else
	{
	    print STDERR "No detransformation for $key, copied.\n";

	    # simply copy

	    $detransformed->{$key} = $value;
	}
    }

    # store the detransformed data

    $result{detransformed} = $detransformed;

    print STDERR "Detransformation result is :\n", Dumper(\%result);

    # return result

    return \%result ;
}


# test sub : test the functionality of Poetical::TreeFormType.

sub _main
{
    my $query = new CGI();

    my $tree;
    my $tree1;

    $tree
	= {
	   a => {
		 a1 => '-a1',
		 a2 => '-a2',
		},
	   b => [
		 '-b1',
		 '-b2',
		 '-b3',
		],
	   c => {
		 c1 => {
			c11 => '-c11',
		       },
		 c2 => {
			c21 => '-c21',
		       },
		},
	   d => {
		 d1 => {
			d11 => {
				d111 => '-d111',
			       },
		       },
		},
	   e => [
		 {
		  e1 => {
			 e11 => {
				 e111 => '-e111',
				},
			},
		 },
		 {
		  e2 => {
			 e21 => {
				 e211 => '-e211',
				},
			},
		 },
		 {
		  e3 => {
			 e31 => {
				 e311 => '-e311',
				},
			},
		 },
		],
	  };

    $tree->{functions}
	= {
	   'USS_MON' => {
                         'functions' => {
					 'ant_ctrl' => 1,
					 'beacon_ctrl' => 0
                                        }
			},
	   'USS_RF' => {
                        'functions' => {
					'buc' => 0
                                       }
		       },
	   'USS_RX0' => {
                         'functions' => {
					 'BDC_2' => 2,
					 'dehydrator' => 4,
					 'BDC_1' => 1,
					 'BDC_RD' => 3
                                        }
			},
	   'USS_CTRL' => {
                          'functions' => {
					  'wg_sw_pol' => 1,
					  'wg_sw_tx' => 0,
					  'wg_sw_tx_alarm' => 2,
					  'wg_sw_pol_alarm' => 3
                                         }
			 }
	  };

    $tree->{system}
	= {
	   '1. Station name' => 'DTV Al Jazeera',
	   '6. Sems software packages' => [
                                           'site_al_jazeera_*.tgz',
                                           'snmp_gw_*.tgz'
					  ],
	   '3. Sems software version' => '3.10',
	   '2. Internal Sems site name' => 'al_jazeera',
	   '5. Configuration license key' => '54d7:ee83:1094:b973:4774:4732:36ef:dd3f',
	   '4. Running Sems identification' => 'Sems is not running ?'
	  };

#    $tree = do '/var/sems/sems.config';

    $tree1->{ANT_CTRL} =
    {
     type     => 'UserDefined',
     bus      => 'dummy',
     addr     => 0,
     equipm_url  => 'USS_MON+main',
     ok_function => { "USS_MON.ant_ctrl.ntcSeEqSxSwitchControl" => 0, },
    };

    my $document
	= new Poetical::TreeFormType
	    (
	     CGI => $query,
	     name => 'tree-tester',
	     output_mode => 'ascii',
	     center => 1,
	     contents => $tree->{devices} ? $tree->{devices} : $tree,
# 	     array_filter =>
# 	     sub
# 	     {
# #		 my ($context, $component) = @_;

# 		 $_[0]->{path} =~ m|/-b2$| ? 0 : 1;
# 	     },
# 	     hash_filter =>
# 	     sub
# 	     {
# #		 my ($context, $hash_key, $hash) = @_;

# 		 $_[0]->{path} =~ m|/c| ? 0 : 1;
# 	     },
	     component_transformator =>
	     sub
	     {
		 my ($transform_data, $context, $contents) = @_;

# 		 print STDERR $context->{path}, "\n";

		 # rename the element with name 'b'.

		 if ($context->{path} =~ m|[^/]/b$|)
		 {
		     $transform_data->{display} = 0;
		     $transform_data->{string} = 'Y';
		 }

		 # remove the element with name 'c'.

		 if ($context->{path} =~ m|[^/]/c$|)
		 {
		     $transform_data->{display} = 0;
		     $transform_data->{string} = 'Y';
		 }
	     },
	     component_transformator1 =>
	     sub
	     {
		 my ($transform_data, $context, $contents) = @_;

# 		 print $context->{path}, "\n";

		 # default : do not display anything

		 $transform_data->{display} = 0;

		 # display functions and ok_function.

		 if (
		     $context->{path} =~ m|^.*?/.*?/[^/]*?function|

# 		     # display leds.

# 		     || $context->{path} =~ m|^.*?/.*?/led|

# 		     # display device names

# 		     || $context->{path} =~ m|[^/]*/[^/]*$|
		    )
		 {
		     $transform_data->{display} = 1;

# 		     if ($debug_enabled)
# 		     {
# 			 print STDERR "$context->{path} matches functions\n";
# 		     }
		 }

		 if (
# 		     $context->{path} =~ m|^.*?/.*?/[^/]*?function|

		     # display leds.

		     $context->{path} =~ m|^.*?/.*?/led|

# 		     # display device names

# 		     || $context->{path} =~ m|[^/]*/[^/]*$|
		    )
		 {
 		     $transform_data->{display} = 1;

# 		      if ($debug_enabled)
# 		      {
# 			  print STDERR "$context->{path} matches leds\n";
# 		      }
		 }

		 if (
# 		     $context->{path} =~ m|^.*?/.*?/[^/]*?function|

# 		     # display leds.

# 		     || $context->{path} =~ m|^.*?/.*?/led|

		     # display device names

		     $context->{path} =~ m|^[^/]*/[^/]+$|
		    )
 		 {
 		     $transform_data->{display} = 1;

# 		     if ($debug_enabled)
# 		     {
# 			 print STDERR "$context->{path} matches device names\n";
# 		     }
		 }
	     },
	    );

    $document->formalize();

}


1;


