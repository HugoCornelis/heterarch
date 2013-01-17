#!/usr/bin/perl -w
#

package Poetical::Utility;


#
# How to add a new config file ?
#
# 1. Add the necessary information to the config file database.
#
# 1.a. Define the appropriate tags.
#
# 1.b. Define the filename.
#
# 1.c. Add the new data to the global config file database.
#
# 2. Define reader/writer subs :
#
# 2.a. for read config.
#
# 2.b. for write config.
#
# 2.c. for restore config.
#
# 2.d. for factory write config.
#
# These subs are normally only frontends for the low-level subs they
# should call.  Export only the high-level ones, i.e. the ones you
# have defined.  Next, implement Poetical modules for the new config
# file.
#


use strict;


#<--- -*- mmm-classes:html-js -*- --->


our $stderr_logging = 0;

BEGIN
{
#     use Poetical::Persistency;

    # default : stderr_logging is disabled

    $stderr_logging = 0;

    sub unique
    {
	if (!@_)
	{
	    return ();
	}

	my @result = (shift);

	foreach (@_)
	{
	    if ($result[$#result] ne $_)
	    {
		push @result, $_;
	    }
	}

	return @result;
    }

    # param list can be array or ref ro array
    sub array_max {
	my ($first, @list) = @_;
	if (ref $first) {
	    @list = @$first;
	} else {
	    unshift @list, $first;
	}
	my $max;
	foreach (@list) {
	    $max = $_ if ! defined $max or $max < $_;
	}
	return $max;
    }


    #
    # create a sensible backup filename.
    #
    # $_[0] : fully qualified filename.
    #

    sub create_backup_name
    {
	my $filename = shift ;

	my $count = 0;

	my $backup_name = "$filename~$count";

	# loop over backups to determine oldest backup

	my $oldest = $count;

	my $ctime_oldest = 9999999999; # 1118654454;

	while (-e $backup_name)
	{
	    # get inode change time

	    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime,
		$mtime, $ctime, $blksize, $blocks)
		= stat($backup_name);

	    # keep track of oldest name.

	    if ($ctime_oldest > $ctime)
	    {
		$ctime_oldest = $ctime;
		$oldest = $count;
	    }

	    # check next backup name ...

	    $count++;

	    # ... but stop at wrap value

	    if ($count > 20)
	    {
		# need to replace oldest file.

		$count = $oldest;

		# oldest file known, break loop

		last;
	    }

	    # compute next backup name

	    $backup_name = "$filename~$count";
	}

	# return possibly new backup name

	return("$filename~$count");
    }


    sub import
    {
	# check if stderr_logging is imported.

	my $count = -1;

	my $index = array_max map { $count++; /^STDERR_LOGGING$/ ? $count : -1 } @_;

	# if stderr_logging is imported

	if ($index ne -1)
	{
	    # remove it from the list to export

	    splice @_, $index, 1;

	    # and enable stderr_logging

	    $stderr_logging = 1;
	}

	# export specified symbols into the callers namespace

	Poetical::Utility->export_to_level(1, @_);
    }

    # only if we are root

    #! this test prevents user permission problems when used with
    #! class_hierarchy.cgi.

    if ($< eq 0)
    {
	my $logfile = create_backup_name('/var/log/poetical_error.log');

	# redirect STDERR Poetical one-shot log.

	`>$logfile ; ln -sf $logfile /var/log/poetical_error.log`;

	use CGI::Carp qw(carpout);
	use FileHandle;
	my $log = FileHandle->new();
	open($log, ">>$logfile")
	    or die("Unable to open logfile $logfile: $!\n");
	carpout($log);
    }
}


#use diagnostics -verbose;
use Data::Dumper;


# ======================================================================
sub clean_dump {			# varname_base part
    my ($varname_base, $part, %options) = @_;
    my ($purity, $indent, $quotekeys, $sortkeys, $varname)
	= ($Data::Dumper::Purity,
	   $Data::Dumper::Indent,
	   $Data::Dumper::Quotekeys,
	   $Data::Dumper::Sortkeys,
	   $Data::Dumper::Varname);

    $Data::Dumper::Purity    = 1;
    $Data::Dumper::Indent    = 2;
    $Data::Dumper::Quotekeys = 0;
    $Data::Dumper::Sortkeys  = $options{sort} || 1;
    $Data::Dumper::Varname   = $varname_base || 'aaa7bbbb';

    my $dmp = Dumper $part;

    $dmp =~ s/\$$Data::Dumper::Varname.\s*=\s+/   /sg
      unless $varname_base;
    $dmp =~ s/^         //gm;
    $dmp =~ s/[;\n\s]+\Z/;\n/s;
    $dmp =~ s/'([-+]?[1-9]\d*)'/$1/sg;	# intergers not in quotes (take care
                                        # of strings like 0007)
    $dmp =~ s/'0'/0/gs;			# dumper places 0s in quotes. why?

    $Data::Dumper::Purity = $purity;
    $Data::Dumper::Indent = $indent;
    $Data::Dumper::Quotekeys = $quotekeys;
    $Data::Dumper::Sortkeys = $sortkeys;
    $Data::Dumper::Varname = $varname;

    return $dmp;
}


require Exporter;


our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
		    documents_formalize
		    documents_merge_data
		    documents_parse_input
		    java_script_popup_function
		    java_script_reload
		   );


my $sems_config_file = '/var/sems/sems.config';


#
# caches are read from a file returning a perl value (i.e. hash, array or
# whatever perl understands as an rvalue).
#

sub cache_exists
{
#    unlink $_[0];

    return -r $_[0]
}


sub cache_read
{
    return do $_[0];
}


sub cache_write
{
    my $filename = shift;

    my $data = shift;

    my $directory = $filename;

    $directory =~ s|(.*)/.*|$1|;

    if ($stderr_logging)
    {
	print STDERR "Creating $directory\n";
    }

    mkdir $directory, 0777;

    open(CACHE, ">$filename")
	|| die("can't open $filename: $!");

    my $header = <<EOH;
#!/usr/bin/perl
# -*- perl -*-
# Poetical cache file.
# Date : (__DATE__)
# Name : ($filename)
#

EOH

    my $date = `date`;

    chomp $date;

    $header =~ s/__DATE__/$date/;

    print CACHE $header;
    print CACHE "\$data = \n";
    print CACHE clean_dump('',$data);
    print CACHE "return \$data\n\n\n";
    close(CACHE);
}


# #
# # create a sensible backup filename.
# #
# # $_[0] : fully qualified filename.
# #

# sub create_backup_name
# {
#     my $filename = shift ;

#     my $count = 0;

#     my $backup_name = "$filename~$count";

#     # loop over backups to determine oldest backup

#     my $oldest = $count;

#     my $ctime_oldest = 0;

#     while (-e $backup_name)
#     {
# 	# get inode change time

# 	my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime,
# 	    $mtime, $ctime, $blksize, $blocks)
# 	    = stat($filename);

# 	# keep track of oldest name.

# 	if (!$ctime_oldest)
# 	{
# 	    $ctime_oldest = $ctime;
# 	    $oldest = $count;
# 	}

# 	if ($ctime_oldest > $ctime)
# 	{
# 	    $ctime_oldest = $ctime;
# 	    $oldest = $count;
# 	}

# 	# check next backup name ...

# 	$count++;

# 	# ... but stop at wrap value

# 	if ($count > 20)
# 	{
# 	    # need to replace oldest file.

# 	    $count = $oldest;

# 	    # oldest file known, break loop

# 	    last;
# 	}

# 	$backup_name = "$filename~$count";
#     }

#     # return possibly new backup name

#     return("$filename~$count");
# }


# #
# # create a backup and write new content.
# #
# # $_[0] : fully qualified filename.
# #
# # $_[1] : new content of file.
# #

# sub create_backup_and_write
# {
#     my $filename = shift;

#     my $contents = shift;

#     # compute a sensible backup name

#     my $backup_name = create_backup_name($filename);

#     # old file is now owned by root

#     chown 0, 0, $filename;

#     # move the old file

#     rename $filename, $backup_name ;

#     # write new content to new file

#     str2file($contents, $filename);

#     # set owner of old and new file to 'sems'

#     any_config_set_owner('sems', $backup_name, $filename, );

#     return 1;
# }


# #
# # create a backup with factory settings.
# #
# # $_[0] : fully qualified filename.
# #

# sub create_factory_backup
# {
#     my $fullpath = shift;

#     $fullpath =~ m|(.*)/(.*)|;

#     my $factory_name = get_factory_name($fullpath);

#     my $factory_master_name = get_factory_master_name($fullpath);

#     if ( ! -e $factory_name)
#     {
# 	# normally the factory backup is created during installation.
# 	# ( in /sems/site_defaults/ )

# 	my $content = file2str($fullpath) || '';

# 	str2file($content, $factory_name);

# 	str2file($content, $factory_master_name);

# 	if ($stderr_logging)
# 	{
# 	    print STDERR "Writing backup for $fullpath : $factory_name\n";
# 	}
#     }
#     else
#     {
# 	if ($stderr_logging)
# 	{
# 	    print STDERR "Already created factory name $factory_name\n";
# 	}
#     }
# }


sub documents_formalize
{
    my $documents = shift;

    my $options = shift;

    my $str = '';

    my $ruler = '';

    # additionally center documents

#     print '<center>';

    foreach my $document (@$documents)
    {
	$str .= $ruler . $document->formalize();

	if (exists $options->{rulers}
	    && $options->{rulers})
	{
	    if ($document->is_empty())
	    {
		print '';
	    }
	    else
	    {
		print '<hr>';
	    }
	}
    }

#     print '</center>';
}


sub documents_merge_data
{
    my $documents = shift;

    my $data = shift;

    if (scalar keys %$data)
    {
	foreach my $document (@$documents)
	{
	    $document->merge_data($data);
	}
    }
}


sub documents_parse_input
{
    my $documents = shift;

    my $options = shift;

    my $result = {};

    if ($ENV{REQUEST_METHOD} eq 'POST')
    {
	foreach my $document (@$documents)
	{
	    my $document_result = $document->parse_input();

	    $result
		= {
		   %$result,
		   %$document_result,
		  };
	}
    }

    return $result;
}


#
# Get filename of file with factory settings, given filename of file with
# actual settings.
#
# $_[0] : fully qualified filename.
#

sub get_factory_master_name
{

    my $fullpath = shift ;

    my $factory_name = $fullpath;

    #! I have the strong conviction that this line does not do anything at all...

    $factory_name =~ s(/var/sems/)(/sems/site_defaults/)s;

    return("$fullpath.factory.master");
#    return($factory_name);
}


sub get_factory_name
{

    my $fullpath = shift ;

    my $factory_name = $fullpath;

    #! I have the strong conviction that this line does not do anything at all...

    $factory_name =~ s(/var/sems/)(/sems/site_defaults/)s;

    return("$fullpath.factory");
#    return($factory_name);
}


sub java_script_popup_function
{
    return "
<script language='JavaScript'>

function popup(url)
{
    window.open(url, '', 'width=500,height=300,resizable=yes', 0);
}
</script>

";
}


sub java_script_reload
{
    my $timeout = shift;

    # add javascript to force a reload every N seconds.

    return "
<script language='JavaScript'>

function force_reload()
{
    location.reload();
}

top.reload_timerId = setTimeout('force_reload()', $timeout);

</script>

";
}


1;


