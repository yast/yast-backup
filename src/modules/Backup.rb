# encoding: utf-8

#  File:
#    Backup.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  Internal
#
#  $Id$
#
#  Main file for backup module
#
require "yast"

module Yast
  class BackupClass < Module
    def main
      Yast.import "UI"

      textdomain "backup"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Nfs"
      Yast.import "Popup"
      Yast.import "FileUtils"
      Yast.import "String"
      Yast.import "Service"
      Yast.import "Directory"

      Yast.include self, "backup/functions.rb"

      # include "hwinfo/classnames.ycp";
      # do not include (requires installed yast2-tune)
      # just use that part of the ClassNames from classnames.ycp
      @ClassNames = {
        262 => {
          # TRANSLATORS: name of device (the same as in yast2-tune) - the first device
          "name" => _(
            "Mass storage device"
          ),
          0      => _("Disk"),
          1      => _("Tape"),
          2      => _("CD-ROM"),
          3      => _("Floppy disk"),
          # TRANSLATORS: name of device (the same as in yast2-tune) - the last device
          128    => _(
            "Storage device"
          )
        }
      }

      # maximum cron file index
      @max_cron_index = 0

      @script_store_ext2_area = "/sbin/e2image"
      @script_get_partition_table = "/sbin/fdisk -l"
      @script_get_files = "/usr/lib/YaST2/bin/backup_search.pl"
      @script_create_archive = "/usr/lib/YaST2/bin/backup_archive.pl"

      # day names, key is integer used in crontab
      @daynames = {
        1 => _("Monday"),
        2 => _("Tuesday"),
        3 => _("Wednesday"),
        4 => _("Thursday"),
        5 => _("Friday"),
        6 => _("Saturday"),
        7 => _("Sunday")
      }

      @ordinal_numbers = {
        1  => _("1st"),
        2  => _("2nd"),
        3  => _("3rd"),
        4  => _("4th"),
        5  => _("5th"),
        6  => _("6th"),
        7  => _("7th"),
        8  => _("8th"),
        9  => _("9th"),
        10 => _("10th"),
        11 => _("11th"),
        12 => _("12th"),
        13 => _("13th"),
        14 => _("14th"),
        15 => _("15th"),
        16 => _("16th"),
        17 => _("17th"),
        18 => _("18th"),
        19 => _("19th"),
        20 => _("20th"),
        21 => _("21st"),
        22 => _("22nd"),
        23 => _("23rd"),
        24 => _("24th"),
        25 => _("25th"),
        26 => _("26th"),
        27 => _("27th"),
        28 => _("28th"),
        29 => _("29th"),
        30 => _("30th"),
        31 => _("31st")
      }

      # global settings

      @backup_profiles = {} # map of all available profiles

      # global defaults
      @default_archive_name = "" # archive file name
      @default_description = "" # user comment
      @default_archive_type = :tgz # archive type

      @default_multi_volume = false
      @default_volume_size = :fd144
      @default_user_volume_size = ""
      @default_user_volume_unit = nil

      @default_search = true # search files which do not belong to any package
      @default_all_rpms_content = false # by default only changed RPM-files are backed up
      @default_system = false # backup system areas
      @default_display = false # display files before creating archive
      @default_do_md5_test = true
      @default_perms = true # store RPM file if owner/permissions were changed

      @default_default_dir = [
        "/media",
        "/tmp",
        "/var/lock",
        "/var/run",
        "/var/tmp",
        "/var/cache",
        "/sys",
        "/windows",
        "/mnt",
        "/var/lib/ntp/proc"
      ] # default excluded directoried from search
      @default_dir_list = deep_copy(@default_default_dir) # selected directoried to exclude
      @default_include_dir = "/"
      @default_regexp_list = []

      # iso9660 is used on CDROM, ntfs read-only
      @default_fs_exclude = ["iso9660", "ntfs", "none"] # selected filesystems to exclude from search
      @default_detected_fs = nil # detected filesystems

      @default_detected_ext2 = nil # detected mounted ext2 filesystems
      @default_ext2_backup = [] # selected ext2 filesystems to backup

      @default_backup_pt = true # backup partition table

      @default_backup_all_ext2 = false # backup all mounted ext2 partitions
      @default_backup_none_ext2 = true # backup none ext2 partitions
      @default_backup_selected_ext2 = false # backup selected ext2 partitions

      @default_tmp_dir = "/tmp"

      #global list default_all_entered_dirs = [];

      @default_backup_files = {} # all found files to backup
      @default_selected_files = nil # selected files to backup
      @default_unselected_files = [] # files, which user explicitly unselected
      #global list default_selected_directories = [];	// default directories to backup

      #global boolean default_LVMsnapshot = true;
      #global boolean default_testonly = false;
      @default_autoprofile = true
      #global boolean default_systembackup = true;
      @default_target_type = :file
      #global string default_target_device = nil;
      #global map default_target_devices_options = $[];
      @default_temporary_dir = "/var/lib/YaST2/backup/tmp"

      @default_nfsserver = ""
      @default_nfsexport = ""

      @default_mail_summary = true

      # global variables initialized to default values:
      @archive_name = @default_archive_name # archive file name
      @description = @default_description # user comment
      @archive_type = @default_archive_type # archive type

      @profile_is_new_one = false # newly created archive

      @multi_volume = @default_multi_volume
      @volume_size = @default_volume_size
      @user_volume_size = @default_user_volume_size
      @user_volume_unit = @default_user_volume_unit

      @user_vol_size = 0
      @temporary_dir = @default_temporary_dir
      @mail_summary = @default_mail_summary

      @do_search = @default_search # search files which do not belong to any package
      @backup_all_rpms_content = @default_all_rpms_content # backup content of all packages
      @system = @default_system # backup system areas
      @display = @default_display # display files before creating archive
      @do_md5_test = @default_do_md5_test
      @perms = @default_perms

      @target_type = @default_target_type
      #global string target_device = default_target_device;
      #global map target_devices_options = default_target_devices_options;

      @default_dir = deep_copy(@default_default_dir) # default excluded directoried from search
      @dir_list = deep_copy(@default_dir_list) # selected directoried to exclude
      @include_dirs = [@default_include_dir] # selected included directories

      @regexp_list = deep_copy(@default_regexp_list)

      @fs_exclude = deep_copy(@default_fs_exclude) # selected filesystems to exclude from search
      @detected_fs = deep_copy(@default_detected_fs) # detected filesystems

      @detected_ext2 = deep_copy(@default_detected_ext2) # detected mounted ext2 filesystems
      @ext2_backup = deep_copy(@default_ext2_backup) # selected ext2 filesystems to backup

      @backup_pt = @default_backup_pt # backup partition table

      @backup_all_ext2 = @default_backup_all_ext2 # backup all mounted ext2 partitions
      @backup_none_ext2 = @default_backup_none_ext2 # backup none ext2 partitions
      @backup_selected_ext2 = @default_backup_selected_ext2 # backup selected ext2 partitions

      @tmp_dir = @default_tmp_dir
      # archive target dir used in functions
      @target_dir = ""

      @cron_mode = false
      @cron_profile = ""

      @backup_helper_scripts = []

      #global boolean LVMsnapshot = default_LVMsnapshot;
      #global boolean testonly = default_testonly;
      @autoprofile = @default_autoprofile
      #global boolean systembackup = default_systembackup;

      @nfsserver = @default_nfsserver
      @nfsexport = @default_nfsexport
      @nfsmount = nil # NFS mount point, remember for unmounting

      @backup_files = Builtins.eval(@default_backup_files) # all found files to backup
      @selected_files = Builtins.eval(@default_selected_files) # selected files to backup
      @unselected_files = deep_copy(@default_unselected_files) # files, which user explicitly unselected

      #global list selected_directories = default_selected_directories;
      #global list all_entered_dirs = default_all_entered_dirs;

      @no_interactive = false # whether the user should setup configuration manually
      @selected_profile = nil # name of the selected profile, nil for no selected profile (default settings)

      # default volume size if it wasn't detected
      @undetected_volume_size = 1024 * 1024 * 1024

      @installable_packages = []
      @complete_backup = []

      # list of files to be deleted finishing the backup editation
      @remove_cron_files = []

      # result of removing old archives
      @remove_result = {}

      # cached detected mount points
      @detected_mpoints = nil
      # end of global settings

      @cron_settings = {}

      # media description - capacity is maximum file size which fits
      # to formatted medium using widely used file system (FAT on floppies)

      # just archiving
      @just_creating_archive = false

      @cd_media_descriptions = [
        {
          "label"    => _("CD-R/RW 650 MB (74 min.)"),
          "symbol"   => :cd650,
          "capacity" => 649 * 1024 * 1024
        }, # exact size is 703.1 MB - remaining space is for ISO fs
        {
          "label"    => _("CD-R/RW 700 MB (80 min.)"),
          "symbol"   => :cd700,
          "capacity" => 702 * 1024 * 1024
        }
      ] # exact size is 650.4 MB - remaining space is for ISO fs

      @floppy_media_descriptions = [
        {
          "label"    => _("Floppy 1.44 MB"),
          "symbol"   => :fd144,
          "capacity" => 1423 * 1024
        }, # 1213952B is exact size for FAT fs
        {
          "label"    => _("Floppy 1.2 MB"),
          "symbol"   => :fd12,
          "capacity" => 1185 * 1024
        }
      ] # 1457664B is exact size for FAT fs

      @zip_media_descriptions =
        # $[
        # 	"label" : _("ZIP 250 MB"),
        # 	"symbol" : `zip250,
        # 	"capacity" : ?????
        #     ],
        [
          {
            "label"    => _("ZIP 100 MB"),
            "symbol"   => :zip100,
            "capacity" => 95 * 1024 * 1024
          }
        ] # exact size is 96MiB (64 heads, 32 sectors, 96 cylinders, 512B sector)

      @misc_descriptions =
        # $[
        # 	"label" : _("Default Volume Size"),
        # 	"symbol" : `default_size,
        # 	"capacity" : 1024*1024*1024
        #     ]
        []

      @media_descriptions = Convert.convert(
        Builtins.merge(
          Builtins.merge(
            Builtins.merge(@cd_media_descriptions, @floppy_media_descriptions),
            @zip_media_descriptions
          ),
          @misc_descriptions
        ),
        :from => "list",
        :to   => "list <map <string, any>>"
      )

      @units_description = [
        { "label" => _("bytes"), "capacity" => 1, "symbol" => :B },
        {
          # 10^3 bytes
          "label"    => _("kB"),
          "capacity" => 1000,
          "symbol"   => :kB
        },
        {
          # 2^10 bytes
          "label"    => _("KiB"),
          "capacity" => 1024,
          "symbol"   => :kiB
        },
        {
          # 10^6 bytes
          "label"    => _("MB"),
          "capacity" => 1000000,
          "symbol"   => :MB
        },
        {
          # 2^20 bytes
          "label"    => _("MiB"),
          "capacity" => 1024 * 1024,
          "symbol"   => :MiB
        }
      ]

      # File where configuration is stored
      @configuration_filename = "/var/adm/YaST/backup/profiles"

      @backup_scripts_dir = "/var/adm/YaST/backup/scripts/"

      # When creating backup on NFS share, /etc/mtab is modified after mounting the NFS
      # share to a temporary directory. This causes problems later after restoring
      # the backup because mountpoint was only temporary and doesn't exist anymore.
      #
      # See BNC #675259
      @temporary_mtab_file = Builtins.sformat(
        "%1/temporary_mtab_file",
        Directory.tmpdir
      )
      @mtab_file = "/etc/mtab"
    end

    # Return capacity of required medium
    # @param [Array<Hash{String => Object>}] media Medium descriptions
    # @param [Symbol] m Identification of required medium
    # @return [Fixnum] Size of medium in bytes

    def GetCapacity(media, m)
      media = deep_copy(media)
      result = nil

      Builtins.foreach(media) do |val|
        if Ops.get_symbol(val, "symbol") == m
          result = Ops.get_integer(val, "capacity")
        end
      end if media != nil

      result
    end


    # Return backup_search.pl script parameters according to state of variables
    # @return [String] String with command line parameters

    def get_search_script_parameters
      script_options = " --start-dir / --output-progress" # required parameter for YaST2 frontend

      if @backup_all_rpms_content
        # see bnc #344643
        Builtins.y2milestone("Backup all RPMs content...")
        script_options = Ops.add(script_options, " --all-rpms-content")
      end

      script_options = Ops.add(script_options, " --search") if @do_search

      # Include Dirs
      @include_dirs = Builtins.toset(@include_dirs)
      Builtins.y2milestone("Directories to include: %1", @include_dirs)
      if Builtins.size(@include_dirs) == 0
        @include_dirs = [@default_include_dir]
      end
      Builtins.foreach(@include_dirs) do |d|
        if d != nil
          script_options = Ops.add(
            script_options,
            Builtins.sformat(" --include-dir '%1'", String.Quote(d))
          )
        end
      end

      # Exclude Dirs
      Builtins.y2milestone("Directories to exclude: %1", @dir_list)
      if Ops.greater_than(Builtins.size(@dir_list), 0)
        Builtins.foreach(@dir_list) do |d|
          if d != nil
            script_options = Ops.add(
              script_options,
              Builtins.sformat(" --exclude-dir '%1'", String.Quote(d))
            )
          end
        end
      end

      # Exclude Files
      Builtins.y2milestone("Files to exclude: %1", @regexp_list)
      if Ops.greater_than(Builtins.size(@regexp_list), 0)
        Builtins.foreach(@regexp_list) do |r|
          if r != nil
            script_options = Ops.add(
              script_options,
              Builtins.sformat(" --exclude-files '%1'", String.Quote(r))
            )
          end
        end
      end

      # Exclude FileSystems
      Builtins.y2milestone("Filesystems to exclude: %1", @fs_exclude)
      if Ops.greater_than(Builtins.size(@fs_exclude), 0)
        Builtins.foreach(@fs_exclude) do |i|
          script_options = Ops.add(
            script_options,
            Builtins.sformat(" --exclude-fs '%1'", String.Quote(i))
          )
        end
      end

      # save list of installable packages and pass it to the search script
      if Ops.greater_than(Builtins.size(@installable_packages), 0)
        content = Builtins.mergestring(@installable_packages, "\n")
        listfile = Ops.add(
          Convert.to_string(SCR.Read(path(".target.tmpdir"))),
          "/packagelist"
        )

        SCR.Write(path(".target.string"), listfile, content)

        script_options = Ops.add(
          Ops.add(script_options, " --inst-src-packages "),
          listfile
        )
      end

      script_options = Ops.add(script_options, " --no-md5") if !@do_md5_test

      # if (display files before archiving them)
      if @display
        Builtins.y2milestone("Files files will be displayed before archiving")
        # add widget file option
        script_options = Ops.add(
          Ops.add(
            Ops.add(script_options, " --widget-file "),
            Convert.to_string(SCR.Read(path(".target.tmpdir")))
          ),
          "/items.ycp"
        )

        # add items list option
        script_options = Ops.add(
          Ops.add(
            Ops.add(script_options, " --list-file "),
            Convert.to_string(SCR.Read(path(".target.tmpdir")))
          ),
          "/items-list.ycp"
        )
      else
        Builtins.y2milestone("Displaying files will be skipped")
      end

      # add package verification option
      script_options = Ops.add(script_options, " --pkg-verification")

      Builtins.y2milestone("Search script options: %1", script_options)

      script_options
    end

    # Stores the content of /etc/mtab to a 'safe place'
    def BackupMtab
      # nothing to backup
      if !FileUtils.Exists(@mtab_file)
        Builtins.y2error("There is no mtab file!")
        return false
      end

      Builtins.y2milestone(
        "Creating backup of %1 to %2\n---\n%3\n---",
        @mtab_file,
        @temporary_mtab_file,
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("cat '%1'", String.Quote(@mtab_file))
        )
      )

      # creating backup by `cat` - the original file attributes are kept intact
      if Convert.to_integer(
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "cat '%1' > '%2'",
              String.Quote(@mtab_file),
              String.Quote(@temporary_mtab_file)
            )
          )
        ) != 0
        Builtins.y2error(
          "Cannot backup %1 to %2",
          @mtab_file,
          @temporary_mtab_file
        )
        return false
      end

      true
    end

    # Restores the original content of /etc/mtab
    def RestoreMtab
      # nothing to restore from
      if !FileUtils.Exists(@temporary_mtab_file)
        Builtins.y2error(
          "There is no mtab file (%1) to restore",
          @temporary_mtab_file
        )
        return false
      end

      Builtins.y2milestone(
        "Restoring backup of %1 from %2",
        @mtab_file,
        @temporary_mtab_file
      )

      # restoring by `cat` - the original file attributes are kept intact
      if Convert.to_integer(
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "cat '%1' > '%2'",
              String.Quote(@temporary_mtab_file),
              String.Quote(@mtab_file)
            )
          )
        ) != 0
        Builtins.y2error(
          "Cannot restore content of %1 to %2",
          @temporary_mtab_file,
          @mtab_file
        )
        return false
      end

      Builtins.y2milestone(
        "Current %1 file contains\n---\n%2\n---",
        @mtab_file,
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("cat '%1'", String.Quote(@mtab_file))
        )
      )

      # cleaning up
      if Convert.to_integer(
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("rm -f '%1'", @temporary_mtab_file)
          )
        ) != 0
        Builtins.y2error(
          "Cannot remove temporary mtab file %1",
          @temporary_mtab_file
        )
        return false
      end

      true
    end

    # Pre-backup function - mount NFS share if required
    # @return [Boolean] true on success
    def PrepareBackup
      if @target_type == :nfs && @nfsmount == nil
        # BNC #675259: Backup /etc/mtab before it's changed by mounting a NFS share
        BackupMtab()

        @nfsmount = Nfs.Mount(@nfsserver, @nfsexport, nil, "", "")

        # BNC #675259: Restore backup of /etc/mtab before the backup archive is created
        RestoreMtab()

        return @nfsmount != nil
      end

      true
    end

    # Post-backup function - unmount mounted NFS share
    # @return [Boolean] true on success
    def PostBackup
      if @target_type == :nfs && @nfsmount != nil
        ret = Nfs.Unmount(@nfsmount)
        @nfsmount = nil
        return ret
      end

      true
    end

    # Return backup_search.pl script parameters according to state of variables
    # @param [String] file_list Where is list of files to backup stored
    # @param [String] file_comment Where is comment stored
    # @return [String] String with command line parameters

    def get_archive_script_parameters(file_list, file_comment)
      archive_options = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(" --verbose --files-info '", String.Quote(file_list)),
            "' --comment-file '"
          ),
          String.Quote(file_comment)
        ),
        "'"
      )

      if Ops.greater_than(Builtins.size(@complete_backup), 0)
        # store list of completely backed up files into a file
        complete_string = Builtins.mergestring(@complete_backup, "\n")
        tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))

        SCR.Write(
          path(".target.string"),
          Ops.add(tmpdir, "/complete_backup"),
          complete_string
        )
        archive_options = Ops.add(
          Ops.add(Ops.add(archive_options, " --complete-backup "), tmpdir),
          "/complete_backup"
        )
      else
        Builtins.y2debug("complete_backup is empty")
      end

      Builtins.y2debug(
        "nfsmount: %1, archive_name: %2",
        @nfsmount,
        @archive_name
      )

      archive_options = Ops.add(
        Ops.add(
          Ops.add(archive_options, " --archive-name '"),
          String.Quote(
            @target_type == :file ?
              @archive_name :
              Builtins.sformat("%1/%2", @nfsmount, @archive_name)
          )
        ),
        "'"
      )

      if @system
        # add partition tabel option
        if @backup_pt
          archive_options = Ops.add(archive_options, " --store-ptable")
        end

        tmp_selected_pt = []
        Builtins.foreach(
          @ext2_backup # get device names from `item(`id(XYZ), "XYZ")
        ) do |sel_tmp_pt|
          tmp = Ops.get_string(sel_tmp_pt, 1)
          tmp_selected_pt = Builtins.add(tmp_selected_pt, tmp) if tmp != nil
        end 


        detected_ext2_strings = []

        Builtins.foreach(@detected_ext2) do |info|
          part = Ops.get_string(info, "partition")
          if part != nil
            detected_ext2_strings = Builtins.add(detected_ext2_strings, part)
          end
        end 


        partitions = @backup_all_ext2 ?
          detected_ext2_strings :
          @backup_none_ext2 ? [] : tmp_selected_pt

        Builtins.y2milestone("Backup Ext2 partitions: %1", partitions)

        Builtins.foreach(partitions) do |spt|
          archive_options = Ops.add(
            Ops.add(archive_options, " --store-ext2 "),
            spt
          )
        end
      end


      typemap = {
        :tgz  => "tgz",
        :tbz  => "tbz2",
        :tar  => "tar",
        :stgz => "stgz",
        :stbz => "stbz2",
        :star => "star",
        :txt  => "txt"
      }

      archive_options = Ops.add(
        Ops.add(archive_options, " --archive-type "),
        Ops.get_string(typemap, @archive_type, "tgz")
      )


      if @multi_volume
        if @volume_size == :user_defined
          # compute volume size (in kiB)
          vol_size = Builtins.tointeger(
            Ops.divide(
              Ops.multiply(
                Builtins.tofloat(@user_volume_size),
                Builtins.tofloat(
                  GetCapacity(@units_description, @user_volume_unit)
                )
              ),
              1024.0
            )
          )

          Builtins.y2debug("Volume size is %1 kiB", vol_size)

          if Ops.greater_than(vol_size, 0)
            archive_options = Ops.add(
              Ops.add(archive_options, " --multi-volume "),
              Builtins.sformat("%1", vol_size)
            )
          else
            Builtins.y2warning("Bad volume size: %1", @user_volume_size)
          end
        else
          archive_options = Ops.add(
            Ops.add(archive_options, " --multi-volume "),
            Builtins.tointeger(
              Ops.divide(
                Builtins.tofloat(GetCapacity(@media_descriptions, @volume_size)),
                1024.0
              )
            )
          )
        end
      end

      if Ops.greater_than(Builtins.size(@tmp_dir), 0)
        archive_options = Ops.add(
          Ops.add(archive_options, " --tmp-dir "),
          @tmp_dir
        )
      end

      Builtins.y2milestone("Archive script options: %1", archive_options)

      archive_options
    end


    # Exclude file systems without device

    def ExcludeNodevFS
      filesystems = Convert.convert(
        SCR.Read(path(".proc.filesystems")),
        :from => "any",
        :to   => "map <string, string>"
      )

      return if filesystems == nil

      Builtins.foreach(filesystems) do |k, v|
        @fs_exclude = Builtins.add(@fs_exclude, k) if v == "nodev"
      end 


      @fs_exclude = Builtins.toset(@fs_exclude)

      Builtins.y2milestone("Detected nodev filesystems: %1", @fs_exclude)

      nil
    end

    # Write autoinstallation profile to file autoinst.xml to the same directory as archive
    # @param [Array<String>] volumes list of created archives (it is written to the XML profile as restoration source)
    # @return [Hash] map $[ "result" : boolean (true on success), "profile" : string (profile file name) ]

    def WriteProfile(volumes)
      volumes = deep_copy(volumes)
      archive = Ops.add(
        @target_type == :nfs && @nfsmount != nil ? Ops.add(@nfsmount, "/") : "",
        @archive_name
      )

      pos = Builtins.findlastof(archive, "/")
      dir = ""
      file = archive

      if pos != nil && Ops.greater_than(pos, 0)
        dir = Ops.add(Builtins.substring(archive, 0, pos), "/")
        file = Builtins.substring(archive, Ops.add(pos, 1))
      end

      directory = dir

      Builtins.y2debug("dir: %1, file: %2", dir, file)

      prefix = "file://"

      # change prefix according to volume size or archive destination
      # check if file is written to NFS file system
      fs = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map>"
      )

      fs = Builtins.filter(fs) do |info|
        Ops.get_string(info, "vfstype", "") == "nfs"
      end

      Builtins.foreach(fs) do |info|
        mountpoint = Ops.get_string(info, "file", "")
        spec = Ops.get_string(info, "spec", "")
        server = Builtins.substring(spec, 0, Builtins.findfirstof(spec, ":"))
        remdir = Builtins.substring(
          spec,
          Ops.add(Builtins.findfirstof(spec, ":"), 1)
        )
        if mountpoint != "" && spec != ""
          if Builtins.substring(archive, 0, Builtins.size(mountpoint)) == mountpoint
            Builtins.y2milestone(
              "NFS server: %1, directory: %2",
              server,
              remdir
            )

            prefix = "nfs://"
            dir = Ops.add(Ops.add(Ops.add(server, ":"), remdir), "/")
          end
        end
      end 


      # set prefix according to volume size
      if prefix == "" && @multi_volume == true
        if @volume_size == :fd144 || @volume_size == :fd12
          prefix = "fd://"
          dir = "/"
        elsif @volume_size == :cd700 || @volume_size == :cd650
          prefix = "cd://"
          dir = "/"
        end
      end

      Builtins.y2debug("backup write profile: prefix=%1, dir=%2", prefix, dir)

      volumestrings = []

      if Ops.greater_than(Builtins.size(volumes), 0)
        Builtins.foreach(volumes) do |volfile|
          f = volfile
          pos2 = Builtins.findlastof(volfile, "/")
          if pos2 != nil && Ops.greater_than(pos2, 0)
            f = Builtins.substring(volfile, Ops.add(pos2, 1))
          end
          volumestrings = Builtins.add(
            volumestrings,
            Ops.add(Ops.add(prefix, dir), f)
          )
        end
      else
        volumestrings = [Ops.add(Ops.add(prefix, dir), file)]
      end

      restore = { "archives" => volumestrings }

      # add default selection - select all packages to restore
      packages_sel = {}

      Builtins.foreach(@selected_files) do |pkg, info|
        # get package base name
        if pkg != ""
          pkg = Builtins.regexpsub(pkg, "(.*)-.*-.*", "\\1")
        else
          pkg = "_NoPackage_"
        end
        Ops.set(packages_sel, pkg, { "sel_type" => "X" })
      end 


      directory = "/" if directory == ""

      # store profile to this file
      profilefile = Ops.add(
        Ops.add(directory, GetBaseName(@archive_name)),
        ".xml"
      )
      # (tapes)
      removable_device = false
      if Builtins.regexpmatch(archive, "^/dev/")
        # save xml to a temporary file
        removable_device = true
        profilefile = Ops.add(
          Convert.to_string(SCR.Read(path(".target.tmpdir"))),
          "/backup-profile.xml"
        )
      end

      Builtins.y2debug("Profile location: %1", profilefile)

      # create and save autoinstallation profile
      res = CloneSystem(profilefile, ["lan"], "restore", restore)
      Builtins.y2milestone("Clone result: %1", res)

      # tar that temporary file to a device
      if removable_device
        command = Builtins.sformat(
          "cd '%1'; /bin/tar -cf '%2' 'backup-profile.xml'",
          String.Quote(Convert.to_string(SCR.Read(path(".target.tmpdir")))),
          String.Quote(@archive_name)
        )
        run = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
        Builtins.y2milestone("Running command %1 -> %2", command, run)
        res = false if Ops.get_integer(run, "exit", -1) != 0
        profilefile = @archive_name
      end

      if @target_type == :nfs
        pos = Builtins.findlastof(@archive_name, "/")
        nm = pos != nil && Ops.greater_than(pos, 0) ?
          Builtins.substring(@archive_name, 0, pos) :
          ""

        Builtins.y2debug("pos: %1, nm: %2", pos, nm)

        # update XML location if it was stored on NFS
        profilefile = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(Ops.add(Ops.add(@nfsserver, ":"), @nfsexport), "/"),
                nm
              ),
              Ops.greater_than(Builtins.size(nm), 0) ? "/" : ""
            ),
            GetBaseName(@archive_name)
          ),
          ".xml"
        )
        Builtins.y2debug("Updated profile location: %1", profilefile)
      end

      { "result" => res, "profile" => profilefile }
    end


    # Parse cron file
    # @param [String] filename File to parse
    # @return [Hash] parsed values: $["auto":boolean, "day":integer, "hour":integer,
    #         "minute":integer, "weekday":integer, "every":symbol] or empty map if
    #         parse error occured

    def ReadCronSetting(filename)
      ret = {}

      return deep_copy(ret) if filename == nil || filename == ""

      filecontent = Convert.to_string(
        SCR.Read(path(".target.string"), filename)
      )
      lines = Builtins.splitstring(filecontent, "\n")

      # filter out comments
      lines = Builtins.filter(lines) { |l| !Builtins.regexpmatch(l, "^[ \t]*#") }

      line = Ops.get(lines, 0, "")

      return deep_copy(ret) if line == nil || line == ""

      regex = "^([^ \t]*)[ \t]*([^ \t]*)[ \t]([^ \t]*)[ \t]([^ \t]*)[ \t]([^ \t]*)[ \t]*[^ \t]*[ \t]*/usr/lib/YaST2/bin/backup_cron[ \t]*\"*[ \t]*profile[ \t]*=[ \t]*([^\"]*)\"*"
      every = :none
      cronsettings = {}
      profilename = ""

      # is cron setting supported (ranges, lists and steps are NOT supported)
      unknown_settings = false
      bad_settings = false

      if Builtins.regexpmatch(line, regex)
        minute_str = Builtins.regexpsub(line, regex, "\\1")
        hour_str = Builtins.regexpsub(line, regex, "\\2")

        Builtins.y2milestone(
          "minute_str: %1, hour_str: %2",
          minute_str,
          hour_str
        )

        if !Builtins.regexpmatch(minute_str, "^[0-9]*$") ||
            !Builtins.regexpmatch(hour_str, "^[0-9]*$")
          unknown_settings = true
        end

        Builtins.y2milestone("unknown_settings: %1", unknown_settings)
        minute = Builtins.tointeger(minute_str)
        hour = Builtins.tointeger(hour_str)

        if Ops.greater_than(hour, 23) || Ops.less_than(hour, 0) ||
            Ops.greater_than(minute, 59) ||
            Ops.less_than(minute, 0)
          bad_settings = true
        end

        day = Builtins.regexpsub(line, regex, "\\3")
        month = Builtins.regexpsub(line, regex, "\\4")
        weekday = Builtins.regexpsub(line, regex, "\\5")

        Builtins.y2milestone("line: %1", line)
        Builtins.y2milestone("day: %1", day)

        intday = 1
        intweekday = 0

        profilename = Builtins.regexpsub(line, regex, "\\6")
        Builtins.y2milestone("profilename: %1", profilename)

        if month != "*"
          # error
          unknown_settings = true
        end

        if day == "*" && weekday == "*"
          # start every day
          every = :day
        elsif day == "*"
          every = :week

          unknown_settings = true if !Builtins.regexpmatch(weekday, "^[0-9]*$")

          intweekday = Builtins.tointeger(weekday)

          if Ops.greater_than(intweekday, 7) || Ops.less_than(intweekday, 0)
            bad_settings = true
          end
        elsif weekday == "*"
          every = :month

          unknown_settings = true if !Builtins.regexpmatch(day, "^[0-9]*$")

          intday = Builtins.tointeger(day)

          if Ops.greater_than(intday, 31) || Ops.less_than(intday, 1)
            bad_settings = true
          end
        else
          unknown_settings = true
        end

        cronsettings = {
          "auto"    => true,
          "day"     => intday,
          "hour"    => hour,
          "minute"  => minute,
          "weekday" => intweekday,
          "every"   => every
        }
        Builtins.y2milestone("cronsettings: %1", cronsettings)
      else
        unknown_settings = true
      end

      if unknown_settings == true
        # %1 is profile name, %2 is filename
        Report.Warning(
          Builtins.sformat(
            _(
              "cron settings for profile %1\n" +
                "in file %2\n" +
                "are not fully supported.\n"
            ),
            profilename,
            filename
          )
        )
      end

      if bad_settings == true
        #%1 is profile name, %2 is file name
        Report.Error(
          Builtins.sformat(
            _(
              "Some time values for profile %1\n" +
                "in file %2\n" +
                "are out of range."
            ),
            profilename,
            filename
          )
        )
      end

      every != :none ?
        { "profilename" => profilename, "cronsettings" => cronsettings } :
        {}
    end


    # Parse all /etc/cron.d/yast2-backup-* files and update profiles

    def ReadCronSettings
      crondir = "/etc/cron.d"
      files = Convert.convert(
        SCR.Read(path(".target.dir"), crondir),
        :from => "any",
        :to   => "list <string>"
      )

      # reset cron setings
      Builtins.foreach(@backup_profiles) do |name, opts|
        tmp = Builtins.eval(opts)
        cr = Builtins.eval(Ops.get_map(opts, :cron_settings, {}))
        Ops.set(cr, "cronfile", "")
        Ops.set(cr, "cron_changed", false)
        Ops.set(tmp, :cron_settings, Builtins.eval(cr))
        Ops.set(@backup_profiles, name, Builtins.eval(tmp))
      end 


      if files != nil && Ops.greater_than(Builtins.size(files), 0)
        # parse all /etc/cron.d/yast2-backup-* files
        Builtins.foreach(files) do |file|
          if Builtins.regexpmatch(file, "^yast2-backup-[0-9]*$") == true
            cron_index = Builtins.tointeger(
              Builtins.regexpsub(file, "yast2-backup-([0-9]*)", "\\1")
            )

            Builtins.y2milestone("cron_index: %1", cron_index)
            if Ops.greater_than(cron_index, @max_cron_index)
              @max_cron_index = cron_index
            end

            # parse cron file
            cron = ReadCronSetting(Ops.add(Ops.add(crondir, "/"), file))
            Builtins.y2milestone("parsed cron config: %1", cron)

            if cron != {} && cron != nil
              profilename = Ops.get_string(cron, "profilename", "")
              cronsettings = Builtins.eval(
                Ops.get_map(cron, "cronsettings", {})
              )

              # update profile
              if profilename != "" && cronsettings != {}
                profile = Builtins.eval(
                  Ops.get(@backup_profiles, profilename, {})
                )

                Ops.set(
                  cronsettings,
                  "cronfile",
                  Ops.add(Ops.add(crondir, "/"), file)
                )

                # merge maps - include old backup settings from read profile
                cronsettings = Builtins.union(
                  Builtins.eval(Ops.get_map(profile, :cron_settings, {})),
                  cronsettings
                )

                Ops.set(profile, :cron_settings, Builtins.eval(cronsettings))
                Ops.set(@backup_profiles, profilename, Builtins.eval(profile))
              end
            end
          end
        end
      end

      Builtins.y2milestone("max_cron_index: %1", @max_cron_index)

      nil
    end


    # Read backup profiles from file, do not set any global settings, just
    # @see backup_profiles. The profiles are stored in hardcoded place (configuration_filename variable).
    # @return [Boolean] true if there are some profiles available

    def ReadBackupProfiles
      if FileUtils.Exists(@configuration_filename)
        Builtins.y2milestone(
          "Reading configuration from %1",
          @configuration_filename
        )
        @backup_profiles = Convert.convert(
          SCR.Read(path(".target.ycp"), @configuration_filename),
          :from => "any",
          :to   => "map <string, map>"
        )
      else
        Builtins.y2milestone(
          "Configuration file %1 doesn't exist yet",
          @configuration_filename
        )
        @backup_profiles = nil
      end

      # if the list is empty or the file does not exists, set empty map
      @backup_profiles = {} if @backup_profiles == nil

      Builtins.foreach(@backup_profiles) do |profname, opts|
        Builtins.y2debug("Read profile %1: %2", profname, opts)
        if Ops.get_boolean(opts, [:cron_settings, "auto"], false) == true
          Builtins.y2debug("Deactivating profile %1", profname)
          Ops.set(opts, [:cron_settings, "auto"], false)
          Ops.set(@backup_profiles, profname, Builtins.eval(opts))
        end
      end 


      # add cron settings
      ReadCronSettings()

      @backup_profiles != {}
    end

    # Create cron file content for selected profile.
    # @param [String] profilename Name of the profile
    # @return [String] Cron content or empty string if profile has
    #         disabled automatic start

    def CreateCronSetting(profilename)
      input = Ops.get_map(@backup_profiles, [profilename, :cron_settings], {})
      ret = ""

      # return empty string if cron setting was not changed
      if input == nil || input == {} ||
          Ops.get_boolean(input, "cron_changed", false) == false
        return ret
      end

      if Ops.get_boolean(input, "auto", false) == true
        hour = Ops.get_integer(input, "hour", 0)
        minute = Ops.get_integer(input, "minute", 0)
        day = Ops.get_integer(input, "day", 1)
        weekday = Ops.get_integer(input, "weekday", 0)
        every = Ops.get_symbol(input, "every", :unknown)

        if every == :day
          ret = Builtins.sformat(
            "%1 %2 * * *  root  /usr/lib/YaST2/bin/backup_cron \"profile=%3\"\n",
            minute,
            hour,
            profilename
          )
        elsif every == :week
          ret = Builtins.sformat(
            "%1 %2 * * %3  root  /usr/lib/YaST2/bin/backup_cron \"profile=%4\"\n",
            minute,
            hour,
            weekday,
            profilename
          )
        elsif every == :month
          ret = Builtins.sformat(
            "%1 %2 %3 * *  root  /usr/lib/YaST2/bin/backup_cron \"profile=%4\"\n",
            minute,
            hour,
            day,
            profilename
          )
        end

        # add comment to the first line
        ret = Ops.add(
          "# Please do not edit this file manually, use YaST2 backup module instead\n",
          ret
        )
      end

      ret
    end


    # Write cron settings from profiles to /etc/cron.d/yast2-backup-* files

    def WriteCronSettings
      Builtins.y2milestone("backup_profiles: %1", @backup_profiles)

      cron_settings_changed = false
      cron_is_needed = false

      # write cron files
      Builtins.foreach(@backup_profiles) do |name, opts|
        # cron file content
        setting = CreateCronSetting(name)
        cron_file = Ops.get_string(opts, [:cron_settings, "cronfile"], "")
        Builtins.y2milestone("name: %1", name)
        Builtins.y2milestone("setting: %1", setting)
        Builtins.y2milestone(
          "cron_settings: %1",
          Ops.get_map(opts, :cron_settings, {})
        )
        if setting != "" && setting != nil
          # is already cron file existing?
          if Builtins.size(cron_file) == 0
            # no, create new file
            @max_cron_index = Ops.add(@max_cron_index, 1)
            cron_file = Builtins.sformat(
              "/etc/cron.d/yast2-backup-%1",
              @max_cron_index
            )

            # remember new cron file name
            Ops.set(
              @backup_profiles,
              [name, :cron_settings, "cronfile"],
              cron_file
            )
          end

          SCR.Write(path(".target.string"), cron_file, setting)
          Builtins.y2milestone("Created file: %1", cron_file)

          cron_settings_changed = true
          cron_is_needed = true
        elsif Ops.greater_than(Builtins.size(cron_file), 0) &&
            Ops.get_boolean(opts, [:cron_settings, "auto"], false) == false
          # remove existing cron file
          SCR.Execute(path(".target.bash"), Ops.add("/bin/rm -f ", cron_file))
          Builtins.y2milestone("removed old cron file: %1", cron_file)

          cron_settings_changed = true
        end
        # mark saved value as unchanged
        prof = Builtins.eval(Ops.get(@backup_profiles, name, {}))
        cron_s = Builtins.eval(Ops.get_map(prof, :cron_settings, {}))
        Ops.set(cron_s, "cron_changed", false)
        Ops.set(prof, :cron_settings, Builtins.eval(cron_s))
        Ops.set(@backup_profiles, name, Builtins.eval(prof))
      end 


      # Cron needs to be restarted for changes to take effect
      # bugzilla #285442
      if cron_settings_changed
        # running
        if Service.Status("cron") == 0
          # restart it only
          Service.Restart("cron") 

          # not running but needed
        elsif cron_is_needed
          # not enabled, enable it
          Service.Enable("cron") if !Service.Enabled("cron")
          # and start it
          Service.Start("cron")
        end
      end

      nil
    end


    # Write the backup profiles to a file - hardcoded configuration_filename.
    # @return [Boolean] true if the write operation was successful.

    def WriteBackupProfiles
      # update cron setting
      WriteCronSettings()

      profiles_file = @configuration_filename
      if !SCR.Write(path(".target.ycp"), profiles_file, @backup_profiles)
        Builtins.y2error("Unable to write profiles into a file")
        # TRANSLATORS: An error popup message
        #		%1 is the file name
        Popup.Error(
          Builtins.sformat(
            _(
              "Could not store profiles to the file %1.\nThe profile changes will be lost."
            ),
            profiles_file
          )
        )
        return false
      end

      Builtins.foreach(@remove_cron_files) do |filename|
        if filename != ""
          Builtins.y2milestone("Removing file: '%1'", filename)
          if !Convert.to_boolean(SCR.Execute(path(".target.remove"), filename))
            Builtins.y2warning("Cannot remove cron file '%1'", filename)
          end
        end
      end

      true
    end


    # Take the current profile information and store it into a given profile.
    # If the profile already exists, it will be overwritten.
    # @param [String] profile_name name of a profile to be stored into

    def StoreSettingsToBackupProfile(profile_name)
      new_profile = {
        :archive_name          => @archive_name,
        :description           => @description,
        :archive_type          => @archive_type,
        :multi_volume          => @multi_volume,
        :volume_size           => @volume_size,
        :user_volume_size      => @user_volume_size,
        :user_volume_unit      => @user_volume_unit,
        :search                => @do_search,
        :all_rpms_content      => @backup_all_rpms_content,
        :system                => @system,
        :display               => @display,
        :do_md5_test           => @do_md5_test,
        :default_dir           => @default_dir,
        :dir_list              => @dir_list,
        :fs_exclude            => @fs_exclude,
        :regexp_list           => @regexp_list,
        :include_dirs          => @include_dirs,
        :detected_fs           => @detected_fs,
        :detected_ext2         => @detected_ext2,
        :ext2_backup           => @ext2_backup,
        :backup_pt             => @backup_pt,
        :backup_all_ext2       => @backup_all_ext2,
        :backup_none_ext2      => @backup_none_ext2,
        :backup_selected_ext2  => @backup_selected_ext2,
        :unselected_files      => @unselected_files,
        #	`all_entered_dirs	: all_entered_dirs,
        #	`selected_directories	: selected_directories,
        #	`LVMsnapshot		: LVMsnapshot,
        #	`testonly		: testonly,
        :autoprofile           => @autoprofile,
        #	`systembackup		: systembackup,
        :perms                 => @perms,
        :nfsserver             => @nfsserver,
        :nfsexport             => @nfsexport,
        :mail_summary          => @mail_summary,
        :tmp_dir               => @tmp_dir,
        :target_type           => @target_type,
        #	`target_device		: target_device,
        #	`target_devices_options	: target_devices_options,
        :backup_helper_scripts => @backup_helper_scripts,
        :cron_settings         => @cron_settings
      }

      # add the new profile
      Ops.set(@backup_profiles, profile_name, new_profile)

      nil
    end

    # Restore the global settings from a given backup profile.
    # @param [String] profile_name name of a profile to be used
    # @return If the name of the profile cannot be found, return false, otherwise return true.
    def RestoreSettingsFromBackupProfile(profile_name)
      # return false, is there is no such profile
      return false if !Builtins.haskey(@backup_profiles, profile_name)

      # get the profile data
      profile = Ops.get(@backup_profiles, profile_name)

      # editing archive instead of adding new one
      @profile_is_new_one = false

      # setup global settings according to profile
      # TODO: check, if all settings are valid
      @archive_name = Ops.get_string(
        profile,
        :archive_name,
        @default_archive_name
      )
      @description = Ops.get_string(profile, :description, @default_description)
      @archive_type = Ops.get_symbol(
        profile,
        :archive_type,
        @default_archive_type
      )
      @multi_volume = Ops.get_boolean(
        profile,
        :multi_volume,
        @default_multi_volume
      )
      @volume_size = Ops.get_symbol(profile, :volume_size, @default_volume_size)
      @user_volume_size = Ops.get_string(
        profile,
        :user_volume_size,
        @default_user_volume_size
      )
      @user_volume_unit = Ops.get_symbol(
        profile,
        :user_volume_unit,
        @default_user_volume_unit
      )
      @do_search = Ops.get_boolean(profile, :search, @default_search)
      @backup_all_rpms_content = Ops.get_boolean(
        profile,
        :all_rpms_content,
        @default_all_rpms_content
      )
      @system = Ops.get_boolean(profile, :system, @default_system)
      @display = Ops.get_boolean(profile, :display, @default_display)
      @do_md5_test = Ops.get_boolean(
        profile,
        :do_md5_test,
        @default_do_md5_test
      )
      @default_dir = Convert.convert(
        Ops.get(profile, :default_dir, @default_default_dir),
        :from => "any",
        :to   => "list <string>"
      )

      #    dir_list =		profile[ `dir_list ]:		default_dir_list;

      read_dir_list = Convert.convert(
        Ops.get(profile, :dir_list, @default_dir_list),
        :from => "any",
        :to   => "list <string>"
      )

      # convert list of items to list of strings
      if Ops.is(read_dir_list, "list <string>")
        @dir_list = Convert.convert(
          read_dir_list,
          :from => "any",
          :to   => "list <string>"
        )
      elsif Ops.is(read_dir_list, "list <term>")
        # convert dir list from the old format
        new_dir_list = []

        Builtins.foreach(
          Convert.convert(read_dir_list, :from => "any", :to => "list <term>")
        ) do |i|
          tmp_id = Ops.get_term(i, 0)
          if tmp_id != nil
            tmp_d = Ops.get_string(tmp_id, 0)

            new_dir_list = Builtins.add(new_dir_list, tmp_d) if tmp_d != nil
          end
        end 


        @dir_list = deep_copy(new_dir_list)
      else
        Builtins.y2warning(
          "Excluded directories - unsupported data type, value is %1",
          read_dir_list
        )
      end

      @fs_exclude = Convert.convert(
        Ops.get(profile, :fs_exclude, @default_fs_exclude),
        :from => "any",
        :to   => "list <string>"
      )
      @detected_fs = Convert.convert(
        Ops.get(profile, :detected_fs, @default_detected_fs),
        :from => "any",
        :to   => "list <string>"
      )
      @detected_ext2 = Convert.convert(
        Ops.get(profile, :detected_ext2, @default_detected_ext2),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      @ext2_backup = Convert.convert(
        Ops.get(profile, :ext2_backup, @default_ext2_backup),
        :from => "any",
        :to   => "list <term>"
      )
      @backup_pt = Ops.get_boolean(profile, :backup_pt, @default_backup_pt)
      @backup_all_ext2 = Ops.get_boolean(
        profile,
        :backup_all_ext2,
        @default_backup_all_ext2
      )
      @backup_none_ext2 = Ops.get_boolean(
        profile,
        :backup_none_ext2,
        @default_backup_none_ext2
      )
      @backup_selected_ext2 = Ops.get_boolean(
        profile,
        :backup_selected_ext2,
        @default_backup_selected_ext2
      )
      @unselected_files = Convert.convert(
        Ops.get(profile, :unselected_files, @default_unselected_files),
        :from => "any",
        :to   => "list <string>"
      )
      #    all_entered_dirs =	profile[ `all_entered_dirs ]:	default_all_entered_dirs;
      #    selected_directories = profile[ `selected_directories ]:	default_selected_directories;
      #    LVMsnapshot =	profile[ `LVMsnapshot ]:	default_LVMsnapshot;
      #    testonly =		profile[ `testonly ]:		default_testonly;
      @autoprofile = Ops.get_boolean(
        profile,
        :autoprofile,
        @default_autoprofile
      )
      #    systembackup =	profile[ `systembackup ]:	default_systembackup;
      @perms = Ops.get_boolean(profile, :perms, @default_perms)
      @nfsserver = Ops.get_string(profile, :nfsserver, @default_nfsserver)
      @nfsexport = Ops.get_string(profile, :nfsexport, @default_nfsexport)
      @target_type = Ops.get_symbol(profile, :target_type, @default_target_type)
      #    target_device =	profile[ `target_device ]:	default_target_device;
      #    target_devices_options = profile[ `target_devices_options ]:	default_target_devices_options;
      @mail_summary = Ops.get_boolean(
        profile,
        :mail_summary,
        @default_mail_summary
      )
      @tmp_dir = Ops.get_string(profile, :tmp_dir, @default_tmp_dir)
      @regexp_list = Convert.convert(
        Ops.get(profile, :regexp_list, @default_regexp_list),
        :from => "any",
        :to   => "list <string>"
      )
      @include_dirs = Convert.convert(
        Ops.get(profile, :include_dirs) { [@default_include_dir] },
        :from => "any",
        :to   => "list <string>"
      )

      @selected_files = deep_copy(@default_selected_files)
      @backup_files = deep_copy(@default_backup_files)

      @selected_profile = profile_name

      @backup_helper_scripts = Ops.get_list(profile, :backup_helper_scripts, [])

      @cron_settings = Ops.get_map(profile, :cron_settings, {})

      true
    end

    # Restore the default global settings.
    def RestoreDefaultSettings
      # setup global settings according to defaults
      @archive_name = @default_archive_name
      @description = @default_description
      @archive_type = @default_archive_type
      @multi_volume = @default_multi_volume
      @volume_size = @default_volume_size
      @user_volume_size = @default_user_volume_size
      @user_volume_unit = @default_user_volume_unit
      @do_search = @default_search
      @backup_all_rpms_content = @default_all_rpms_content
      @system = @default_system
      @display = @default_display
      @do_md5_test = @default_do_md5_test
      @default_dir = deep_copy(@default_default_dir)
      @dir_list = deep_copy(@default_dir_list)
      @fs_exclude = deep_copy(@default_fs_exclude)
      @detected_fs = deep_copy(@default_detected_fs)
      @detected_ext2 = deep_copy(@default_detected_ext2)
      @ext2_backup = deep_copy(@default_ext2_backup)
      @backup_pt = @default_backup_pt
      @backup_all_ext2 = @default_backup_all_ext2
      @backup_none_ext2 = @default_backup_none_ext2
      @backup_selected_ext2 = @default_backup_selected_ext2
      @unselected_files = deep_copy(@default_unselected_files)
      #    all_entered_dirs =	eval( default_all_entered_dirs );
      #    selected_directories = eval( default_selected_directories );
      #    LVMsnapshot = default_LVMsnapshot;
      #    testonly = default_testonly;
      @autoprofile = @default_autoprofile
      #    systembackup = default_systembackup;
      @perms = @default_perms
      @nfsserver = @default_nfsserver
      @nfsexport = @default_nfsexport
      @target_type = @default_target_type
      #    target_devices_options = eval(default_target_devices_options);
      @mail_summary = @default_mail_summary
      @tmp_dir = @default_tmp_dir
      @regexp_list = deep_copy(@default_regexp_list)
      @include_dirs = [@default_include_dir]

      @selected_files = Builtins.eval(@default_selected_files)
      @backup_files = Builtins.eval(@default_backup_files)

      @backup_helper_scripts = []

      @selected_profile = nil

      @cron_settings = {}

      nil
    end

    # Get a sorted list of profile names currently available.
    # @return the list of strings (possibly empty).
    def BackupProfileNames
      result = Builtins.maplist(@backup_profiles) { |key, value| key }
      if result == nil
        return []
      else
        return Builtins.sort(result)
      end
    end

    # Create description of automatic backup.
    # @param [String] profilename Name of the profile
    # @return [String] description string or empty string if profile has
    #         disabled automatic start

    def CreateCronDescription(profilename)
      input = Ops.get_map(@backup_profiles, [profilename, :cron_settings], {})
      ret = ""

      return ret if input == nil || input == {}

      if Ops.get_boolean(input, "auto", false) == true
        hour = Ops.get_integer(input, "hour", 0)
        minute = Ops.get_integer(input, "minute", 0)
        day = Ops.get_integer(input, "day", 1)
        weekday = Ops.get_integer(input, "weekday", 0)
        every = Ops.get_symbol(input, "every", :unknown)

        # hour/minutes time format - set according your local used format
        # usually used conversion specificators:
        # %H - hour (0..23), %I - hour (0..12)
        # %M - minute (0..59), %p - `AM' or `PM'
        # (see man date for more details)
        timeformat = _("%I:%M %p")

        bashcommand = Builtins.sformat(
          "/bin/date --date '%1:%2' '+%3'",
          hour,
          minute,
          timeformat
        )
        # convert hour and minutes to localized time string - use date utility
        result = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), bashcommand)
        )
        ltime = Builtins.mergestring(
          Builtins.splitstring(Ops.get_string(result, "stdout", ""), "\n"),
          ""
        )

        if ltime == ""
          # table item - specified time is invalid
          ret = _("Invalid time")
        elsif every == :day
          # table item - start backup every day (%1 is time)
          ret = Builtins.sformat(_("Back up daily at %1"), ltime)
        elsif every == :week
          # table item - start backup every week (%1 is day name, %2 is time)
          ret = Builtins.sformat(
            _("Back up weekly (%1 at %2)"),
            Ops.get(@daynames, weekday, "?"),
            ltime
          )
        elsif every == :month
          # table item - start backup once a month (%1 is day (ordinal number, e.g. 5th), %2 is time)
          ret = Builtins.sformat(
            _("Back up monthly (%1 day at %2)"),
            Ops.get(@ordinal_numbers, day, "?"),
            ltime
          )
        end
      end

      ret
    end

    # Helper function to extract the list of currently available profiles
    # @return [Array] List of item used in the table widget
    def BackupProfileDescriptions
      result = Builtins.maplist(@backup_profiles) do |key, value|
        # description can be multiline - merge lines
        descr = Builtins.mergestring(
          Builtins.splitstring(
            Ops.get_string(value, :description, @default_description),
            "\n"
          ),
          " "
        )
        displayinfo = UI.GetDisplayInfo
        # limit size of description shown in the table
        # maximum length half of width in ncurses UI
        maxsize = Ops.get_boolean(displayinfo, "TextMode", false) ?
          Ops.divide(Ops.get_integer(displayinfo, "Width", 80), 2) :
          40
        if Ops.greater_than(Builtins.size(descr), maxsize)
          # use only the beginning of the description, add dots
          # BNC #446996: substring for localized strings -> lsubstring
          descr = Ops.add(Builtins.lsubstring(descr, 0, maxsize), "...")
        end
        Item(Id(key), key, descr, CreateCronDescription(key))
      end

      if result == nil
        return []
      else
        return deep_copy(result)
      end
    end

    # Remove given profile.
    # @param [String] profile_name name of a profile to be removed
    # @param [Boolean] remove_cronfile defines whether also the cron settings (stored in file) should be removed
    # @return If the name of the profile cannot be found, return false, otherwise return true.
    def RemoveBackupProfile(profile_name, remove_cronfile)
      # return false, is there is no such profile
      return false if !Builtins.haskey(@backup_profiles, profile_name)

      # If there is some cronfile assigned to the profile, remove it too
      if remove_cronfile &&
          Ops.get(@backup_profiles, [profile_name, :cron_settings, "cronfile"]) != nil
        filename = Ops.get_string(
          @backup_profiles,
          [profile_name, :cron_settings, "cronfile"],
          ""
        )

        Builtins.y2milestone(
          "File '%1' has been marked to be removed",
          filename
        )
        @remove_cron_files = Builtins.add(@remove_cron_files, filename)
      end
      @backup_profiles = Builtins.remove(@backup_profiles, profile_name)

      true
    end



    # Try to detect all removable devices present in the system
    # @param [Boolean] only_writable return only writable devices (e.g. exclude CD-ROMs)
    # @return [Hash] Removable devices info

    def RemovableDevices(only_writable)
      ret = {}

      # detect SCSI, IDE and floppy devices
      devs = Convert.convert(
        Builtins.merge(
          Builtins.merge(
            Convert.convert(
              SCR.Read(path(".probe.scsi")),
              :from => "any",
              :to   => "list <map>"
            ),
            Convert.convert(
              SCR.Read(path(".probe.ide")),
              :from => "any",
              :to   => "list <map>"
            )
          ),
          Convert.convert(
            SCR.Read(path(".probe.floppy")),
            :from => "any",
            :to   => "list <map>"
          )
        ),
        :from => "list",
        :to   => "list <map>"
      )

      Builtins.foreach(devs) do |dev|
        if Ops.get(dev, "class_id") == 262 &&
            Ops.get_integer(dev, "sub_class_id", 0) != 0 # Mass storage device, but not a disk
          dev_name = Ops.get_string(dev, "dev_name", "")
          model = Ops.get_string(dev, "model", "")
          bus = Ops.get_string(dev, "bus", "")
          sub_class_id = Ops.get_integer(dev, "sub_class_id", 128) # default is "Storage device"
          type_symbol = :unknown

          # use non-rewinding tape device
          if Ops.greater_than(Builtins.size(dev_name), 0) && sub_class_id == 1 # check if device is tape
            parts = Builtins.splitstring(dev_name, "/")

            # add 'n' to the device name if it is missing
            # e.g. /dev/st0 (rewinding) -> /dev/nst0 (non-rewinding)
            if !Builtins.regexpmatch(
                Ops.get(parts, Ops.subtract(Builtins.size(parts), 1), ""),
                "^n"
              )
              Ops.set(
                parts,
                Ops.subtract(Builtins.size(parts), 1),
                Ops.add(
                  "n",
                  Ops.get(parts, Ops.subtract(Builtins.size(parts), 1), "")
                )
              )

              dev_name = Builtins.mergestring(parts, "/")

              Ops.set(dev, "dev_name", dev_name)
            end

            type_symbol = :tape
          end

          # type of device (cdrom, disk, tape...) was not detected
          type = Ops.get_locale(
            @ClassNames,
            [262, sub_class_id],
            _("Unknown device type")
          )

          # remove read only devices if it was requested
          # remove CD/DVD-ROM devices, other devices are considered as writable,
          # it doesn't check if inserted medium is writable!

          if sub_class_id == 2 && only_writable
            # CD-ROM sub class, only writable devices are requested
            # if CD device is not CD-R/RW or DVD-R/RW/RAM it is read only
            if !(Ops.get_boolean(dev, "cdr", false) ||
                Ops.get_boolean(dev, "cdrw", false) ||
                Ops.get_boolean(dev, "dvdram", false) ||
                Ops.get_boolean(dev, "dvdr", false))
              dev_name = ""
            end

            type_symbol = :cd
          end

          # predefined media sizes for device - initialize to all types
          media = deep_copy(@media_descriptions)
          preselected = nil
          user_size = 0

          if Ops.get_boolean(dev, "dvd", false)
            type = "DVD-ROM"
            type_symbol = :dvd

            dev_name = "" if only_writable
          elsif Ops.get_boolean(dev, "cdr", false) ||
              Ops.get_boolean(dev, "cdrw", false)
            # CD-R or CD-RW writer device
            type = _("CD Writer")
            type_symbol = Ops.get_boolean(dev, "cdr", false) ? :cdr : :cdrw
            media = deep_copy(@cd_media_descriptions)
            preselected = :cd700
          elsif Ops.get_boolean(dev, "dvdr", false)
            # DVD-R, DVD+R... writer device
            type = _("DVD Writer")
            type_symbol = :dvdr
          elsif Ops.get_boolean(dev, "dvdram", false)
            type = "DVD-RAM"
            type_symbol = :dvdram
          elsif Ops.get_boolean(dev, "zip", false) &&
              Ops.get_integer(dev, "sub_class_id", 0) == 3
            type = "ZIP"
            type_symbol = :zip
            media = deep_copy(@zip_media_descriptions)

            # get medium size
            geometry = Ops.get_map(dev, ["resource", "disk_log_geo"], {})
            sz = Ops.multiply(
              Ops.multiply(
                Ops.get_integer(geometry, "cylinders", 0),
                Ops.get_integer(geometry, "heads", 0)
              ),
              Ops.get_integer(geometry, "sectors", 0)
            )
            sect_sz = Ops.get_string(dev, ["size", "unit"], "") == "sectors" ?
              Ops.get_integer(dev, ["size", "y"], 512) :
              0
            raw_size = Ops.multiply(sz, sect_sz)

            # preselect medium size
            if raw_size == 96 * 64 * 32 * 512
              # this is ZIP-100
              preselected = :zip100
            elsif Ops.greater_than(raw_size, 0)
              # unknown medium, use raw size minus 1MB for file system
              preselected = :user
              user_size = Ops.subtract(raw_size, 1024 * 1024)
            end
          # floppy
          elsif Ops.get_integer(dev, "sub_class_id", 0) == 3
            type_symbol = :floppy
            media = deep_copy(@floppy_media_descriptions)
            sizes = Ops.get_list(dev, ["resource", "size"], [])
            sect_sz = 0

            Builtins.foreach(sizes) do |m|
              unit = Ops.get_string(m, "unit", "")
              if unit == "sectors"
                sect_sz = Ops.multiply(
                  Ops.get_integer(m, "x", 0),
                  Ops.get_integer(m, "y", 512)
                )
              end
            end 


            Builtins.y2milestone("sect_sz: %1", sect_sz)

            if Ops.greater_than(sect_sz, 0)
              if sect_sz == 2880 * 512
                # 1.44 floppy
                preselected = :fd144
              end 
              # else if (sect_sz == 1186*512)
              # 			    {
              # 				// 1.2 floppy
              # 				preselected = `fd12;
              # 			    }
            end
          end

          # volume size was'nt detected, use default value
          if preselected == nil
            preselected = :user
            user_size = @undetected_volume_size
          end

          if Ops.greater_than(Builtins.size(dev_name), 0)
            ret = Builtins.add(
              ret,
              dev_name,
              {
                "model"       => model,
                "type"        => type,
                "bus"         => bus,
                "media"       => media,
                "preselected" => preselected,
                "user_size"   => user_size,
                "type_symbol" => type_symbol
              }
            )
          end
        end
      end if Ops.greater_than(
        Builtins.size(devs),
        0
      )

      deep_copy(ret)
    end

    # Read all packages available on the installation sources
    def ReadInstallablePackages
      @installable_packages = GetInstallPackages()
      Builtins.y2debug("installable_packages: %1", @installable_packages)

      nil
    end

    # Returns detected mount points
    # @return [Hash] detected mount points
    def DetectedMountPoints
      # return cached value if available
      @detected_mpoints = DetectMountpoints() if @detected_mpoints == nil

      deep_copy(@detected_mpoints)
    end

    # Returns local archive name (required if NFS target is used)
    # @return [String] local archive name
    def GetLocalArchiveName
      ret = @archive_name

      if @target_type == :nfs && @nfsmount != nil
        ret = Ops.add(Ops.add(@nfsmount, "/"), @archive_name)
      end

      ret
    end

    # Writes file using the .backup.file_append SCR agent. This file
    # is accepted by backup_archive.pl script. Used global variables:
    # selected_files, backup_files.
    #
    # @return [Hash] with keys
    #	"sel_files" (integer - number of selected files),
    #	"sel_packages" (integer: number of selected packages),
    #	"ret_file_list_stored" (boolean: whether the filelist has been completely stored)
    # @see <a href="../backup_specification.html">Backup module specification</a>

    def MapFilesToString
      num_files = 0
      num_pack = 0

      return {} if @selected_files == nil

      UI.OpenDialog(
        Left(
          Label(
            # busy message
            _("Creating the list of files for the backup...")
          )
        )
      )

      Builtins.y2milestone("Storing filenames list...")
      filelist_tmpfile = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/filelist"
      )
      ret_file_list_stored = true
      flist_appended = nil

      Builtins.foreach(@selected_files) do |pkg, info|
        if pkg != ""
          flist_appended = SCR.Write(
            path(".backup.file_append"),
            [
              filelist_tmpfile,
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(Ops.add("Package: ", pkg), "\n"),
                        "Installed: "
                      ),
                      Ops.get_string(info, "install_prefixes", "(none)")
                    ),
                    "\n"
                  ),
                  Builtins.mergestring(
                    Ops.get_list(info, "changed_files", []),
                    "\n"
                  )
                ),
                "\n"
              )
            ]
          )
          if !flist_appended
            ret_file_list_stored = false
            # a popup error, %1 is as file name
            Report.Error(
              Builtins.sformat(
                _("Cannot write the list of selected files to file %1."),
                filelist_tmpfile
              )
            )
            raise Break
          end

          num_files = Ops.add(
            num_files,
            Builtins.size(Ops.get_list(info, "changed_files", []))
          )
          num_pack = Ops.add(num_pack, 1)
        end
      end

      # huge amount of files, write by one (or using a buffer)
      flist_appended = SCR.Write(
        path(".backup.file_append"),
        [filelist_tmpfile, "Nopackage:\n"]
      )
      Builtins.foreach(Ops.get_list(@selected_files, ["", "changed_files"], [])) do |changed_file|
        flist_appended = SCR.Write(
          path(".backup.file_append"),
          [filelist_tmpfile, Ops.add(changed_file, "\n")]
        )
        if !flist_appended
          ret_file_list_stored = false
          # a popup error, %1 is as file name
          Report.Error(
            Builtins.sformat(
              _("Cannot write the list of selected files to file %1."),
              filelist_tmpfile
            )
          )
          raise Break
        end
        num_files = Ops.add(num_files, 1)
      end
      num_pack = Ops.add(num_pack, 1)

      Builtins.y2milestone("Filename stored")

      # free the lizard
      @selected_files = {}

      UI.CloseDialog

      {
        "sel_files"        => num_files,
        "sel_packages"     => num_pack,
        "file_list_stored" => ret_file_list_stored
      }
    end

    # Remove and/or rename old existing single archives
    # @param [String] name Archive name
    # @param [Fixnum] max Maximum count of existing archives
    # @return [Hash] result
    def RemoveOldSingleArchives(name, max)
      removed = []
      renamed = {}

      return {} if name == "" || name == nil

      # check whether archive already exists
      sz = Convert.to_integer(SCR.Read(path(".target.size"), name))

      if Ops.less_than(sz, 0)
        # file doesn't exist, success
        Builtins.y2milestone("Archive doesn't exist")
        return {}
      end

      # check wheter older archives exist
      parts = Builtins.splitstring(name, "/")
      fname = Ops.get(parts, Ops.subtract(Builtins.size(parts), 1), "")
      dir = Builtins.mergestring(
        Builtins.remove(parts, Ops.subtract(Builtins.size(parts), 1)),
        "/"
      )

      return {} if Builtins.size(fname) == 0

      command = Ops.add(
        Ops.add(Ops.add(Ops.add("/bin/ls -1 -t ", dir), "/*-"), fname),
        " 2> /dev/null"
      )
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      files = Builtins.splitstring(Ops.get_string(result, "stdout", ""), "\n")

      mv_dates = []

      # filter files with date - use regexp
      files = Builtins.filter(files) do |file|
        Builtins.regexpmatch(
          file,
          Ops.add(
            Ops.add(Ops.add(Ops.add("^", dir), "/[0-9]{14}-"), fname),
            "$"
          )
        )
      end

      Builtins.y2milestone("Old archives: %1", files)

      if Ops.greater_than(Builtins.size(files), 0) &&
          Ops.greater_or_equal(Builtins.size(files), max) &&
          Ops.greater_or_equal(max, 0)
        # remove the old archives
        while Ops.greater_than(Builtins.size(files), 0) &&
            Ops.greater_or_equal(Builtins.size(files), max)
          oldarchive = Ops.get(
            files,
            Ops.subtract(Builtins.size(files), 1),
            "__DUMMY__"
          )

          # remove old archive
          command = Ops.add("/bin/rm -f ", oldarchive)
          Builtins.y2milestone("Removing old archive: %1", oldarchive)
          result = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )

          removedoldarchive = oldarchive

          # update NFS archive name
          if @target_type == :nfs
            removedoldarchive = Ops.add(
              Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
              Builtins.substring(oldarchive, Builtins.size(@nfsmount))
            )
          end

          removed = Builtins.add(removed, removedoldarchive)

          # remove old XML profile
          oldXML2 = Ops.add(
            Ops.add(Ops.add(dir, "/"), GetBaseName(oldarchive)),
            ".xml"
          )
          command = Ops.add("/bin/rm -f ", oldXML2)
          result = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )

          # update NFS archive name
          if @target_type == :nfs
            oldXML2 = Ops.add(
              Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
              Builtins.substring(oldXML2, Builtins.size(@nfsmount))
            )
          end

          removed = Builtins.add(removed, oldXML2)

          files = Builtins.remove(files, Ops.subtract(Builtins.size(files), 1))
        end
      end

      stat = Convert.to_map(SCR.Read(path(".target.stat"), name))
      ctime = Ops.get_integer(stat, "ctime", 0)
      ctime_str = SecondsToDateString(ctime)

      # rename existing archive
      command = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(Ops.add(Ops.add("/bin/mv -f ", name), " "), dir),
              "/"
            ),
            ctime_str
          ),
          "-"
        ),
        fname
      )
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      old_name = name
      new_name = Ops.add(
        Ops.add(Ops.add(Ops.add(dir, "/"), ctime_str), "-"),
        fname
      )

      # update NFS archive name
      if @target_type == :nfs
        old_name = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(name, Builtins.size(@nfsmount))
        )
        new_name = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(new_name, Builtins.size(@nfsmount))
        )
        Builtins.y2debug(
          "NFS archive, old_name: %1, new_name: %2",
          old_name,
          new_name
        )
      end


      #    renamed[name] = dir + "/" + ctime_str + "-" + fname;
      Ops.set(renamed, old_name, new_name)

      # rename autoinstallation profile
      oldXML = Ops.add(Ops.add(Ops.add(dir, "/"), GetBaseName(name)), ".xml")
      newXML = Ops.add(
        Ops.add(
          Ops.add(Ops.add(Ops.add(dir, "/"), ctime_str), "-"),
          GetBaseName(fname)
        ),
        ".xml"
      )

      command = Ops.add(Ops.add(Ops.add("/bin/mv -f ", oldXML), " "), newXML)
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      # update NFS archive name
      if @target_type == :nfs
        oldXML = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(oldXML, Builtins.size(@nfsmount))
        )
        newXML = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(newXML, Builtins.size(@nfsmount))
        )
        Builtins.y2debug("NFS archive, oldXML: %1, newXML: %2", oldXML, newXML)
      end

      Ops.set(renamed, oldXML, newXML)

      { "removed" => removed, "renamed" => renamed }
    end


    # Remove and/or rename old existing multivolume archives
    # @param [String] name Archive name
    # @param [Fixnum] max Maximum count of existing archives
    # @return [Hash] result
    def RemoveOldMultiArchives(name, max)
      removed = []
      renamed = {}

      return {} if name == "" || name == nil

      # check wheter older archives exist
      parts = Builtins.splitstring(name, "/")
      fname = Ops.get(parts, Ops.subtract(Builtins.size(parts), 1), "")
      dir = Builtins.mergestring(
        Builtins.remove(parts, Ops.subtract(Builtins.size(parts), 1)),
        "/"
      )

      return {} if Builtins.size(fname) == 0

      # check whether first archive already exists
      sz = Convert.to_integer(
        SCR.Read(
          path(".target.size"),
          Ops.add(Ops.add(Ops.add(dir, "/"), "01_"), fname)
        )
      )

      if Ops.less_than(sz, 0)
        # file doesn't exist, success
        Builtins.y2milestone("First multivolume archive doesn't exist")
        return {}
      else
        Builtins.y2milestone("First multivolume archive already exists")
      end

      command = Ops.add(
        Ops.add(Ops.add(Ops.add("/bin/ls -1 -t ", dir), "/*-*_"), fname),
        " 2> /dev/null"
      )
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      files = Builtins.splitstring(Ops.get_string(result, "stdout", ""), "\n")

      mv_dates = []

      # filter files with date - use regexp
      multi = []
      Builtins.foreach(files) do |file|
        if Builtins.regexpmatch(
            file,
            Ops.add(
              Ops.add(
                Ops.add(Ops.add("^", dir), "/[0-9]{14}-[0-9][0-9]+_"),
                fname
              ),
              "$"
            )
          )
          multi = Builtins.add(multi, file)

          date = Builtins.regexpsub(
            file,
            Ops.add(
              Ops.add(
                Ops.add(Ops.add("^", dir), "/([0-9]{14})-[0-9][0-9]+_"),
                fname
              ),
              "$"
            ),
            "\\1"
          )

          if !Builtins.contains(mv_dates, date)
            mv_dates = Builtins.add(mv_dates, date)
          end
        end
      end 

      files = deep_copy(multi)

      Builtins.y2milestone("Old archives: %1", files)
      Builtins.y2milestone("Old archive dates: %1", mv_dates)

      if Ops.greater_or_equal(Builtins.size(mv_dates), max) &&
          Ops.greater_or_equal(max, 0)
        # remove the old archives
        while Ops.greater_or_equal(Builtins.size(mv_dates), max)
          oldarchivedate = Ops.get_string(
            mv_dates,
            Ops.subtract(Builtins.size(mv_dates), 1),
            "__DUMMY__"
          )

          Builtins.y2milestone("removing archives with date %1", oldarchivedate)

          Builtins.foreach(files) do |fn|
            if Builtins.regexpmatch(
                fn,
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(Ops.add(Ops.add("^", dir), "/"), oldarchivedate),
                      "-[0-9]+_"
                    ),
                    fname
                  ),
                  "$"
                )
              )
              # remove old archive
              command = Ops.add("/bin/rm -f ", fn)
              Builtins.y2milestone("Removing old volume: %1", fn)

              # update NFS archive name
              if @target_type == :nfs
                fn = Ops.add(
                  Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
                  Builtins.substring(fn, Builtins.size(@nfsmount))
                )
              end

              removed = Builtins.add(removed, fn)
              SCR.Execute(path(".target.bash_output"), command)
            end
          end 


          # remove old XML profile
          oldXML2 = Ops.add(
            Ops.add(
              Ops.add(Ops.add(Ops.add(dir, "/"), oldarchivedate), "-"),
              GetBaseName(fname)
            ),
            ".xml"
          )
          command = Ops.add("/bin/rm -f ", oldXML2)

          # update NFS archive name
          if @target_type == :nfs
            oldXML2 = Ops.add(
              Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
              Builtins.substring(oldXML2, Builtins.size(@nfsmount))
            )
          end

          removed = Builtins.add(removed, oldXML2)
          result = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )

          mv_dates = Builtins.remove(
            mv_dates,
            Ops.subtract(Builtins.size(mv_dates), 1)
          )
        end
      end

      # get creation time of the first part of the archive
      stat = Convert.to_map(
        SCR.Read(
          path(".target.stat"),
          Ops.add(Ops.add(Ops.add(dir, "/"), "01_"), fname)
        )
      )
      ctime = Ops.get_integer(stat, "ctime", 0)
      ctime_str = SecondsToDateString(ctime)

      command = Ops.add(
        Ops.add(Ops.add(Ops.add("/bin/ls -1 -t ", dir), "/*_"), fname),
        " 2> /dev/null"
      )
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      files = Builtins.splitstring(Ops.get_string(result, "stdout", ""), "\n")
      files = Builtins.filter(files) do |file|
        Builtins.regexpmatch(
          file,
          Ops.add(Ops.add(Ops.add(Ops.add("^", dir), "/[0-9]+_"), fname), "$")
        )
      end
      Builtins.y2milestone("Existing volumes: %1", files)

      Builtins.foreach(files) do |volume|
        vol_parts = Builtins.splitstring(volume, "/")
        vol_fname = Ops.get(
          vol_parts,
          Ops.subtract(Builtins.size(vol_parts), 1),
          ""
        )
        vol_dir = Builtins.mergestring(
          Builtins.remove(vol_parts, Ops.subtract(Builtins.size(vol_parts), 1)),
          "/"
        )
        # rename existing archive
        from = Ops.add(Ops.add(vol_dir, "/"), vol_fname)
        to = Ops.add(
          Ops.add(Ops.add(Ops.add(vol_dir, "/"), ctime_str), "-"),
          vol_fname
        )
        command = Ops.add(Ops.add(Ops.add("/bin/mv -f ", from), " "), to)
        result = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), command)
        )
        # update NFS archive name
        if @target_type == :nfs
          from = Ops.add(
            Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
            Builtins.substring(from, Builtins.size(@nfsmount))
          )
          to = Ops.add(
            Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
            Builtins.substring(to, Builtins.size(@nfsmount))
          )
          Builtins.y2debug("NFS archive, from: %1, to: %2", from, to)
        end
        Ops.set(renamed, from, to)
        Builtins.y2milestone("renamed volume %1", volume)
      end 


      # rename autoinstallation profile
      oldXML = Ops.add(Ops.add(Ops.add(dir, "/"), GetBaseName(name)), ".xml")
      newXML = Ops.add(
        Ops.add(
          Ops.add(Ops.add(Ops.add(dir, "/"), ctime_str), "-"),
          GetBaseName(fname)
        ),
        ".xml"
      )

      command = Ops.add(Ops.add(Ops.add("/bin/mv -f ", oldXML), " "), newXML)
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      # update NFS archive name
      if @target_type == :nfs
        oldXML = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(oldXML, Builtins.size(@nfsmount))
        )
        newXML = Ops.add(
          Ops.add(Ops.add(@nfsserver, ":"), @nfsexport),
          Builtins.substring(newXML, Builtins.size(@nfsmount))
        )
        Builtins.y2debug("NFS archive, oldXML: %1, newXML: %2", oldXML, newXML)
      end

      Ops.set(renamed, oldXML, newXML)

      { "removed" => removed, "renamed" => renamed }
    end

    # Remove and/or rename old existing archives
    # @param [String] name Archive name
    # @param [Fixnum] max Maximum count of existing archives
    # @param [Boolean] multivolume Is archive archive multivolume?
    # @return [Hash] result
    def RemoveOldArchives(name, max, multivolume)
      multivolume == true ?
        RemoveOldMultiArchives(name, max) :
        RemoveOldSingleArchives(name, max)
    end

    publish :variable => :script_store_ext2_area, :type => "string"
    publish :variable => :script_get_partition_table, :type => "string"
    publish :variable => :script_get_files, :type => "string"
    publish :variable => :script_create_archive, :type => "string"
    publish :variable => :daynames, :type => "map <integer, string>"
    publish :variable => :ordinal_numbers, :type => "map <integer, string>"
    publish :variable => :backup_profiles, :type => "map <string, map>"
    publish :variable => :default_archive_name, :type => "string"
    publish :variable => :default_description, :type => "string"
    publish :variable => :default_archive_type, :type => "symbol"
    publish :variable => :default_multi_volume, :type => "boolean"
    publish :variable => :default_volume_size, :type => "symbol"
    publish :variable => :default_user_volume_size, :type => "string"
    publish :variable => :default_user_volume_unit, :type => "symbol"
    publish :variable => :default_search, :type => "boolean"
    publish :variable => :default_all_rpms_content, :type => "boolean"
    publish :variable => :default_system, :type => "boolean"
    publish :variable => :default_display, :type => "boolean"
    publish :variable => :default_do_md5_test, :type => "boolean"
    publish :variable => :default_perms, :type => "boolean"
    publish :variable => :default_default_dir, :type => "list <string>"
    publish :variable => :default_dir_list, :type => "list <string>"
    publish :variable => :default_include_dir, :type => "string"
    publish :variable => :default_regexp_list, :type => "list <string>"
    publish :variable => :default_fs_exclude, :type => "list <string>"
    publish :variable => :default_detected_fs, :type => "list <string>"
    publish :variable => :default_detected_ext2, :type => "list <map <string, any>>"
    publish :variable => :default_ext2_backup, :type => "list <term>"
    publish :variable => :default_backup_pt, :type => "boolean"
    publish :variable => :default_backup_all_ext2, :type => "boolean"
    publish :variable => :default_backup_none_ext2, :type => "boolean"
    publish :variable => :default_backup_selected_ext2, :type => "boolean"
    publish :variable => :default_tmp_dir, :type => "string"
    publish :variable => :default_backup_files, :type => "map <string, map>"
    publish :variable => :default_selected_files, :type => "map <string, map>"
    publish :variable => :default_unselected_files, :type => "list <string>"
    publish :variable => :default_autoprofile, :type => "boolean"
    publish :variable => :default_target_type, :type => "symbol"
    publish :variable => :default_temporary_dir, :type => "string"
    publish :variable => :default_nfsserver, :type => "string"
    publish :variable => :default_nfsexport, :type => "string"
    publish :variable => :default_mail_summary, :type => "boolean"
    publish :variable => :archive_name, :type => "string"
    publish :variable => :description, :type => "string"
    publish :variable => :archive_type, :type => "symbol"
    publish :variable => :profile_is_new_one, :type => "boolean"
    publish :variable => :multi_volume, :type => "boolean"
    publish :variable => :volume_size, :type => "symbol"
    publish :variable => :user_volume_size, :type => "string"
    publish :variable => :user_volume_unit, :type => "symbol"
    publish :variable => :user_vol_size, :type => "integer"
    publish :variable => :temporary_dir, :type => "string"
    publish :variable => :mail_summary, :type => "boolean"
    publish :variable => :do_search, :type => "boolean"
    publish :variable => :backup_all_rpms_content, :type => "boolean"
    publish :variable => :system, :type => "boolean"
    publish :variable => :display, :type => "boolean"
    publish :variable => :do_md5_test, :type => "boolean"
    publish :variable => :perms, :type => "boolean"
    publish :variable => :target_type, :type => "symbol"
    publish :variable => :default_dir, :type => "list <string>"
    publish :variable => :dir_list, :type => "list <string>"
    publish :variable => :include_dirs, :type => "list <string>"
    publish :variable => :regexp_list, :type => "list <string>"
    publish :variable => :fs_exclude, :type => "list <string>"
    publish :variable => :detected_fs, :type => "list <string>"
    publish :variable => :detected_ext2, :type => "list <map <string, any>>"
    publish :variable => :ext2_backup, :type => "list <term>"
    publish :variable => :backup_pt, :type => "boolean"
    publish :variable => :backup_all_ext2, :type => "boolean"
    publish :variable => :backup_none_ext2, :type => "boolean"
    publish :variable => :backup_selected_ext2, :type => "boolean"
    publish :variable => :tmp_dir, :type => "string"
    publish :variable => :target_dir, :type => "string"
    publish :variable => :cron_mode, :type => "boolean"
    publish :variable => :cron_profile, :type => "string"
    publish :variable => :backup_helper_scripts, :type => "list <map>"
    publish :variable => :autoprofile, :type => "boolean"
    publish :variable => :nfsserver, :type => "string"
    publish :variable => :nfsexport, :type => "string"
    publish :variable => :nfsmount, :type => "string"
    publish :variable => :backup_files, :type => "map <string, map>"
    publish :variable => :selected_files, :type => "map <string, map>"
    publish :variable => :unselected_files, :type => "list <string>"
    publish :variable => :no_interactive, :type => "boolean"
    publish :variable => :selected_profile, :type => "string"
    publish :variable => :undetected_volume_size, :type => "integer"
    publish :variable => :installable_packages, :type => "list <string>"
    publish :variable => :complete_backup, :type => "list <string>"
    publish :variable => :remove_cron_files, :type => "list <string>"
    publish :variable => :remove_result, :type => "map"
    publish :variable => :just_creating_archive, :type => "boolean"
    publish :variable => :cd_media_descriptions, :type => "list <map <string, any>>"
    publish :variable => :floppy_media_descriptions, :type => "list <map <string, any>>"
    publish :variable => :zip_media_descriptions, :type => "list <map <string, any>>"
    publish :variable => :misc_descriptions, :type => "list <map <string, any>>"
    publish :variable => :media_descriptions, :type => "list <map <string, any>>"
    publish :variable => :units_description, :type => "list <map <string, any>>"
    publish :variable => :backup_scripts_dir, :type => "string"
    publish :function => :GetCapacity, :type => "integer (list <map <string, any>>, symbol)"
    publish :function => :get_search_script_parameters, :type => "string ()"
    publish :function => :PrepareBackup, :type => "boolean ()"
    publish :function => :PostBackup, :type => "boolean ()"
    publish :function => :get_archive_script_parameters, :type => "string (string, string)"
    publish :function => :ExcludeNodevFS, :type => "void ()"
    publish :function => :WriteProfile, :type => "map (list <string>)"
    publish :function => :ReadCronSetting, :type => "map (string)"
    publish :function => :ReadCronSettings, :type => "void ()"
    publish :function => :ReadBackupProfiles, :type => "boolean ()"
    publish :function => :CreateCronSetting, :type => "string (string)"
    publish :function => :WriteCronSettings, :type => "void ()"
    publish :function => :WriteBackupProfiles, :type => "boolean ()"
    publish :function => :StoreSettingsToBackupProfile, :type => "void (string)"
    publish :function => :RestoreSettingsFromBackupProfile, :type => "boolean (string)"
    publish :function => :RestoreDefaultSettings, :type => "void ()"
    publish :function => :BackupProfileNames, :type => "list <string> ()"
    publish :function => :CreateCronDescription, :type => "string (string)"
    publish :function => :BackupProfileDescriptions, :type => "list <term> ()"
    publish :function => :RemoveBackupProfile, :type => "boolean (string, boolean)"
    publish :function => :RemovableDevices, :type => "map (boolean)"
    publish :function => :ReadInstallablePackages, :type => "void ()"
    publish :function => :DetectedMountPoints, :type => "map ()"
    publish :function => :GetLocalArchiveName, :type => "string ()"
    publish :function => :MapFilesToString, :type => "map ()"
    publish :function => :RemoveOldSingleArchives, :type => "map (string, integer)"
    publish :function => :RemoveOldMultiArchives, :type => "map (string, integer)"
    publish :function => :RemoveOldArchives, :type => "map (string, integer, boolean)"
  end

  Backup = BackupClass.new
  Backup.main
end
