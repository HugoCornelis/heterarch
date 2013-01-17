#!/usr/bin/perl -w
#

package Poetical::DefaultFormType;


use Data::Dumper;


#
# Guess the format of a document hash.
#
# TODO: facility to sort columns
#       facility to distinguish between be_defined and filter_defined

sub GuessFormat
{
    my $documented_hash = shift;

    my $format
	= {
	   columns => [],
	   hashkey => 'name',
	  };

    # get a first clue of the format

    my $asked_rows = $documented_hash->{rows};
    my $asked_columns = $documented_hash->{columns};

    # go through all rows

    my $contents = $documented_hash->{contents};

    foreach my $row_key (%$contents)
    {
	my $row = $contents->{$row_key};

	# first column is treated specially in case of hash.

	my $first = 1;

	#t examine the type of column
	#t can be hash or list.

	# go through all columns

	#t implemented facility to sort the columns.

	foreach my $column_key (%$row)
	{
	    my $column_format;

	    if ($first)
	    {
		$column_format
		    = {
		       header => 'name',
		       key_name => undef,
		       type => 'constant',
		       be_defined => 1,
#                      width => 150,
		      };
	    }
	    else
	    {
		$column_format
		    = {
		       header => '__UNKNOWN__',
		       key_name => '__UNKNOWN__',
		       type => 'constant',
		       be_defined => 1,
#                      width => 150,
		      };

	    }

	    #t examine the column.

	    #t fill in the format.

	    push @{$format->{columns}}, $column_format;

	    # first column handled.

	    my $first = 0;
	}

    }

    return $format;
}


#
# Given a hash, guesses a FormType class and format to render the
# hash.
#

sub DefaultGuesser
{
    my $documented_hash = shift;

    # set default class.

    my $guessed_class = 'Poetical::DefaultFormType';

    my $guessed_format = GuessFormat($documented_hash);;

    return($guessed_class, $guessed_format);
}


#
# The default document has the following properties :
#   submit, reset and factory buttons.
#   uses the DefaultGuesser to guess the document type.
#
# Beware : the returned instance is not a blessed in this package.
#

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # guess document type.

  my ($guessed_class, $guessed_format) = DefaultGuesser($_[0]);

  # have to replace this with a guessed-class call.

  my $self  = $guessed_class::new(
				  format => $guessed_format,
				 );

  # I could bless here and use autoload, except for intuition of the
  # user of this class, what could be a real practical use ?

#  bless ($self, $class);

  return $self;
}


sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self  = $guessed_class::new(
				  has_submit => 1,
				  has_reset => 1,
				  has_factory => 1,
				 );

  return $self;
}


1;


