#!/usr/bin/perl -w
#!/usr/bin/perl -d:ptkdb -w
#


use strict;


package Neurospaces::Documentation;


our $documents;


$0 =~ m(.*/(.*));

my $program_name = $1;

$program_name =~ m((.*)[_-](.*));

my $documentation_set_name = $1;
my $root_operation_name = $2;


sub find_documentation
{
    use YAML;

    my $args = shift;

    my $names = $args->{names} || [];

    my $tags = $args->{tags} || [];

    # get all documents explicitly asked for

    $documents
	= {
	   map
	   {
	       $_ => 1,
	   }
	   (
	    @$names
	    ? @$names
	    : @{ local $/ ; @{$args->{tags}} ? [] : Load(`${documentation_set_name}-tagfilter 2>&1 "published"`) },
	   ),
	  };

    # get all documents selected by tags

    foreach my $tag (@$tags)
    {
	local $/;

	my $documents_tag = Load(`${documentation_set_name}-tagfilter 2>&1 "$tag"`);

	if (!scalar @$documents_tag)
	{
	    next;
	}
	
	$documents
	    = {
	       %$documents,
	       map
	       {
		   $_ => $tag,
	       }
	       @$documents_tag,
	      };
    }

    return $documents;
}


package Neurospaces::Documentation::Publications;


our $all_publication_results;


sub unique
{
    my @list = @_;

    my %seen = ();

    my @unique
	= (grep
	   { ! $seen{$_} ++ }
	   @list
	  );

    return @unique;
}


sub contents_page_generate
{
#     mkdir "html/htdocs/neurospaces_project/${documentation_set_name}/$target_directory";

    my $configuration = shift;

    my $html_output_directory = shift;

    my $home_page_document = shift;

    my $contents_file = $html_output_directory . "/${documentation_set_name}/contents.html";

#     my $contents_file = $html_output_directory . "/html/contents.html";

    open(CONTENTS,">$contents_file") or die "cannot open file for writing: $!";

    my $html_starter = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<html>
<head>
  <meta
 content=\"text/html; charset=ISO-8859-1\"
 http-equiv=\"content-type\">
  <title>Neurospaces Content Management System</title>
</head>
<body>
For the home page please click <a
 href=\"${home_page_document}/${home_page_document}.html\">here.</a>
<br>
For the webcheck directory please click <a
 href=\"webcheck/\">here.</a>
<br>
For the statistics output please click <a
 href=\"../../awstats/awstats.pl\">here.</a>
<br>
<br>
This is a listing of all published documents in the ${documentation_set_name} documentation. <br>
<br>
<br>
<ul>
";

    print CONTENTS $html_starter;

    #t this needs to be replaced with the same loop as in the main build script.
    #t likely saying that contents generation should be part of the main build script.

    my $documentlist = `${documentation_set_name}-tagfilter published`;

    my $tmp = YAML::Load($documentlist);

    my @published_documents = sort @$tmp;

    foreach (@published_documents)
    {
	my $descriptor_file = $_ . "/descriptor.yml";

	my $descriptor = YAML::LoadFile($descriptor_file);

	my @dirs = split(/\//,$_);

	my $documentname = $dirs[-1];

	print CONTENTS "<li><a href=\"";

	my $document
	    = Neurospaces::Documentation::Document->new
		(
		 {
		  name => $documentname,
		 },
		);

	my $suffix = ".html";

	if ($document->is_pdf())
	{
	    $suffix = ".pdf";
	}

	print CONTENTS $documentname . "/" . $documentname . $suffix;

	print CONTENTS "\">";

	print CONTENTS $descriptor->{'document name'};

	print CONTENTS "</a></li>\n";
    }

    print CONTENTS "</ul>\n</body>\n</html>\n";

    close CONTENTS;

    print "Constructed the contents page\n";
}


sub extract_processed_tags
{
    #! note the syntax to force perl to build an intermediate array result

    my $result
	= [
	   sort
	   @{
	       [
		unique
		map
		{
		    my $result = $all_publication_results->{$_}->{document}->{descriptor}->{tags};

		    @$result;
		}
		keys %$all_publication_results,
	       ],
	   },
	  ];

    return $result;
}


sub insert_publication_production_result
{
    my $document = shift;

    my $build_result = shift;

    my $document_name = $document->{name};

    $all_publication_results->{$document_name}
	= {
	   document => $document,
	   build_result => $build_result,
	  };
}


sub publish_production_results
{
    my $prefix = shift;

    my $selectors = shift;

    use YAML;

    my $result;

    my $all_results
	= {
	   map
	   {
	       (
		scalar keys %{ $all_publication_results->{$_}->{build_result} }
		? ($all_publication_results->{$_}->{document}->{name} => $all_publication_results->{$_}->{build_result}, )
		: (),
	       );
	   }
	   keys %$all_publication_results,
	  };

    print Dump( { "${prefix}_all_publication_results" => $all_results, }, );

    use IO::File;

    my $results_file = IO::File->new(">/tmp/${prefix}_all_publication_results");

    if ($results_file)
    {
	print $results_file Dump( { "${prefix}_all_publication_results" => $all_results, }, );
    }
    else
    {
	print "$0: *** Error: cannot ${prefix}_all_publication_results write to /tmp/${prefix}_all_publication_results\n";

	$result = "cannot write ${prefix}_all_publication_results to /tmp/${prefix}_all_publication_results";
    }

    return $result;
}


sub report_all_output
{
    my $selectors = shift;

    use YAML;

    my $result
	= {
	   map
	   {
	       $_ => $all_publication_results->{$_}->{document}->{output};
	   }
	   keys %$all_publication_results,
	  };

    return $result;
}


sub start_publication_production
{
    $all_publication_results = {};
}


package Neurospaces::Documentation::Descriptor;


sub has_tag
{
    my $self = shift;

    my $tag = shift;

    my $tags = $self->{tags};

    foreach (@$tags)
    {
	if ( $tag eq $_ )
	{
	    return 1;
	}
    }

    return 0;
}


package Neurospaces::Documentation::Document;


sub compile
{
    my $self = shift;

    my $options = shift;

    my $result;

    my $directory = $self->{name};

    # read the descriptor

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	$result = "cannot read descriptor for $self->{name} ($descriptor_error)";

	return $result;
    }

    if ($options->{verbose})
    {
	print "$0: entering $directory\n";
    }

    if (!chdir $directory)
    {
	$result = "cannot change to directory $directory";

	return $result;
    }

    # check for the obsolete tag first so we don't end up doing
    # any extra work.

    if ($self->is_obsolete())
    {
	print "$0: this document is obsolete, skipping.\n";
    }

    # if we find a makefile

    elsif (-f 'Makefile')
    {
	# that is what we use

	system "make compile_document";

	if ($?)
	{
	    $result = 'make compile_document failed';
	}

	#t not clear how to do the email processing here
    }

    # Here we check for the redirect attribute and perform actions as
    # necessary.

    elsif ($self->is_redirect())
    {
	$result = $self->compile_redirect($options);
    }
    elsif ($self->is_restructured_text())
    {
	$result = $self->compile_restructured_text($options);
    }
    elsif ($self->is_rich_text_format())
    {
	$result = $self->compile_rich_text_format($options);
    }
    elsif ($self->is_pdf())
    {
	$result = $self->compile_pdf($options);
    }
    elsif ($self->is_mp3())
    {
	$result = $self->compile_mp3($options);
    }
    elsif ($self->is_msword())
    {
	$result = $self->compile_msword($options);
    }
    elsif ($self->is_wav())
    {
	$result = $self->compile_wav($options);
    }
    elsif ($self->is_html())
    {
	$result = $self->compile_html($options);
    }
    elsif ($self->is_png())
    {
	$result = $self->compile_png($options);
    }
    elsif ($self->is_ps())
    {
	$result = $self->compile_ps($options);
    }
    else
    {
	$result = $self->compile_latex($options);
    }

    if ($options->{verbose})
    {
	print "$0: leaving $directory\n";
    }

    chdir '..';

    return $result;
}


sub compile_2_dvi
{
    my $self = shift;

    my $filename = shift;

    my $filename_base = shift;

    my $options = shift;

    # read latex source

    use IO::File;

    my $source_file = IO::File->new("<$filename");

    my $source_text = join "", <$source_file>;

    $source_file->close();

    # update the bibliographic reference

    $source_text =~ s(\\bibliography\{\.\./tex/bib/)(\\bibliography\{\.\./\.\./tex/bib/)g;

    # update html links to their proper file types.

    my $source_html = update_hyperlinks($self->{descriptor}, $source_text);

    # write converted source

    $source_file = IO::File->new(">$filename");

    print $source_file $source_html;

    $source_file->close();

    # copy external files

    system "cp -rp ../plos2009.bst .";

    # copy figures

    system "cp -rp ../figures/* figures/";

#     if ($?)
#     {
# 	return "cp -rp ../figures/* figures/";
#     }

    if ($options->{verbose})
    {
	print "$0: " . "latex -halt-on-error '$filename'" . "\n";
    }

    system "latex -halt-on-error '$filename'";

    if ($?)
    {
	print "$0: *** Error: latex -halt-on-error '$filename' failed\n";

	return "latex -halt-on-error '$filename' failed";
    }

    #! note: both makeindex and bibtex produce error returns when
    #! there is no correct configuration for them in the latex file, we
    #! ignore these error returns

    if ($options->{verbose})
    {
	print "$0: " . "makeindex -c '$filename_base'" . "\n";
    }

    system "makeindex -c '$filename_base'";

#     if ($?)
#     {
# 	print "------------------ Error: makeindex -c '$filename_base'\n";

# 	return "makeindex -c '$filename_base'";
#     }

    if ($options->{verbose})
    {
	print "$0: " . "bibtex '$filename_base'" . "\n";
    }

    system "bibtex '$filename_base'";

#     if ($?)
#     {
# 	print "------------------ Error: bibtex '$filename_base'\n";

# 	return "bibtex '$filename_base'";
#     }

    if ($options->{verbose})
    {
	print "$0: " . "latex -halt-on-error '$filename'" . "\n";
    }

    system "latex -halt-on-error '$filename'";

    if ($?)
    {
	print "$0: *** Error: latex '$filename'\n";

	return "latex '$filename'";
    }

    if ($options->{verbose})
    {
	print "$0: " . "latex -halt-on-error '$filename'" . "\n";
    }

    system "latex -halt-on-error '$filename'";

    if ($?)
    {
	print "$0: *** Error: latex '$filename'\n";

	return "latex '$filename'";
    }

    $self->{compile_2_dvi}->{$filename} = 1;

    return undef;
}


sub compile_2_htlatex
{
    my $self = shift;

    my $filename = shift;

    my $filename_base = shift;

    my $options = shift;

    my $result;

    if (!$self->{compile_2_dvi}->{$filename})
    {
	my $compile_error = $self->compile_2_dvi($filename, $filename_base, $options);

	if ($compile_error)
	{
	    return $compile_error;
	}
    }

    mkdir 'htlatex';

    mkdir 'htlatex/figures';

    if ($options->{verbose})
    {
	print "$0: entering htlatex\n";
    }

    chdir "htlatex";

    # generate htlatex output

    if (not $options->{parse_only})
    {
# 	system "cp ../$filename_base.aux .";
# 	system "cp ../$filename_base.bbl .";
# 	system "cp ../$filename_base.blg .";
# 	system "cp ../$filename_base.dvi .";
# 	system "cp ../$filename_base.log .";
# 	system "cp ../$filename_base.out .";
# 	system "cp ../$filename_base.tex .";

# 	system "cp ../$filename_base.{aux,bbl,blg,dvi,log,out,tex} .";

	# read latex source

	use IO::File;

	my $source_file = IO::File->new("<../$filename");

	my $source_text = join "", <$source_file>;

	$source_file->close();

	# update the bibliographic reference

	$source_text =~ s(\\bibliography\{\.\./\.\./tex/bib/)(\\bibliography\{\.\./\.\./\.\./tex/bib/)g;

	# update htlatex links to their proper file types.

	my $source_htlatex = update_hyperlinks($self->{descriptor}, $source_text);

	# write converted source

	$source_file = IO::File->new(">$filename");

	print $source_file $source_htlatex;

	$source_file->close();

	# copy external files

	system "cp -rp ../plos2009.bst .";

	# copy figures

	system "cp -rp ../figures/* figures/";

	#t some of these were already done by ->compile_2_dvi()

	system "latex -halt-on-error '$filename'";
	system "latex -halt-on-error '$filename'";
	system "latex -halt-on-error '$filename'";

	if ($?)
	{
	    $result = "compiling $filename (latex '$filename': $?)";
	}

	#! note: both makeindex and bibtex produce error returns when
	#! there is no correct configuration for them in the latex file, we
	#! ignore these error returns

	system "makeindex -c '$filename_base'";

# 	if ($?)
# 	{
# 	    $result = "makeindex -c '$filename_base'";
# 	}

	system "bibtex '$filename_base'";

# 	if ($?)
# 	{
# 	    $result = "bibtex '$filename_base'";
# 	}

	system "htlatex '$filename'";

	if ($?)
	{
	    $result = "compiling $filename (htlatex '$filename', $?)";
	}
    }

    if ($options->{verbose})
    {
	print "$0: leaving htlatex\n";
    }

    chdir "..";

    # now select which of the conversions we will use for the website

    my $source_format = 'htlatex';

    system "cp -a $source_format html";

    if ($?)
    {
	$result = "cp -a htlatex html";
    }

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      htlatex => "output/htlatex/$filename_base.html",
	     },
	    );
    }

    return $result;
}


sub compile_2_pdf
{
    my $self = shift;

    my $filename = shift;

    my $filename_base = shift;

    my $options = shift;

    my $result;

    if (!$self->{compile_2_dvi}->{$filename})
    {
	my $compile_error = $self->compile_2_dvi($filename, $filename_base, $options);

	if ($compile_error)
	{
	    return $compile_error;
	}
    }

    mkdir "pdf";

    if ($options->{verbose})
    {
	print "$0: entering pdf\n";
    }

    chdir "pdf";

    if (not $options->{parse_only})
    {
	system "ps2pdf '../ps/$filename_base.ps' '$filename_base.pdf'";

	if ($?)
	{
	    $result = "creating $filename_base.pdf from $filename_base.ps (ps2pdf '../ps/$filename_base.ps' '$filename_base.pdf', $?)";
	}

    }

    if ($options->{verbose})
    {
	print "$0: leaving pdf\n";
    }

    chdir "..";

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      pdf => "output/pdf/$filename_base.pdf",
	     },
	    );
    }

    return $result;
}


sub compile_2_ps
{
    my $self = shift;

    my $filename = shift;

    my $filename_base = shift;

    my $options = shift;

    my $result;

    if (!$self->{compile_2_dvi}->{$filename})
    {
	my $compile_error = $self->compile_2_dvi($filename, $filename_base, $options);

	if ($compile_error)
	{
	    return $compile_error;
	}
    }

    mkdir "ps";

#     if ($options->{verbose})
#     {
# 	print "$0: creating ps\n";
#     }

#     chdir "ps";

    if (not $options->{parse_only})
    {
	system "dvips '$filename_base.dvi' -o '$filename_base.ps'";

	if ($?)
	{
	    $result = "creating dvi from $filename (dvips '$filename_base.dvi' -o '$filename_base.ps', $?)";
	}

	system "mv '$filename_base.ps' ps";
    }

#     if ($options->{verbose})
#     {
# 	print "$0: leaving ps\n";
#     }

#     chdir "..";

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      ps => "output/ps/$filename_base.ps",
	     },
	    );
    }

    return $result;
}


# ($directory, $filetype)
#
# Takes a particular file type to use an as extension for copying
# data to an output directory.

sub compile_file_copy
{
    my $self = shift;

    my $filetype = shift;

    system "rm -fr output";

    system "mkdir -p output/ps";

    if ($?)
    {
	return "mkdir -p output/ps";
    }

    system "mkdir -p output/pdf";

    if ($?)
    {
	return "mkdir -p output/pdf";
    }

    system "mkdir -p output/htlatex";

    if ($?)
    {
	return "mkdir -p output/htlatex";
    }

    system "cp *.$filetype output/htlatex";

    if ($?)
    {
	return "copying $filetype files to the htlatex output directory (cp *.$filetype output/htlatex, $?)";
    }

    system "cp *.$filetype output/ps";

    if ($?)
    {
	return "copying $filetype files to the postscript output directory (cp *.$filetype output/ps, $?)";
    }

    system "cp *.$filetype output/pdf";

    if ($?)
    {
	return "copying $filetype files to the pdf output directory (cp *.$filetype output/pdf, $?)";
    }

    return undef;
}


sub compile_html
{
    my $self = shift;

    my $directory = $self->{name};

    my $html_output;

    if ($self->{descriptor}->{modules}->{'HTML::Template'})
    {
	use HTML::Template;

	my $template
	    = HTML::Template->new
		(
		 filename => "$directory.html",
		);

	my $variables = $self->{descriptor}->{modules}->{'HTML::Template'}->{var};

	foreach my $variable_name (keys %$variables)
	{
	    my $variable_value = $variables->{$variable_name};

	    $template->param($variable_name => $variable_value);
	}

	$html_output = $template->output();
    }
    else
    {
	my $input_file = IO::File->new("<$directory.html");

	undef $/;

	$html_output = <$input_file>;

	$input_file->close();
    }

#     my $result = $self->compile_file_copy('html');

    my $result = "";

    my $filetype = 'html';

    system "rm -fr output";

    system "mkdir -p output/ps";

#     if ($?)
#     {
# 	$result = "mkdir -p output/ps";
#     }

#     system "mkdir -p output/pdf";

#     if ($?)
#     {
# 	$result = "mkdir -p output/pdf";
#     }

    system "mkdir -p output/html";

    if ($?)
    {
	$result = "mkdir -p output/html";
    }

    my $output_file = IO::File->new(">output/html/$directory.html");

#     system "cp *.$filetype output/html";

    print $output_file $html_output;

    if ($?)
    {
	$result = "generating $filetype files to the html output directory (template *.$filetype output/html, $?)";
    }
    else
    {
	$output_file->close();
    }

#     system "cp *.$filetype output/ps";

#     if ($?)
#     {
# 	$result = "copying $filetype files to the postscript output directory (cp *.$filetype output/ps, $?)";
#     }

#     system "cp *.$filetype output/pdf";

#     if ($?)
#     {
# 	$result = "copying $filetype files to the pdf output directory (cp *.$filetype output/pdf, $?)";
#     }

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      html => "output/html/$directory.html",
	     },
	    );
    }

    return $result;
}


sub compile_latex
{
    my $self = shift;

    my $options = shift;

    my $result;

    my $directory = $self->{name};

    # find relevant source files

    my $filenames = $self->source_filenames();

    # loop over source files

    foreach my $filename (@$filenames)
    {
	# for latex sources

	if ($filename =~ /(.*)\.tex$/)
	{
	    #t build a model of how output is generated

	    $filename_base = $1;

	    my $latex_compilation_model
		= {
		   build_date => 0,
		   output => [
			      {
			       name => "output/$filename_base.dvi",
			       build_date => 0,
			       output => [
					  {
					   name => "output/htlatex/$filename_base.html",
					   build_date => 0,
					  },
					  {
					   name => "output/pdf/$filename_base.pdf",
					   build_date => 0,
					  },
					  {
					   name => "output/ps/$filename_base.ps",
					   build_date => 0,
					  },
					 ],
			      },
			     ],
		   name => "$filename_base.tex",
		  };

	    chdir "output";

	    # prepare output: general latex processing

# 	    $filename =~ m((.*)\.tex$);

# 	    my $filename_base = $1;

	    # Remove references to self, as well as any empty itemize blocks
	    # since the itemize blocks kill the cron job. After we remove
	    # the references and resave the file.

	    if ($filename =~ m/contents-level[1234567]/)
	    {
		# read latex source

		use IO::File;

		my $source_file = IO::File->new("<../$filename");

		my $source_text = join "", <$source_file>;

		$source_file->close();

		my @name = split(/\./,$filename);

		$source_text =~ s(\\item \\href\{\.\.\/$name[0]\/$name[0]\.\w+\}\{\\bf \\underline\{.*\}\})( )g;

		# remove empty itemize environments (otherwise latex complains)

		$source_text =~ s(\\begin\{itemize\}\s+\\end\{itemize\})( )g;

		open(OUTPUT,">$filename");

		print OUTPUT $source_text;

		close(OUTPUT);
	    }

	    if (not $options->{parse_only})
	    {
		# generate ps output

		$result = $self->compile_2_ps($filename, $filename_base, $options);

		# generate pdf output

		$result = $result or $self->compile_2_pdf($filename, $filename_base, $options);

		# generate htlatex output

		$result = $result or $self->compile_2_htlatex($filename, $filename_base, $options);
	    }

	    chdir "..";
	}

	# else unknown source file type

	else
	{
	    print "$0: unknown file type for $filename (ignored)\n";
	}
    }

    return $result;
}


sub compile_pdf
{
    my $self = shift;

    my $directory = $self->{name};

    my $result = $self->compile_file_copy('pdf');

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      pdf => "output/pdf/$directory.pdf",
	     },
	    );
    }

    return $result;
}


sub compile_png
{
    my $self = shift;

    my $directory = $self->{name};

    my $result = $self->compile_file_copy('png');

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      png => "output/html/$directory.png",
	     },
	    );
    }

    return $result;
}


sub compile_ps
{
    my $self = shift;

    my $directory = $self->{name};

    my $result = $self->compile_file_copy('ps');

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      ps => "output/ps/$directory.ps",
	     },
	    );
    }

    return $result;
}


sub compile_mp3
{
    my $self = shift;

    my $directory = $self->{name};

    my $result = $self->compile_file_copy('mp3');

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      html => "output/html/$directory.mp3",
	     },
	    );
    }

    return $result;
}


sub compile_msword
{
    my $self = shift;

    my $directory = $self->{name};

    my $result;

    mkdir "output";

    mkdir "output/pdf";

    system "soffice --accept='socket,port=8100;urp;' --invisible &";

    sleep 1;

    if ($?)
    {
	$result = "soffice --accept='socket,port=8100;urp;' --invisible &";
    }
    else
    {
	if ($self->has_tag("doc"))
	{
	    system "jodconverter $directory.doc $directory.pdf";
	}
	elsif ($self->has_tag("docx"))
	{
	    system "jodconverter $directory.docx $directory.pdf";
	}
	elsif ($self->has_tag("odt"))
	{
	    system "jodconverter $directory.odt $directory.pdf";
	}

	if ($?)
	{
	    $result = "jodconverter $directory.(doc|docx|odt) $directory.pdf";
	}
	else
	{
	    system "mv $directory.pdf output/pdf";

	    if (not $result)
	    {
		$self->output_register
		    (
		     {
		      pdf => "output/pdf/$directory.pdf",
		     },
		    );
	    }

	    mkdir "output/html";

	    if ($self->has_tag("doc"))
	    {
		system "jodconverter $directory.doc $directory.html";
	    }
	    elsif ($self->has_tag("docx"))
	    {
		system "jodconverter $directory.docx $directory.html";
	    }
	    elsif ($self->has_tag("odt"))
	    {
		system "jodconverter $directory.odt $directory.html";
	    }

	    if ($?)
	    {
		$result = "jodconverter $directory.(doc|docx|odt) $directory.html";
	    }
	    else
	    {
		system "mv $directory.html output/html";

		if (not $result)
		{
		    $self->output_register
			(
			 {
			  html => "output/html/$directory.html",
			 },
			);
		}
	    }
	}
    }

    return $result;
}


sub compile_redirect
{
    my $self = shift;

    my $document = $self->{name};

    my $redirect_url = $self->{descriptor}->{redirect};

    my $result;

    chdir $document;

    system "mkdir -p output/ps";

    if ($?)
    {
	$result = "mkdir -p output/ps";
    }

    system "mkdir -p output/pdf";

    if ($?)
    {
	$result = "mkdir -p output/pdf";
    }

    system "mkdir -p output/html";

    if ($?)
    {
	$result = "mkdir -p output/html";
    }

    my @tmp = split(/\//,$document);

    my $doctitle = $tmp[-1];

    my $html_document = $doctitle  . ".html";

    open(OUTPUT,">$html_document");
    print OUTPUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n<html>\n  <head>\n    <title>";
    print OUTPUT $html_document . " (http redirect)";
    print OUTPUT "</title>\n  </head>\n  <body><meta http-equiv=\"refresh\" content=\"0;URL=";
    print OUTPUT $redirect_url;
    print OUTPUT "\">\n  </body>\n</html>\n\n";
    close(OUTPUT);

#     print "$0: copying redirect file to output directories\n";

#     system "cp -f $html_document output/ps";

#     if ($?)
#     {
# 	$result = "cp -f $html_document output/ps";
#     }

#     system "cp -f $html_document output/pdf";

#     if ($?)
#     {
# 	$result = "cp -f $html_document output/pdf";
#     }

    system "cp -f $html_document output/html";

    if ($?)
    {
	$result = "cp -f $html_document output/html";
    }

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      html => "output/html/$html_document",
	     },
	    );
    }

    return $result;
}


sub compile_restructured_text
{
    my $self = shift;

    my $directory = $self->{name};

    my $result;

    # find relevant source files

    my $filenames = $self->source_filenames();

    # loop over source files

    foreach my $filename (@$filenames)
    {
	# for restructured text sources

	if ($filename =~ /\.rst$/)
	{
	    chdir "output";

	    # prepare output: general rst processing

	    $filename =~ m((.*)\.rst$);

	    my $filename_base = $1;

# 	    if (not $options->{parse_only})
	    {
		# generate pdf output

# 		{
# 		    mkdir "pdf";

# # 		    if ($options->{verbose})
# 		    {
# 			print "$0: entering pdf\n";
# 		    }

# 		    chdir "pdf";

# # 		    if (not $options->{parse_only})
# 		    {
# 			system "rst2pdf '../$filename_base.rst' -o '$filename_base.pdf'";

# 			if ($?)
# 			{
# 			    $result = "rst2pdf '../$filename_base.rst' -o '$filename_base.pdf'";
# 			}

# 		    }

# # 		    if ($options->{verbose})
# 		    {
# 			print "$0: leaving pdf\n";
# 		    }

# 		    chdir "..";
# 		}

		# generate html output

		{
		    mkdir 'html';

		    mkdir 'html/figures';

# 		    if ($options->{verbose})
		    {
			print "$0: entering html\n";
		    }

		    chdir "html";

		    # read latex source

		    use IO::File;

		    my $source_file = IO::File->new("<../$filename");

		    my $source_text = join "", <$source_file>;

		    $source_file->close();

		    $source_file = IO::File->new(">$filename");

		    print $source_file $source_text;

		    $source_file->close();

		    # copy figures

		    system "cp -rp ../figures/* figures/";

		    #     if ($?)
		    #     {
		    # 	return "cp -rp ../figures/* figures/";
		    #     }

		    # generate html output

# 		    if (not $options->{parse_only})
		    {
			system "rst2html '../$filename' '$filename_base.html'";

			if ($?)
			{
			    system "rst2html.py '../$filename' '$filename_base.html'";

			    if ($?)
			    {
				$result = "creating html for $filename (rst2html(.py)? '../$filename' '$filename_base.html', $?)";
			    }
			}
		    }

# 		    if ($options->{verbose})
		    {
			print "$0: leaving html\n";
		    }

		    chdir "..";
		}

		if (not $result)
		{
		    $self->output_register
			(
			 {
			  html => "output/html/$filename_base.html",
			 },
			);
		}
	    }

	    chdir "..";
	}

	# else unknown source file type

	else
	{
	    print "$0: unknown file type for $filename";
	}
    }

    return $result;
}


sub compile_rich_text_format
{
    my $self = shift;

    my $directory = $self->{name};

    my $result;

    # find relevant source files

    my $filenames = $self->source_filenames();

    # loop over source files

    foreach my $filename (@$filenames)
    {
	# for restructured text sources

	if ($filename =~ /\.rtf$/)
	{
	    chdir "output";

	    # prepare output: general rst processing

	    $filename =~ m((.*)\.rtf$);

	    my $filename_base = $1;

# 	    if (not $options->{parse_only})
	    {
		# generate latex output

		{
		    system "unrtf '../$filename_base.rtf' --latex >'$filename_base.tex'";

		    if ($?)
		    {
			$result = "creating latex from $filename (unrtf '../$filename_base.rtf' --latex >'$filename_base.tex', $?)";
		    }

		}

		# generate html output

		{
		    mkdir 'html';

		    mkdir 'html/figures';

# 		    if ($options->{verbose})
		    {
			print "$0: entering html\n";
		    }

		    chdir "html";

		    # read latex source

		    use IO::File;

		    my $source_file = IO::File->new("<../$filename");

		    my $source_text = join "", <$source_file>;

		    $source_file->close();

		    $source_file = IO::File->new(">$filename");

		    print $source_file $source_text;

		    $source_file->close();

		    # copy figures

		    system "cp -rp ../figures/* figures/";

		    #     if ($?)
		    #     {
		    # 	return "cp -rp ../figures/* figures/";
		    #     }

		    # generate html output

# 		    if (not $options->{parse_only})
		    {
			system "unrtf '../$filename' --html >'$filename_base.html'";

			if ($?)
			{
			    $result = "creating html for $filename (unrtf '../$filename' --html >'$filename_base.html', $?)";
			}
		    }

# 		    if ($options->{verbose})
		    {
			print "$0: leaving html\n";
		    }

		    chdir "..";
		}
	    }

	    chdir "..";

	    if (not $result)
	    {
		$self->output_register
		    (
		     {
		      html => "output/html/$filename_base.html",
		     },
		    );
	    }
	}

	# else unknown source file type

	else
	{
	    print "$0: unknown file type for $filename";
	}
    }

    return $result;
}


sub compile_wav
{
    my $self = shift;

    my $directory = $self->{name};

    my $result = $self->compile_file_copy('wav');

    if (not $result)
    {
	$self->output_register
	    (
	     {
	      html => "output/html/$directory.wav",
	     },
	    );
    }

    return $result;
}


sub check
{
    my $self = shift;

    my $options = shift;

    my $result;

    print "$0: Checking $self->{name}\n";

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	$result = "cannot read descriptor for $self->{name} ($descriptor_error)";

	return $result;
    }

    if (!$self->{descriptor}->{tags}
	|| ref $self->{descriptor}->{tags} !~ /ARRAY/)
    {
	$result = "invalid tag specification for $self->{name}";
    }

    return $result;
}


sub copy
{
    my $self = shift;

    my $options = shift;

    my $result;

    my $directory = $self->{name};

    if ($options->{verbose})
    {
	print "$0: entering $directory\n";
    }

    chdir $directory;

    # if we find a makefile

    if (-f 'Makefile')
    {
	# that is what we use

	system "make copy_document";

	if ($?)
	{
	    $result = "make copy_document of $self->{name}, $?";
	}

    }
    else
    {
	# find relevant source files

	my $filenames = $self->source_filenames();

	# loop over source files

	foreach my $filename (@$filenames)
	{
	    # for latex and restructured text sources

	    if ($filename =~ /\.(rst|rtf|tex)$/)
	    {
		# create workspace directories for generating output

		mkdir "output";
		#mkdir 'output/figures';

		# copy source files

		system "cp $filename output/";

		if ($?)
		{
		    $result = "copying $filename to the output directory (cp $filename output/, $?)";
		}
		elsif (-d "figures")
		{

		    system "cp -rfp figures output/";

		    if ($?)
		    {
			$result = "copying $filename/figures to the output directory (cp -rfp figures output/, $?)";
		    }

		}

		if ($?)
		{
		}
		elsif (-d "snippets")
		{

		    system "cp -rfp snippets output/";

		    if ($?)
		    {
			$result = "copying $filename/snippets to the output directory (cp -rfp snippets output/, $?)";
		    }

		}
	    }

	    # else unknown source file type

	    else
	    {
		print "$0: unknown file type for $filename";

		$result = "unknown file type for $filename, expecting .rst, .rtf, or .tex filename extension";
	    }
	}
    }

    if ($options->{verbose})
    {
	print "$0: leaving $directory\n";
    }

    chdir '..';

    return $result;
}


sub email
{
    my $self = shift;

    my $options = shift;

    my $set_name = $options->{set_name} || "${documentation_set_name}";

    my $build_directory = "$ENV{HOME}/neurospaces_project/$set_name/source/snapshots/0/";

    my $document_name = $self->{name};

    my $email_adresses = $self->{email_adresses};

    my $user = getpwuid($>) || "Unknown User Account";

    my $to = join ' ', @$email_adresses;

    if ($self->{output}->{pdf})
    {
	print "$0: Sending to $to with $document_name pdf attachment\n";

	my $attachment = $build_directory . $document_name . "/" . $self->{output}->{pdf};

	my $command = "mutt -s '$0: mail from $user' -a $attachment -- $to";

	open(MAIL, "| $command");

	print MAIL "This email was sent to you by the Neurospaces content management system on behalf of $user.  Please see the attached pdf file for more information.";

	close(MAIL);
    }
    elsif ($self->{output}->{ps})
    {
	print "$0: Sending to $to with $document_name ps attachment\n";

	my $attachment = $build_directory . $document_name . "/" . $self->{output}->{ps};

	my $command = "mutt -s '$0: mail from $user' -a $attachment -- $to";

	open(MAIL, "| $command");

	print MAIL "This email was sent to you by the Neurospaces content management system on behalf of $user.  Please see the attached postscript file for more information.";

	close(MAIL);
    }
    elsif ($self->{output}->{html})
    {
	print "$0: Sending to $to with $document_name html link\n";

	my $command = "mutt -s '$0: mail from $user' -- $to";

	my $link = "http://www.genesis-sim.org/${documentation_set_name}/$document_name/$document_name.html";

	open(MAIL, "| $command");

	print MAIL "This email was sent to you by the Neurospaces content management system on behalf of $user.  Please follow the link below for more information.\n\n$link\n";

	close(MAIL);
    }

    my $result;

    return $result;
}


sub expand
{
    my $self = shift;

    my $options = shift;

    my $result;

    # only expand in regular latex files

    if (not $self->is_latex()
        and not $self->is_restructured_text())
    {
	return $result;
    }

    # expand contents of each level of the documentation

    my $contents_documents
	= {
	   'contents-level1' => 1,
	   'contents-level2' => 1,
	   'contents-level3' => 1,
	   'contents-level4' => 1,
	   'contents-level5' => 1,
	   'contents-level6' => 1,
	   'contents-level7' => 1,
	  };

    my $document_name = $self->{name};

    if ($contents_documents->{$document_name})
    {
	my $command = "${documentation_set_name}-tagreplaceitems '$document_name' '$document_name' --verbose";

	print "$0: executing \"$command\"\n";

	system $command;

	if ($?)
	{
	    $result = "for document '$document_name': failed to execute ($command, $?)\n";
	}
    }

    # expand related documentation links

    if (not $result)
    {
	# loop over all related information tags

	my $related_tags = $self->related_tags();

	if (not ref $related_tags)
	{
	    $result = $related_tags;

	    return $result;
	}

	foreach my $related_tag (@$related_tags)
	{
	    # expand the document

	    my $command = "${documentation_set_name}-tagreplaceitems $related_tag '$document_name' --verbose --exclude '$document_name'";

	    print "$0: executing \"$command\"\n";

	    system $command;

	    if ($?)
	    {
		$result = "for document '$document_name': failed to execute ($command, $?)\n";

		last;
	    }
	}
    }

    # expand dynamically generated snippets

    if (0 and -f "$document_name/output/$document_name.tex")
    {
	# expand the document

	my $command = "${documentation_set_name}-snippet '$document_name/output/$document_name.tex' --verbose";

	system $command;

	if ($?)
	{
	    $result = "for document '$document_name': failed to execute ($command, $?)\n";

	    last;
	}
    }

    # resolve internal HCMS cross references

    if (-f "$document_name/output/$document_name.tex")
    {
	# expand the document

	my $contents;

	{
	    # slurp contents

	    local $/;

	    open my $descriptor, "$document_name/output/$document_name.tex"
		or print "****************ERRORS\n"; # die $!;
	    undef $/;
	    $contents = <$descriptor>;
	    close $descriptor;
	}

	if ($contents)
	{
	    my $old_contents = $contents;

	    # $1: a prefix
	    # $2: component name
	    # $3: full document, with leading directory
	    # $4: link text

	    print "resolving internal HCMS cross references\n";

	    #t note that latex commands embedded in the curly braces will not work properly.

	    if ($contents =~ s(([^\\])\\heterarchxref\{../../../../../([\-a-zA-Z]*)/source/snapshots/0/([^\}]*)\}\{([^\}]*)\})($1\\href{../../$2/$3}{$4})g)
	    {
		print "Replaced ($1\\heterarchxref\{../../../../../$2/source/snapshots/0/$3\}\{$4\}) with ($1\\href{../../$2/$3}{$4})\n";
	    }

	    # if something has changed

	    if ($old_contents ne $contents)
	    {
		# replace the file

		open my $descriptor, ">" . "$document_name/output/$document_name.tex"
		    or die $!;
		print $descriptor $contents;
		close $descriptor;
	    }
	}
    }

    # return result

    return $result;
}


sub find_snippets
{
    my $self = shift;

    # convert document_filename to directory where it is stored

    my $document_filename = $self->{filename} || $self->{name};

    # remove filename and extension from the document filename

    $document_filename =~ s((.*)/.*)($1);

    # construct snippets directory name

    my $snippet_directory = $document_filename . "/snippets/";

    my $snippets
	= [
	   map
	   {
	       chomp; $_
	   }
	   `find $snippet_directory \\! -type d -name "*[^~]"`,
	  ];

    my $result
	= {
	   map
	   {
	       my $snippet_filename = $_;

	       s(.*/(.*))($1);

	       $_ => Neurospaces::Documentation::Snippet->new(
							      {
							       filename => $snippet_filename,
							       name => $_,
							      },
							     ),
	   }
	   @$snippets,
	  };

    return $result;
}


sub has_tag
{
    my $self = shift;

    my $tag = shift;

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	die "$0: document descriptor cannot be read ($descriptor_error)";
    }

    return $self->{descriptor}->has_tag($tag);
}


sub is_html
{
    my $self = shift;

    return $self->has_tag('html');
}


sub is_latex
{
    my $self = shift;

    return not (
		$self->is_html()
		or $self->is_mp3()
		or $self->is_msword()
		or $self->is_obsolete()
		or $self->is_pdf()
		or $self->is_png()
		or $self->is_ps()
		or $self->is_redirect()
		or $self->is_restructured_text()
		or $self->is_rich_text_format()
		or $self->is_wav()
	       );
}


sub is_mp3
{
    my $self = shift;

    return $self->has_tag('mp3');
}


sub is_msword
{
    my $self = shift;

    return
	($self->has_tag('doc')
	 or $self->has_tag('docx')
	 or $self->has_tag('odt'));
}


sub is_obsolete
{
    my $self = shift;

    return $self->has_tag('obsolete');
}


sub is_pdf
{
    my $self = shift;

    return $self->has_tag('pdf');
}


sub is_png
{
    my $self = shift;

    return $self->has_tag('png');
}


sub is_ps
{
    my $self = shift;

    return $self->has_tag('ps');
}


sub is_redirect
{
    my $self = shift;

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	die "$0: document descriptor cannot be read ($descriptor_error)";
    }

    return $self->has_tag('redirect');
}


sub is_restructured_text
{
    my $self = shift;

    return $self->has_tag('rst');
}


sub is_rich_text_format
{
    my $self = shift;

    return $self->has_tag('rtf');
}


sub is_wav
{
    my $self = shift;

    return $self->has_tag('wav');
}


sub new
{
    my $package = shift;

    my $options = shift;

    my $self
	= {
	   %$options,
	  };

    if (not exists $self->{name})
    {
	if (exists $self->{directory_name})
	{
	    my $directory_name = $self->{directory_name};

	    my @dirs = split(/\//, $directory_name);

	    my $name = $dirs[-1];

	    $self->{name} = $name;
	}
    }

    bless $self, $package;

    return $self;
}


sub nop
{
    my $self = shift;

    my $options = shift;

    my $result;

    return $result;
}


sub output_filename
{
    my $self = shift;

    my $document_name = $self->{name};

    my $result;

    if (exists $self->{output_filename})
    {
	$result = $self->{output_filename};
    }
    else
    {
	$result = "$document_name/output/$document_name";

	if ($self->is_latex())
	{
	    $result .= ".tex";
	}
	elsif ($self->is_restructured_text())
	{
	    $result .= ".rst";
	}
    }

    $self->{output_filename} = $result;

    return $result;
}


sub output_register
{
    my $self = shift;

    my $output = shift;

    if (not exists $self->{output})
    {
	$self->{output} = {};
    }

    $self->{output}
	= {
	   %{$self->{output}},
	   %$output,
	  };
}


sub publish
{
    my $self = shift;

    my $options = shift;

    my $result;

    # read the descriptor

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	$result = "cannot read descriptor for $self->{name} ($descriptor_error)";

	return $result;
    }

    my $directory = $self->{name};

    if ($options->{verbose})
    {
	print "$0: entering $directory\n";
    }

    if (!chdir $directory)
    {
	return "cannot change to directory $directory (now in " . `pwd` . ")";
    }

    # check for the obsolete tag first so we don't end up doing
    # any extra work.

    if ($self->is_obsolete())
    {
	print "$0: this document is obsolete, skipping.\n";
    }

    # if we find a makefile

    elsif (-f 'Makefile' )
    {
	# that is what we use

	system "make prepare_publish_document";

	if ($?)
	{
	    $result = "make prepare_publish_document";
	}

    }

    # no makefile

    else
    {
	# find relevant output containing generated files

	my $outputs
	    = [
	       'output/html',
	      ];

	# loop over source files

	foreach my $output (@$outputs)
	{
	    my @tmp = split /\//, $directory;

	    my $target_directory = $tmp[-1];

	    if ($options->{verbose})
	    {
		print "$0: copying files for $directory to html/htdocs/neurospaces_project/${documentation_set_name}/$target_directory\n";
	    }

	    # put it in the place for publication.

	    mkdir "../html/htdocs/neurospaces_project/${documentation_set_name}/$target_directory";

	    #! note: -pr for BSD (MAC) compatibility.

	    system "cp -pr $output/* '../html/htdocs/neurospaces_project/${documentation_set_name}/$target_directory'";

	    if ($?)
	    {
		$result = "cp -pr $output/* '../html/htdocs/neurospaces_project/${documentation_set_name}/$target_directory'";
	    }

	}
    }

    if ($options->{verbose})
    {
	print "$0: leaving $directory\n";
    }

    chdir '..';

    return $result;
}


sub read_descriptor
{
    my $self = shift;

    my $filename;

    if (not exists $self->{directory_name})
    {
	$filename = $self->{name} . "/descriptor.yml";
    }
    else
    {
	$filename = $self->{directory_name} . "/descriptor.yml";
    }

    if ($self->{descriptor})
    {
	return '';
    }

    eval
    {
	$self->{descriptor} = YAML::LoadFile($filename);
    };

    if ($@)
    {
	return $@;
    }
    else
    {
	bless $self->{descriptor}, "Neurospaces::Documentation::Descriptor";

	return undef;
    }
}


sub related_tags
{
    my $self = shift;

    my $result;

    my $descriptor_error = $self->read_descriptor();

    if ($descriptor_error)
    {
	$result = "cannot read descriptor for $self->{name} ($descriptor_error)";

	return $result;
    }

    my $tags = $self->{descriptor}->{tags};

    $result = [];

    foreach my $tag (@$tags)
    {
	if ($tag =~ /^related-/)
	{
	    push @$result, $tag;
	}
    }

    return $result;
}
	

sub source_filenames
{
    my $self = shift;

    my $result
	= [
	   sort
	   map
	   {
	       chomp; $_
	   }
	   `ls *.tex`,
	   `ls *.rst`,
	   `ls *.rtf`,
	  ];

    return $result;
}


#
# Function to update hyperlinks in the source text
#

sub update_hyperlinks
{
    my $descriptor = shift;

    my $source_text = shift;

    print "$0: updating hyperlinks\n";

    $source_text =~ s(\\href\{\.\./([^}]*)\.pdf)(\\href\{../$1.html)g;

    $source_text =~ s(\\href\{\.\./([^}]*)\.tex)(\\href\{../$1.html)g;

    $source_text =~ s(\\href\{\.\./([^}]*)\.rst)(\\href\{../$1.html)g;

    # remove empty itemize environments (otherwise latex complains)

    #! this is a duplicated statement / operation, see above

    $source_text =~ s(\\begin\{itemize\}\s+\\end\{itemize\})( )g;

#     # convert eps links to png links

#     $source_text =~ s(\\includegraphics\{figures/([^}]*)\.eps)(\\includegraphics\{figures/$1.png)g;

    # here we handle special cases for pdf files. Since several files in the
    # documentation can be pdf we need to check all of the published docs
    # for the pdf tag. Operation is a bit expensive.
    # NOTE: Duplicates code from ${documentation_set_name}-tagreplaceitems

    my $published_pdfs_yaml = `${documentation_set_name}-tagfilter 2>&1 pdf published`;

    my $published_pdfs = YAML::Load($published_pdfs_yaml);

    foreach my $published_pdf (@$published_pdfs)
    {
	$published_pdf =~ /.*\/(.*)/;

	my $document_name = $1;

	$source_text =~ s(\\href\{\.\./$document_name/$document_name\.html)(\\href\{../$document_name/$document_name.pdf)g;
    }

    return $source_text;
}


package Neurospaces::Documentation::Snippet;


sub new
{
    my $package = shift;

    my $options = shift;

    my $self
	= {
	   %$options,
	  };

    bless $self, $package;

    return $self;
}


sub read_content
{
    my $self = shift;

    if (exists $self->{content})
    {
	return '';
    }

    # slurp content

    open my $descriptor, $self->{filename}
	or return $!;

    local $/;

    $self->{content} = <$descriptor>;

    close $descriptor;

    return undef;
}


sub replacement_string
{
    my $self = shift;

    if (exists $self->{replacement_string})
    {
	return $self->{replacement_string};
    }

    # read the snippet content

    my $error = $self->read_content();

    if ($error)
    {
	#t no nice error propagation

	print STDERR "$0: $error";

	return undef;
    }

    # loop over all backquote strings

    my $content = $self->{content};

    while ($content =~ m/\G.*?`([^`]*)`/gs)
    {
	my $position = pos($content);

	# execute the command

	my $command = $1;

	my $replacement = `$command`;

	if ($?)
	{
	    print STDERR "$0: *** Error: running '$command' returned status $?\n";
	}

	# replace the command with its expansion

	if ($self->{verbose})
	{
	    print "$0: for $self->{filename}: found $command at $position, replacing ... \n";
	}

	$content =~ s(`$command`)($replacement)g;

	# set the new position

	pos($content) = $position;
    }

    # fill in the replacement_string

    $self->{replacement_string} = $content;

    # return replacement_string

    return $content;
}


1;



