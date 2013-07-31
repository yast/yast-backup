# encoding: utf-8

#  File:
#    help_texts.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Help texts used in workflow dialogs
#
module Yast
  module BackupHelpTextsInclude
    def initialize_backup_help_texts(include_target)
      textdomain "backup"
    end

    # Help text for archive dialog
    # @return [String] Help text

    def backup_help_archive_settings
      # For translators: help text in archive setting dialog - part 1/3
      _(
        "<P><B><big>Backup</big></B><BR>To create a backup of your system,\n" +
          "enter the absolute path for the file in which to store the backup in \n" +
          "<b>Filename</b>. To store the file on an NFS server, select <b>Network</b> \n" +
          "as the location and enter the server details."
      ) +
        # For translators: help text in archive setting dialog - part 2/3
        _(
          "<P>The backup module creates a tar archive with changed files and \n" +
            "an autoinstallation profile for easy and fast system reinstallation. \n" +
            "To store only the names of detected files instead of creating an archive, \n" +
            "select <B>Only Create List of Files Found</B>.</P>"
        ) +
        # For translators: help text in archive setting dialog - part 3/3
        _(
          "<P>If you use ACLs (access control lists) for file access and \n" +
            "want to back them up, select the subarchive type star.  To create a \n" +
            "multivolume archive, for example, for storage on a fixed-size media \n" +
            "like CDs, use <b>Options</b> to configure these settings.</P>"
        )
    end


    # Help text for archive options dialog
    # @return [String] Help text

    def backup_help_archive_options
      # For translators: help text in tar options dialog - part 1/3
      _(
        "<P><B><BIG>Multivolume Archive</BIG></B><BR>\n" +
          "A backup archive can be divided into several smaller parts. This is useful \n" +
          "if an archive is larger than the space available on the backup medium.</P>"
      ) +
        # For translators: help text in tar options dialog - part 2/3
        _(
          "<P>To create a multivolume archive,  enable that option and \n" +
            "select your backup medium.  If your backup medium is not in the list, \n" +
            "select <B>Custom</B>.  Then enter the volume size in <b>Custom Size</b>.</P>"
        ) +
        # For translators: help text in tar options dialog - part 3/3
        # http://en.wikipedia.org/wiki/Byte
        _(
          "<P><B>Note:</B> 1 kB=1000 bytes, 1 KiB=1024 bytes, etc. \n" +
            "The entered volume size will be rounded down to a \n" +
            "multiple of 2048 bytes.</P>"
        )
    end


    # Help text for backup settings dialog
    # @return [String] Help text

    def backup_help_backup_setting
      # For translators: help text in backup settings dialog - part 1
      _(
        "<P><B><BIG>Backup Options</BIG></B><BR>Here, select which parts of the system to search and back up. <B>Archive Description</B> is an optional description of the backup archive.</P>"
      ) +
        # For translators: help text in backup settings dialog - part 2
        _(
          "<P>The archive will contain files from packages that were changed since\n" +
            "package installation or upgrade. Files that do not belong to any\n" +
            "package can be optionally added to the archive.</P>"
        ) +
        # For translators: help text in backup settings dialog - part 3
        _(
          "<P>Check <B>Display List of Files</B> to show and edit a list of files found before creating the backup archive.</P>"
        ) +
        # For translators: help text in backup settings dialog - part 4
        _(
          "<P>If you select <b>Check MD5 Sum</b>, the MD5 sum is used to determine if the file was changed. It is more reliable than checking the size or modification time, but takes longer.</P>"
        ) +
        # TRANSLATORS: help text in backup settings dialog - part 5
        _(
          "<p>Select <b>Backup Content of All Packages</b> to back up all files belonging\n" +
            "to all installed packages. This option is useful when creating an archive that\n" +
            "need not have the same installation repositories or the same packages\n" +
            "available in order to restore. It is faster not to use this option.</p>\n"
        )
    end



    # Help text for system backup dialog
    # @return [String] Help text

    def backup_help_system_backup
      # For translators: help text in system backup dialog
      _(
        "<P><B><BIG>System Backup</BIG></B><BR>\n" +
          "Critical disk system areas can be added to the backup archive. \n" +
          "They can be used to restore the system in case of a crash.</P>"
      )
    end


    # Help text for searching modified dialog
    # @return [String] Help text

    def backup_help_searching_modified
      # For translators: help text in searching modified dialog - part 1/3
      _(
        "<P><B><BIG>Searching</BIG></B><BR>\n" +
          "The modified file search is in progress.  This takes several minutes, \n" +
          "depending on the speed of your system and the number of installed \n" +
          "packages.</P>"
      )
    end


    # Help text for searching files dialog
    # @return [String] Help text

    def backup_help_searching_files
      # For translators: help text in searching files dialog - part 1/3
      _(
        "<P><B><BIG>Searching</BIG></B><BR>The search is in progress for files that do not belong to a package. This takes several minutes, depending on the speed of your system and the size of the file system.</P>"
      )
    end


    # Help text for file selection dialog
    # @return [String] Help text

    def backup_help_file_selection
      # For translators: help text in file dialog - part 1/2
      _(
        "<P><B><BIG>Detected Files</BIG></B><BR>This is a list of files found. Select which files to store in the archive.</P>"
      ) +
        # For translators: help text in file dialog - part 2/2
        _(
          "<P>A mark in the first column indicates that the file will be backed up.</P>"
        )
    end


    # Help text for creating archive dialog
    # @return [String] Help text

    def backup_help_creating_archive
      # For translators: help text in creating archive dialog - part 1/2
      _(
        "<P><B><BIG>Creating Archive</BIG></B><BR>Archive creation is in progress.</P>"
      )
    end


    # Help text for backup summary dialog
    # @return [String] Help text

    def backup_help_summary
      # For translators: help text in summary dialog - part 1/2
      _(
        "<P><B><BIG>Summary</BIG></B><BR>This displays the result \nof the backup. Click <B>Details</B> to see more information.</P>"
      )
    end


    # Return help text for the automatic backup (cron setting) dialog
    # @return [String] Translated help text

    def backup_help_cron_dialog
      # For translators: help text in the automatic backup dialog (1/4)
      _(
        "<P><B><BIG>Automatic Backup</BIG></B><BR>\n" +
          "The selected profile can be started automatically in the background without \n" +
          "any user interaction.</P>"
      ) +
        # For translators: help text in the automatic backup dialog (2/4)
        _(
          "<P>To start the backup automatically with the selected profile, \n" +
            "check <b>Start Backup Automatically</b> and set how often and when the \n" +
            "backup should be started. Use the 24-hour clock format for <b>Hour</b>.</P>"
        ) +
        # For translators: help text in the automatic backup dialog (3/4)
        _(
          "<P>The previous full backup archive, if it exists, will be renamed by \n" +
            "putting the date in the form YYYYMMDDHHMMSS at the beginning of the \n" +
            "filename. If the number of old archives is greater than the predefined \n" +
            "value, the oldest archives are deleted. All archives are stored\n" +
            "as <b>full backups</b>.</P>"
        ) +
        # For translators: help text in automatic backup dialog (4/4)
        _(
          "<p>For the root user to receive information about the backup, \n" +
            "select <b>Send Summary Mail to User root</b>.  This summary contains \n" +
            "information about the files included in the backup and any errors that \n" +
            "occur.</p>"
        )
    end

    # Help text displayed in profile management dialog
    # @return Translated help text

    def profile_help
      # For translators: help text in profile management dialog - part 1/4
      _(
        "<P><B><BIG>System Backup</BIG></B><BR>\n" +
          "This backup tool searches files on your system and creates a backup \n" +
          "archive from them. It is a small, easy-to-use backup program. \n" +
          "If you need advanced features, such as incremental backup or \n" +
          "network backup, you should use an expert tool.</P>"
      ) +
        #For translators: help text in profile management dialog - part 2/4
        _(
          "<P>This dialog shows the list of currently stored backup \n" +
            "profiles. A backup profile is used to name a group of different settings, \n" +
            "such as the name of an archive and how to search for files.</P>"
        ) +
        # For translators: help text in profile management dialog - part 3/4
        _(
          "<P>You can have a number of profiles, each with a unique name. \n" +
            "Using the actions in <B>Profile Management</B>, you can add a new profile \n" +
            "based on default values, duplicate an existing profile, change the settings \n" +
            "stored in a profile, or delete a profile. Use the <b>Automatic Backup</b> \n" +
            "option to configure routine backups of the selected profile.</P>"
        ) +
        # For translators: help text in profile management dialog - part 4/4
        _(
          "<P>Press <B>Create Backup</B> to start the backup using \n" +
            "settings stored in the currently selected profile. Press \n" +
            "<B>Back Up Manually</B> to use default settings that can be \n" +
            "modified before starting the backup process.</P>"
        )
    end


    # Help text displayed in expert options dialog
    # @return Translated help text

    def expert_options_help
      # For translators: help text in backup expert options dialog - part 1/3
      _(
        "<P><BIG><B>Expert Options</B></BIG><BR>Some advanced configuration options\ncan be set in this dialog. Usually there is no need to modify the default values.</P>"
      ) +
        # For translators: help text in backup expert options dialog - part 3/3
        _(
          "<P>System areas, such as partition table or ext2 image, can be added to the backup archive with <b>Back Up Hard Disk System Areas</b>. These system areas can only be restored from an archive manually.</P>"
        ) +
        # For translators: help text in backup expert options dialog - part 2/3
        _(
          "<P>In <B>Temporary Directory</B>, set the location in which parts\n" +
            "of the archive are stored before the final archive is created. The temporary directory should have enough\n" +
            "free space for the entire archive.</P>\n"
        )
    end

    # Help text displayed in constraints dialog
    # @return Translated help text

    def backup_help_constraints
      # For translators: help text in exclude directory dialog - part 1/5
      _(
        "<p><b>Included Directories</b><br>\n" +
          "It is possible to limit the search to back up only selected directories.\n" +
          "To add a new directory, click <b>Add</b> and select a directory.\n" +
          "To change or delete a directory, select it and click \n" +
          "<b>Edit</b> or <b>Delete</b>.\n" +
          "If you do not select any directory or if you delete all the already listed ones,\n" +
          "the entire file system is searched and backed up.</p>\n"
      ) +
        # For translators: help text in exclude directory dialog - part 2/5
        _(
          "<P><BIG><B>Constraints</B></BIG>\n" +
            "<BR>It is possible to exclude some files from the backup.\n" +
            "Search constraints can be a directory, file system, or regular expression.\n" +
            "Use <b>Edit</b> to modify an existing constraint, or\n" +
            "<b>Delete</b> to remove the selected constraint.\n" +
            "To add a new constraint, click <b>Add</b> then select the type of constraint. </P>"
        ) +
        # For translators: help text in exclude directory dialog - part 3/5
        _(
          "<P><B>Directory</B>: All files located in the specified directories will not be backed up.</P>"
        ) +
        # For translators: help text in exclude directory dialog - part 4/5
        _(
          "<P><B>File System</B>: It is possible to exclude all files located\n" +
            "on a certain type of file system (such as ReiserFS or Ext2).\n" +
            "The root directory will always be searched, even if its file system is selected.\n" +
            "File systems that cannot be used on a local disk, such as network file systems,\n" +
            "are excluded by default.</P>"
        ) +
        # For translators: help text in exclude directory dialog - part 5/5
        _(
          "<P><B>Regular Expressions</B>: Any filename that matches any of the regular expressions will not be backed up. Use Perl regular expressions. To exclude, for example, <tt>*.bak</tt> files, add the regular expression <tt>\\.bak$</tt>.</P>"
        )
    end
  end
end
