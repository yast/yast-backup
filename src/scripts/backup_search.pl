#!/usr/bin/perl -w

#
#  File:
#    backup_files.pl
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  Description:
#    This script searches modified files in system (comparing
#    to the RPM database) a and files which do not belong do any
#    package. Output is list of files and optional more
#    information about progress of search.
#
# $Id$
#

use Getopt::Long;
use strict;

#function prototypes
sub ReadAllPackages();
sub FsToDirs(@);
sub ReadAllFiles(%%);
sub VerifyPackages(@%);
sub SearchDirectory($%%%);

# command line options
my $search_files = 0;
my @exclude_d = ();
my @exclude_fs = ();
my $help = 0;

my $output_progress = 0;
my $output_files = 0;
my $output_default = 0;
my $enhanced_check_nopkg = 0;
my $disable_check_multiple = 0;
my $no_md5 = 0;

my %exclude_dirs;


# parse command line options
GetOptions('search' => \$search_files, 'exclude-dir=s' => \@exclude_d,
    'exclude-fs=s' => \@exclude_fs,  'help' => \$help,
    'output-progress' => \$output_progress, 'output-files' => \$output_files,
    'output-default' => \$output_default, 'enhanced-check' => \$enhanced_check_nopkg,
    'disable-check-multiple' => \$disable_check_multiple, 'no-md5' => \$no_md5
);

if ($help)
{
    print "Usage: $0 [options]\n";
    print "\nSearch modified files in packages to backup, optionaly search files which\n";
    print "  do not belong to any package.\n\n";

    print "Options:\n\n";


    print "  --disable-check-multiple   Do not check if backup is needed for changed files \
which are in multiple packages, always backup them\n\n";
    print "  --no-md5          Do not use MD5 test in verification\n";

    print "  --search           Search files which do not belog to any package\n";
    print "    --exclude-dir <dir>  Exclude directory <dir> from search\n";
    print "    --exclude-fs <fs>    Exclude filesystem <fs> from search\n";
    print "    --enhanced-check     Enhanced check of owner - slower search, but more accurate\n\n";

    print "  --output-files     Display only names of files to backup\n";
    print "  --output-progress  Display data for frontend\n";
    print "  --output-default   Default output is in format accepted by 'backup_achive' script\n";
    exit 0;
}


$| = 1;

if (!$output_files and !$output_progress)
{
    $output_default = 1;
}



# convert array to hash
foreach my $d (@exclude_d) {$exclude_dirs{$d} = 1;}

# verify installed packages
my @installed_packages = ReadAllPackages();

my %packages_files;
my %package_files_inodes;

my %dups = ReadAllFiles(\%packages_files, \%package_files_inodes);

VerifyPackages(\@installed_packages, \%dups);

if ($search_files)
{
    if (!$output_files)
    {
	print "Nopackage:\n";
    }
   
    # insert excluded mountpoints to excluded directories
    foreach my $d (FsToDirs(@exclude_fs)) {$exclude_dirs{$d} = 1;}

    # read list of all files in installed packages
#   ReadAllFiles(\%packages_files);

    # start searching from root directory
    SearchDirectory('/', \%packages_files, \%exclude_dirs, \%package_files_inodes);
}

######################################################

# return list of installed packages
sub ReadAllPackages()
{
    # read all installed packages
    open(RPMQA, "rpm -qa |")
	or die "Command 'rpm -qa' failed\n";

    print "<installed>\n";

    my $line;
    my @all_packages;

    while ($line = <RPMQA>) 
    {
	print $line;

	chomp($line);
	push(@all_packages, $line);
    }

    close(RPMQA);

    print "</installed>\n";

    return @all_packages;
}

# verify each package in the list
sub VerifyPackages(@%)
{
    my ($packages, $duplicates) = @_;

    foreach my $package (@$packages) {
	if (!$output_files)
	{
	    print "Package: $package\n";

	    print "Installed:";
	    system('export LC_ALL=C; rpm -q '.$package.' --queryformat " %{INSTPREFIXES}"');
	    print "\n";
	}

	my $md5_param = ($no_md5) ? "--nomd5" : "";

	# verification of the package - do not check package dependencies, do not run verify scripts
	open(RPMV, "export LC_ALL=C; rpm -V $package $md5_param --noscripts --nodeps |")
	    or die "Verification of package $package failed.";

	while (my $line = <RPMV>)
	{
	    chomp ($line);

	    # modified files have set flags Size or MTime

	    my $file = undef;
	    my $size = 0;
	    my $mtime = 0;
	    my $md5_test = 0;

    	    my $backup = 1;
	    
	    if ($no_md5)
	    {
		$size = ($line =~ /^S.* (\/.*)/);
		if ($size)
		{
		    $file = $1;
		}
		
		$mtime = ($line =~ /^\..{6}T.* (\/.*)/);
		if ($mtime)
		{
		    $file = $1;
		}


		if ($size or $mtime)
		{
		    # check if Mtime changed file is in more than one package
		    if (!$disable_check_multiple and $mtime and !$size and $no_md5 and $$duplicates{$file})
		    {
			open(RPMQFILE, "rpm -qf $file |");
			my @packages_list = ();

			while (my $pkg = <RPMQFILE>)
			{
			    chomp($pkg);
			    
			    if ($pkg ne $package)
			    {
				push(@packages_list, $pkg);
			    }
			}
			close(RPMQFILE);

			foreach my $pack (@packages_list)
			{
			    # it is not possible to verify one file from package
			    # so all files in package are verified
			    # in this verification is not MD5 test excluded
			    # TODO LATER: don't grep but cache results of all files from package
			    open(RPMVRF, "rpm -V $pack --nodeps --noscripts | grep $file |");
			    
			    my $fl = <RPMVRF>;
			    
			    if (!defined $fl)
			    {
				$backup = 0;
			    }
			    else
			    {
				while (my $fl = <RPMVRF>)
				{
				    if (($fl !~ /^S.* \/./) and ($fl !~ /^\..{6}T.* \/.*/) and ($fl !~ /^..5.* \/.*/))
				    {
					$backup = 0;
				    }
				}
			    }
			    
			    close(RPMVRF);
			    
			}
		    }
		}
		
	    }
	    else
	    {
		$md5_test = ($line =~ /^..5.* (\/.*)/);
		if ($md5_test)
		{
		    $file = $1;
		}
	    }

	    if (defined $file and $backup)
	    {
		my @filestat = stat($file);

		if (!$output_files)
		{
		    print "Size: $filestat[7] $file\n";
		}
		else
		{
		    print "$file\n";
		}
	    }
	}

	close(RPMV);
    }
}


# read all files which belong to packages
sub ReadAllFiles(%%) 
{
    my ($all_files, $pkg_inodes) = @_;
    my %duplicates;
    
    open(RPMQAL, "rpm -qal |")
	or die "Command 'rpm -qal' failed\n";

    if ($output_progress)
    {
	print "Reading all files\n";
    }

    while (my $line = <RPMQAL>) 
    {
	chomp($line);

	if (-r $line)
	{
	    if (exists $$all_files{$line})
	    {
		$duplicates{$line} = 1;
	    }
	    else
	    {
		my @st = stat($line);
		$pkg_inodes->{$st[0].$st[1]} = 1;	# store device and inode number

		$all_files->{$line} = 1;
	    }
	}
    }

    close(RPMQAL);

    if ($output_progress)
    {
     	print "Files read\n";
    }

    return %duplicates;
}

# search files which do not belong to any package
sub SearchDirectory($%%%)
{
    my ($dir, $files, $exclude, $inodes) = @_;

    if ($output_progress)
    {
	print "Dir: $dir\n";
    }

    # add ending '/' if neccessary
    if (substr($dir, length($dir) - 1) ne '/')
    {
	$dir .= '/';
    }

    opendir(DIR, $dir)
	or return;

    # read directory content
    my @content = readdir(DIR);
    closedir(DIR);

    foreach my $item (@content)
    {
	my $fullname = $dir.$item;

	if (-l $fullname)
	{
	    next;	# skip symbolic links
	}

	if (-f $fullname)
	{
	    # is file is some package?
	    if (!$$files{$fullname})
	    {
		if ($enhanced_check_nopkg)
		{
		    # it seems that file $fullname is not any package, check this by rpm query
		    
		    # this double checking is needed because for example rpm -qf sax2 says that
		    # sax2 has files in directory /var/X11R6/lib/sax, but /var/X11R6/lib is symlink
		    # to /usr/X11R6/lib/X11, so it seems that files /usr/X11R6/lib/X11/sax/* are not
		    # owned by any package, but rpm -qf /usr/X11R6/lib/X11/sax/* tells that files
		    # are in package sax2

		    # TODO check more files at once
		    
		    open(RPMQF, "rpm -qf $fullname 2> /dev/null |");

		    my $line = <RPMQF>;

		    if (!defined $line)	# if output is empty then file is not owned by any package
		    {
			if (!$output_files)
			{
	    		    my @filestat = stat($fullname);
			    print "Size: $filestat[7] $fullname\n";
			}
			else
			{
			    print "$fullname\n";
			}
		    }
		    else
		    {
			while (<RPMQF>){};	# read remaining output
		    }
		    
		    close(RPMQF);
		}
		else
		{
		    my @filestat = stat($fullname);

		    if (!defined $inodes->{$filestat[0].$filestat[1]})
		    {
			if (!$output_files)
			{
			    print "Size: $filestat[7] $fullname\n";
			}
			else
			{
			    print "$fullname\n";
			}
		    }
	    
		}
	    }
	}
	else
	{
	    # ignore . and .. directories
	    if ($item ne "." and $item ne ".." and -d $fullname)
	    {
		if (!$$exclude{$fullname})
		{
		    SearchDirectory($fullname, $files, $exclude, $inodes);
		}
	    }
	}
    }
}

# convert filesystems to mount point directories
sub FsToDirs(@)
{
    my @fs = @_;
    my @dirs = ();
    my $line;
    my @arr;

    foreach my $fsys (@fs)
    {
	open(MOUNTT, "export LC_ALL=C; mount -t $fsys |")
	    or next;
     
	while ($line = <MOUNTT>)
	{
	    @arr = split(/ /, $line);
	    push(@dirs, $arr[2]);
	}     

	close(MOUNTT);
    }

    return @dirs;
}



