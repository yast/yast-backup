#!/usr/bin/perl
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
#TODO use strict;

#use File::Temp qw/ tempfile tempdir /;  # not in perl 5.6.0
 
use POSIX qw(tmpnam strftime);


sub harddisks()
{
    my @disks = ();

    open(PTS, "/proc/partitions")
        or die "Can not open /proc/partitions file!\n";

    while (my $line = <PTS>)
    {
	chomp($line);

	if ($line =~ /^\s+\d+\s+\d+\s+\d+ ([ehsx])d(.)$/)
	{
	    push(@disks, "$1d$2");
	}
    }

    close(PTS);

    return @disks;
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

# parse command line options
GetOptions('archive-name=s' => \$archive_name, 
    'archive-type=s' => \$archive_type, 'help' => \$help,
    'store-ptable' => \$store_pt, 'store-ext2=s' => \@ext2_parts,
    'verbose' => \$verbose, 'files-info=s' => \$files_info,
    'comment-file=s'=> \$comment_file
);


if ($help or $files_info eq '' or $archive_name eq '')
{
    print "Usage: $0 [options]\n\n";
    
    print "This script creates backup archive as specified in input file and in command line options.\n";
    print "Options --archive-name and --files-info are mandatory.\n\n";
    
    print "Options:\n\n";
    
    print "  --help                Display this help\n\n";
    print "  --archive-name <file> Target archive file name\n";
    print "  --archive-type <type> Type of compression used by tar, type can be 'tgz' - compressed by gzip, 'tbz2' - compressed by bzip2 or 'tar' - no compression, default is 'tgz'\n";
    print "  --verbose             Print progress information\n";
    print "  --store-ptable        Add partition table information to archive\n";
    print "  --store-ext2 <device> Store Ext2 system area from device\n";
    print "  --files-info          Data file from backup_search script\n";
    print "  --comment-file <file> Use comment stored in file\n\n";
        
    exit 0;
}


$| = 1;

# archive type option
if ($archive_type ne 'tgz' && $archive_type ne 'tbz2' && $archive_type ne 'tar')
{
    $archive_type = 'tgz';
}

# for security reasons set permissions only to owner
umask(0077);

my $tmp_dir_root = tmpnam();

do 
{
    while (-e $tmp_dir_root)
    {
	$tmp_dir_root = tmpnam();
    }
}
until mkdir($tmp_dir_root, 0700);


my $tmp_dir = $tmp_dir_root."/tmp";
mkdir($tmp_dir);

$tmp_dir .= "/YaST2-backup";
mkdir($tmp_dir);


my $files_num = 0;

open(OUT, '>', $tmp_dir_root."/files")
    or die "Can not open file $tmp_dir_root/files\n";


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

    @disks = harddisks();

    foreach my $disk (@disks)
    {
	my $stored = 0;
	
	if (system("/sbin/fdisk -l /dev/$disk > $tmp_dir/partition_table_$disk.txt 2> /dev/null") >> 8 == 0)
	{
	    if (system("dd if=/dev/$disk of=$tmp_dir/partition_table_$disk bs=512 count=1") >> 8 == 0)
	    {
		print OUT "tmp/YaST2-backup/partition_table_$disk.txt\n";
		print OUT "tmp/YaST2-backup/partition_table_$disk\n";
		$files_num = $files_num + 2;

		$stored = 1;

		print "Stored partition: $disk\n";
	    }
	    else
	    {
		unlink("$tmp_dir/partition_table_$disk.txt");
	    }
	}

	push(@disks_results, $stored);
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
	
	if ($line =~ /\/.+/)
	{
	    if (-r $line)		# output only readable files from files-info
	    {
		print OUT $line."\n";
		$files_num++;
		print FILES_INFO $line."\n";
	    }
	    else
	    {
		print STDERR "File $line is not readable.\n"
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


# TODO files info should be first file for faster unpacking (???)
# ... seems NO, tar does not exit when selected file is unpacked
# note: tar writes file name after starting unpacking of this file

print OUT "tmp/YaST2-backup/files_info\n";
$files_num++;


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

    system("/sbin/e2image $part $output_name");

    if (-s $output_name)
    {
	if ($verbose)
	{
	    print "Success\n";
	    print OUT "/tmp/YaST2-backup/e2image_".$tr_dev_name;
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

my $tar_command = "tar -c -f $archive_name --files-from $tmp_dir_root/files --ignore-failed-read -C $tmp_dir_root -S";

if ($verbose)
{
    $tar_command .= ' -v';
}

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

if ($verbose)
{
    print "/Tar result: $?\n";
}


# delete contents of temporary directory
# TODO: better cleanup - unlink only created files, no blind unlink of possibly created files...

unlink($tmp_dir.'/hostname');
unlink($tmp_dir.'/date');
unlink($tmp_dir.'/comment');
unlink($tmp_dir.'/partition_table');
unlink($tmp_dir.'/files_info');
unlink($tmp_dir_root.'/files');


foreach my $part (@ext2_parts)
{
    # transliterate all '/' characters to '_' in device name
    my $tr_dev_name = $part;
    $tr_dev_name =~ tr/\//_/;

    unlink($tmp_dir.'/e2image'.$tr_dev_name);
}

my $index = 0;

foreach my $pt_result (@disks_results)
{
    if ($pt_result)
    {
	unlink($tmp_dir.'/partition_table_'.$disks[$index].'.txt');
	unlink($tmp_dir.'/partition_table_'.$disks[$index]);
    }
    
    $index++;
}

rmdir($tmp_dir);
rmdir($tmp_dir_root.'/tmp');
rmdir($tmp_dir_root);


