#!/usr/bin/perl -w
#!/usr/bin/perl -d:ptkdb -w
#


use strict;


package Neurospaces::Documentation;


our $documents;


$0 =~ m(.*/(.*));

my $program_name = $1;

$program_name =~ m((.*)[_-](.*));

my $documentation_set_name = $::option_set_name || $1;
my $root_operation_name = $2;


sub build_directory
{
    # get the project directory

    my $result = project_directory();

    # if there is a project descriptor

    my $project_descriptor_filename = "$result/project-descriptor.yml";

    if (-f $project_descriptor_filename)
    {
	# if it is valid yaml

	my $project_descriptor;

	eval
	{
	    $project_descriptor = YAML::LoadFile($project_descriptor_filename);
	};

	if ($@)
	{
	    die "$0: *** Error: invalid project descriptor $project_descriptor_filename";
	}
	elsif (exists $project_descriptor->{'documentation directory'})
	{
	    # add the directory where documents are found to the build directory

	    $result .= "/" . $project_descriptor->{'documentation directory'};
	}
    }

    return $result;
}


sub find_documentation
{
    use YAML;

    my $args = shift;

    my $names = $args->{names} || [];

    my $tags = $args->{tags} || [];

    # get all documents explicitly asked for

    $documentation_set_name = $::option_set_name || $documentation_set_name;

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


sub project_directory
{
    #t this should come from a query using neurospaces_build because
    #t it is the only one that knows about the project layout.

    $documentation_set_name = $::option_set_name || $documentation_set_name;

    my $result = "$ENV{HOME}/neurospaces_project/${documentation_set_name}/source/snapshots/0";

    return $result;
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
    my $configuration = shift;

    my $publication_directory = shift;

    my $home_page_document = shift;

    my $build_directory = Neurospaces::Documentation::build_directory();

    $documentation_set_name = $::option_set_name || $documentation_set_name;

    my $contents_file = $publication_directory . "/contents.html";

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
    my $options = shift;

    my $result;

    $all_publication_results = {};

    # prepare directory structure

    my $publication_directory = $options->{publication_directory};

    system "mkdir -p '$publication_directory'";

    if ($?)
    {
	return "mkdir -p '$publication_directory'";
    }

    return $result;
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

    system "mkdir -p output/html";

    if ($?)
    {
	return "mkdir -p output/html";
    }

    system "cp *.$filetype output/html";

    if ($?)
    {
	return "copying $filetype files to the html output directory (cp *.$filetype output/html, $?)";
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

	    my $filename_base = $1;

	    my $latex_2_html_compilation_model
		= {
		   filedate => 0,
		   filename => "$filename_base.tex",
		   filetype => 'latex',
		   identifier => 'latex',
		   targets => [
			       {
				build_commands => [
# 						   {
# 						    command => "cp -rp ../../plos2009.bst .",
# 						   },
						   {
						    command => "cp -rp '../$filename' .",
						   },
						   {
						    command => "mkdir -p figures/",
						   },
						   {
						    command => "cp -rp ../../figures/* figures/ || true",
						   },
						   {
						    command => "mkdir -p sounds/",
						   },
						   {
						    command => "cp -rp ../../sounds/* sounds/ || true",
						   },
						   {
						    command => "latex -halt-on-error '$filename'",
						   },
						   {
						    command => "makeindex -c '$filename_base' || true",
						   },
						   {
						    command => "bibtex '$filename_base' || true",
						   },
						   {
						    command => "latex -halt-on-error '$filename'",
						   },
						   {
						    command => "latex -halt-on-error '$filename'",
						   },
						  ],
				filedate => 0,
				filename => "$filename_base.dvi",
				filetype => 'dvi',
				identifier => 'latex/dvi',
				targets => [
					    {
					     build_commands => [
# 								{
# 								 command => "cp -rp ../../plos2009.bst .",
# 								},
								{
								 command => "cp -rp '../$filename' .",
								},
								{
								 command => "mkdir -p figures/",
								},
								{
								 command => "cp -rp ../../figures/* figures/ || true",
								},
								{
								 command => "mkdir -p sounds/",
								},
								{
								 command => "cp -rp ../../sounds/* sounds/ || true",
								},
								{
								 command => "latex -halt-on-error '$filename'",
								},
								{
								 command => "makeindex -c '$filename_base' || true",
								},
								{
								 command => "bibtex '$filename_base' || true",
								},
								{
								 command => "latex -halt-on-error '$filename'",
								},
								{
								 command => "latex -halt-on-error '$filename'",
								},
								{
								 command => "htlatex '$filename'",
								},
							       ],
					     filedate => 0,
					     filename => "$filename_base.html",
					     filetype => 'htlatex',
					     identifier => 'latex/dvi/htlatex',
					    },
					    {
					     build_commands => [
								{
								 command => "dvips '../dvi/$filename_base.dvi' -o '$filename_base.ps'",
								},
							       ],
					     filedate => 0,
					     filename => "$filename_base.ps",
					     filetype => 'ps',
					     identifier => 'latex/dvi/ps',
					     targets => [
							 {
							  build_commands => [
									     {
									      command => "ps2pdf '../ps/$filename_base.ps' '$filename_base.pdf'",
									     },
									    ],
							  filedate => 0,
							  filename => "$filename_base.pdf",
							  filetype => 'pdf',
							  identifier => 'latex/dvi/ps/pdf',
							 },
							],
					    },
					   ],
			       },
			       {
				build_commands => [
# 						   {
# 						    command => "cp -rp ../../plos2009.bst .",
# 						   },
						   {
						    command => "cp -rp '../$filename' .",
						   },
						   {
						    command => "mkdir -p figures/",
						   },
						   {
						    command => "cp -rp ../../figures/* figures/ || true",
						   },
						   {
						    command => "mkdir -p sounds/",
						   },
						   {
						    command => "cp -rp ../../sounds/* sounds/ || true",
						   },
						   {
						    command => "latexml --dest='$filename_base.xml' '$filename_base'",
						   },
						   {
						    command => "latexmlpost --format=xhtml --novalidate --dest='$filename_base.html' '$filename_base'",
						   },

						   # it seems that when there is no title given
						   # in the latex, latexmlpost produces an empty
						   # element for the title in the html.  This causes
						   # problems with firefox.

						   {
						    command => 'perl -i -p -e \'s{(\s+)<title/>(\s+)}{$1<title> No title given </title>$2}\' ' . "'$filename_base.html'",
						   },
						  ],
				filedate => 0,
				filename => "$filename_base.html",
				filetype => 'latexml',
				identifier => 'latex/latexml',
			       },
			      ],
		  };

	    chdir "output";

	    # prepare output: general latex processing

# 	    $filename =~ m((.*)\.tex$);

# 	    my $filename_base = $1;

	    # Remove references to self, as well as any empty itemize blocks
	    # since the itemize blocks kill the cron job. After we remove
	    # the references and resave the file.

	    $self->latex_build_targets($options, undef, undef, $latex_2_html_compilation_model);

	    # that the build leaves us in one of the build target directories

	    chdir '..';

	    # now select which of the conversions we will use for the website

	    if (not $result)
	    {
		$self->select_compiled_html();
	    }

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

    $documentation_set_name = $::option_set_name || $documentation_set_name;

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
	$documentation_set_name = $::option_set_name || $documentation_set_name;

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

	    $documentation_set_name = $::option_set_name || $documentation_set_name;

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

	$documentation_set_name = $::option_set_name || $documentation_set_name;

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

	    while ($contents =~ m(([^\\])\\heterarchxref\{../../../../../([\-a-zA-Z]*)/source/snapshots/0/([^\}]*)\}\{([^\}]*)\})gs) #($1\\href{../../$2/$3}{$4})
	    {
		my $position = pos($contents);

		my $prefix = $1;

		my $prefixqm = quotemeta($prefix);

		my $component_name = $2;

		my $component_nameqm = quotemeta($component_name);

		my $document_path = $3;

		my $document_pathqm = quotemeta($document_path);

		my $link_text = $4;

		my $link_textqm = quotemeta($link_text);

# 		if ($options->{verbose})
		{
		    print "$0: Checking ($1\\heterarchxref\{../../../../../$2/source/snapshots/0/$3\}\{$4\}) for replacement with ($1\\href{../../$2/$3}{$4})\n";
		}

		# if the component is locally installed

		if (-d "$ENV{HOME}/neurospaces_project/$component_name")
		{
		    # keep these links local

# 		    if ($options->{verbose})
		    {
			print "$0: Converting to a local href ($document_path)\n";
		    }

		    if ($contents =~ s(($prefixqm)\\heterarchxref\{../../../../../($component_nameqm)/source/snapshots/0/($document_pathqm)\}\{($link_textqm)\})($prefix\\href\{../../../../../html/htdocs/neurospaces_project/$component_name/$document_path\}\{$link_text\})gs)
		    {
		    }
		    else
		    {
			print "$0: *** Error: did not match ($component_name/$document_path) while it was previously found for local href conversion\n";
		    }
		}

		# else the component is not locally installed

		else
		{
		    # create href to a well known server for this component

# 		    if ($options->{verbose})
		    {
			print "$0: Converting to a global href ($document_path)\n";
		    }

		    if ($contents =~ s(($prefixqm)\\heterarchxref\{../../../../../($component_nameqm)/source/snapshots/0/($document_pathqm)\}\{($link_textqm)\})($prefix\\href\{http://91.183.94.6/heterarch/$component_name/$document_path\}\{$link_text\})gs)
		    {
		    }
		    else
		    {
			print "$0: *** Error: did not match ($component_name/$document_path) while it was previously found for global href conversion\n";
		    }

		}

		# restore the matching position

		pos($contents) = $position;
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

    # generate the contents pages

    if ($document_name =~ m/contents-level[1234567]/)
    {
	# read latex source

	use IO::File;

	my $source_file = IO::File->new("<$document_name/output/$document_name.tex");

	my $source_text = join "", <$source_file>;

	$source_file->close();

	#! this is not necessary anymore, correct?

	my @name = split(/\./, $document_name);

	$source_text =~ s(\\item \\href\{\.\.\/$name[0]\/$name[0]\.\w+\}\{\\bf \\underline\{.*\}\})( )g;

	# remove empty itemize environments (otherwise latex complains)

	$source_text =~ s(\\begin\{itemize\}\s+\\end\{itemize\})( )g;

	open(OUTPUT,">$document_name/output/$document_name.tex");

	print OUTPUT $source_text;

	close(OUTPUT);
    }

    # correct bibliography references

    if (-f "$document_name/output/$document_name.tex")
    {
	# read latex source

	use IO::File;

	my $source_file = IO::File->new("<$document_name/output/$document_name.tex");

	my $source_text = join "", <$source_file>;

	$source_file->close();

	# update the bibliographic reference

	$source_text =~ s(\\bibliography\{\.\./\.\./tex/bib/)(\\bibliography\{\.\./\.\./\.\./tex/bib/)g;

	# update latex links to their proper file types.

	#t For clarity of the code: this should be done in a separate
	#t block, or all the latex ! source modifiers should be
	#t integrated.  One or the other.

	my $source_htlatex = update_hyperlinks($self->{descriptor}, $source_text);

	# write converted source

	$source_file = IO::File->new(">$document_name/output/$document_name.tex");

	print $source_file $source_htlatex;

	$source_file->close();
    }

    # return result

    return $result;
}


=head2 is_wav

Find the snippets available for this document.

The snippets are found in the documents /snippets directory as files
whose filenames do not end in the '~' character.

A hash of Neurospaces::Documentation::Snippet objects is returned.

=cut

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


=head2 has_tag

Does the document have the given tag?

=cut

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


=head2 is_html

Is the document an HTML file?

=cut

sub is_html
{
    my $self = shift;

    return $self->has_tag('html');
}


=head2 is_latex

Is the document a latex file?

This is inferred from not being any of the other file types.

=cut

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


=head2 is_mp3

Is the document an MP3 file?

=cut

sub is_mp3
{
    my $self = shift;

    return $self->has_tag('mp3');
}


=head2 is_msword

Is the document an MSWord file?

=cut

sub is_msword
{
    my $self = shift;

    return
	($self->has_tag('doc')
	 or $self->has_tag('docx')
	 or $self->has_tag('odt'));
}


=head2 is_obsolete

Is the document obsolete?

=cut

sub is_obsolete
{
    my $self = shift;

    return $self->has_tag('obsolete');
}


=head2 is_pdf

Is the document a PDF file?

=cut

sub is_pdf
{
    my $self = shift;

    return $self->has_tag('pdf');
}


=head2 is_png

Is the document a PNG file?

=cut

sub is_png
{
    my $self = shift;

    return $self->has_tag('png');
}


=head2 is_ps

Is the document a postscript file?

=cut

sub is_ps
{
    my $self = shift;

    return $self->has_tag('ps');
}


=head2 is_redirect

Is the document an HTTP redirect?

=cut

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


=head2 is_restructured_text

Is the document restructured text?

=cut

sub is_restructured_text
{
    my $self = shift;

    return $self->has_tag('rst');
}


=head2 is_rich_text_format

Is the document a rich text format file?

=cut

sub is_rich_text_format
{
    my $self = shift;

    return $self->has_tag('rtf');
}


=head2 is_wav

Is the document a wav file?

=cut

sub is_wav
{
    my $self = shift;

    return $self->has_tag('wav');
}


=head2 latex_build_targets

Build the latex targets of the document according to the given
compilation model.

To build the intermediate stages this sub recurses as required.

Dates are taken into account to decide whether a given target or
intermediate target should be build.  But, currently, due to an
unknown bug this may not work under all circumstances.

=cut

sub latex_build_targets
{
    my $self = shift;

    my $options = shift;

    my $filename = shift;

    my $filedate = shift;

    my $compilation_model = shift;

    my $compilers = $options->{compilers};

    # the default is to compile with all compilers

    # but if at least one compiler is given

    my $must_compile = @$compilers == 0;

    foreach my $compiler (@$compilers)
    {
	# one of the given compilers must match with the identifier in the compilation_model

	if ($compiler eq $compilation_model->{identifier})
	{
	    $must_compile = 1;
	}
    }

    # if we must not compile

    if (not $must_compile)
    {
	# return

	return;
    }

    # create the directory for this target

    mkdir $compilation_model->{filetype};

    chdir $compilation_model->{filetype};

    # if this filetype needs to be built

    my $needs_rebuild = 1;

    my $target_filename = $compilation_model->{filename};

    if (defined $filedate
	and -e $target_filename)
    {
	my ($target_dev, $target_ino, $target_mode, $target_nlink, $target_uid, $target_gid, $target_rdev, $target_size, $target_atime, $target_mtime, $target_ctime, $target_blksize, $target_blocks)
	    = stat($target_filename);

	if ($filedate < $target_mtime)
	{
	    $needs_rebuild = 1;
	}
	else
	{
	    $needs_rebuild = 0;
	}

	$compilation_model->{filedate} = $target_mtime;
    }

    if ($needs_rebuild)
    {
	# execute the commands to build the target file

	my $build_commands = $compilation_model->{build_commands} || [];

	foreach my $build_command (@$build_commands)
	{
	    my $command = $build_command->{command};

	    if ($options->{verbose})
	    {
		print "$0: " . "latex_build_targets($command)\n";
	    }

	    system "$command";

	    if ($?)
	    {
		print "$0: *** Error: ($command) failed, $?\n";

		chdir '..';

		return "($command) failed";
	    }

	}
    }

    # we have built this target, go back to the parent directory

    chdir '..';

    # loop over all targets

    my $targets = $compilation_model->{targets} || [];

    if ($targets)
    {
	foreach my $target (@$targets)
	{
	    if (defined $filedate)
	    {
		# we are still in the directory of the previous target, so
		# go to the parent directory

# 		chdir '..';
	    }

	    # build the target in this directory

	    $self->latex_build_targets($options, $compilation_model->{filename}, $compilation_model->{filedate}, $target);
	}
    }
}


=head2 new

Construct a new document abstraction.

If the document is not given a name, it is inferred from the
directory_name option.

=cut

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


=head2 nop

Do not perform any processing on a document.

This sub is used as a substitute for other processing subs where
appropriate.

=cut

sub nop
{
    my $self = shift;

    my $options = shift;

    my $result;

    return $result;
}


=head2 output_filename

Compute the output filename of the document.

Use by heterarch-tagreplaceitems, but inconsistent with other subs
AFAICT, because it prefixes the result with the name of the document.

=cut

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


=head2 output_register

Add the given output to the output methods of this document.

The given output must be a hash that maps an extension to a filenamen
including a relative path.  Commonly the relative path starts with
"output/".

=cut

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


=head2 pdf_2_text_blocks

Prepare a file containing a document for processing.

This sub places the document ino a temporary location, unrelated to a
publicly known documentation set.

Returns a Neurospaces::Documentation::Document.

=cut

sub pdf_2_text_blocks
{
    my $self = shift;

    my $package = shift;

    my $options = shift;

    # get filters that filter out unwanted text blocks

    my $filters = $options->{filters};

    # register whether to extract images

#     my $images = $options->{images};

    # get whether to pack multiline text blocks

    my $packing = $options->{packing};

    # set verbose mode

    my $verbose = $options->{verbose};

    # by default: empty result

    my $result = [];

    # parse the pdf file

    my $directory_name = $self->{directory_name};

    use Cwd;

    my $cwd = getcwd();

    if (not chdir $directory_name)
    {
	return "cannot change to directory $directory_name (now in " . `pwd` . ")";
    }

    my $document_name = $self->{name};

    my $pdf_filename = $document_name . ".pdf";

    my $xml_string = `pdftohtml "$pdf_filename" -xml -stdout`;

    my $images = `pdfimages "$pdf_filename" figures/figure`;

    if (not chdir $cwd)
    {
	return "cannot change to directory $cwd (now in " . `pwd` . ")";
    }

    if (0)
    {
	my $left_offsets = {};

	use XML::Simple;

	my $xml
	    = XMLin
		(
		 $xml_string,
		 ForceArray => 1,
		 ForceContent => 1,
		 KeyAttr => [],
		);

	if ($verbose)
	{
	    use Data::Dumper;

	    print Dumper($xml);
	}

	# sort and loop over all text lines in this pdf

	my $text_blocks = [];

	my $last_line = -1;

	my $current_text_block_content = '';

	my $text_lines = $xml->{page}->[0]->{text};

	foreach my $text_line (sort { $a->{left} <=> $b->{left} } @$text_lines)
	{
	    # if this is from the same text block

	    if ($last_line eq -1)
	    {
		$current_text_block_content = $text_line->{content};
	    }
	    elsif ($last_line->{left} eq $text_line->{left})
		# 		   and $last_line->{font} eq $text_line->{font})
		# 		   and $last_line->{height} eq $text_line->{height})
	    {
		$current_text_block_content .= "\n" . $text_line->{content};
	    }

	    # else

	    else
	    {
		# push the current text block to the result

		push
		    @$text_blocks,
		    {
		     content => $current_text_block_content,
		     left => $last_line->{left},
		    };

		# start a new text block

		$current_text_block_content = $text_line->{content};
	    }

	    # remember the last line we parsed

	    $last_line = $text_line;
	}

	# loop over all the found text blocks and register their left offset

	foreach my $text_block (@$text_blocks)
	{
	    $left_offsets->{$text_block->{left}} = $text_block;
	}
    }

    {
	use XML::LibXML;

	my $dom = XML::LibXML->new->load_xml(string => $xml_string);

	my $root = $dom->documentElement();

	my $xc = XML::LibXML::XPathContext->new( $root );

	# loop over all the text nodes

	my $last_line = -1;

	my $text_blocks = [];

	my $current_text_block;

	my $selector = "/pdf2xml/page/text"; #  "/pdf2xml/page/text[\@left=\"741\"]";

	my $nodes = $xc->findnodes( $selector );

	foreach my $node (@$nodes)
	{
	    my $attributes = [ $node->attributes(), ];

	    if ($verbose)
	    {
		print "$0:" . $node->toString() . " :: " . $node->nodeValue() . " :: " . "\n";

		print "$0: attributes: " . ( join ", ", map { $_->nodeName() . " -> " . $_->value; } @$attributes ) . "\n";
	    }

	    my $childnodes = [ $node->childNodes(), ];

	    foreach my $childnode (@$childnodes)
	    {
		if ($verbose)
		{
		    print "$0:  " . $childnode->toString() . "\n";
		}

		my $childname = $childnode->nodeName();

		if ($childname eq 'i')
		{
		    if ($verbose)
		    {
			print "$0:  <i> " . $childnode->toString() . "\n";
		    }
		}
		elsif ($childname eq 'b')
		{
		    if ($verbose)
		    {
			print "$0:  <b> " . $childnode->toString() . "\n";
		    }
		}
		else
		{
		    if ($verbose)
		    {
			print "$0:  content " . $childnode->toString() . "\n";
		    }
		}
	    }

	    # construct a line for this node

	    my $node_string = $node->toString();

	    if ($node_string =~ m(<text top="([0-9]+)" left="([0-9]+)" width="([0-9]+)" height="([0-9]+)" font="([0-9]+)">(.+)</text>)i)
	    {
		#t here we can split the text box into multiple parts using the journal specific splitter

		my $current_text_line
		    = {
		       content => $6,
		       font => $5,
		       height => $4,
		       left => $2,
		       top => $1,
		       width => $3,
		      };

		# filter unwanted text blocks

		my $skip = 0;

		foreach my $filter_name (keys %$filters)
		{
		    my $filter = $filters->{$filter_name};

		    $skip = ($current_text_line->{content} =~ m/$filter/);

		    if ($skip)
		    {
			last;
		    }
		}

		if ($skip)
		{
		    # keep the last line the same
		}

		# if this is the first line

		elsif ($last_line eq -1)
		{
		    # start the result of the current text block

		    my $node_string = $node->toString();

		    if ($node_string =~ m(<text top="([0-9]+)" left="([0-9]+)" width="([0-9]+)" height="([0-9]+)" font="([0-9]+)">(.+)</text>)i)
		    {
			$current_text_block = $current_text_line;
		    }

		    # remember the last line we parsed

		    $last_line = $current_text_line;
		}

		# if this node has the same left offset as the previous one

		elsif (($last_line->{left} eq $current_text_line->{left}
		       # 		   and $last_line->{font} eq $text_line->{font})
		       # 		   and $last_line->{height} eq $text_line->{height})
		       )
		       and ($options->{packing} eq 'multiline'))
		{
		    # concat the results

		    $current_text_block->{content} .= "\n" . $current_text_line->{content};

		    # remember the last line we parsed

		    $last_line = $current_text_line;
		}

		# else

		else
		{
		    # push the current text block to the result

		    push @$text_blocks, $current_text_block;

		    # start a new text block

		    $current_text_block = $current_text_line;

		    # remember the last line we parsed

		    $last_line = $current_text_line;

		}
	    }

	}

	# construct a useful result

	my $id_counter = 1;

	foreach my $text_block ( @$text_blocks, )
	{
	    my $snippet = (substr $text_block->{content}, 0, 30);

	    if (length $snippet >= 30)
	    {
		my $size = length($text_block->{content}) >= 60 ? 30 : length($text_block->{content}) - 30;

		$snippet .= " ... " . (substr $text_block->{content}, - $size, - $size);
	    }

	    1 while ($snippet =~ s/\n/ /g);

	    my $content = $text_block->{content};

	    push
		@$result,
		    $package->new
			(
			 {
			  content => $content,
			  id => $id_counter,
			  snippet => $snippet,
			  text_block => $text_block,
			 },
			);

	    $id_counter++;

	}
    }

    # return result

    return $result;
}


=head2 prepare

Prepare a file containing a document for processing.

This sub places the document in a temporary location, unrelated to a
publicly known documentation set.

Returns a Neurospaces::Documentation::Document.

=cut

sub prepare
{
    my $package = shift;

    my $options = shift;

    # filename of the document, full pathname and extension

    my $filename = $options->{filename};

    # a customizable path prefix

    my $application_name = $options->{application_name};

    $filename =~ m(((.*)/)?(.*)\.(.*));

    my $source_directory = $1;

    my $document_name = $3;

    my $extension = $4;

    my $directory_name = "/tmp/${application_name}_$$/$document_name";

    {
	print STDERR "/tmp/${application_name}_$$\n";

	my $created = mkdir "/tmp/${application_name}_$$";

	if (not -d "/tmp/${application_name}_$$")
	{
	    return undef;
	}
    }

    {
	print STDERR "/tmp/${application_name}_$$/$document_name\n";

	my $created = mkdir "/tmp/${application_name}_$$/$document_name";

	if (not -d "/tmp/${application_name}_$$/$document_name")
	{
	    return undef;
	}
    }

    # only if the file already exist

    if (-e $filename)
    {
	# try to copy it

	print STDERR "$directory_name/$document_name.$extension\n";

	use File::Copy ();

	my $copied = File::Copy::copy($filename, "$directory_name/$document_name.$extension");

	if (not $copied)
	{
	    return undef;
	}
    }

    {
	print STDERR "$directory_name/figures\n";

	my $figures_directory = "$directory_name/figures";

	my $created = mkdir $figures_directory;

	if (not -d "$directory_name/figures")
	{
	    return undef;
	}
    }

    my $result
	= $package->new
	    (
	     {
	      %$options,
	      directory_name => $directory_name,
	      name => $document_name,
	      extension => $extension,
	      source_directory => $source_directory,
	     },
	    );

    return $result;
}


=head2 publish

Publish the document after it has been compiled.

At present, the compiled document is copied to the directory
output/html.

Returns undef for success, a string describing the error on failure.

=cut

sub publish
{
    my $self = shift;

    my $options = shift;

    my $result;

    my $publication_directory = $options->{publication_directory};

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
		$documentation_set_name = $::option_set_name || $documentation_set_name;

		print "$0: copying files for $directory to $publication_directory/$target_directory\n";
	    }

	    # put it in the place for publication.

	    mkdir "$publication_directory/$target_directory";

	    #! note: -pr for BSD (MAC) compatibility.

	    system "cp -pr $output/* '$publication_directory/$target_directory'";

	    if ($?)
	    {
		$result = "cp -pr $output/* '$publication_directory/$target_directory'";
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


sub select
{
    my $self = shift;

    my $options = shift;

    my $document_name = $self->{name};

    my $result = '';

    my $error;

    my $selectors = $options->{selectors};

    # read the XML version of the document

    my $build_directory = Neurospaces::Documentation::build_directory();

    my $filename;

    if ($options->{input_type} eq 'latexml')
    {
	$filename = "$build_directory/$document_name/output/latexml/$document_name.xml";
    }
    elsif ($options->{input_type} eq 'html')
    {
	$filename = "$build_directory/$document_name/output/latexml/$document_name.html";
    }

    if (-f $filename)
    {
	use XML::LibXML;

	if ($options->{output_type} eq 'xml')
	{
	    $result .= "  <selection>\n";

	    $result .= "    <document_set>\n";

	    $result .= "      $build_directory\n";

	    $result .= "    </ document_set>\n";

	    $result .= "    <document_name>\n";

	    $result .= "      $document_name\n";

	    $result .= "    </ document_name>\n";

	    foreach my $selector (@$selectors)
	    {
		$result .= "    <selector>\n";

		$result .= "      $selector\n";

		$result .= "    </selector>\n";
	    }

	    $result .= "  </ selection>\n";

	    $result .= "  <result>\n";
	}

	my $dom = XML::LibXML->new->parse_file($filename);

	my $root = $dom->documentElement();

	my $xc = XML::LibXML::XPathContext->new( $root );

	if ($options->{input_type} eq 'latexml')
	{
	    $xc->registerNs("lx", "http://dlmf.nist.gov/LaTeXML");

	    if ($options->{namespace_prefixing})
	    {
		foreach my $selector (@$selectors)
		{
		    1 while $selector =~ s(/([-_a-zA-Z]+)(\[|/|$))(/lx:$1$2)g;
		}
	    }
	}
	elsif ($options->{input_type} eq 'html')
	{
	    $xc->registerNs("xhtml", "http://www.w3.org/1999/xhtml");
	    $xc->registerNs("mathml", "http://www.w3.org/1998/Math/MathML");
	    $xc->registerNs("svg", "http://www.w3.org/2000/svg");

	    if ($options->{namespace_prefixing})
	    {
		foreach my $selector (@$selectors)
		{
		    1 while $selector =~ s(/([-_a-zA-Z]+)(\[|/|$))(/xhtml:$1$2)g;
		}
	    }
	}

	foreach my $selector (@$selectors)
	{
# 	    my $nodes = $xc->findnodes( '/ns1:xml/ns2:element[@id="myID"]' );

	    my $nodes = $xc->findnodes( $selector );

# 	    foreach my $sentence_node ( $xc->findnodes('//ns:sentence[position()=2]')->get_nodelist )

	    foreach my $node (@$nodes)
	    {
# 		print "    " . $node->textContent() . "\n";

		if ($options->{output_type} eq 'xml')
		{
		    $result .= "    " . $node->toString() . "\n";
		}
		else
		{
		    $result .= "'$document_name:" . $node->line_number(). "': '" . $node->toString() . "'\n";
		}
	    }
	}

	if ($options->{output_type} eq 'xml')
	{
	    $result .= "  </ result>\n";
	}
    }
    else
    {
	# set the error

	$error = \"cannot read XML document ($filename)";
    }

    # return the error or the result

    if ($error)
    {
	return $error;
    }
    else
    {
	return $result;
    }
}


sub select_compiled_html
{
    my $self = shift;

    my $result;

    # create the target directory

    system "mkdir -p output/html";

    if ($?)
    {
	$result = "mkdir -p output/html";
    }

    if (not $result)
    {
	# now select which of the conversions we will use for the website

	my $source_format = 'htlatex';

	print `pwd`;

	system "cp -a output/$source_format/* output/html";

	if ($?)
	{
	    $result = "cp -a output/$source_format/* output/html";
	}

	if (not $result)
	{
	    my $filename_base = $self->{name};

	    $self->output_register
		(
		 {
		  htlatex => "output/$source_format/$filename_base.html",
		 },
		);
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
	   `ls *.tex 2>/dev/null`,
	   `ls *.rst 2>/dev/null`,
	   `ls *.rtf 2>/dev/null`,
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

    $documentation_set_name = $::option_set_name || $documentation_set_name;

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


package Neurospaces::Documentation::TextBlock;


=head2 new

Construct a new text block abstraction.

If the document is not given a name, it is inferred from the
directory_name option.

=cut

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


1;


