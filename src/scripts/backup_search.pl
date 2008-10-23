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
sub VerifyPackages(@%%);
sub SearchDirectory($%%%);

# command line options
my $search_files = 0;
my @exclude_d = ();
my @exclude_fs = ();
my @exclude_reg = ();
my @include_d = ();
my $has_include_d = 0;

our @exclude_reg_comp = undef;
my $start_directory = '/';
my $help = 0;

my $same_fs = 0;
my $output_progress = 0;
my $output_files = 0;
my $output_default = 0;
my $no_md5 = 0;
my $pkg_verification = 0;
my $inst_src_packages = "";
my %instalable_packages;

my $widget_file = "";
my $list_items_file = "";
my $widget_index = 1;
my $first = 1;

my %exclude_dirs;
my %include_dirs;

# parse command line options
GetOptions('search' => \$search_files, 'exclude-dir=s' => \@exclude_d,
    'exclude-fs=s' => \@exclude_fs, 'help' => \$help, 'exclude-files=s' => \@exclude_reg,
    'output-progress' => \$output_progress, 'output-files' => \$output_files,
    'output-default' => \$output_default, 'widget-file=s'=> \$widget_file,
    '--list-file=s'=> \$list_items_file,
    'start-dir=s' => \$start_directory, 'same-fs' => \$same_fs,
    'pkg-verification' => \$pkg_verification,
    'no-md5' => \$no_md5, 'inst-src-packages=s'=> \$inst_src_packages,
    'include-dir=s' => \@include_d,
);

if ($help)
{
    print "Usage: $0 [options]\n";
    print "\nSearch modified files in packages to backup, optionaly search files which\n";
    print "  do not belong to any package.\n\n";

    print "Options:\n\n";

    print "  --no-md5          Do not use MD5 test in verification\n";

    print "  --search           Search files which do not belog to any package\n";
    print "    --exclude-dir <dir>  Exclude directory <dir> from search\n";
    print "    --exclude-fs <fs>    Exclude filesystem <fs> from search\n";
    print "    --exclude-files <r>  Exclude files matching regular expression <r>\n";
    
    print "    --include-dir <dir>  Only directories listed are backed up\n";

    print "  --output-files     Display only names of files to backup\n";
    print "  --output-progress  Display data for frontend\n";
    print "  --output-default   Default output is in format accepted by 'backup_achive' script\n";
    print "  --inst-src-packages <file>	File with list of available packages in the installation sources.\n";
    print "  --pkg-verification	Verify RPM packages, report changed files\n";
    print "  --start-dir <dir>	Start search in directory <dir>, report changed package files only in subdirectory <dir>\n";
    print "  --same-fs		Stay on the selected filesystem\n";

    exit 0;
}


$| = 1;

# compile regular expressions (speed matching up)
if (@exclude_reg > 0)
{
    @exclude_reg_comp = map qr/$_/, @exclude_reg;
}

if (!$output_files and !$output_progress)
{
    $output_default = 1;
}

if ($widget_file ne "")
{
    open(WIDGETFILE, ">$widget_file");
    print WIDGETFILE "[\n";

    open(WIDGETFILE2, ">${widget_file}2");
    print WIDGETFILE2 "[\n";
}

if ($list_items_file ne "") {
    open(LISTITEMSFILE, ">$list_items_file");
    print LISTITEMSFILE "[\n";
}

# directory names with slash
my @exclude_dir_slash = ();

# convert array to hash
foreach my $d (@exclude_d) {
    $exclude_dirs{$d} = 1;

    if (defined $d && substr($d, -1, 1) ne "/")
    {
	$d = $d.'/';
    }

    push(@exclude_dir_slash, $d);
}

# Either some directories are included
# (meaning that only these directories are backed up)
# and $has_include_d is true and %include_dirs contains these dirs
#
# Or the whole filesystem AKA root "/" is backed up
# $has_include_d is false
#
# Excludes still work!

# Evaluating Includes
foreach my $d (sort(@include_d)) {
    # including the whole root fs
    if ($d eq "/") {
	%include_dirs = {};
	$has_include_d = 0;
	last;
    }

    $d =~ s/\/*$//;
    $has_include_d = 1;

    # There mustn't be any directory already listed in another one
    my $current_path_check = "";
    my $add_new_path = 1;
    foreach my $d_item (split(/\//, $d)) {
	$current_path_check .= ($current_path_check eq "/" ? "":"/").$d_item;
	#print "\tCheck >>".$current_path_check."<<\n";
	if (defined $include_dirs{$current_path_check}) {
	    #print $d." is already in ".$current_path_check."\n";
	    $add_new_path = 0;
	    last;
	}
    }

    if ($add_new_path) {
	#print "Adding: ".$d."\n";
	$include_dirs{$d} = 1;
    }
}

# verify installed packages
my @installed_packages = ReadAllPackages();

# convert array to hash
my %installed_packages_hash;
foreach my $ip (@installed_packages) {$installed_packages_hash{$ip} = 1;}

# get list of unavailable packages
my %unavailable_pkgs = ();
if ($inst_src_packages ne "")
{
    open(INST_SRC, $inst_src_packages);

    while (my $ipkg = <INST_SRC>)
    {
	chomp($ipkg);
	$instalable_packages{$ipkg} = 1;
    }

    close(INST_SRC);

    # get packages which are unavailable (modified or non-SuSE)
    foreach my $pk (@installed_packages)
    {
	if (!defined $instalable_packages{$pk})
	{
	    $unavailable_pkgs{$pk} = 1;
	}
    }
}

undef %instalable_packages;
undef %installed_packages_hash;

my %packages_files;
my %package_files_inodes;
my %dups;

# bnc #421214
sub Quote ($) {
    my $string = shift;

    if (not defined $string || $string eq "") {
	return '';
    };

    $string =~ s/\'/\'"\'"\'/g;
    $string = '\''.$string.'\'';

    return $string;
}

# read list of all package's files if searching not owned files is required
# or MD5 sum is not used in searching modified files
if ($search_files or $no_md5)	
{
    %dups = ReadAllFiles(\%packages_files, \%package_files_inodes);
}
else
{
    if ($output_progress)
    {
     	print "Files read\n";
    }
}

# release list of files if it will not be used to save memory
if (!$search_files)
{
    %packages_files = ();
}

if ($pkg_verification)
{
    VerifyPackages(\@installed_packages, \%unavailable_pkgs, \%dups);
}

if ($search_files)
{
    if (!$output_files)
    {
	print "Nopackage:\n";
    }
   
    # insert excluded mountpoints to excluded directories
    foreach my $d (FsToDirs(@exclude_fs)) {$exclude_dirs{$d} = 1;}

    # if it is required to stay on the selected file system then
    # add all mountpoints to the exclude dirs
    # TODO: this approach is not 100% reliable - a device can mounted after this check
    if ($same_fs)
    {
	open(MOUNT, "-|", "LC_ALL=C /bin/mount");

	while (my $line = <MOUNT>) 
	{
	    chomp($line);

	    if ($line =~ /^.* on (.*) type /)
	    {
		$exclude_dirs{$1} = 1;
	    }
	}

	close(MOUNT);
    }

    # start searching from every-single include-dir
    if ($has_include_d > 0) {
    # start searching from root directory
	foreach my $dir (sort(@include_d)) {
	    SearchDirectory($dir, \%packages_files, \%exclude_dirs, \%package_files_inodes);
	}
    } else {
	SearchDirectory($start_directory, \%packages_files, \%exclude_dirs, \%package_files_inodes);
    }
}
# backup RPM DB if some updated package was found
elsif (keys(%unavailable_pkgs) > 0)
{
    if (!$output_files)
    {
	print "Nopackage:\n";
    }

    $start_directory = "/var/lib/rpm";
    SearchDirectory($start_directory, \%packages_files, \%exclude_dirs, \%package_files_inodes);
}
    

if ($widget_file ne "")
{
    print WIDGETFILE "\n]\n";
    close(WIDGETFILE);

    print WIDGETFILE2 "\n]\n";
    close(WIDGETFILE2);
}

if ($list_items_file ne "") {
    print LISTITEMSFILE "\n]\n";
    close LISTITEMSFILE;
}

exit 0;
# End of main part
######################################################

# return list of installed packages
sub ReadAllPackages()
{
    # read all installed packages
    open(RPMQA, "-|", "LC_ALL=C rpm -qa")
	or die "Command 'rpm -qa' failed\n";

    print "Reading installed packages\n";

    my $line;
    my @all_packages;

    while ($line = <RPMQA>) 
    {
	chomp($line);
	push(@all_packages, $line);
    }

    close(RPMQA);

    my $n = @all_packages;
    print "Packages: $n\n";

    return @all_packages;
}

sub BackItUp_AccordingIncludes ($);

# uses global variable exclude_reg_comp (precompiled regular expressions)
sub PrintFoundFile($$$$$)
{
    my ($file, $ref_package, $widget_file, $output_files, $start_directory) = @_;

    # $widget_index <-> using the global one

    return if (! BackItUp_AccordingIncludes($file));

    if (defined $file)
    {
	# finish function if file is not in the specified directory
	if (substr($file, 0, length($start_directory)) ne $start_directory)
	{
	    return;
	}

	# check wheter file matches any of the specified regular expression
	foreach my $reg (@exclude_reg_comp) {
	    if (defined $reg && $file =~ $reg)
	    {
		# finish function if a match is found

		###
		# Arrary should be aplhabetically sorted, when the file (alphabetically sorted)
		# matches the middle item of the array, the array could be reversed
		###

		return;
	    }
	}

	# check wheter file matches any of the specified direcory name
	foreach my $ex_d (@exclude_dir_slash) {
	    if (defined $ex_d && $file =~ "^$ex_d")
	    {
		# finish function if a match is found
		
		###
		# Arrary should be aplhabetically sorted, when the file (alphabetically sorted)
		# matches the middle item of the array, the array could be reversed
		###
		
		return;
	    }
	}

	++$widget_index;

	# escaping newline characters is needed because each file
	# is reported on separate line
	
	$file =~ s/\\/\\\\/g;
	$file =~ s/\n/\\n/g;

	if (!$output_files) {
	    my $size = 0;
	    if ((! -d $file) && (! -l $file)) {
		$size = -s $file;
	    }
	    print "Size: ".$size." ".$file."\n";
	} else {
	    print $file."\n";
	}

	if ($widget_file ne "")
	{
	    print WIDGETFILE '`item(`id('.$widget_index.'), "X", "'.$file.'", "'.$$ref_package.'"),'."\n";
	    print WIDGETFILE2 '`item(`id('.$widget_index.'), " ", "'.$file.'", "'.$$ref_package.'"),'."\n";
	}

	if ($list_items_file ne "") {
	    print LISTITEMSFILE '['.$widget_index.', "'.$file.'"],'."\n";
	}
    }
}

# Check file and return whether to backup or not
sub CheckFile {
    my $line = shift;
    my $refref_duplicates_file = shift;
    my $package = shift;

		# modified files have set flags Size or MTime

		my $file = undef;
		my $size = 0;
		my $mtime = 0;
		my $link = 0;
		my $md5_test = 0;

		my $backup = 1;
		my $file_size = 0;

		$link = ($$line =~ /^....L.* (\/.*)/);

		if ($link)
		{
		    $file = $1;
		}

		if ($no_md5)
		{
		    $size = ($$line =~ /^S.* (\/.*)/);
		    if ($size)
		    {
			$file = $1;
		    }
		    
		    $mtime = ($$line =~ /^\..{6}T.* (\/.*)/);
		    if ($mtime)
		    {
			$file = $1;
		    }


		    if ($size or $mtime)
		    {
			# check if Mtime changed file is in more than one package
			if ($mtime and !$size and $no_md5 and $$$refref_duplicates_file{$file})
			{
			    open(RPMQFILE, "-|", "LC_ALL=C rpm -qf ".Quote ($file));
			    my @packages_list = ();
			    
			    while (my $pkg = <RPMQFILE>)
			    {
			    	chomp($pkg);
			    	
			    	if ($pkg ne $$package)
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
				open(RPMVRF, "-|", "LC_ALL=C rpm -V ".Quote ($pack)." --nodeps | grep ".Quote ($file));
				
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
		    $md5_test = ($$line =~ /^..5.* (\/.*)/);
		    if ($md5_test)
		    {
			$file = $1;
		    }
		}

    return ($backup,$file);
}

sub PrintOutInstPrefix ($) {
    my $package = shift;

    my $rpm_query = 'LC_ALL=C rpm -q --queryformat "%{INSTPREFIXES}" '.Quote ($package);
    print "Installed: ".`$rpm_query`."\n";
}

# verify each package in the list
sub VerifyPackages(@%%) {
    my ($packages, $unavail, $duplicates) = @_;

    # rpm -q --filesbypkg @all-rpm-packages

    ### Printing out all unavailable packages and their content
    if (keys %{$unavail}) {
	my $command = "";
	foreach my $pack (keys %{$unavail}) {
	    $command .= ' '.Quote ($pack);
	}

	$command = 'LC_ALL=C rpm -q --queryformat "FULL-PACKAGE-NAME: %{NAME}-%{VERSION}-%{RELEASE}\n" --filesbypkg '.$command;
	open(RPML, "-|", $command) || do {
	    warn "Cannot run: ".$command;
	};
	my $current_package_name = '';
	while (my $l = <RPML>) {
	    chomp($l);
	    next if (!$l);
	    # output is:
	    #PACKAGE-NAME: full-package-name-with-version
	    #package    (spaces)    file
	    #package    (spaces)    another-file

	    if ($l =~ /^FULL-PACKAGE-NAME: (.*)$/) {
		print "Complete package: ".$1."\n";
		PrintOutInstPrefix($1);
		$current_package_name = $1;
		next;
	    } else {
		# package name without version
		$l =~ /^([^ \t]+)[ \t]+(.+)$/;
	    
		# checking existency of a file on the system
		if (-e $2) {
		    PrintFoundFile($2, \$current_package_name, $widget_file, $output_files, $start_directory);
		}
	    }
	}
	close (RPML);
    }

    ### Print out all availabe packages
    my $md5_param = ($no_md5) ? "--nomd5" : "";
    foreach my $package (@$packages) {
	# skipping unavailable packages for this run
	next if (defined $$unavail{$package});

	if (!$output_files) {
	    print "Package: ".$package."\n";
	    PrintOutInstPrefix($package);
	}

	# verification of the package - do not check package dependencies
	open(RPMV, "-|", "LC_ALL=C rpm -V ".Quote ($package)." $md5_param --nodeps")
	    or die "Verification of package $package failed.";

	    while (my $line = <RPMV>) {
		chomp ($line);
		my ($backup,$file)=CheckFile(\$line, \$duplicates, \$package);
		if ($backup) {
		    PrintFoundFile($file, \$package, $widget_file, $output_files, $start_directory);
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
    
    open(RPMQAL, "-|", "LC_ALL=C rpm -qal")
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
		#if ($search_files)
		#{
		#    my @st = stat($line);
		#    $pkg_inodes->{$st[0].$st[1]} = 1;	# store device and inode number
		#}

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


sub isinpackage($)
{
    my ($filename) = @_;

    open(RPMQFILE, '-|', 'LANG=C rpm -qf '.Quote ($filename).' 2>/dev/null');
    my $inpackage = 0;

    while (my $pkg = <RPMQFILE>)
    {
	# bnc #421214, backup also symbolic links
	if ( $pkg !~ /is not owned by any package$/ ) {
	    $inpackage = 1;
	}
    }
    close(RPMQFILE);

    return $inpackage;
}

sub BackItUp_AccordingIncludes ($) {
    my $file_dir = shift;

    # There are some includes, run through the machinery
    if ($has_include_d) {
	my @subdirs = split(/\//, $file_dir);
	#print "\nDEBUG: searching for : >>".$file_dir."<<\n";

	while (1) {
	    # no match other possible
	    return 0 if (@subdirs == 0);
	    
	    # the last item is >><< empty but leads to the "/" root fs
	    my $check_dir = join("/", @subdirs);
	    #print "\ttrying: ".$check_dir."\n";

	    if (defined $include_dirs{$check_dir}) {
		#print "DEBUG: found ".$check_dir."\n";
		last;
	    }

	    # for the next turn
	    pop(@subdirs);
	}
    }
    
    return 1;
}

# search files which do not belong to any package
sub SearchDirectory($%%%)
{
    my ($dir, $files, $exclude, $inodes) = @_;
    
    return if (! BackItUp_AccordingIncludes($dir));

    if ($output_progress)
    {
	print 'Dir: '.$dir."\n";
    }

    my $in_dir = $dir;

    # add ending '/' if neccessary
    $dir .= '/' if ($dir !~ /\/$/);

    opendir(DIR, $dir)
	or return;

    # read directory content
    my @content = readdir(DIR);
    closedir(DIR);

    # only directories, filesystems and regexps can be excluded
    # PrintFoundFile works with regexps

    my $emptypackage = "";
    foreach my $item (@content) {
	    my $fullname = $dir.$item;

	    # skipping . and .. directories
	    next if ($item eq "." || $item eq "..");

	    if (-l $fullname)
	    {
		if (!$$files{$fullname})
		{
		    if (isinpackage($fullname) == 0)
		    {
			PrintFoundFile($fullname, \$emptypackage, $widget_file, $output_files, $dir);
		    }
		}
	    }
	    elsif (-f $fullname || -d $fullname)
	    {
		# is file is some package?
		if (!$$files{$fullname})
		{
		    PrintFoundFile($fullname, \$emptypackage, $widget_file, $output_files, $dir);
		}

		# do recursive search in subdirectory (if it is not excluded)
		if (-d $fullname)
		{
		    if (!$$exclude{$fullname})
		    {
			SearchDirectory($fullname, $files, $exclude, $inodes);
		    }
		}

	    }
	    # ignore sockets - they can't be archived
	    elsif (!$$files{$fullname} and !(-S $fullname))
	    {
		PrintFoundFile($fullname, \$emptypackage, $widget_file, $output_files, $dir);
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
	open(MOUNTT, "-|", "export LC_ALL=C; mount -t ".Quote ($fsys))
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
