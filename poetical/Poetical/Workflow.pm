#!/usr/bin/perl -w
#

package Poetical::Workflow;


#
# A workflow object describes the possible flows through different
# forms, before and after visiting a given form.
#
# Given a form :
#
# 1. What to do after visiting this form.
#
# 2. What has been done before visiting this form.
#
# 3. Give related forms, and possible describe how they are related.
#
#
# The package exports routines that support to automatically create
# links for the above mentioned flows for the following :
#
# 1. Header generation, header().
#
# 2. Trailer generation, trailer().
#
# Both subs take as options :
#
# 1. after => 1 : generate links to the form to visit after the
# current form.  This option is best combined with trailer().
#
# 2. before => 1 : generate links to the form just visited.  This
# option is best combined with header().
#
# 3. related => 1 : generate links to the forms related to the current
# one.  I guess this option is also best combined with header().
#
#
# The real links generated depend on the configuration given to the
# constructor.  Normally this configuration is taken literally from
# the persistency layer configuration file for the module the form
# belongs to.
#

use strict;


use URI;


sub _canonical_uri
{
    my $self = shift;

    my $result = shift;

#     if ($result =~ /\?/)
#     {
# 	#! removes CGI parameters

# 	$result =~ s/\?.*//;
#     }

    if ($result =~ /^http/)
    {
# 	#! removes 'http://localhost/webmin

# 	$result =~ s(^http://([^/]+/){2})(/);

	#! or removes 'http://localhost:10000

	$result =~ s(^http(s)?://([^/]+/){1})(/);
    }

    return $result;
}


sub _generate_after
{
    my $self = shift;

    my $options = shift;

    my $history = $options->{history};

    my $result = '';

#     $result .= '<small>';

    $result .= '<font size="-2" style="position: absolute; left: 20%;">';

    my $index = $self->_sequence_index();

    if (defined $index)
    {
	# generate a part of the sequence

	$index++;

	my $sequence = $self->{configuration}->{sequence};

	$result .= $self->_generate_sequence( [ @$sequence[$index .. $#$sequence] ], { history => $history, }, );
    }

    $result .= '</font>';

#     $result .= '</small>';

    return $result;
}


sub _generate_before
{
    my $self = shift;

    my $options = shift;

    my $history = $options->{history};

    my $result = '';

#     $result .= '<small>';

    $result .= '<font size="-2" style="position: absolute; left: 5%;">';

    my $index = $self->_sequence_index();

    if (defined $index)
    {
	# generate a part of the sequence

	$index--;

	my $sequence = $self->{configuration}->{sequence};

	$result .= $self->_generate_sequence( [ @$sequence[0 .. $index] ], { history => $history, }, );
    }

    $result .= '</font>';

#     $result .= '</small>';

    return $result;
}


sub _generate_history
{
    my $self = shift;

    my $options = shift;

    my $history = $options->{history};

    my $result = '';

    $result .= '<font size="-2" style="position: absolute; right: 5%;">';

    my $sequence
	= [
	   map
	   {
	       my $result
		   = {
		      label => m([^?]*/(.+)) && $1,
		      target => $_,
		     };

	       $result;
	   }
	   split ';', $history,
	  ];

    if ($sequence && @$sequence)
    {
	$result .= 'History : ';

	$result .= $self->_generate_sequence( [ @$sequence[0 .. $#$sequence] ], { history => $history, , maximum => -3, }, );
    }

    $result .= '</font>';

    return $result;
}


sub _generate_related
{
    my $self = shift;

    my $options = shift;

    my $history = $options->{history};

    my $result = '';

    $result .= '<font size="-2" style="position: absolute; right: 5%;">';

    my $sequence = $self->{configuration}->{related};

    if ($sequence && @$sequence)
    {
	$result .= 'Related : ';

	$result .= $self->_generate_sequence( [ @$sequence[0 .. $#$sequence] ], { history => $history, }, );
    }

    $result .= '</font>';

    return $result;
}


sub _generate_sequence
{
    my $self = shift;

    my $sequence = shift;

    my $options = shift;

    my $result = '';

    my $history = $options->{history} || '';

#     #t counterpart of Poetical::FormType processing, centralized abstraction needed.

#     $history =~ s/\\;/;/g;

    my $separator = $options->{separator} || '&nbsp;---&nbsp;';

    # determine the start and stop of the sequence to render

    my $start = 0;

    my $stop = $#$sequence;

    if (defined $options->{maximum})
    {
	my $maximum = $options->{maximum};

	if ($maximum < 0)
	{
	    $start = $#$sequence + $maximum;

	    if ($start < 0)
	    {
		$start = 0;
	    }
	}
	else
	{
	    $stop = $maximum;

	    if ($stop > $#$sequence)
	    {
		$stop = $#$sequence;
	    }
	}
    }

    # loop through the sequence

    my $first = 1;

    foreach my $step (@$sequence[$start .. $stop])
    {
	if (!$first)
	{
	    $result .= $separator;
	}

	my $target = $self->_canonical_uri($step->{target});

	# add the current element to the result

	#t remove localhost, replace it with whatever should be in the URL.
	#t also respect the protocol, i.e. http or https.

# 	$result .= "<a href=\"http://localhost/webmin$target";

	if ($ENV{WEBMIN_CONFIG} =~ /usermin/i)
	{
	    $result .= "<a href=\"https://localhost:20000$target";
	}
	else
	{
	    $result .= "<a href=\"https://localhost:10000$target";
	}

	if ($target =~ /\?/)
	{
	    $result .= "&document_history=$history\"";
	}
	else
	{
	    $result .= "?document_history=$history\"";
	}

	$result .= ">$step->{label}</a>";

	$first = 0;
    }

    return $result;
}


sub header
{
    my $self = shift;

    my $options = shift;

    my $history = shift;

    my $result = '';

    $result .= '<div>';

    if ($options->{before})
    {
	$result .= $self->_generate_before( { history => $history, }, );
    }

    if ($options->{after})
    {
	$result .= $self->_generate_after( { history => $history, }, );
    }

    if ($options->{related})
    {
	$result .= $self->_generate_related( { history => $history, }, );
    }

    if ($options->{history})
    {
	$result .= $self->_generate_history( { history => $history, }, );
    }

    $result .= '</div>';

    return $result;
}


sub new
{
    my $proto = shift;

    my $class = ref($proto) || $proto;

    my $configuration = shift;

    my $runtime = shift;

    my $self
	= {
	   configuration => $configuration,
	   runtime => $runtime,
	  };

    bless ($self, $class);

    return $self;
}


sub _sequence_index
{
    my $self = shift;

    my $result;

    my $sequence = $self->{configuration}->{sequence};

    # identify self in the workflow sequence

    my $uri_string = $self->_canonical_uri($self->{runtime}->{self});

    my $uri = URI->new($uri_string);

    my $path = $uri->path();

    my $parameters = { $uri->query_form(), };

    #t divide $uri in the url locator part and the parameter part
    #t test locator part
    #t test module selection related parameters.

    #t never include document_history in the tests

    my $count = 0;

    foreach my $step (@$sequence)
    {
	# if found

# 	my $expression = quotemeta $step->{target};

# 	if ($uri =~ /^$expression$/)

	my $uri_target = URI->new($step->{target});

	my $target_path = $uri_target->path();

	my $target_parameters = { $uri_target->query_form(), };

	#t this should at least be configurable

	my $parameters_to_consider
	    = {
	       module_name => 1,
	       submodule_name => 1,
	      };

	# if path part matches

	if ($path eq $target_path)
	{
	    my $match = 1;

	    # if parameters match

	    map
	    {
		$parameters->{$_} ne $target_parameters->{$_}
		    && ($match = 0);
	    }
		keys %$parameters_to_consider;

	    if ($match)
	    {
		# set result

		$result = $count;

		last;
	    }
	}

	$count++;
    }

    return $result;
}


sub trailer
{
    my $self = shift;

    my $options = shift;

    my $history = shift;

    my $result = '';

    if ($options->{after})
    {
	$result .= $self->_generate_after();
    }

    if ($options->{before})
    {
	$result .= $self->_generate_before();
    }

    if ($options->{related})
    {
	$result .= $self->_generate_related();
    }

    return $result;
}


1;


