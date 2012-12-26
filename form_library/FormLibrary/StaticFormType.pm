#!/usr/bin/perl -w
#

package FormLibrary::StaticFormType;


use strict;

use CGI;

use Data::Dumper;

use FormLibrary::FormType;


our @ISA = ("FormLibrary::FormType");


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

    if ($self->{name} =~ /_/)
    {
	print STDERR "FormType Error: Document names must not contain an '_'\n";

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
	    = caller(0);

	print STDERR "FormType Error: at $filename:$line, $subroutine\n";

	require Carp;

	Carp::cluck "FormType Error: at $filename:$line, $subroutine\n";
    }

    bless ($self, $class);

    $self->set_is_empty();

#     print STDERR Data::Dumper::Dumper($self);

    return $self;
}


# a static document has an static writer : it buffers everything till flushed.

sub writer
{
    my $self = shift;

    my $content = shift;

    if (!exists $self->{writer_output})
    {
	$self->{writer_output} = '';
    }

    $self->{writer_output} .= $content;

}


# print the generated result to STDOUT.

sub flush
{
    my $self = shift;

    print $self->{writer_output};
}


# remove the generated result.

sub unflush
{
    my $self = shift;

    $self->{writer_output} = '';
}


1;


