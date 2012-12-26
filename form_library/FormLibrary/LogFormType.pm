#!/usr/bin/perl -w
#

package FormLibrary::LogFormType;


use Data::Dumper;

use IO::File;


use FormLibrary::FormType;


@ISA = ("FormLibrary::FormType");


sub form_info_contents
{
    print STDERR "form_info_contents\n";

    my $self = shift;

    my $query = $self->{CGI};

    my $str = '';

    my $count = 0;

#    my $contents = $self->{contents};

    if ($self->{logs}->{view})
    {
	$self->open_log_file();

	my $record;

 	#! small optimization : first fetch all required methods, next use the
 	#! methods without slow lookups.  Seems a lot faster at first
 	#! impression, though could be an impression only.

 	my $record_reader = $self->can('read_log_record');
 	my $record_filter = $self->can('record_filter');
 	my $writer = $self->can('writer');

	while ($record = &$record_reader($self))
	{
	    if (&$record_filter($self, $record))
	    {
 		&$writer($self, $record);
 		&$writer($self, "<br>");
	    }
	}
    }

    $self->set_not_empty();
}


sub form_info_end
{
    print STDERR "form_info_end\n";

    my $self = shift;

    my $str = '';

    $str .= "<hr>\n";

    $self->writer($str);
}


sub form_info_start
{
    print STDERR "form_info_start\n";

    my $self = shift;

    my $query = $self->{CGI};

    my $str = '';

    if (exists $self->{selectors})
    {
	$str .= "<hr>\n";
    }

    $str .= "<br>\n";

    foreach my $selector (@{$self->{selectors}})
    {
	$str .= $selector->{description};

	$str .= $query->popup_menu(
				   -name => "$self->{name}_$selector->{id}",
				   -default => $selector->{popup}->{default},
				   -values => $selector->{popup}->{options},
				   -override => 1,
				  );

	$str .= "<br>\n";
    }

    $str .= $query->submit(
			   -name => "$self->{name}_submit",
			   -value => ' Search Log Files ',
			  );

    $self->writer($str);
}


# everything has been written already : nothing to flush.

sub flush
{
    my $self = shift;
}


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %options = @_;

    my $self = $class->SUPER::new(%options);

    $self->{logs}->{files}
        = "((cat `ls -1 /var/log/sems*.gz` | gunzip ) || true) && cat /var/log/sems |";

    # $self is FormType, rebless to LogFormType.

    bless ($self, $class);

    return $self;
}


# the writer of a LogFormType writes immediately to STDOUT for a better
# interactive experience.

sub writer
{
    my $self = shift;

    my $content = shift;

#    print STDERR Dumper($self, $content);
#    print STDERR Dumper($content);

    if (!exists $self->{writer_output})
    {
	$self->{writer_output} = '';
    }

    $self->{writer_output} .= $content;

    print $content;

}


sub open_log_file
{
    #open(LOG, "</var/log/sems");

    my $fh = IO::File->new();

    if ($fh->open($_[0]->{logs}->{files}))
    {
	$_[0]->{logs}->{file_handle} = $fh;
    }
    else
    {
	$_[0]->{logs}->{file_handle} = undef;
    }
}


sub read_log_record
{
    my $log = $_[0]->{logs}->{file_handle};

    local $/ = "\n";

    my $record = $log->getline();

    return($record);
}


sub record_filter
{
    my $self = shift;

    die "The package " . ref($self) . " does not define a sub record_filter().";
}


1;


