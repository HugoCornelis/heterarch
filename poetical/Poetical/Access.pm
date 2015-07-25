#!/usr/bin/perl -w
#

package Poetical::Access;


use strict;

use utf8;


use Data::Dumper;


sub configure
{
    my $package = shift;

    my $args = { @_ };

    print STDERR Data::Dumper::Dumper($args);

    my $count = 0;

    foreach my $module (keys %$args)
    {
	if ($count)
	{
	    #t report error : access level for multiple modules requested
	}

	#! a lot of room for extensions here...
	#!
	#! perhaps need to add a mechanism that describes how to call the
	#! framework beneath ?  This framework is currently hardcoded to
	#! be Webmin.

	#t 1. rename 'level' to 'editable', use as a boolean.
	#t 2. add a key 'level' that gives the access level.

	#t distinction needed between webmin acls and apache .htaccess

	my $access_description = $args->{$module};

	my $level = $access_description->{level};

	my $label = $access_description->{label};

	check_access($module, $label, $level);

	$count++;
    }

}


print STDERR "In Poetical::Access\n";

sub import
{
    print STDERR "In import()\n";

    print STDERR Data::Dumper::Dumper(\@_);

    my $package = (caller())[0];

    shift;

    $package->Poetical::Access::configure(@_);
}


sub check_access
{
    my $module = shift;

    my $label = shift;

    my $level = shift;

    my $editable;

    # init (web|user)min specific stuff.

    &::init_config();

    my %access = &::get_module_acl();

#     print STDERR Dumper(\%ENV);

    if ($ENV{WEBMIN_CONFIG} =~ /usermin/i)
    {
	# convert usermin format to webmin format

	$access{$module} = $access{mode};
    }

    print STDERR "Access to $module for this user : $access{$module}\n";
    print STDERR Dumper(\%access);

    $access{$module}
	|| &::error("You are not allowed to view the $label");


    local $_ = $access{$module};

 ACCESS:
    {
	# restricted view only

	/^1$/ and do
	{
	    $editable = 0;

	    last ACCESS;
	};

	# full view only

	/^2$/ and do
	{
	    $editable = 0;

	    last ACCESS;
	};

	# restricted edit

	/^3$/ and do
	{
	    $editable = 1;

	    last ACCESS;
	};

	# full edit

	/^4$/ and do
	{
	    $editable = 2;

	    last ACCESS;
	};

	# not allowed

	{
	    &::error("You are not allowed to view the $label");
	}
    }

    # if not editable

    if (!$editable)
    {
	# the script is allowed to continue, but without writing anything

	$::ENV{REQUEST_METHOD} = 'GET';
    }

    $$level = $editable;

    print STDERR "Poetical Access Levels : $editable, $$level, $::editable\n";

    return 1;
}


1;


