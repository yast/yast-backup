#!/usr/bin/perl -w

#
#  File:
#    backup_archive.pl
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  Description:
#    This script creates backup archive as specified with command
#    line parameters.
#
# $Id$
#

use Getopt::Long;
use strict;

use File::Temp qw( tempdir );
use POSIX qw( strftime );

# return all harddisks present in system
sub harddisks($)
{
    my @disks = ();
    my ($verbose) = @_;

    if (defined open(SFD, '/sbin/sfdisk -s 2> /dev/null |'))
    {
	while (my $sfline = <SFD>)
	{
	    chomp($sfline);

	    if ($sfline =~ /^\/dev\/(.d.):\s+\d+$/)
	    {
		push(@disks, $1);
	    }
	}

	close(SFD);

	if ($verbose)
	{
	    print "Partition tables info read\n";
	}
    }

    return @disks;
}

# create parent directories for new file
sub create_dirs($)
{
    my ($f) = @_;
    my $ix = rindex($f, '/');

    if ($ix > 0)
    {
	my $dirs = substr($f, 0, $ix);
	system("/bin/mkdir -p $dirs 2> /dev/null");		# create directory with parents
    }
}

sub remove_escape($)
{
    my ($in) = @_;

    my $num_bkslh = 0;
    my $len = length($in);
    my $idx = 0;

    my $result = '';
    
    while($idx < $len)
    {
	my $char = substr($in, $idx, 1);

	if ($char eq "\\")
	{
	    $num_bkslh = $num_bkslh + 1;
	}
	else
	{
	    if ($num_bkslh > 0)
	    {
		$result .= "\\" x ($num_bkslh >> 1);

		if (($char eq "n") and ($num_bkslh % 2 != 0))
		{
		    $result .= "\n";
		}
		else
		{
		    $result .= $char;
		}
	    }
	    else
	    {
		$result .= $char;
	    }
	    
	    $num_bkslh = 0;
	}
	
	$idx += 1;
    }

    # add trailing backslashes
    $result .= "\\" x ($num_bkslh >> 1);

    return $result;
}


# command line options
my $archive_name = '';
my $archive_type = '';
my $help = '0';
my $store_pt = '0';
my @ext2_parts = ();
my $verbose = '0';
my $files_info = '';
my $comment_file = '';
my $multi_volume = undef;

# parse command line options
GetOptions('archive-name=s' => \$archive_name, 
    'archive-type=s' => \$archive_type, 'help' => \$help,
    'store-ptable' => \$store_pt, 'store-ext2=s' => \@ext2_parts,
    'verbose' => \$verbose, 'files-info=s' => \$files_info,
    'comment-file=s'=> \$comment_file, 'multi-volume=i' => \$multi_volume
);


if ($help or $files_info eq '' or $archive_name eq '')
{
    print "Usage: $0 [options]\n\n";
    
    print "This script creates backup archive as specified in input file and in command line options.\n";
    print "Options --archive-name and --files-info are mandatory.\n\n";
    
    print "Options:\n\n";
    
    print "  --help                Display this help\n\n";
    print "  --archive-name <file> Target archive file name\n";
    print "  --archive-type <type> Type of compression used by tar, type can be 'tgz' - compressed by gzip, 'tbz2' - compressed by bzip2, 'tar' - no compression or 'txt' - only list of files is generated instead crating archive. Default is 'tgz'\n";
    print "  --multi-volume <size> Create multiple volume archive, size is in kiB (1kiB = 1024B)\n";
    print "  --verbose             Print progress information\n";
    print "  --store-ptable        Add partition tables information to archive\n";
    print "  --store-ext2 <device> Store Ext2 system area from device\n";
    print "  --files-info <file>         Data file from backup_search script\n";
    print "  --comment-file <file> Use comment stored in file\n\n";
        
    exit 0;
}


$| = 1;

# archive type option
if ($archive_type ne 'tgz' && $archive_type ne 'tbz2' && $archive_type ne 'tar' && $archive_type ne 'txt')
{
    $archive_type = 'tgz';
}

# for security reasons set permissions only to owner
umask(0077);

# only store list of files - filter input list
if ($archive_type eq 'txt')
{
    print "Storing list\n";

    create_dirs($archive_name);

    open(OUT, '>', $archive_name)
	or die "Error storing file list\n";

    if (defined open(FILES, $files_info))
    {
	while (my $line = <FILES>)
	{
	    chomp($line);
	    
	    if (substr($line, 0, 1) eq "/")
	    {
		print OUT $line."\n";
	    }
	}
	
	close(FILES);
    }

    close(FILES_INFO);

    print "File list stored\n";
    
    exit 0;
}

my $tmp_dir_root = tempdir(CLEANUP => 1);	# remove directory content at exit

my $tmp_dir = $tmp_dir_root."/tmp";
if (!mkdir($tmp_dir))
{
    die "Can not create directory $tmp_dir\n";
}

$tmp_dir .= "/info";
if (!mkdir($tmp_dir))
{
    die "Can not create directory $tmp_dir\n";
}

my $tmp_dir_sys = $tmp_dir_root."/tmp/system";
if (!mkdir($tmp_dir_sys))
{
    die "Can not create directory $tmp_dir_sys\n";
}

my $files_num = 0;

open(OUT, '>', $tmp_dir."/files")
    or die "Can not open file $tmp_dir/files\n";


print OUT "info/files\n";
$files_num++;

print OUT "info/packages_info\n";
$files_num++;


# store host name
use Sys::Hostname;
my $host = hostname();

if ($verbose)
{
    print "Storing hostname: ";
}

open(HOST, '>', $tmp_dir.'/hostname');
print HOST $host;
close(HOST);

if (-s $tmp_dir.'/hostname')
{
    if ($verbose)
    {
	print "Success\n";
    }
    
    print OUT "info/hostname\n";
    $files_num++;
}
else
{
    if ($verbose)
    {
	print "Failed\n";
    }
}


# store date
if ($verbose)
{
    print "Storing date: ";
}

my $date = strftime('%d.%m.%Y  %H:%M', localtime());

open(DATE, '>', $tmp_dir.'/date');
print DATE $date;
close(DATE);


if (-s $tmp_dir.'/date')
{
    if ($verbose)
    {
	print "Success\n";
    }
    
    print OUT "info/date\n";
    $files_num++;
}
else
{
    if ($verbose)
    {
	print "Failed\n";
    }
}

my @disks = ();
my @disks_results = ();


# store partition table info
if ($store_pt)
{
    if ($verbose)
    {
	print "Storing partition table\n";
    }

    @disks = harddisks($verbose);

    foreach my $disk (@disks)
    {
	my $stored = 0;

	if (system("/sbin/sfdisk -d /dev/$disk > $tmp_dir_sys/partition_table_$disk.txt 2> /dev/null") >> 8 == 0)
	{
	    if (system("dd if=/dev/$disk of=$tmp_dir_sys/partition_table_$disk bs=512 count=1 2> /dev/null") >> 8 == 0)
	    {
		print OUT "system/partition_table_$disk.txt\n";
		print OUT "system/partition_table_$disk\n";
		$files_num = $files_num + 2;

		$stored = 1;

		if ($verbose)
		{
		    print "Stored partition: $disk\n";
		}
	    }
	    else
	    {
		unlink("$tmp_dir_sys/partition_table_$disk.txt");

		if ($verbose)
		{
		    print "Error storing partition: /dev/$disk";
		}
	    }
	}
	else
	{
	    if ($verbose)
	    {
		print "Error storing partition: /dev/$disk";
	    }
	}

	push(@disks_results, $stored);
    }
}

# copy comment
if (length($comment_file) > 0)
{
    system("cp $comment_file $tmp_dir/comment");

    if ($? == 0)
    {
	print OUT "info/comment\n";
	$files_num++;
    }
}


if ($verbose)
{
    print "Storing list of installed packages\n";
}

system("rpm -qa > $tmp_dir/installed_packages 2> /dev/null");

if ($verbose)
{
    if ($? == 0)
    {
	print "Packages stored: Success\n";

	print OUT "info/installed_packages\n";
	$files_num = $files_num + 1;
    }
    else
    {
	print "Packages stored: Failed\n";
    }
}


# store ext2 system area

foreach my $part (@ext2_parts)
{
    if ($verbose)
    {
	print "Storing ext2 area: $part\n";
    }

    # transliterate all '/' characters to '_' in device name
    my $tr_dev_name = $part;
    $tr_dev_name =~ tr/\//_/;

    my $output_name = $tmp_dir_sys."/e2image".$tr_dev_name;

    system("/sbin/e2image $part $output_name 2> /dev/null");

    if (-s $output_name)
    {
	# compress e2image, tar is used because e2image is sparse file
	system("tar -j -C $tmp_dir_sys -S -c -f $tmp_dir_sys/e2image$tr_dev_name.tar.bz2 e2image$tr_dev_name");
	
	if ($? == 0)
	{
	    print OUT "system/e2image$tr_dev_name.tar.bz2\n";
	    $files_num++;
	}
	
	if ($verbose)
	{
	    if ($? == 0)
	    {
		print "Success\n";
	    }
	    else
	    {
		print "Failed\n";
	    }
	}
    }
    else
    {
	if ($verbose)
	{
	    print "Failed\n";
	}
    }
}


# filter files_info file, output only file names

open(FILES_INFO, "> $tmp_dir/packages_info")
    or die "Can not create file $tmp_dir/packages_info\n";

my $package_name;
my $install_prefix;

my $opened;


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year += 1900;
$mon++;

my $date_str = sprintf("%04d%02d%02d", $year, $mon, $mday);

if ($verbose)
{
    print "Creating archive:\n";
}

if (defined open(FILES, $files_info))
{
    while (my $line = <FILES>)
    {
	chomp($line);
	
	if ($line =~ /^\/.+/)
	{
	    if (-r remove_escape($line) or -l remove_escape($line))	# output only readable files from files-info
						# symlinked files need not to be readable
	    {
    		print FILES_INFO $line."\n";

		if (defined $opened)
		{
		    print PKGLIST $line."\n";
		}
	    }
	    else
	    {
    		print "/File not readable: $line\n";
	    }
	}
	else
	{
	    if ($line =~ /Package: (.*)/ || $line eq "Nopackage:")
	    {

		if (defined $opened)
		{
		    close(PKGLIST);

		    my $command = "/bin/tar -c -v --files-from $tmp_dir_root/$package_name --ignore-failed-read -S -f $tmp_dir_root/tmp/$package_name-$date_str-0.tar";

		    print OUT "$package_name-$date_str-0.tar";
		    $files_num++;

		    if ($archive_type eq 'tgz')
		    {
			$command .= '.gz -z';
			print OUT ".gz\n";
		    }
		    else
		    {
			if ($archive_type eq 'tbz2')
			{
			    $command .= '.bz2 -j';
			    print OUT ".bz2\n";
			}
			else
			{
			    print OUT "\n";
			}
		    }

		    $command .= " 2> /dev/null";

		    system($command);

		}
		
		$package_name = ($line eq "Nopackage:") ? "NOPACKAGE" : $1;

		$opened = open(PKGLIST, ">$tmp_dir_root/$package_name");
		print FILES_INFO $line."\n";
	    }
	    else
	    {	if ($line =~ /Installed: (.*)/)
		{
		    $install_prefix = $1;
		    print FILES_INFO $line."\n";
		}
		else	
		{
		    print STDERR "Unknown text in input file: $line\n";
		}
	    }
	}
    }
    
    close(FILES);
}


if (defined $opened)
{
    close(PKGLIST);

    my $command = "/bin/tar -c -v --files-from $tmp_dir_root/$package_name --ignore-failed-read -S -f $tmp_dir_root/tmp/$package_name-$date_str-0.tar";

    print OUT "$package_name-$date_str-0.tar";
    $files_num++;

    if ($archive_type eq 'tgz')
    {
	$command .= '.gz -z';
	print OUT ".gz\n";
    }
    else
    {
	if ($archive_type eq 'tbz2')
	{
	    $command .= '.bz2 -j';
	    print OUT ".bz2\n";
	}
	else
	{
	    print OUT "\n";
	}
    }

    $command .= " 2> /dev/null";

    system($command);

}

close(FILES_INFO);

close(OUT);


if ($verbose)
{
    print "Creating target archive file...\n";
}

# create required subdirs
create_dirs($archive_name);


# used tar options:
#  -c 			create archive
#  -f <file> 		archive file name
#  --files-from <file>	read list from file
#  -z			pack archive by gzip
#  -j			pack archive by bzip2
#  -v			verbose output
#  --ignore-failed-read	continue after read error
#  -C <dir>		change to dir befor archiving
#  -S			store sparse files efficiently (for e2images)
#  -M			multi volume archive
#  -L <size>		volume size in kiB
#  -V <str>		volume prefix label

my $tar_command = "(export LC_ALL=C; tar -c --files-from $tmp_dir/files --ignore-failed-read -C $tmp_dir_root/tmp -S";

if ($verbose)
{
    $tar_command .= ' -v';
}


if (defined $multi_volume && $multi_volume >= 0)
{
    my $output_directory;
    my $output_filename;

    my $volume_num = 1;
    
    use File::Spec::Functions "splitpath";
    
    (my $dummy, $output_directory, $output_filename) = File::Spec->splitpath($archive_name);
    
    use Cwd;

    # if directory part is empty set it to current dir
    if ($output_directory eq "")
    {
	$output_directory = cwd();
    }                                                                       
 
    if (substr($output_directory, 0, 1) eq ".")
    {
	my $d = substr($output_directory, 1);

	$output_directory = cwd().$d;
    }
    
    # delete ending '/' if present
    if (substr($output_directory, -1, 1) eq "/")
    {
	chop($output_directory);
    }
    
    my $num_string = sprintf("%02d", $volume_num);
    $tar_command .= " -M -V 'YaST2 backup:' -f $output_directory/${num_string}_$output_filename";

    if ($multi_volume > 0)
    {
	my $num_blocks = 4;	# set block size to 4*512B (default is 20) with value 1 or 2 I get SIGSEGV :-( 
	
	# round size down: subtract block size
	if ($multi_volume > ($num_blocks / 2) && $multi_volume % ($num_blocks / 2) != 0)
	{
	    $multi_volume -= $num_blocks / 2;
	}

	$tar_command .= " -L $multi_volume -b $num_blocks";
    }

    # redirect STDERR to STDOUT
    $tar_command .= " 2>&1)";


    use FileHandle;
    use IPC::Open2;

    # start subprocess
    my $pid = open2(*Reader, *Writer, $tar_command );

    my $buffer = ""; 
    my $char;

    # output from tar contains strings: name of file added to archive or prompt for next volume

    while(read(Reader, $char, 1) != 0)
    {
	if ($char eq "\n")
	{
	    print "$buffer\n";
	    $buffer = "";
	}
	else
	{
	    $buffer .= $char;		# add character to buffer

	    if ($buffer =~ /Prepare volume #(\d+) for `.*' and hit return: /)
	    {
		if ($1 == $volume_num)
		{
		    print Writer "y\n";
		}
		else
		{
		    print "/Volume created: $output_directory/${num_string}_$output_filename\n";

		    $volume_num++;
		    $num_string = sprintf("%02d", $volume_num);

		    print Writer "n $output_directory/${num_string}_$output_filename\n";
		}

		$buffer = "";	# clear buffer for next file name or tar prompt
	    }
	}
    }

    print "/Volume created: $output_directory/${num_string}_$output_filename\n";
}
else
{
    # create standard (no multi volume) archive 
    $tar_command .= " -f $archive_name 2> /dev/null)";

    system($tar_command);
}


if ($verbose)
{
    print "/Tar result: $?\n";
}


