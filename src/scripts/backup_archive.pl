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
	system("/bin/mkdir -p $dirs");		# create directory with parents
    }
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
my $multi_volume = '0';

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
    print "  --multi-volume <size> Create multiple volume archive, size is volume size in bytes\n";
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
	    
	    if ($line =~ /^\/.+/)
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

$tmp_dir .= "/YaST2-backup";
if (!mkdir($tmp_dir))
{
    die "Can not create directory $tmp_dir\n";
}

my $files_num = 0;

open(OUT, '>', $tmp_dir_root."/files")
    or die "Can not open file $tmp_dir_root/files\n";


print OUT "tmp/YaST2-backup/files_info\n";
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
    
    print OUT "tmp/YaST2-backup/hostname\n";
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

my $date = strftime('%x %X', localtime());

open(DATE, '>', $tmp_dir.'/date');
print DATE $date;
close(DATE);


if (-s $tmp_dir.'/date')
{
    if ($verbose)
    {
	print "Success\n";
    }
    
    print OUT "tmp/YaST2-backup/date\n";
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

	if (system("/sbin/sfdisk -d /dev/$disk > $tmp_dir/partition_table_$disk.txt 2> /dev/null") >> 8 == 0)
	{
	    if (system("dd if=/dev/$disk of=$tmp_dir/partition_table_$disk bs=512 count=1 2> /dev/null") >> 8 == 0)
	    {
		print OUT "tmp/YaST2-backup/partition_table_$disk.txt\n";
		print OUT "tmp/YaST2-backup/partition_table_$disk\n";
		$files_num = $files_num + 2;

		$stored = 1;

		if ($verbose)
		{
		    print "Stored partition: $disk\n";
		}
	    }
	    else
	    {
		unlink("$tmp_dir/partition_table_$disk.txt");

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

	print OUT "tmp/YaST2-backup/installed_packages\n";
	$files_num = $files_num + 1;
    }
    else
    {
	print "Packages stored: Failed\n";
    }
}

			    


# filter files_info file, output only file names

open(FILES_INFO, "> $tmp_dir/files_info")
    or die "Can not create file $tmp_dir/files_info\n";

if (defined open(FILES, $files_info))
{
    while (my $line = <FILES>)
    {
	chomp($line);
	
	if ($line =~ /^\/.+/)
	{
	    if (-r $line)		# output only readable files from files-info
	    {
		print OUT $line."\n";
		$files_num++;
		print FILES_INFO $line."\n";
	    }
	    else
	    {
		if ($verbose)
		{
		    print "/File not readable: $line\n";
		}
	    }
	}
	else
	{
	    print FILES_INFO $line."\n";
	}
    }
    
    close(FILES);
}

close(FILES_INFO);


if (length($comment_file) > 0)
{
    system("cp $comment_file $tmp_dir/comment");

    if ($? == 0)
    {
	print OUT "tmp/YaST2-backup/comment\n";
	$files_num++;
    }
}


#store ext2 system area

foreach my $part (@ext2_parts)
{
    if ($verbose)
    {
	print 'Storing ext2 area: '.$part."\n";
    }

    # transliterate all '/' characters to '_' in device name
    my $tr_dev_name = $part;
    $tr_dev_name =~ tr/\//_/;

    my $output_name = $tmp_dir."/e2image".$tr_dev_name;

    system("/sbin/e2image $part $output_name 2> /dev/null");

    if (-s $output_name)
    {
	if ($verbose)
	{
	    print "Success\n";
	    print OUT "tmp/YaST2-backup/e2image".$tr_dev_name;
	    $files_num++;
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


close(OUT);


if ($verbose)
{
    print "Files: $files_num\n";
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

my $tar_command = "tar -c --files-from $tmp_dir_root/files --ignore-failed-read -C $tmp_dir_root -S";

if ($verbose)
{
    $tar_command .= ' -v';
}


if ($multi_volume > 0)
{
    # split archive to multi volume
    # fifo is used to avoid storing whole file
    
    my $fifo_out = "$tmp_dir_root/fifo";

    if (system("mkfifo -m 0600 $fifo_out 2> /dev/null") != 0)
    {
	die "Can not create FIFO $fifo_out\n";
    }

    
    $tar_command .= " -f $fifo_out &";

    my $packer_command = "cat $fifo_out";
    if ($archive_type eq 'tgz')
    {
	$packer_command .= ' | gzip -c |';
    }
    else
    {
	if ($archive_type eq 'tbz2')
	{
	    $packer_command .= ' | bzip2 -c |';
	}
	else
	{
	    $packer_command .= ' |';
	}
    }

    # start tar
    system($tar_command);
    
    my $volume = 1;

    # start packing utility
    open(PACKER, $packer_command)
	or die "Can not start program: $packer_command\n";

    my $buffer;
    my $written;
    my $block_size = 32768;
    my $len = 0;

    my $output_directory;
    my $output_filename;

    use File::Spec::Functions "splitpath";
    (my $dummy, $output_directory, $output_filename) = File::Spec->splitpath($archive_name);

    # if directory part is empty set it to current path
    if ($output_directory eq "")
    {
	$output_directory = '.';
    }

    while(!eof(PACKER))
    {
	my $volume_string = sprintf("%02d", $volume);
	
	open(OUTPUT, '>'.$output_directory.'/'.$volume_string.'_'.$output_filename)
	    or die "Can not open target file: ";

	if ($verbose)
	{
	    print '/Volume created: '.$volume_string.'_'.$output_filename."\n";
	}

	$written = 0;
	    
	while ($written + $block_size < $multi_volume && !eof(PACKER))
	{
	    $len = read(PACKER, $buffer, $block_size);

	    if ($len > 0)
	    {
		$written += $len;
		print OUTPUT $buffer;
	    }
	}

	if (!eof(PACKER))
	{
	    $len = read(PACKER, $buffer, $multi_volume - $written);

	    if ($len > 0)
	    {
		print OUTPUT $buffer;
	    }
	}

	close(OUTPUT);

	$volume++;
    }

    close(PACKER);

    unlink($fifo_out);
}
else
{
    $tar_command .= " -f $archive_name";

    if ($archive_type eq 'tgz')
    {
	$tar_command .= ' -z';
    }
    else
    {
	if ($archive_type eq 'tbz2')
	{
	    $tar_command .= ' -j';
	}
    }
    
    system($tar_command.' 2> /dev/null');
}


if ($verbose)
{
    print "/Tar result: $?\n";
}


