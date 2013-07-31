# encoding: utf-8

#  File:
#    ui.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Yast2 user interface functions - dialogs
module Yast
  module BackupUiInclude
    def initialize_backup_ui(include_target)
      Yast.import "UI"

      Yast.import "Backup"
      Yast.import "Wizard"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "NetworkPopup"
      Yast.import "Nfs"
      Yast.import "PackageSystem"
      Yast.import "Confirm"
      Yast.import "Mode"

      Yast.include include_target, "backup/help_texts.rb"
      Yast.include include_target, "backup/functions.rb"

      textdomain "backup"

      @wait_time = 250 # loop delay (in miliseconds)

      # used for the ag_process
      @backup_PID = nil

      # variables needed for backup when freezes on ZERO (or almost zero) free space
      @waiting_without_output = 0
      @enough_free_space_tmp = true
      @enough_free_space_target = true

      # wait 1 minute between checking for the free space
      @max_wait_without_output = 60000
      # wait sec between checking
      @wait_sec_check = 59
      @next_time_check = Ops.add(Builtins.time, @wait_sec_check)
      # minimal reasonable free space is 512K
      @min_free_space = 512

      @last_input = nil

      @deselected_ids = {}

      # type of item (displayed in the table)
      @filesystem_text = _("File system")
      # type of item (displayed in the table)
      @directory_text = _("Directory")
      # type of item (displayed in the table)
      @regexp_text = _("Regular expression")

      @selected_pkg_num = 0 # number of packages which files are selected
      @modified_size = 0 # size
      @modified_num = 0 # number of modified files


      @nopkg_num = 0 # number of found files which do not belong to any package
      @nopkg_size = 0 # size
      @selected_files_num = 0 # number of selected files to backup

      @checkmark = "X"
      @nocheckmark = " "

      @root_warning_displayed = false

      @file_list_stored = false

      @hostname_stored = false
      @date_stored = false
      @comment_stored = false
      @e2image_results = [] # results of storing ext2 images
      @archived_num = 0
      @not_readable_files = []
      @created_archive_files = []
      @failed_ptables = []
      @stored_ptables = []
      @read_ptables_info = false
      @stored_list = false

      @tar_result = 1 # exit status of tar
      @total_files = 0 # total number of files in archive
      @added_files = 0

      @packages_list_stored = false
      @profilewritten = {} # result of writing profile

      # -->>
      # definition of variables for search dialog/functions
      # trying to break huge cycle into more smaller functions

      @package_num = 0
      @actual_package = ""
      @package_files = []
      @actual_instprefixes = ""
      @line = ""
      @total_packages = 0

      # output strings from search script
      @id_package = "Package: "
      @id_complete_package = "Complete package: "
      @id_file = "Size: "
      @id_nopackage = "Nopackage:"
      @id_instprefixes = "Installed: "
      @id_reading_packages = "Reading installed packages"
      @id_packages_num = "Packages: "
      @id_reading_files = "Reading all files"
      @id_files_read = "Files read"

      @search_no_package = false
      @reading_installed_packages = false

      # we are in ncurses
      @in_ncurses = false

      @ui_last_refresh = 0
      @ui_time_now = 0

      @dir_last_refresh = 0
      @dir_time_now = 0
      @dir_shown = ""

      #  Variables for the ArchivingDialog() and functions beyond
      @id_hostname = "Storing hostname: "
      @id_date = "Storing date: "
      @id_partab = "Storing partition table"
      @id_ptstored = "Stored partition: "
      @id_ok = "Success"
      @id_failed = "Failed"
      @id_storing_installed_pkgs = "Storing list of installed packages"
      @id_storedpkg = "Packages stored: "
      @id_ext2 = "Storing ext2 area: "
      @id_archive = "Creating archive:"
      @id_tar_exit = "/Tar result:"
      @id_new_volume = "/Volume created: "
      @id_not_readable = "/File not readable: "
      @id_not_stored = "Error storing partition: "
      @id_pt_read = "Partition tables info read"
      @id_creating_target = "Creating target archive file..."

      @selected_info = {}

      @last_file_stage = 0
      @this_file_stage = 0
      @stages_for_files = 0
    end

    # Function periodically checks the free space
    def CheckFreeSpace
      @waiting_without_output = Ops.add(@waiting_without_output, @wait_time)

      if Ops.greater_or_equal(@waiting_without_output, @max_wait_without_output)
        # null the waiting time now
        @waiting_without_output = 0
        return if Ops.less_than(Builtins.time, @next_time_check)
        # next space check - not before time() + wait_sec_check
        @next_time_check = Ops.add(Builtins.time, @wait_sec_check)

        # null the free space flags
        @waiting_without_output = 0
        @enough_free_space_tmp = true
        @enough_free_space_target = true

        # check the tmpdir free space
        free_tmp = Convert.to_integer(
          SCR.Read(path(".system.freespace"), Backup.tmp_dir)
        )
        if free_tmp != -1 && Ops.less_than(free_tmp, @min_free_space)
          @enough_free_space_tmp = false
        end

        # check the targetdir free space
        free_target = Convert.to_integer(
          SCR.Read(path(".system.freespace"), Backup.target_dir)
        )
        if free_target != -1 && Ops.less_than(free_target, @min_free_space)
          @enough_free_space_target = false
        end
      end

      nil
    end

    def EvaluateFreeSpace(ret)
      # If zero (or almost zero) free space in tmpdir
      if !@enough_free_space_tmp
        Builtins.y2warning("Not enough free space in the temporary directory")
        # cron mode => finish immediately
        if Backup.cron_mode
          Builtins.y2milestone("Finishing backup...")
          return :abort 
          # !cron mode => ask user
        elsif Convert.to_boolean(
            SCR.Read(path(".process.running"), @backup_PID)
          )
          if !Popup.YesNoHeadline(
              # headline of a popup message
              _("Warning"),
              # a popup question - no free space, %1 is the name of the directory
              Builtins.sformat(
                _(
                  "There is not enough free space in the temporary directory %1.\nContinue anyway?"
                ),
                Backup.tmp_dir
              )
            )
            Builtins.y2milestone("Finishing backup...")
            return :abort
          else
            Builtins.y2milestone("Trying co continue...")
            @waiting_without_output = 0
            return ret
          end 
          # background agent is not running
        else
          # a popup error message - no free space, %1 is the name of the directory
          Report.Error(
            Builtins.sformat(
              _(
                "There is not enough free space in the backup target directory %1.\nAborting the backup."
              ),
              Backup.tmp_dir
            )
          )
          return :abort
        end
      end

      # If zero (or almost zero) free space in targetdir
      if !@enough_free_space_target
        Builtins.y2warning(
          "Not enough free space in the backup target directory"
        )
        # cron mode => finish immediately
        if Backup.cron_mode
          Builtins.y2milestone("Finishing backup...")
          return :abort 
          # !cron mode => ask user
        elsif Convert.to_boolean(
            SCR.Read(path(".process.running"), @backup_PID)
          )
          if !Popup.YesNoHeadline(
              # headline of a popup message
              _("Warning"),
              # a popup question - no free space, %1 is the name of the directory
              Builtins.sformat(
                _(
                  "There is not enough free space in the backup target directory %1.\nContinue anyway?"
                ),
                Backup.target_dir
              )
            )
            Builtins.y2milestone("Finishing backup...")
            return :abort
          else
            Builtins.y2milestone("Trying co continue...")
            @waiting_without_output = 0
            return ret
          end 
          # background agent is not running
        else
          # a popup error message - no free space, %1 is the name of the directory
          Report.Error(
            Builtins.sformat(
              _(
                "There is not enough free space in the backup target directory %1.\nAborting the backup."
              ),
              Backup.target_dir
            )
          )
          return :abort
        end
      end

      # nothing changed
      ret
    end

    # Wait for output from subprocess or user action. If user press `abort button, then subprocess is terminated.
    # @param [Fixnum] wait Delay in miliseconds between user action checks (if no output from subprocess is available)
    # @param [Symbol] abort_question Symbol for AbortConfirmation function - which dialog will be displayed if Abort button is pressed
    # @return [Symbol] Pressed button id or nil if some data is ready from subprocess.

    def waitForUserOrProcess(wait, abort_question)
      ret = Convert.to_symbol(UI.PollInput)

      if ret == :abort || ret == :cancel
        Builtins.y2warning("Abort pressed")
        ret = :abort

        if AbortConfirmation(abort_question)
          SCR.Execute(path(".process.kill"), @backup_PID) if @backup_PID != nil
          return ret
        else
          ret = nil
        end
      end

      if @backup_PID != nil &&
          Convert.to_boolean(SCR.Read(path(".process.running"), @backup_PID))
        if Convert.to_boolean(
            SCR.Read(path(".process.buffer_empty"), @backup_PID)
          ) == true
          Builtins.sleep(wait)
        end

        ret = Convert.to_symbol(UI.PollInput)

        if ret == :abort || ret == :cancel
          ret = :abort
          Builtins.y2warning("Abort pressed")

          if Backup.just_creating_archive
            CheckFreeSpace()
            ret = EvaluateFreeSpace(ret)
          else
            if AbortConfirmation(abort_question)
              SCR.Execute(path(".process.kill"), @backup_PID)
            else
              ret = nil
            end
          end
        end
      end

      ret
    end

    # <<--

    def ResetGlobalVariables
      @deselected_ids = {}
      @selected_pkg_num = 0
      @modified_size = 0
      @modified_num = 0
      @nopkg_num = 0
      @selected_files_num = 0
      @archived_num = 0
      @not_readable_files = []
      @created_archive_files = []
      @failed_ptables = []
      @stored_ptables = []
      @tar_result = 1
      @total_files = 0
      @added_files = 0

      @package_num = 0
      @actual_package = ""
      @package_files = []
      @actual_instprefixes = ""
      @line = ""
      @total_packages = 0

      @search_no_package = false
      @reading_installed_packages = false

      Backup.just_creating_archive = false

      ui_capabilities = UI.GetDisplayInfo
      @in_ncurses = Ops.get_boolean(ui_capabilities, "TextMode", true)
      Builtins.y2milestone("Running in TextMode: %1", @in_ncurses)

      nil
    end

    # Function for installing packages
    def InstallNeededPackages(packages)
      packages = deep_copy(packages)
      if Builtins.size(packages) == 0
        Builtins.y2error("empty list of packages to be installed")
        return false
      end

      return true if Mode.test

      if !PackageSystem.CheckAndInstallPackagesInteractive(packages)
        Builtins.y2debug("star package wasn't installed")
        return false
      end

      true
    end

    # Update widget status in the dialog. Enable/disable widget according to
    # checkbox/combobox value.
    def update_cron_dialog
      if UI.QueryWidget(Id(:enabled), :Value) == true
        UI.ChangeWidget(Id(:time), :Enabled, true)

        UI.ChangeWidget(
          Id(:weekday),
          :Enabled,
          UI.QueryWidget(Id(:time), :Value) == :week
        )
        UI.ChangeWidget(
          Id(:day),
          :Enabled,
          UI.QueryWidget(Id(:time), :Value) == :month
        )

        UI.ChangeWidget(Id(:hour), :Enabled, true)
        UI.ChangeWidget(Id(:minute), :Enabled, true)

        UI.ChangeWidget(Id(:old), :Enabled, true)
        UI.ChangeWidget(Id(:mail), :Enabled, true)
      else
        # disable all widgets
        UI.ChangeWidget(Id(:time), :Enabled, false)
        UI.ChangeWidget(Id(:weekday), :Enabled, false)
        UI.ChangeWidget(Id(:day), :Enabled, false)
        UI.ChangeWidget(Id(:hour), :Enabled, false)
        UI.ChangeWidget(Id(:minute), :Enabled, false)
        UI.ChangeWidget(Id(:old), :Enabled, false)
        UI.ChangeWidget(Id(:mail), :Enabled, false)
      end

      nil
    end

    # Refresh widget states in the location dialog
    def update_location_dialog
      nfs = UI.QueryWidget(Id(:nfs), :Value) == true

      UI.ChangeWidget(Id(:nfsserver), :Enabled, nfs)
      UI.ChangeWidget(Id(:selectexport), :Enabled, nfs)
      UI.ChangeWidget(Id(:nfsexport), :Enabled, nfs)
      UI.ChangeWidget(Id(:selecthost), :Enabled, nfs)

      nil
    end

    # Ask whether archive can be overwritten if it already exists
    # @return [Boolean] true when archive can be overwritten, nil when an error occured (e.g. NFS mount failed)
    def WriteArchive
      ret = true

      Builtins.y2milestone("target_type: %1", Backup.target_type)

      exists = Backup.target_type == :file ?
        Ops.greater_or_equal(
          Convert.to_integer(
            SCR.Read(path(".target.size"), Backup.archive_name)
          ),
          0
        ) :
        NFSFileExists(Backup.nfsserver, Backup.nfsexport, Backup.archive_name)

      Builtins.y2milestone("exists: %1", exists)

      if exists == true
        # For translators %1 is archive file name (e.g. /tmp/backup.tar)
        ret = Popup.YesNo(
          Builtins.sformat(
            _("File %1 already exists.\nOverwrite it?"),
            Backup.archive_name
          )
        )
      elsif exists == nil
        ret = nil
      end

      ret
    end

    # Display dialog for automatic backup - set time when backup module will
    # be started at background with current selected profile.
    # @return [Symbol] User input value
    def CronDialog
      # read current settings from profile
      current_profile = Builtins.eval(
        Ops.get(Backup.backup_profiles, Backup.selected_profile, {})
      )
      current_settings = Builtins.eval(
        Ops.get_map(current_profile, :cron_settings, {})
      )

      # current day settings
      cday = Ops.get_symbol(current_settings, "every", :none)
      cweekday = Ops.get_integer(current_settings, "weekday", 0)

      items = []
      # create combo box content
      Builtins.foreach(Backup.daynames) do |num, name|
        items = Builtins.add(items, Item(Id(num), name, cweekday == num))
      end 


      # dialog header - %1 is profile name
      Wizard.SetContents(
        Builtins.sformat(
          _("Automatic Backup Options for Profile %1"),
          Backup.selected_profile
        ),
        VBox(
          VSpacing(0.5),
          # check box label
          Left(
            CheckBox(
              Id(:enabled),
              Opt(:notify),
              _("&Start Backup Automatically"),
              Ops.get_boolean(current_settings, "auto", false)
            )
          ),
          VSpacing(0.45),
          HBox(
            HSpacing(4),
            VBox(
              # frame label
              #rwalter please remove this frame
              #`Frame(_("Frequency"), as you wish
              VBox(
                VSpacing(0.45),
                HBox(
                  HSpacing(1),
                  ComboBox(
                    Id(:time),
                    Opt(:notify),
                    _("&Frequency"),
                    [
                      Item(Id(:day), _("Daily"), cday == :day),
                      Item(Id(:week), _("Weekly"), cday == :week),
                      Item(Id(:month), _("Monthly"), cday == :month)
                    ]
                  ),
                  HStretch()
                ),
                VSpacing(0.45)
              ), #)
              #),
              VSpacing(0.45),
              # frame label
              Frame(
                _("Backup Start Time"),
                VBox(
                  VSpacing(0.45),
                  HBox(
                    HSpacing(1),
                    # combo box label
                    ComboBox(Id(:weekday), _("Day of the &Week"), items),
                    HSpacing(2),
                    # integer field widget label
                    IntField(
                      Id(:day),
                      _("&Day of the Month"),
                      1,
                      31,
                      Ops.get_integer(current_settings, "day", 1)
                    ),
                    HStretch()
                  ),
                  VSpacing(0.45),
                  HBox(
                    HSpacing(1),
                    # integer field widget label
                    IntField(
                      Id(:hour),
                      _("&Hour"),
                      0,
                      23,
                      Ops.get_integer(current_settings, "hour", 0)
                    ),
                    HSpacing(2),
                    # integer field widget label
                    IntField(
                      Id(:minute),
                      _("&Minute"),
                      0,
                      59,
                      Ops.get_integer(current_settings, "minute", 0)
                    ),
                    HStretch()
                  ),
                  VSpacing(0.45)
                )
              ),
              VSpacing(0.45),
              #rwalter we can probably do without this one too.
              #`Frame(_("Other Settings"), well, let's see
              VBox(
                VSpacing(0.45),
                HBox(
                  HSpacing(1),
                  # integer field widget label
                  IntField(
                    Id(:old),
                    _("Ma&ximum Number of Old Full Backups"),
                    0,
                    100,
                    Ops.get_integer(current_settings, "old", 3)
                  ),
                  HStretch()
                ),
                VSpacing(0.45),
                # Checkbox label
                Left(
                  CheckBox(
                    Id(:mail),
                    _("S&end Summary Mail to User root"),
                    Backup.mail_summary
                  )
                ),
                VSpacing(0.45)
              )
            ),
            HSpacing(2)
          )
        ),
        backup_help_cron_dialog,
        true,
        true
      )

      # replace 'Next' button with 'Ok'
      Wizard.SetNextButton(:next, Label.OKButton)
      UI.SetFocus(Id(:next))

      # set initial widget states
      update_cron_dialog

      ret = Convert.to_symbol(UI.UserInput)

      while !Builtins.contains([:abort, :cancel, :back, :next], ret)
        update_cron_dialog
        ret = Convert.to_symbol(UI.UserInput)
      end

      if ret == :cancel
        ret = :abort
      elsif ret == :next
        # store setting to the selected profile
        if Backup.selected_profile != nil
          cron_changed = Ops.get(current_settings, "auto") !=
            UI.QueryWidget(Id(:enabled), :Value) ||
            Ops.get(current_settings, "every") !=
              UI.QueryWidget(Id(:time), :Value) ||
            Ops.get(current_settings, "weekday") !=
              UI.QueryWidget(Id(:weekday), :Value) ||
            Ops.get(current_settings, "day") != UI.QueryWidget(Id(:day), :Value) ||
            Ops.get(current_settings, "hour") !=
              UI.QueryWidget(Id(:hour), :Value) ||
            Ops.get(current_settings, "minute") !=
              UI.QueryWidget(Id(:minute), :Value)

          Builtins.y2milestone("cron_changed: %1", cron_changed)

          Ops.set(
            current_settings,
            "auto",
            UI.QueryWidget(Id(:enabled), :Value)
          )
          Ops.set(current_settings, "every", UI.QueryWidget(Id(:time), :Value))

          Ops.set(
            current_settings,
            "weekday",
            UI.QueryWidget(Id(:weekday), :Value)
          )
          Ops.set(current_settings, "day", UI.QueryWidget(Id(:day), :Value))
          Ops.set(current_settings, "hour", UI.QueryWidget(Id(:hour), :Value))
          Ops.set(
            current_settings,
            "minute",
            UI.QueryWidget(Id(:minute), :Value)
          )

          Ops.set(current_settings, "old", UI.QueryWidget(Id(:old), :Value))

          Ops.set(current_settings, "cron_changed", cron_changed)

          Ops.set(
            current_profile,
            :cron_settings,
            Builtins.eval(current_settings)
          )
          Ops.set(
            current_profile,
            :mail_summary,
            UI.QueryWidget(Id(:mail), :Value)
          )
          Ops.set(
            Backup.backup_profiles,
            Backup.selected_profile,
            Builtins.eval(current_profile)
          )

          Builtins.y2milestone(
            "Profile: %1, New settings: %2",
            Backup.selected_profile,
            current_settings
          )
        end
      end

      Wizard.RestoreNextButton

      ret
    end

    # Refresh widget status (enable/disable) in the displayed dialog.
    # @param [Boolean] enable_archive_type if true enable archive selection combo box
    #	and option push button, select "archive" radio button.
    #	If enable_archive_type is false then disbale widgets, select
    #	"only list" radio button.

    def refresh_widget_status(enable_archive_type)
      if enable_archive_type == false
        UI.ChangeWidget(Id(:type), :Enabled, false)
        UI.ChangeWidget(Id(:opts), :Enabled, false)
        #	UI::ChangeWidget(`id(`description), `Enabled, false);
        UI.ChangeWidget(Id(:rbgroup), :CurrentButton, :only_list)
      else
        UI.ChangeWidget(Id(:type), :Enabled, true)
        UI.ChangeWidget(Id(:opts), :Enabled, true)
        #	UI::ChangeWidget(`id(`description), `Enabled, true);
        UI.ChangeWidget(Id(:rbgroup), :CurrentButton, :archive)
      end

      nil
    end

    # Dialog asks for aborting the new profile creation,
    # If aborted, profile is deleted and true returned.
    #
    # @param  string profile name
    # @return [Boolean] whether `abort` meaning is returned
    def AbortNewProfileCreation(profile_name)
      # TRANSLATORS: Popup question, [Yes] means `cancel the profile creation`
      cancel_it = Popup.YesNo(_("Really cancel the profile creation?"))

      if cancel_it
        # remove the profile
        Backup.RemoveBackupProfile(profile_name, true)
        # abort the creation
        return true
      else
        # continue creation
        return false
      end
    end

    # Dialog for setting archive options
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def ArchDialog
      # do not allow manual changes of configuration
      if Backup.no_interactive
        cont2 = true
        nfsdir = ""

        # no multivolume and does not exists, continue
        if !Backup.multi_volume
          # check if archive can be (over)written
          cont2 = WriteArchive()

          if cont2 == nil
            # error popup message - NFS mount failed
            Popup.Error(_("Cannot mount the selected NFS share."))

            cont2 = false
          end
        elsif Backup.multi_volume # test if some volume part exists
          # list directory content
          dir = Builtins.substring(
            Backup.archive_name,
            0,
            Builtins.findlastof(Backup.archive_name, "/")
          )
          fn = Builtins.substring(
            Backup.archive_name,
            Ops.add(Builtins.findlastof(Backup.archive_name, "/"), 1)
          )

          if Backup.target_type == :nfs
            nfsdir = Nfs.Mount(Backup.nfsserver, Backup.nfsexport, nil, "", "")

            if nfsdir == nil
              # error popup message - NFS mount failed
              Popup.Error(_("Cannot mount the selected NFS share."))
            else
              dir = Ops.add(Ops.add(nfsdir, "/"), dir)
            end
          end

          Builtins.y2debug("dir: %1", dir)
          Builtins.y2debug("file: %1", fn)

          ls = Convert.convert(
            SCR.Read(path(".target.dir"), dir),
            :from => "any",
            :to   => "list <string>"
          )

          matched = false

          conflict_file = ""

          # check if some volume part exists
          Builtins.foreach(ls) do |f|
            if Builtins.regexpmatch(f, Ops.add("d*_", fn)) == true
              if matched == false
                matched = true
                conflict_file = f
              end
            end
          end 


          Builtins.y2debug("found volume part: %1", conflict_file)

          # display question
          if matched == true
            # For translators %1 is volume file name (e.g. /tmp/01_backup.tar)
            cont2 = Popup.YesNo(
              Builtins.sformat(
                _(
                  "The existing file %1 could become part of new volume set and be overwritten.\nReally continue?"
                ),
                Ops.add(Ops.add(dir, "/"), conflict_file)
              )
            )
          else
            cont2 = true
          end
        end

        # unmount mounted directory
        Nfs.Unmount(nfsdir) if Ops.greater_than(Builtins.size(nfsdir), 0)

        if cont2
          @last_input = :next
          return @last_input
        end
      end

      # dialog header
      Wizard.SetContents(
        _("Archive Settings"),
        VBox(
          VSpacing(0.5),
          HBox(
            InputField(Id(:filename), Opt(:hstretch), Label.FileName),
            HSpacing(1),
            VBox(Label(""), PushButton(Id(:browse_file), Label.BrowseButton))
          ),
          VSpacing(0.5),
          Frame(
            _("Backup Location"),
            HBox(
              RadioButtonGroup(
                Id(:source),
                Opt(:notify),
                VBox(
                  VSpacing(0.3),
                  # radio button label
                  Left(
                    RadioButton(
                      Id(:file),
                      Opt(:notify),
                      _("&Local File"),
                      Backup.target_type == :file
                    )
                  ),
                  VSpacing(0.3),
                  # radio button label
                  Left(
                    RadioButton(
                      Id(:nfs),
                      Opt(:notify),
                      _("Network (N&FS)"),
                      Backup.target_type == :nfs
                    )
                  ),
                  HBox(
                    HSpacing(2),
                    # text entry label
                    InputField(
                      Id(:nfsserver),
                      Opt(:hstretch),
                      _("I&P Address or Name of NFS Server"),
                      Backup.nfsserver
                    ),
                    HSpacing(1),
                    # push button label
                    VBox(
                      Label(""),
                      # Pushbutton label
                      PushButton(Id(:selecthost), _("&Select..."))
                    )
                  ),
                  HBox(
                    HSpacing(2),
                    # text entry label
                    InputField(
                      Id(:nfsexport),
                      Opt(:hstretch),
                      _("&Remote Directory"),
                      Backup.nfsexport
                    ),
                    HSpacing(1),
                    # push button label
                    VBox(
                      Label(""),
                      # Pushbutton label
                      PushButton(Id(:selectexport), _("S&elect..."))
                    )
                  ),
                  VSpacing(0.3)
                )
              ),
              HSpacing(1)
            )
          ),
          VSpacing(0.5),
          # frame label
          Frame(
            _("Archive Type"),
            VBox(
              VSpacing(Opt(:hstretch), 0.5),
              RadioButtonGroup(
                Id(:rbgroup),
                VBox(
                  Left(
                    RadioButton(
                      Id(:archive),
                      Opt(:notify),
                      _("Create Backup Archive")
                    )
                  ),
                  HBox(
                    HSpacing(4.0),
                    ComboBox(
                      Id(:type),
                      Opt(:notify),
                      # combo box label
                      _("Archive &Type"),
                      # archive type - combo box item
                      [
                        Item(Id(:tgz), _("tar with tar-gzip subarchives")),
                        # archive type - combo box item
                        Item(Id(:tbz), _("tar with tar-bzip2 subarchives")),
                        # archive type - combo box item
                        Item(Id(:tar), _("tar with tar subarchives")),
                        # archive type - combo box item
                        Item(Id(:stgz), _("tar with star-gzip subarchives")),
                        # archive type - combo box item
                        Item(Id(:stbz), _("tar with star-bzip2 subarchives")),
                        # archive type - combo box item
                        Item(Id(:star), _("tar with star subarchives"))
                      ]
                    ),
                    HSpacing(3.0),
                    VBox(
                      VSpacing(1.0),
                      # push button label
                      PushButton(Id(:opts), _("&Options..."))
                    ),
                    HStretch()
                  ),
                  VSpacing(0.5),
                  # radiobutton label
                  Left(
                    RadioButton(
                      Id(:only_list),
                      Opt(:notify),
                      _("Only Create List of Files Found")
                    )
                  )
                )
              ),
              VSpacing(0.5)
            )
          ),
          VSpacing(0.5)
        ),
        backup_help_archive_settings,
        true,
        true
      )

      update_location_dialog

      Backup.archive_type = :tgz if Backup.archive_type == nil

      # set values
      UI.ChangeWidget(Id(:filename), :Value, Backup.archive_name)
      #    UI::ChangeWidget(`id(`description), `Value, Backup::description);

      if Backup.archive_type != :txt
        UI.ChangeWidget(Id(:type), :Value, Backup.archive_type)
      end
      refresh_widget_status(Backup.archive_type != :txt)

      cont = false
      ret = nil
      id_result = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/id -u")
      )

      if Ops.get_string(id_result, "stdout", "") != "0\n" &&
          @root_warning_displayed == false
        # warning popup message
        Popup.Warning(
          _(
            "You are not logged in as root.\n" +
              "Some files can only be read by the user root.\n" +
              "Not all files will be backed up,\n" +
              "so it will not be possible to restore\n" +
              "the system completely later.\n" +
              "\n" +
              "System areas on hard disks can only\n" +
              "be backed up by root.\n"
          )
        )
        @root_warning_displayed = true
      end


      while !cont
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :browse_file
          # TRANSLATORS: explanatory headline for UI::AskForExistingFile pop-up
          new_filename = UI.AskForSaveFileName(
            "",
            "",
            _("Where would you like to store the backup?")
          )
          if new_filename != nil && new_filename != ""
            UI.ChangeWidget(Id(:filename), :Value, new_filename)
          end
          next
        end

        # update dialog (enable/disable widgets)
        update_location_dialog

        Backup.nfsserver = Convert.to_string(
          UI.QueryWidget(Id(:nfsserver), :Value)
        )
        Backup.nfsexport = Convert.to_string(
          UI.QueryWidget(Id(:nfsexport), :Value)
        )

        Backup.archive_name = Convert.to_string(
          UI.QueryWidget(Id(:filename), :Value)
        )
        type = Convert.to_symbol(UI.QueryWidget(Id(:rbgroup), :CurrentButton)) == :only_list ?
          :txt :
          Convert.to_symbol(UI.QueryWidget(Id(:type), :Value))

        # add extension ".tar" if it is missing
        if type != :txt
          Backup.archive_name = AddMissingExtension(Backup.archive_name, ".tar")
          UI.ChangeWidget(Id(:filename), :Value, Backup.archive_name)
        end

        if ret == :type
          stat = Convert.to_symbol(UI.QueryWidget(Id(:type), :Value)) != :txt

          UI.ChangeWidget(Id(:opts), :Enabled, stat)
        else
          if ret == :next
            # check NFS server and export name
            if Convert.to_boolean(UI.QueryWidget(Id(:nfs), :Value)) == true
              if Builtins.size(
                  Convert.to_string(UI.QueryWidget(Id(:nfsserver), :Value))
                ) == 0
                Popup.Warning(
                  _(
                    "A server name is required.\nEnter the server name to use.\n"
                  )
                )
                next
              elsif Builtins.size(
                  Convert.to_string(UI.QueryWidget(Id(:nfsexport), :Value))
                ) == 0
                Popup.Warning(
                  _(
                    "A remote directory name is required.\nEnter the directory name to use.\n"
                  )
                )
                next
              end
            end

            # check if star is installed for star subarchive type
            if (type == :star || type == :stgz || type == :stbz) &&
                Ops.less_than(
                  Convert.to_integer(
                    SCR.Read(path(".target.size"), "/usr/bin/star")
                  ),
                  0
                )
              InstallNeededPackages(["star"])
            end

            Builtins.y2milestone("Multivolume: %1", Backup.multi_volume)

            if Builtins.size(Backup.archive_name) == 0
              # warning popup message
              Popup.Warning(
                _(
                  "An archive filename is required.\nEnter the filename to use.\n"
                )
              )
              cont = false
              next
            end

            if Builtins.substring(Backup.archive_name, 0, 1) != "/" &&
                Backup.target_type == :file
              # warning popup message
              Popup.Warning(
                _(
                  "Enter the archive filename with\nits absolute path, as in /tmp/backup.tar."
                )
              )
              cont = false
              next
            end

            if Builtins.regexpmatch(Backup.archive_name, "/")
              dir = Builtins.substring(
                Backup.archive_name,
                0,
                Builtins.findlastof(Backup.archive_name, "/")
              )

              # testing if the directory exists or if it is possible to create it
              error_message = IsPossibleToCreateDirectoryOrExists(dir)
              if error_message != ""
                Popup.Error(error_message)

                cont = false
                next
              end
            end

            if !Backup.multi_volume
              # check if archive can be (over)written
              cont = WriteArchive()

              if cont == nil
                # error popup message - NFS mount failed
                Popup.Error(_("Cannot mount the selected NFS share."))

                cont = false
              end
            elsif Backup.multi_volume # test if some volume part exists
              # list directory content
              dir = Builtins.substring(
                Backup.archive_name,
                0,
                Builtins.findlastof(Backup.archive_name, "/")
              )
              fn = Builtins.substring(
                Backup.archive_name,
                Ops.add(Builtins.findlastof(Backup.archive_name, "/"), 1)
              )

              Builtins.y2debug("dir: %1", dir)
              Builtins.y2debug("file: %1", fn)

              ls = Convert.convert(
                SCR.Read(path(".target.dir"), dir),
                :from => "any",
                :to   => "list <string>"
              )

              matched = false

              conflict_file = ""

              # check if some volume part exists
              Builtins.foreach(ls) do |f|
                if Builtins.regexpmatch(f, Ops.add("d*_", fn)) == true
                  if matched == false
                    matched = true
                    conflict_file = f
                  end
                end
              end 


              Builtins.y2debug("found volume part: %1", conflict_file)

              # display question
              if matched == true
                # For translators %1 is volume file name (e.g. /tmp/01_backup.tar)
                cont = Popup.YesNo(
                  Builtins.sformat(
                    _(
                      "The existing file %1 could become part of new volume set and be overwritten.\nReally continue?"
                    ),
                    Ops.add(Ops.add(dir, "/"), conflict_file)
                  )
                )
              else
                cont = true
              end
            else
              cont = true
            end
          elsif ret == :back
            # backup profile is a new profile, just created
            if Backup.profile_is_new_one
              ret = :back
              cont = AbortNewProfileCreation(Backup.selected_profile)
            else
              ret = :back
              cont = true
            end
          elsif ret == :abort || ret == :cancel
            ret = :abort
            cont = AbortConfirmation(:changed)
          elsif ret == :only_list || ret == :archive
            refresh_widget_status(ret == :archive)
          elsif ret == :file || ret == :nfs
            update_location_dialog

            Backup.target_type = ret
          # select NFS server
          elsif ret == :selecthost
            srv = NetworkPopup.NFSServer(Backup.nfsserver)

            if srv != nil
              UI.ChangeWidget(Id(:nfsserver), :Value, srv)
              Backup.nfsserver = srv
            end
          # select NFS export
          elsif ret == :selectexport
            server = Convert.to_string(UI.QueryWidget(Id(:nfsserver), :Value))

            if Ops.greater_than(Builtins.size(server), 0)
              exp = NetworkPopup.NFSExport(server, Backup.nfsexport)

              if exp != nil
                UI.ChangeWidget(Id(:nfsexport), :Value, exp)
                Backup.nfsexport = exp
              end
            else
              Popup.Message(_("Enter a server name."))
            end
          else
            cont = true
          end
        end
      end

      # get values
      Backup.archive_type = Convert.to_symbol(
        UI.QueryWidget(Id(:rbgroup), :CurrentButton)
      ) == :archive ?
        Convert.to_symbol(UI.QueryWidget(Id(:type), :Value)) :
        :txt

      if ret == :opts
        if Builtins.contains(
            [:tar, :tgz, :tbz, :stgz, :stbz, :star],
            Backup.archive_type
          )
          ret = :tar_opt
        end
      end

      @last_input = ret
      ret
    end


    # Setting multi volume archive options
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def TarOptionsDialog
      description_combo = MediaList2UIList(Backup.media_descriptions)
      # combo box item - user defined volume size of archive
      description_combo = Builtins.add(
        description_combo,
        Item(Id(:user_defined), _("Custom"))
      )

      Builtins.y2milestone("%1", description_combo)

      description_combo_units = MediaList2UIList(Backup.units_description)
      Builtins.y2milestone("%1", description_combo_units)

      # dialog header
      Wizard.SetContents(
        _("Archive File Options"),
        VBox(
          VSpacing(0.5),
          # frame label
          Frame(
            _("Multivolume Archive"),
            VBox(
              VSpacing(Opt(:hstretch), 0.5),
              # check box label
              Left(
                CheckBox(
                  Id(:multi_volume),
                  Opt(:notify),
                  _("&Create a Multivolume Archive"),
                  Backup.multi_volume
                )
              ),
              VSpacing(0.5),
              HBox(
                HSpacing(3.5),
                VBox(
                  # combo box label
                  Left(
                    ComboBox(
                      Id(:vol),
                      Opt(:notify),
                      _("&Volume Size"),
                      description_combo
                    )
                  ),
                  VSpacing(0.5),
                  Left(
                    VSquash(
                      HBox(
                        # text entry label
                        Bottom(
                          InputField(
                            Id(:user_size),
                            Opt(:hstretch),
                            _("Custom &Size")
                          )
                        ),
                        HSpacing(1),
                        Bottom(
                          ComboBox(Id(:user_unit), "", description_combo_units)
                        ),
                        HStretch()
                      )
                    )
                  ),
                  VSpacing(0.5)
                ),
                HSpacing(1.0)
              )
            )
          ),
          VSpacing(1.0)
        ),
        backup_help_archive_options,
        true,
        true
      )

      # replace 'Next' button with 'Ok'
      Wizard.SetNextButton(:ok, Label.OKButton)
      UI.SetFocus(Id(:ok))

      # allow only digits in the text entry
      UI.ChangeWidget(Id(:user_size), :ValidChars, "0123456789")

      Backup.volume_size = :fd144 if Backup.volume_size == nil
      UI.ChangeWidget(Id(:vol), :Value, Backup.volume_size)

      tmp_size = ""
      tmp_size = Backup.user_volume_size if Backup.user_volume_size != nil
      UI.ChangeWidget(Id(:user_size), :Value, tmp_size)

      Backup.user_volume_unit = :B if Backup.user_volume_unit == nil
      UI.ChangeWidget(Id(:user_unit), :Value, Backup.user_volume_unit)

      SetMultiWidgetsState()

      cont = false
      ret = nil

      while !cont
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :ok
          if Convert.to_boolean(UI.QueryWidget(Id(:multi_volume), :Value)) == true &&
              Convert.to_symbol(UI.QueryWidget(Id(:vol), :Value)) == :user_defined &&
              Ops.less_than(
                Ops.divide(
                  Ops.multiply(
                    Builtins.tofloat(UI.QueryWidget(Id(:user_size), :Value)),
                    Builtins.tofloat(
                      Backup.GetCapacity(
                        Backup.units_description,
                        Convert.to_symbol(
                          UI.QueryWidget(Id(:user_unit), :Value)
                        )
                      )
                    )
                  ),
                  1024.0
                ),
                10.0
              )
            # warning popup message
            Popup.Warning(_("Volume size must be at least 10240 bytes."))
          else
            cont = true

            Backup.multi_volume = Convert.to_boolean(
              UI.QueryWidget(Id(:multi_volume), :Value)
            )
            Backup.volume_size = Convert.to_symbol(
              UI.QueryWidget(Id(:vol), :Value)
            )
            Backup.user_volume_size = Convert.to_string(
              UI.QueryWidget(Id(:user_size), :Value)
            )
            Backup.user_volume_unit = Convert.to_symbol(
              UI.QueryWidget(Id(:user_unit), :Value)
            )
          end
        else
          if ret == :multi_volume || ret == :vol
            SetMultiWidgetsState()
          else
            if ret == :abort || ret == :cancel
              ret = :abort
              cont = AbortConfirmation(:changed)
            else
              cont = true
            end
          end
        end
      end

      # Restore 'next' button
      Wizard.RestoreNextButton

      ret
    end


    # Dialog for setting backup options
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def BackupDialog
      # do not allow manual changes of configuration
      return :next2 if Backup.no_interactive

      # dialog header
      Wizard.SetContents(
        _("Backup Options"),
        VBox(
          VSpacing(0.5),
          #rwalter consider whether this frame and the next should be eliminated to simplify the dialog
          # frame label
          Frame(
            _("File Selection"),
            VBox(
              VSpacing(0.3),
              # check box label
              Left(
                CheckBox(
                  Id(:search),
                  Opt(:notify),
                  _("&Back Up Files Not Belonging to Any Package"),
                  Backup.do_search
                )
              ),
              # check box label
              Left(
                CheckBox(
                  Id(:all_rpms_content),
                  Opt(:notify),
                  _("Back up Content of &All Packages"),
                  Backup.backup_all_rpms_content
                )
              ),
              VSpacing(0.3),
              # check box label
              Left(
                CheckBox(
                  Id(:display),
                  _("Display List of Files Before &Creating Archive"),
                  Backup.display
                )
              ),
              VSpacing(0.3)
            )
          ),
          VSpacing(0.5),
          # frame label
          Frame(
            _("Search Options"),
            VBox(
              VSpacing(0.3),
              # frame label
              Left(
                CheckBox(
                  Id(:md5_check),
                  _("Check MD&5 Sum instead of Time or Size"),
                  Backup.do_md5_test
                )
              ),
              VSpacing(0.3)
            )
          ),
          VSpacing(0.3),
          # multi line widget label
          MultiLineEdit(
            Id(:description),
            _("Archive &Description"),
            Backup.description
          ),
          VSpacing(0.3),
          PushButton(Id(:xpert), _("E&xpert...")),
          VSpacing(0.5)
        ),
        backup_help_backup_setting,
        true,
        true
      )

      ret = nil

      while ret != :next && ret != :abort && ret != :back && ret != :xpert
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort || ret == :cancel
          ret = :abort
          if !AbortConfirmation(:changed)
            ret = nil # not confirmed, unset ret
          end
        end
      end

      # get values
      Backup.backup_all_rpms_content = Convert.to_boolean(
        UI.QueryWidget(Id(:all_rpms_content), :Value)
      )
      Backup.do_search = Convert.to_boolean(UI.QueryWidget(Id(:search), :Value))
      Backup.display = Convert.to_boolean(UI.QueryWidget(Id(:display), :Value))
      Backup.do_md5_test = Convert.to_boolean(
        UI.QueryWidget(Id(:md5_check), :Value)
      )
      Backup.description = Convert.to_string(
        UI.QueryWidget(Id(:description), :Value)
      )

      ret
    end


    # System area backup options
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def SystemBackupDialog
      if Backup.detected_ext2 == nil
        # status message - label
        Wizard.SetContents(
          "",
          Label(_("Detecting mounted ext2 file systems...")),
          "",
          false,
          false
        )
        Backup.detected_ext2 = Ext2Filesystems()
        Backup.ext2_backup = AddIdExt2(Backup.detected_ext2)
      end

      # dialog header
      Wizard.SetContents(
        _("System Area Backup"),
        VBox(
          VSpacing(0.5),
          # frame label
          Frame(
            _("Partition Table"),
            VBox(
              VSpacing(0.4),
              # check box label
              CheckBox(
                Id(:pt),
                Opt(:hstretch),
                _("Ba&ck Up Partition Tables"),
                Backup.backup_pt
              ),
              VSpacing(0.4)
            )
          ),
          VSpacing(0.5),
          # frame label
          Frame(
            _("Ext2 File System Critical Area Backup"),
            RadioButtonGroup(
              Id(:rbg),
              VBox(
                VSpacing(0.3),
                # radio button label
                Left(
                  RadioButton(
                    Id(:none),
                    Opt(:notify),
                    _("N&one"),
                    Backup.backup_none_ext2
                  )
                ),
                VSpacing(0.3),
                # radio button label
                Left(
                  RadioButton(
                    Id(:allmounted),
                    Opt(:notify),
                    _("All &Mounted"),
                    Backup.backup_all_ext2
                  )
                ),
                VSpacing(0.3),
                # radio button label
                Left(
                  RadioButton(
                    Id(:selected),
                    Opt(:notify),
                    _("&Selected"),
                    Backup.backup_selected_ext2
                  )
                ),
                HBox(
                  HSpacing(3.0),
                  VBox(
                    # table header
                    Table(
                      Id(:par),
                      Header(_("Ext2 Partition"), _("Mount Point")),
                      Backup.ext2_backup
                    ),
                    Left(
                      HBox(
                        # push button label
                        PushButton(Id(:addnew), Opt(:key_F3), _("A&dd...")),
                        # push button label
                        PushButton(Id(:edit), Opt(:key_F4), _("&Edit...")),
                        # push button label
                        PushButton(Id(:delete), Opt(:key_F5), _("De&lete"))
                      )
                    )
                  ),
                  HSpacing(2.0)
                ),
                VSpacing(0.4)
              )
            )
          ),
          VSpacing(1.0)
        ),
        backup_help_system_backup,
        true,
        true
      )

      Wizard.SetNextButton(:finish, Label.OKButton)
      UI.SetFocus(Id(:finish))

      UI.ChangeWidget(Id(:par), :Enabled, Backup.backup_selected_ext2)
      UI.ChangeWidget(Id(:addnew), :Enabled, Backup.backup_selected_ext2)

      # Enable the buttons only if they are of any use
      enable_modif_buttons = Ops.greater_than(
        Builtins.size(Backup.ext2_backup),
        0
      )

      UI.ChangeWidget(Id(:edit), :Enabled, enable_modif_buttons)
      UI.ChangeWidget(Id(:delete), :Enabled, enable_modif_buttons)

      ret = nil

      while ret != :finish && ret != :back && ret != :abort
        ret = Convert.to_symbol(UI.UserInput)

        curr = Convert.to_string(UI.QueryWidget(Id(:par), :CurrentItem))
        if curr != nil
          if ret == :edit
            edited = ShowEditDialog(Label.EditButton, curr, nil, [])

            if Ops.get(edited, "clicked") == :ok
              txt = Ops.get_string(edited, "text", "")
              dir = Ext2MountPoint(txt)

              if txt != curr
                if Builtins.contains(
                    Backup.ext2_backup,
                    Item(Id(txt), txt, dir)
                  )
                  # error popup message, %1 is partition name (e.g. /dev/hda1)
                  Popup.Error(
                    Builtins.sformat(
                      _("Partition %1 is already in the list."),
                      txt
                    )
                  )
                else
                  # refresh ext2_backup content
                  Backup.ext2_backup = Builtins.maplist(Backup.ext2_backup) do |i|
                    tmp = Ops.get_string(i, [0, 0], "")
                    if tmp == curr
                      next Item(Id(txt), txt, dir)
                    else
                      next deep_copy(i)
                    end
                  end

                  # refresh table content
                  UI.ChangeWidget(Id(:par), :Items, Backup.ext2_backup)

                  Builtins.y2debug("ext2: %1", Backup.ext2_backup)
                end
              end
            end
          end

          if ret == :delete
            next if !Confirm.DeleteSelected

            Backup.ext2_backup = Builtins.filter(Backup.ext2_backup) do |i|
              tmp = Ops.get_string(i, [0, 0], "")
              tmp != curr
            end
            UI.ChangeWidget(Id(:par), :Items, Backup.ext2_backup)
          end
        end

        if ret == :addnew
          detected_ext2_strings = []

          Builtins.foreach(Backup.detected_ext2) do |info|
            part = Ops.get_string(info, "partition")
            if part != nil
              detected_ext2_strings = Builtins.add(detected_ext2_strings, part)
            end
          end 


          # popup dialog header
          result = ShowEditDialog(
            _("&Add Ext2 Partition"),
            "",
            detected_ext2_strings,
            []
          )

          if Ops.get_symbol(result, "clicked") == :ok
            sz = Builtins.size(Backup.ext2_backup)
            new_par = Ops.get_string(result, "text")
            dir = Ext2MountPoint(new_par)

            # add new partition only if it's not empty a it isn't already in list
            if new_par != "" && new_par != nil
              if Builtins.contains(
                  Backup.ext2_backup,
                  Item(Id(new_par), new_par, dir)
                )
                # error popup message, %1 is partition name (e.g. /dev/hda1)
                Popup.Error(
                  Builtins.sformat(
                    _("Partition %1 is already in the list."),
                    new_par
                  )
                )
              else
                Backup.ext2_backup = Builtins.add(
                  Backup.ext2_backup,
                  Item(Id(new_par), new_par, dir)
                )
                UI.ChangeWidget(Id(:par), :Items, Backup.ext2_backup)

                Builtins.y2debug("ext2: %1", Backup.ext2_backup)
              end
            end
          end
        end

        # Enable the buttons only if they are of any use
        enable_modif_buttons = Ops.greater_than(
          Builtins.size(Backup.ext2_backup),
          0
        )

        UI.ChangeWidget(Id(:edit), :Enabled, enable_modif_buttons)
        UI.ChangeWidget(Id(:delete), :Enabled, enable_modif_buttons)

        if ret == :allmounted || ret == :selected || ret == :none
          Backup.backup_all_ext2 = Convert.to_boolean(
            UI.QueryWidget(Id(:allmounted), :Value)
          )
          Backup.backup_none_ext2 = Convert.to_boolean(
            UI.QueryWidget(Id(:none), :Value)
          )
          Backup.backup_selected_ext2 = Convert.to_boolean(
            UI.QueryWidget(Id(:selected), :Value)
          )

          UI.ChangeWidget(Id(:par), :Enabled, Backup.backup_selected_ext2)
          UI.ChangeWidget(Id(:addnew), :Enabled, Backup.backup_selected_ext2)
          UI.ChangeWidget(Id(:edit), :Enabled, Backup.backup_selected_ext2)
          UI.ChangeWidget(Id(:delete), :Enabled, Backup.backup_selected_ext2)
        end

        if ret == :abort || ret == :cancel
          ret = :abort
          if !AbortConfirmation(:changed)
            ret = nil # not confirmed, uset ret
          end
        end
      end

      Backup.backup_pt = Convert.to_boolean(UI.QueryWidget(Id(:pt), :Value))

      Wizard.RestoreNextButton

      ret
    end

    # Check whether there is enough free space.
    # @param [Fixnum] required required space in kB
    # @param [Fixnum] available required space in kB
    # @param [Symbol] target_type selected target archive type
    # @return [Boolean] true = there is enough free space, false = not enough free space,
    #   nil = may be not enough space (compression is used, impossible to tell exactly)

    def is_space(required, available, target_type)
      Builtins.y2milestone("Checking free space for the backup.")

      return false if Ops.less_than(available, 0)

      if Builtins.contains([:tgz, :stgz, :tbz, :stbz], target_type)
        # require at least 10M extra free space (overhead)
        required = Ops.add(required, 10240)
        Builtins.y2milestone("Required: %1, Available: %2", required, available)
        return Ops.less_than(required, available) ? true : nil
      elsif target_type == :tar || target_type == :star
        # require at least 10M extra free space (overhead)
        required = Ops.add(required, 10240)
        Builtins.y2milestone("Required: %1, Available: %2", required, available)
        return Ops.less_than(required, available)
      elsif target_type == :txt
        # require at least 500k extra free space (overhead)
        required = Ops.add(required, 500)
        Builtins.y2milestone("Required: %1, Available: %2", required, available)
        return Ops.less_than(required, available)
      else
        Builtins.y2warning("Unknown archive type: %1", target_type)
        Builtins.y2milestone("Required: %1, Available: %2", required, available)
      end

      nil
    end

    # Display warning dialog - there is (may) not enough free space in the directory.
    # The dialog is not displayed when cron mode is active (there is no real UI).
    # @param [String] dir directory
    # @param [Boolean] fits if true no dialog is displayed, if false display "there is no space",
    # if nil display "there may not be space"
    # @return [Boolean] false = abort backup

    def display_free_space_warning(fits, dir)
      cont = true

      # don't ask in cron mode - there is no UI
      # always continue, summary mail with fail message
      # will be sent to root user
      return cont if Backup.cron_mode == true

      if fits == false
        # there is no enough space
        cont = Popup.YesNo(
          Builtins.sformat(
            _(
              "There is not enough free space in directory %1.\nContinue anyway?\n"
            ),
            dir
          )
        )
      elsif fits == nil
        # may be that there is not enough space
        cont = Popup.YesNo(
          Builtins.sformat(
            _(
              "There may not be enough free space in directory %1.\nContinue anyway?\n"
            ),
            dir
          )
        )
      end

      cont
    end

    # Check available free space and decide whether archive will fit
    # @param [Fixnum] found_size total size of found files in bytes
    # @param [String] tmp_dir selected temporary directory
    # @param [String] target_dir target archive directory
    # @param [Symbol] target_type target archive type
    # @return [Boolean] true = archive fits, false = it doesn't fit,
    #    nil = may not fit (compression is used, there is no guarantee that
    #    archive will fit but it can be possible if compression ratio will
    #    be enough high

    def check_space(found_size, tmp_dir, target_dir, target_type)
      # required size in 1024-blocks
      found_size = Ops.divide(found_size, 1024)

      available_tmp = get_free_space(tmp_dir)
      available_target = get_free_space(target_dir)

      if Builtins.size(available_target) == 0 ||
          Builtins.size(available_tmp) == 0
        return true
      end

      fits = true

      # temporary and target directories are same
      if Ops.get_string(available_tmp, "device") ==
          Ops.get_string(available_target, "device")
        free = Ops.get_integer(available_target, "free", 0)
        # required space is doubled (tmpdir + target_dir)
        required = Ops.add(found_size, found_size)

        fits = is_space(required, free, target_type)

        return false if display_free_space_warning(fits, target_dir) == false
      else
        # temporary location and target directories are different
        fits = is_space(
          found_size,
          Ops.get_integer(available_target, "free", 0),
          target_type
        )
        return false if display_free_space_warning(fits, target_dir) == false

        fits = is_space(
          found_size,
          Ops.get_integer(available_tmp, "free", 0),
          target_type
        )
        return false if display_free_space_warning(fits, tmp_dir) == false
      end

      true
    end

    # Sets dialog contents - Searching for Modified Files
    # @param [Fixnum] total_packages
    def SetDialogContents_SearchingForModifiedFiles(total_packages)
      Builtins.y2milestone("Progress Packages: %1", total_packages)
      Wizard.SetContents(
        # dialog header
        _("Searching for Modified Files"),
        VBox(
          VSpacing(0.5),
          Left(
            # label text, followed by number of files found so far
            Label(
              Id(:numfiles),
              Ops.add(
                _("Modified Files: "),
                Builtins.sformat("%1", @modified_num)
              )
            )
          ),
          VSpacing(0.5),
          Left(
            # label text, followed by sizes of files
            Label(
              Id(:totsize),
              Ops.add(_("Total Size: "), String.FormatSize(@modified_size))
            )
          ),
          VSpacing(0.5),
          Left(
            # label text, followed by name of current package
            Label(
              Id(:package),
              _("Searching in Package: ") + "                            "
            )
          ),
          VSpacing(3.0),
          Left(
            # bug #172406
            MinSize(
              42,
              2,
              VBox(
                HStretch(),
                # progress bar label
                ProgressBar(
                  Id(:progress),
                  Opt(:hstretch),
                  _("Search"),
                  total_packages
                )
              )
            )
          ),
          VStretch()
        ),
        backup_help_searching_modified,
        false,
        false
      )
      UI.RecalcLayout

      nil
    end

    # Initializes variables before the SearchingModifiedDialog
    def InitSearchingModifiedDialog
      if !Backup.cron_mode
        Wizard.ClearContents
        Wizard.SetContents(
          "",
          # label text
          Label(_("Reading packages available at the software repositories...")),
          backup_help_searching_modified,
          false,
          false
        )
      end

      # read list of available packages at the original installation sources
      Backup.ReadInstallablePackages

      # initialize list of completely backed up packages
      Backup.complete_backup = []

      @selected_pkg_num = 0

      Backup.selected_files = {}

      nil
    end


    # Takes care about installed packages
    def Search_ProcessInstalledPackages
      if Builtins.substring(@line, 0, Builtins.size(@id_packages_num)) == @id_packages_num
        @reading_installed_packages = false
        @total_packages = Builtins.tointeger(
          Builtins.substring(@line, Builtins.size(@id_packages_num))
        )

        Builtins.y2milestone(
          "Number of installed packages: %1",
          @total_packages
        )
      end

      nil
    end

    def Search_ChangedPackageFiles
      # store package's changed files
      if Ops.greater_than(Builtins.size(@package_files), 0)
        Ops.set(
          Backup.selected_files,
          @actual_package,
          {
            "changed_files"    => @package_files,
            "install_prefixes" => @actual_instprefixes
          }
        )
        @package_files = []
        @selected_pkg_num = Ops.add(@selected_pkg_num, 1)
      end

      complete = Builtins.substring(
        @line,
        0,
        Builtins.size(@id_complete_package)
      ) == @id_complete_package
      @actual_package = complete ?
        Builtins.substring(@line, Builtins.size(@id_complete_package)) :
        Builtins.substring(@line, Builtins.size(@id_package))

      if complete == true
        Builtins.y2debug("Complete package: %1", @actual_package)
        Backup.complete_backup = Builtins.add(
          Backup.complete_backup,
          @actual_package
        )
      end
      @package_num = Ops.add(@package_num, 1)

      # Do not refresh UI in cron mode
      return if Backup.cron_mode

      @ui_time_now = Builtins.time

      # BNC#756493: Refresh the UI max. once per second
      # Otherwise it uses too much CPU on faster systems / disks
      if Ops.greater_than(@ui_time_now, @ui_last_refresh)
        @ui_last_refresh = @ui_time_now

        UI.ChangeWidget(
          Id(:package),
          :Value,
          Ops.add(_("Searching in Package: "), @actual_package)
        )
        UI.ChangeWidget(Id(:progress), :Value, @package_num)
        # bug #172406
        # Cannot be used for ncurses
        UI.RecalcLayout if !@in_ncurses
      end

      nil
    end

    # Updates UI: Modified files size and count
    def Search_UpdateFilesAndSize(modified_size, modified_num)
      # There's no UI in cron mode
      return if Backup.cron_mode

      @ui_time_now = Builtins.time

      if Ops.greater_than(@ui_time_now, @ui_last_refresh)
        @ui_last_refresh = @ui_time_now

        UI.ChangeWidget(
          Id(:totsize),
          :Value,
          Ops.add(_("Total Size: "), String.FormatSize(modified_size.value))
        )
        UI.ChangeWidget(
          Id(:numfiles),
          :Value,
          Ops.add(
            _("Modified Files: "),
            Builtins.sformat("%1", modified_num.value)
          )
        )
      end

      nil
    end

    # Updates UI while searching for modified files
    def Search_ModifiedFiles
      @line = Builtins.substring(@line, Builtins.size(@id_file))

      size_str = Builtins.substring(@line, 0, Builtins.findfirstof(@line, " "))
      @modified_size = Ops.add(@modified_size, Builtins.tointeger(size_str))
      @modified_num = Ops.add(@modified_num, 1)

      modified_size_ref = arg_ref(@modified_size)
      modified_num_ref = arg_ref(@modified_num)
      Search_UpdateFilesAndSize(modified_size_ref, modified_num_ref)
      @modified_size = modified_size_ref.value
      @modified_num = modified_num_ref.value

      found_file = Builtins.substring(
        @line,
        Ops.add(Builtins.findfirstof(@line, " "), 1)
      )

      # escape newlines in file name
      # double backslashes
      parts = Builtins.splitstring(found_file, "\\")
      escaped = Builtins.mergestring(parts, "\\\\")

      # change newline to \n
      parts = Builtins.splitstring(escaped, "\n")
      escaped = Builtins.mergestring(parts, "\\n")

      # add file to list of found files
      @package_files = Builtins.add(@package_files, escaped)

      nil
    end

    def Search_NonPackageFile
      if Ops.greater_than(Builtins.size(@package_files), 0)
        Ops.set(
          Backup.selected_files,
          @actual_package,
          {
            "changed_files"    => @package_files,
            "install_prefixes" => @actual_instprefixes
          }
        )
        @package_files = []
        @selected_pkg_num = Ops.add(@selected_pkg_num, 1)
      end

      @actual_package = "" # empty package name
      @search_no_package = true # no package part of output

      Builtins.y2milestone(
        "Searching files which are not in any package started"
      )

      nil
    end

    # Reads list of packages files, installed packages
    def Search_ReadListOfFilesAndPackages
      if @line == @id_reading_files
        if !Backup.cron_mode
          # label text
          Wizard.SetContents(
            "",
            Label(_("Reading packages files...")),
            backup_help_searching_modified,
            false,
            false
          )
        end
      else
        if @line == @id_reading_packages
          Builtins.y2milestone("Reading installed packages")

          if !Backup.cron_mode
            # label text
            Wizard.SetContents(
              "",
              Label(_("Reading list of installed packages...")),
              backup_help_searching_modified,
              false,
              false
            )
          end

          @reading_installed_packages = true
        else
          if @line == @id_files_read
            if !Backup.cron_mode
              SetDialogContents_SearchingForModifiedFiles(@total_packages)
              UI.RecalcLayout
            end

            Builtins.y2milestone("Searching in packages started")
          else
            Builtins.y2warning("Unknown output from search script: %1", @line)
          end
        end
      end

      nil
    end

    # Function sets the dialog contents before searching files...
    def SetDialogContents_SearchingFiles
      # dialog header
      Wizard.SetContents(
        _("Searching Files"),
        VBox(
          HStretch(),
          VSpacing(0.5),
          Left(
            # label text, followed by value
            Label(
              Id(:numfiles),
              Ops.add(_("Modified Files: "), Builtins.sformat("%1", @nopkg_num))
            )
          ),
          VSpacing(0.5),
          Left(
            # label text, followed by value
            Label(
              Id(:totsize),
              Ops.add(_("Total Size: "), String.FormatSize(@nopkg_size))
            )
          ),
          VSpacing(0.5),
          Left(
            # bug #172406
            MinSize(
              42,
              1,
              # label text, followed by current directory name
              Label(
                Id(:directory),
                _("Searching in Directory: ") +
                  "                                                            "
              )
            )
          )
        ),
        backup_help_searching_files,
        false,
        false
      )
      UI.RecalcLayout

      nil
    end

    # Function might be removed, only for testing memory spent...
    def MemorySpent
      command = "LC_ALL=C /bin/ps auxw | grep \"\\(y2base\\|^USER\\)\" | grep -v \"grep\""
      run_ps = Convert.convert(
        SCR.Execute(path(".target.bash_output"), command),
        :from => "any",
        :to   => "map <string, any>"
      )
      if Ops.get_integer(run_ps, "exit", 0) != 0
        Builtins.y2warning(
          "MemorySpent Error: '%1'",
          Ops.get_string(run_ps, "stderr", "")
        )
      end
      Ops.get_string(run_ps, "stdout", "")
    end

    def CallPrePostBackupScripts(scripts_to_call, dialog_caption)
      scripts_to_call = deep_copy(scripts_to_call)
      Builtins.y2milestone("Running scripts: %1", scripts_to_call)

      Wizard.SetContents(
        dialog_caption,
        VBox(
          LogView(Id("script_log"), _("User-Defined Scripts Output"), 18, 1024)
        ),
        " ",
        false,
        false
      )
      UI.RecalcLayout

      dialog_ret = true
      ui_wait_time = 100

      Builtins.foreach(scripts_to_call) do |script_to_call|
        script = Ops.get_string(script_to_call, "path", "")
        if script == nil || script == ""
          Builtins.y2error("Cannot run script %1", script_to_call)
          next
        end
        Builtins.y2milestone("Running script %1", script)
        UI.ChangeWidget(
          Id("script_log"),
          :LastLine,
          Builtins.sformat(_("Starting script %1...\n"), script)
        )
        script_PID = Convert.to_integer(
          SCR.Execute(
            path(".process.start_shell"),
            script,
            { "C_locale" => true }
          )
        )
        Builtins.y2milestone("Script started with PID %1", script_PID)
        if script_PID == nil || script_PID == 0
          Builtins.y2error("Cannot start script %1", script)
          Report.Error(Builtins.sformat(_("Cannot start %1 script\n"), script))
          next
        end
        ret = nil
        line = nil
        errline = nil
        # something might be still in the buffer(s)
        last_line_non_empty = nil
        while Convert.to_boolean(SCR.Read(path(".process.running"), script_PID)) ||
            !Convert.to_boolean(
              SCR.Read(path(".process.buffer_empty"), script_PID)
            ) ||
            last_line_non_empty == true
          last_line_non_empty = false

          line = Convert.to_string(
            SCR.Read(path(".process.read_line"), script_PID)
          )
          if line != nil
            UI.ChangeWidget(Id("script_log"), :LastLine, Ops.add(line, "\n"))
            last_line_non_empty = true
          end

          errline = Convert.to_string(
            SCR.Read(path(".process.read_line_stderr"), script_PID)
          )
          if errline != nil
            UI.ChangeWidget(Id("script_log"), :LastLine, Ops.add(errline, "\n"))
            last_line_non_empty = true
          end

          if Backup.cron_mode
            if Convert.to_boolean(
                SCR.Read(path(".process.buffer_empty"), @backup_PID)
              ) == true
              Builtins.sleep(@wait_time)
            end
          else
            ret = UI.PollInput

            if ret == :abort || ret == :cancel
              Builtins.y2warning("Abort pressed")
              ret = :abort

              if AbortConfirmation(:changed)
                SCR.Execute(path(".process.kill"), script_PID)
                dialog_ret = false
                break
              end
            end

            if line == nil && errline == nil
              if Convert.to_boolean(
                  SCR.Read(path(".process.buffer_empty"), @backup_PID)
                ) == true
                Builtins.sleep(ui_wait_time)
              end
            end
          end
        end
        SCR.Execute(path(".process.release"), script_PID)
        UI.ChangeWidget(Id("script_log"), :LastLine, "\n\n")
        raise Break if dialog_ret != true
      end

      dialog_ret
    end

    def CallScriptsBeforeBackup
      scripts_to_call = Builtins.filter(Backup.backup_helper_scripts) do |one_script|
        Ops.get_string(one_script, "type", "before") == "before"
      end

      if Ops.less_than(Builtins.size(scripts_to_call), 1)
        Builtins.y2milestone("No 'before' scripts to call...")
        return :next
      end

      if !CallPrePostBackupScripts(scripts_to_call, _("User-Defined Scripts"))
        Builtins.y2milestone("Aborting the backup")
        return :abort
      end

      :next
    end

    def CallScriptsAfterBackup
      scripts_to_call = Builtins.filter(Backup.backup_helper_scripts) do |one_script|
        Ops.get_string(one_script, "type", "before") != "before"
      end

      if Ops.less_than(Builtins.size(scripts_to_call), 1)
        Builtins.y2milestone("No 'after' scripts to call...")
        return :next
      end

      if !CallPrePostBackupScripts(scripts_to_call, _("User-Defined Scripts"))
        Builtins.y2milestone("Aborting the backup")
        return :abort
      end

      :next
    end

    def Search_ShowCurrentDir(actual_dir)
      # No update
      return if @dir_shown == actual_dir.value

      @dir_time_now = Builtins.time

      if Ops.greater_than(@dir_time_now, @dir_last_refresh)
        UI.ChangeWidget(
          Id(:directory),
          :Value,
          Ops.add(_("Searching in Directory: "), actual_dir.value)
        )
        @dir_last_refresh = @dir_time_now
        @dir_shown = actual_dir.value

        # BNC#172406: Cannot be used for ncurses
        UI.RecalcLayout if !@in_ncurses
      end

      nil
    end

    # Display progress of searching modified files in packages
    # @return [Symbol] Symbol for wizard sequencer - pressed button
    def SearchingModifiedDialog
      ResetGlobalVariables()
      InitSearchingModifiedDialog()

      Builtins.y2milestone(
        "Search script: %1",
        Ops.add(Backup.script_get_files, Backup.get_search_script_parameters)
      )

      # starting the searching script in the background
      @backup_PID = Convert.to_integer(
        SCR.Execute(
          path(".process.start_shell"),
          Ops.add(Backup.script_get_files, Backup.get_search_script_parameters),
          { "C_locale" => true }
        )
      )
      script_out = []

      started = @backup_PID != nil && Ops.greater_than(@backup_PID, 0)

      ret = nil

      Builtins.y2milestone(
        "subprocess started: %1 (PID: %2)",
        started,
        @backup_PID
      )

      if !started
        # error popup message
        Report.Error(
          _("Could not start the search script.\nAborting the backup.\n")
        )
        @line = ""
        while @line != nil
          @line = Convert.to_string(
            SCR.Read(path(".process.read_line_stderr"), @backup_PID)
          )
          Builtins.y2error("Error: %1", @line)
        end

        if Backup.cron_mode
          return :abort
        else
          return :maindialog
        end
      end

      search_time = Builtins.time

      # while background script runs
      while Convert.to_boolean(SCR.Read(path(".process.running"), @backup_PID)) ||
          !Convert.to_boolean(
            SCR.Read(path(".process.buffer_empty"), @backup_PID)
          )
        @line = Convert.to_string(
          SCR.Read(path(".process.read_line"), @backup_PID)
        ) # read line

        while @line != nil
          # reading installed packages until the last package is read
          if @reading_installed_packages
            Search_ProcessInstalledPackages()
          else
            if Builtins.substring(@line, 0, Builtins.size(@id_package)) == @id_package ||
                Builtins.substring(
                  @line,
                  0,
                  Builtins.size(@id_complete_package)
                ) == @id_complete_package
              Search_ChangedPackageFiles()
            else
              if Builtins.substring(@line, 0, Builtins.size(@id_file)) == @id_file
                @ui_last_refresh = 0
                Search_ModifiedFiles()
              else
                if @line == @id_nopackage
                  Search_NonPackageFile()
                  break
                else
                  if Builtins.substring(
                      @line,
                      0,
                      Builtins.size(@id_instprefixes)
                    ) == @id_instprefixes
                    @actual_instprefixes = Builtins.substring(
                      @line,
                      Builtins.size(@id_instprefixes)
                    )
                  else
                    Search_ReadListOfFilesAndPackages()
                  end
                end
              end
            end
          end

          @line = Convert.to_string(
            SCR.Read(path(".process.read_line"), @backup_PID)
          ) # read line
        end

        break if @search_no_package

        if Backup.cron_mode
          # BNC #568615: yast2 backup takes much longer when scheduled
          if Convert.to_boolean(
              SCR.Read(path(".process.buffer_empty"), @backup_PID)
            ) == true
            Builtins.sleep(@wait_time)
          end

          ret = nil
        else
          ret = waitForUserOrProcess(@wait_time, :changed)
        end

        return ret if ret != nil
      end
      # end of the 'while' backround script runs

      if Ops.greater_than(Builtins.size(@package_files), 0)
        Ops.set(
          Backup.selected_files,
          @actual_package,
          {
            "changed_files"    => @package_files,
            "install_prefixes" => @actual_instprefixes
          }
        )
        @selected_pkg_num = Ops.add(@selected_pkg_num, 1)
      end

      Builtins.y2milestone("All packages verified.")

      # searching files not belonging to any package
      if @search_no_package
        actual_dir = "/"

        # Strings are not localized on purpose: Used for matching output from
        # the searching script
        id_readingall = "Reading all files"
        id_readall = "Files read"
        id_dir = "Dir: "

        # Chached value
        size_id_dir = Builtins.size(id_dir)

        SetDialogContents_SearchingFiles() if !Backup.cron_mode

        @ui_last_refresh = 0

        package_files_part = []
        new_files = 0

        dir_shown = ""

        while Convert.to_boolean(
            SCR.Read(path(".process.running"), @backup_PID)
          ) ||
            !Convert.to_boolean(
              SCR.Read(path(".process.buffer_empty"), @backup_PID)
            )
          # test of script_out size is needed, because previous while cycle was interrupted and script could exited with no new output...
          @line = Convert.to_string(
            SCR.Read(path(".process.read_line"), @backup_PID)
          ) # read line
          next if @line == nil

          # --->
          if Builtins.substring(@line, 0, Builtins.size(@id_file)) == @id_file
            @line = Builtins.substring(@line, Builtins.size(@id_file))

            size_str = Builtins.substring(
              @line,
              0,
              Builtins.findfirstof(@line, " ")
            )
            size_line = nil
            if size_str != nil && size_str != ""
              size_line = Builtins.tointeger(size_str)
              @nopkg_size = Ops.add(@nopkg_size, size_line) if size_line != nil
            end

            @nopkg_num = Ops.add(@nopkg_num, 1)

            modified_size_ref = arg_ref(@modified_size)
            modified_num_ref = arg_ref(@modified_num)
            Search_UpdateFilesAndSize(modified_size_ref, modified_num_ref)
            @modified_size = modified_size_ref.value
            @modified_num = modified_num_ref.value

            found_file = Builtins.substring(
              @line,
              Ops.add(Builtins.findfirstof(@line, " "), 1)
            )

            # escape newlines in file name
            # double backslashes
            parts = Builtins.splitstring(found_file, "\\")
            escaped = Builtins.mergestring(parts, "\\\\")

            # change newline to \n
            parts = Builtins.splitstring(escaped, "\n")
            escaped = Builtins.mergestring(parts, "\\n")

            # add file to list of found files
            package_files_part = Builtins.add(package_files_part, escaped)
            new_files = Ops.add(new_files, 1)

            # merge more files in one step - it's faster
            if new_files == 1000
              @package_files = Builtins.merge(
                @package_files,
                package_files_part
              )
              package_files_part = []
              new_files = 0
            end
          else
            if !Backup.cron_mode
              if Builtins.substring(@line, 0, size_id_dir) == id_dir
                actual_dir = Builtins.substring(@line, size_id_dir)
              end
            end
          end

          actual_dir_ref = arg_ref(actual_dir)
          Search_ShowCurrentDir(actual_dir_ref)
          actual_dir = actual_dir_ref.value
          # <---

          script_out = []

          if Backup.cron_mode == true
            # BNC #568615: yast2 backup takes much longer when scheduled
            if Convert.to_boolean(
                SCR.Read(path(".process.buffer_empty"), @backup_PID)
              ) == true
              Builtins.sleep(@wait_time)
            end

            ret = nil
          else
            ret = waitForUserOrProcess(@wait_time, :changed)
          end

          if ret != nil
            return ret if AbortConfirmation(:changed) if ret == :abort
          end
        end

        Ops.set(
          Backup.selected_files,
          @actual_package,
          {
            "changed_files"    => Builtins.merge(
              @package_files,
              package_files_part
            ),
            "install_prefixes" => @actual_instprefixes
          }
        )
      end

      search_time = Ops.subtract(Builtins.time, search_time)
      Builtins.y2milestone("Searching done after %1 sec.", search_time)

      dparts = Builtins.splitstring(Backup.archive_name, "/")
      dparts = Builtins.remove(dparts, Ops.subtract(Builtins.size(dparts), 1))
      tdir = Builtins.mergestring(dparts, "/")

      # just for other functions
      Backup.target_dir = tdir

      # check available space
      if check_space(
          Ops.add(@nopkg_size, @modified_size),
          Backup.tmp_dir,
          Backup.target_dir,
          Backup.archive_type
        ) == false
        # there is no space, user selected not to continue
        if Backup.cron_mode
          return :abort
        else
          return :maindialog
        end
      end

      if Backup.display && !Backup.no_interactive
        Backup.selected_files = nil if Backup.selected_files == {}

        return :next
      else
        # skip the files listed in Backup::unselected_files
        if Backup.unselected_files != nil
          # try to find each file in selected files
          Builtins.foreach(Backup.unselected_files) do |file|
            new_selected = {}
            Builtins.foreach(Backup.selected_files) do |pak, val|
              changed_files = Ops.get_list(val, "changed_files", [])
              if Builtins.contains(changed_files, file)
                changed_files = Builtins.filter(changed_files) { |v| v != file }

                # construct new package description
                Ops.set(
                  Backup.selected_files,
                  [pak, "changed_files"],
                  changed_files
                )
                Ops.set(
                  Backup.selected_files,
                  [pak, "install_prefixes"],
                  Ops.get_list(val, "install_prefixes", [])
                )
              end
            end
          end
          Builtins.y2milestone(
            "Filtered out unselected files according to profile"
          )
        end

        # count number of files
        @selected_files_num = 0

        Builtins.foreach(Backup.selected_files) do |pak, val|
          @selected_files_num = Ops.add(
            @selected_files_num,
            Builtins.size(Ops.get_list(val, "changed_files", []))
          )
        end

        return Backup.display && !Backup.cron_mode ? :next : :next2 # `next2 = skip file selection dialog
      end
    end

    # Display found files, user can select files to backup
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def FilesDialog
      # busy message
      Wizard.SetContents(
        "",
        Label(_("Adding files to table...")),
        "",
        false,
        false
      )

      t1 = Builtins.time

      items = []
      items_filename = Ops.add(Directory.tmpdir, "/items-list.ycp")

      if FileUtils.Exists(items_filename)
        Builtins.y2milestone("Reading %1", items_filename)
        items = Convert.convert(
          SCR.Read(path(".target.ycp"), items_filename),
          :from => "any",
          :to   => "list <list>"
        )
      else
        Builtins.y2error("File %1 doesn't exist!", items_filename)
      end

      # dialog header
      Wizard.SetContents(
        _("File Selection"),
        VBox(
          VSpacing(0.5),
          # label text
          Left(Label(_("Files to Back Up"))),
          Table(
            Id(:table),
            Opt(:notify),
            # table header
            Header(" ", _("Filename"), _("Package")),
            []
          ),
          Left(
            HBox(
              # push button label
              PushButton(Id(:sel_file), _("Select or Deselect &File")),
              # push button label
              PushButton(Id(:sel_all), _("&Select All")),
              # push button label
              PushButton(Id(:desel_all), _("&Deselect All"))
            )
          ),
          VSpacing(1.0)
        ),
        backup_help_file_selection,
        true,
        true
      )

      # Items are pre-defined in the file
      items_filename_show = Ops.add(Directory.tmpdir, "/items.ycp")
      UI.ChangeWidget(
        Id(:table),
        :Items,
        FileUtils.Exists(items_filename_show) ?
          Convert.convert(
            SCR.Read(path(".target.ycp"), items_filename_show),
            :from => "any",
            :to   => "list <term>"
          ) :
          [Item(Id("none"), ["", _("Internal error"), ""])]
      )

      t2 = Builtins.time
      Builtins.y2milestone("UI finished after %1 seconds", Ops.subtract(t2, t1))

      # mark unselected files - use list from previous run
      if Ops.greater_than(Builtins.size(Backup.unselected_files), 0)
        t1 = Builtins.time
        # suppose that number of unselected files is much lower than number of
        # found files (otherwise we should iterate trough list of unselected
        # files)

        Builtins.y2milestone(
          "Found %1 unselected files",
          Builtins.size(Backup.unselected_files)
        )

        UI.OpenDialog(
          Left(
            Label(
              # busy message
              _("Deselecting files...")
            )
          )
        )
        Builtins.foreach(items) do |file_f|
          if Builtins.contains(
              Backup.unselected_files,
              Ops.get_string(file_f, 1)
            ) == true
            Builtins.y2debug(
              "Found previously unselected file: %1 (idx: %2)",
              Ops.get(file_f, 1),
              Ops.get(file_f, 0)
            )
            Ops.set(@deselected_ids, Ops.get_integer(file_f, 0), 1)
          end
        end 

        UI.CloseDialog

        Builtins.y2milestone(
          "searching unselected files was finished after %1 seconds",
          Ops.subtract(Builtins.time, t1)
        )
      end

      if Ops.greater_than(Builtins.size(@deselected_ids), 0)
        Builtins.y2milestone(
          "Deselecting %1 files",
          Builtins.size(@deselected_ids)
        )
        # remove selection mark for deselected files
        Builtins.foreach(@deselected_ids) do |idx, dummy_value|
          UI.ChangeWidget(Id(:table), term(:Item, idx, 0), " ")
        end
      end

      ret = nil
      changed = false

      while ret != :next && ret != :back && ret != :abort
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort || ret == :cancel
          ret = :abort
          if !AbortConfirmation(:changed)
            ret = nil # not confirmed
          else
            break
          end
        end

        current_item = Convert.to_integer(
          UI.QueryWidget(Id(:table), :CurrentItem)
        )

        if ret == :sel_all || ret == :desel_all
          UI.OpenDialog(
            Left(
              Label(
                ret == :sel_all ?
                  # An informative popup label during selecting all items in the table (can consume a lot of time)
                  _("Selecting all items...") :
                  # An informative popup label during deselecting all items in the table (can consume a lot of time)
                  _("Deselecting all items...")
              )
            )
          )

          if ret == :sel_all
            Backup.unselected_files = []
            @deselected_ids = {}
          else
            Backup.unselected_files = []

            Builtins.foreach(Backup.selected_files) do |pack, info|
              Backup.unselected_files = Convert.convert(
                Builtins.merge(
                  Backup.unselected_files,
                  Ops.get_list(info, "changed_files", [])
                ),
                :from => "list",
                :to   => "list <string>"
              )
            end 


            desel_num = Builtins.size(Backup.unselected_files)
            @deselected_ids = {}

            while Ops.greater_than(desel_num, 0)
              Ops.set(@deselected_ids, desel_num, 1)
              desel_num = Ops.subtract(desel_num, 1)
            end
          end

          UI.CloseDialog
          UI.ChangeWidget(
            Id(:table),
            :Items,
            ret == :sel_all ?
              Convert.convert(
                # selecting all
                SCR.Read(
                  path(".target.ycp"),
                  Ops.add(
                    Convert.to_string(SCR.Read(path(".target.tmpdir"))),
                    "/items.ycp"
                  )
                ),
                :from => "any",
                :to   => "list <term>"
              ) :
              Convert.convert(
                # deselecting all
                SCR.Read(
                  path(".target.ycp"),
                  Ops.add(
                    Convert.to_string(SCR.Read(path(".target.tmpdir"))),
                    "/items.ycp2"
                  )
                ),
                :from => "any",
                :to   => "list <term>"
              )
          )

          if current_item != nil
            UI.ChangeWidget(Id(:table), :CurrentItem, current_item)
          end

          changed = true
        else
          if ret == :table || ret == :sel_file
            table_item = Convert.to_term(
              UI.QueryWidget(Id(:table), term(:Item, current_item))
            )

            current_value = Ops.get_string(table_item, 1, @nocheckmark)
            file_name = Ops.get_string(table_item, 2, "unknown file")
            package_name = Ops.get_string(table_item, 3, "unknown package")

            if current_value == @checkmark
              current_value = @nocheckmark

              # add to unselected files
              if !Builtins.contains(Backup.unselected_files, file_name)
                Backup.unselected_files = Builtins.add(
                  Backup.unselected_files,
                  file_name
                )
                Ops.set(@deselected_ids, current_item, 1)
              end

              # remove from selected files
              info = Ops.get(Backup.selected_files, package_name, {})
              if Ops.greater_than(Builtins.size(info), 0)
                chfiles = Ops.get_list(info, "changed_files", [])
                chfiles = Builtins.filter(chfiles) { |fn| fn != file_name }

                Ops.set(
                  Backup.selected_files,
                  [package_name, "changed_files"],
                  chfiles
                )
              end
              Builtins.y2milestone(
                "File %1 removed from %2",
                file_name,
                package_name
              )
            else
              current_value = @checkmark

              # remove from unselected
              Backup.unselected_files = Builtins.filter(Backup.unselected_files) do |fn|
                fn != file_name
              end
              @deselected_ids = Builtins.remove(@deselected_ids, current_item)

              # add to selected
              info = Ops.get(Backup.selected_files, package_name, {})
              chfiles = Ops.get_list(info, "changed_files", [])

              if !Builtins.contains(chfiles, file_name)
                chfiles = Builtins.add(chfiles, file_name)

                Ops.set(
                  Backup.selected_files,
                  [package_name, "changed_files"],
                  chfiles
                )
              end

              Builtins.y2milestone(
                "File %1 added to %2",
                file_name,
                package_name
              )
            end

            # refresh table
            UI.ChangeWidget(
              Id(:table),
              term(:Item, current_item, 0),
              current_value
            )

            changed = true
          end
        end
      end

      return ret if ret == :abort

      # file selection was changed, update profile data
      if changed == true && Backup.selected_profile != nil
        Backup.StoreSettingsToBackupProfile(Backup.selected_profile)
      end

      return :back_from_files if ret == :back

      ret
    end

    def CreateProgress_ArchivingDialog
      # create Progress bar

      # progress stage
      stages1 = [_("Store host information")]
      # progress step
      stages2 = [_("Storing host information...")]

      @selected_info = Backup.MapFilesToString
      @selected_files_num = Ops.get_integer(@selected_info, "sel_files", 0)
      @selected_pkg_num = Ops.get_integer(@selected_info, "sel_packages", 0)

      # number of steps = number of selected files + nuber of selected packages (selected files added below)
      #			+ 6 files (comment, hostname, date, files, installed_packages, packages_info)
      #			+ 3 steps (comment, hostname, installed PRMs)
      #			+ 3 stages (storing files, creating package archives, creating big archive)
      num_stages = 12

      if Backup.system
        # progress stage
        stages1 = Builtins.add(stages1, _("Create system area backup"))
        # progress step
        stages2 = Builtins.add(stages2, _("Creating system area backup..."))

        num_stages = Ops.add(num_stages, 1) if Backup.backup_pt

        num_stages = Ops.add(num_stages, Builtins.size(Backup.ext2_backup))

        num_stages = Ops.add(num_stages, 1) # System backup stage
      end

      if Backup.multi_volume
        num_stages = Ops.add(num_stages, 1) # tar prints Volume label if multi volume selected, but only at first volume
      end

      if Backup.do_search
        num_stages = Ops.add(num_stages, 1) # add NOPACKAGE archive step
      end

      if Ops.greater_than(Builtins.size(Backup.complete_backup), 0)
        num_stages = Ops.add(num_stages, 1) # add complete list step
      end

      @stages_for_files = Ops.multiply(num_stages, 9)

      num_stages = Ops.add(num_stages, @stages_for_files)
      # last file-stage is 0%
      @last_file_stage = 0
      @this_file_stage = 0

      # progress stage
      stages1 = Builtins.add(stages1, _("Create package archives"))
      # progress stage
      stages1 = Builtins.add(stages1, _("Create target archive"))

      # progress step
      stages2 = Builtins.add(stages2, _("Creating package archives..."))
      # progress step
      stages2 = Builtins.add(stages2, _("Creating target archive..."))

      # progress stage
      stages1 = Builtins.add(stages1, _("Write autoinstallation profile"))
      # progress step
      stages2 = Builtins.add(stages1, _("Writing autoinstallation profile..."))

      if Backup.cron_mode == true
        Progress.set(false)
      else
        Builtins.y2milestone(
          "Creating progress dialog with %1 steps",
          num_stages
        )
        Progress.New(
          # progress
          _("Creating Archive"),
          " ",
          num_stages,
          stages1,
          stages2,
          backup_help_creating_archive
        )
      end

      nil
    end

    # Display progress of creating archive
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def ArchivingDialog
      # Creating Progress Bar/Steps
      CreateProgress_ArchivingDialog()

      ret = nil

      progress_count = Ops.add(@selected_pkg_num, @selected_files_num)
      progress_count = 1 if Ops.less_than(progress_count, 1)

      Builtins.y2milestone(
        "Number of selected packages: %1, selected files: %2",
        @selected_pkg_num,
        @selected_files_num
      )

      @file_list_stored = Ops.get_boolean(
        @selected_info,
        "file_list_stored",
        false
      )
      tmpfile_list = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/filelist"
      )

      # store comment to file
      tmpfile_comment = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/comment"
      )
      @comment_stored = SCR.Write(
        path(".target.string"),
        tmpfile_comment,
        Backup.description
      )

      Builtins.y2debug("%1", "Comment stored to file")
      Progress.NextStep

      if !@comment_stored
        Report.Warning(
          Builtins.sformat(
            _("Cannot write comment to file %1."),
            tmpfile_comment
          )
        )
      end

      @added_files = 0

      # prepare start
      Backup.PrepareBackup

      script_out = []

      @archived_num = 0
      tar_running = false

      id_storing_list = "Storing list"
      id_list_stored = "File list stored"

      @e2image_results = []
      @stored_ptables = []
      @created_archive_files = []

      last_out = nil
      system_stage_changed = false

      Builtins.y2milestone("Creating archive...")

      @backup_PID = Convert.to_integer(
        SCR.Execute(
          path(".process.start_shell"),
          Builtins.sformat(
            "%1 %2",
            Backup.script_create_archive,
            Backup.get_archive_script_parameters(tmpfile_list, tmpfile_comment)
          ),
          { "C_locale" => true }
        )
      )
      started = @backup_PID != nil && Ops.greater_than(@backup_PID, 0)

      if !started
        # error popup message
        Report.Error(
          _("Could not start archiving script.\nAborting the backup.\n")
        )
        return :abort
      end

      Backup.just_creating_archive = true

      @line = "-- just -- started --"
      # start while
      #
      # .running might return false
      # but there still might be some buffer left
      while Convert.to_boolean(SCR.Read(path(".process.running"), @backup_PID)) ||
          !Convert.to_boolean(
            SCR.Read(path(".process.buffer_empty"), @backup_PID)
          )
        @line = Convert.to_string(
          SCR.Read(path(".process.read_line"), @backup_PID)
        )
        next if @line == nil

        script_out = [@line]

        # script returned some lines, no check the free space
        if Ops.greater_than(Builtins.size(script_out), 0)
          @waiting_without_output = 0
        end

        while Ops.greater_than(Builtins.size(script_out), 0)
          line = Ops.get(script_out, 0) # read line
          script_out = Builtins.remove(script_out, 0) # remove line

          Builtins.y2debug("Archive script output: %1", line)

          if Backup.archive_type == :txt
            if line != id_storing_list
              if line == id_list_stored
                @stored_list = true

                Builtins.y2debug("List of files stored")
                Progress.NextStep
              else
                Builtins.y2warning(
                  "Unknown output from archive script: %1",
                  line
                )
              end
            end
          else
            if tar_running
              if Builtins.substring(line, 0, Builtins.size(@id_tar_exit)) == @id_tar_exit
                Builtins.y2milestone(
                  "Tar exit: %1\nErr: %2",
                  line,
                  SCR.Read(path(".process.read_stderr"), @backup_PID)
                )

                @tar_result = Builtins.tointeger(
                  Builtins.substring(line, Builtins.size(@id_tar_exit))
                )
              else
                if Builtins.substring(line, 0, Builtins.size(@id_new_volume)) == @id_new_volume
                  vol_name = Builtins.substring(
                    line,
                    Builtins.size(@id_new_volume)
                  )

                  # update NFS archive name
                  if Backup.target_type == :nfs
                    Builtins.y2milestone(
                      "vol_name: %1, nfsmount: %2, size(nfsmount):%3",
                      vol_name,
                      Backup.nfsmount,
                      Builtins.size(Backup.nfsmount)
                    )
                    location = Builtins.substring(
                      vol_name,
                      Builtins.size(Backup.nfsmount)
                    )
                    vol_name = Ops.add(
                      Ops.add(Ops.add(Backup.nfsserver, ":"), Backup.nfsexport),
                      location
                    )
                    Builtins.y2debug("Volume name: %1", vol_name)
                  end

                  @created_archive_files = Builtins.add(
                    @created_archive_files,
                    vol_name
                  )
                elsif line == @id_creating_target
                  Builtins.y2debug("Creating target archive")
                  Progress.NextStage
                elsif Builtins.substring(
                    line,
                    0,
                    Builtins.size(@id_not_readable)
                  ) == @id_not_readable
                  @not_readable_files = Builtins.add(
                    @not_readable_files,
                    Builtins.substring(line, Builtins.size(@id_not_readable))
                  )
                  Builtins.y2warning(
                    "File %1 can not be read.",
                    Builtins.substring(line, Builtins.size(@id_not_readable))
                  )
                  Progress.NextStep
                else
                  if Backup.multi_volume
                    if last_out != line
                      @archived_num = Ops.add(@archived_num, 1)
                      last_out = line
                    end
                  else
                    @archived_num = Ops.add(@archived_num, 1)
                    Builtins.y2debug("File: %1 added to archive", line)
                  end

                  @this_file_stage = Builtins.tointeger(
                    Ops.divide(
                      Ops.multiply(@archived_num, @stages_for_files),
                      progress_count
                    )
                  )
                  if Ops.greater_than(@this_file_stage, @last_file_stage)
                    Progress.NextStep
                    @last_file_stage = @this_file_stage
                  end
                end
              end
            else
              if Builtins.substring(line, 0, Builtins.size(@id_hostname)) == @id_hostname
                tmp = Builtins.substring(line, Builtins.size(@id_hostname))
                @hostname_stored = tmp == @id_ok

                Builtins.y2debug("Hostaneme stored: %1", @hostname_stored)
                Progress.NextStage
              else
                if Builtins.substring(line, 0, Builtins.size(@id_date)) == @id_date
                  tmp = Builtins.substring(line, Builtins.size(@id_date))
                  @date_stored = tmp == @id_ok

                  Builtins.y2debug("Date stored: %1", @date_stored)
                  Progress.NextStep
                else
                  if Builtins.substring(line, 0, Builtins.size(@id_partab)) == @id_partab
                    if !system_stage_changed
                      Progress.NextStage
                      system_stage_changed = true
                    else
                      Progress.NextStep
                    end
                  else
                    if Builtins.substring(line, 0, Builtins.size(@id_ptstored)) == @id_ptstored
                      part_name = Builtins.substring(
                        line,
                        Builtins.size(@id_ptstored)
                      )

                      @added_files = Ops.add(@added_files, 2)
                      @stored_ptables = Builtins.add(@stored_ptables, part_name)
                    else
                      if Builtins.substring(
                          line,
                          0,
                          Builtins.size(@id_not_stored)
                        ) == @id_not_stored
                        Builtins.y2warning("PTble was not stored: %1", line)
                        @failed_ptables = Builtins.add(
                          @failed_ptables,
                          Builtins.substring(
                            line,
                            Builtins.size(@id_not_stored)
                          )
                        )
                      else
                        if Builtins.substring(line, 0, Builtins.size(@id_ext2)) == @id_ext2
                          if !system_stage_changed
                            Progress.NextStage
                            system_stage_changed = true
                          end
                        else
                          if line == @id_archive
                            tar_running = true
                            Builtins.y2debug("Creating archive")

                            # set next stage if system backup was selected, but no partition table or ext2 image was selected
                            if Backup.system && !system_stage_changed
                              Progress.NextStage
                              system_stage_changed = true
                            end

                            Progress.NextStage
                          else
                            if line == @id_ok || line == @id_failed
                              @e2image_results = Builtins.add(
                                @e2image_results,
                                line == @id_ok
                              )
                            else
                              if Builtins.substring(
                                  line,
                                  0,
                                  Builtins.size(@id_not_readable)
                                ) == @id_not_readable
                                @not_readable_files = Builtins.add(
                                  @not_readable_files,
                                  Builtins.substring(
                                    line,
                                    Builtins.size(@id_not_readable)
                                  )
                                )
                                Builtins.y2warning(
                                  "File %1 can not be read.",
                                  Builtins.substring(
                                    line,
                                    Builtins.size(@id_not_readable)
                                  )
                                )
                                Progress.NextStep
                              else
                                if line == @id_pt_read
                                  @read_ptables_info = true
                                else
                                  if Builtins.substring(
                                      line,
                                      0,
                                      Builtins.size(@id_storing_installed_pkgs)
                                    ) == @id_storing_installed_pkgs
                                    Builtins.y2milestone(
                                      @id_storing_installed_pkgs
                                    )
                                  else
                                    if Builtins.substring(
                                        line,
                                        0,
                                        Builtins.size(@id_storedpkg)
                                      ) == @id_storedpkg
                                      @packages_list_stored = Builtins.substring(
                                        line,
                                        Builtins.size(@id_storedpkg)
                                      ) == @id_ok
                                      Builtins.y2debug(
                                        "Stored list of installed packages %1",
                                        @packages_list_stored
                                      )
                                      Progress.NextStep
                                    else
                                      Builtins.y2warning(
                                        "Unknown output from archive script: %1",
                                        line
                                      )
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          if Backup.cron_mode
            ret = nil
            if Convert.to_boolean(
                SCR.Read(path(".process.buffer_empty"), @backup_PID)
              ) == true
              Builtins.sleep(@wait_time)
            end
            CheckFreeSpace()
          else
            ret = waitForUserOrProcess(@wait_time, :changed)
            CheckFreeSpace()
          end

          # evaluetest the free space, asks user when there not enough free space
          # changes ret symbol when needed
          ret = EvaluateFreeSpace(ret)

          if ret != nil
            # free resources when backup is finished
            Backup.PostBackup
            return ret
          end
        end
      end
      # end while

      Builtins.y2milestone(
        "DEBUG: running %1",
        Convert.to_boolean(SCR.Read(path(".process.running"), @backup_PID))
      )
      Builtins.y2milestone(
        "DEBUG: empty %1",
        Convert.to_boolean(SCR.Read(path(".process.buffer_empty"), @backup_PID))
      )

      Backup.selected_files = {}

      if ret == :abort
        # remove incomplete backup archive file
        SCR.Execute(path(".target.remove"), Backup.archive_name)
      else
        # write autoinstallation profile
        Progress.NextStage

        @profilewritten = Backup.WriteProfile(@created_archive_files)
      end

      # free resources when backup is finished
      Backup.PostBackup
      :next
    end


    # Allow user to enter a new profile name. If the profile already exists, it allows
    # to replace it. Allows to rename current profile if current_name in not nil or "".
    #
    # @param  string current name of the profile
    # @return [String] the name for the new profile, "" for cancel
    def AskNewProfileName(current_name)
      # Translators: text of a popup dialog
      dialog_text = _("Enter a name for the new profile.")
      # renaming the current profile
      if current_name != nil && current_name != ""
        # TRANSLATORS: text of a popup dialog, %1 is a profile name to be renamed
        dialog_text = Builtins.sformat(
          _("Enter a new name for the %1 profile."),
          current_name
        )
      end
      # double-quote in name breaks backup in several places
      new_name = ShowEditDialog(dialog_text, "", nil, ["\""])

      while Ops.get_symbol(new_name, "clicked") == :ok &&
          Ops.get(Backup.backup_profiles, Ops.get_string(new_name, "text")) != nil
        # Translators: error popup, %1 is profile name
        if !Popup.YesNo(
            Builtins.sformat(
              _("A profile %1 already exists.\nReplace the existing profile?\n"),
              Ops.get_string(new_name, "text", "")
            )
          )
          # double-quote in name breaks backup at several places
          new_name = ShowEditDialog(
            _("Enter a name for the new profile."),
            "",
            nil,
            ["\""]
          )
        else
          # yes, do replace
          return Ops.get_string(new_name, "text", "")
        end
      end

      if Ops.get_symbol(new_name, "clicked") == :ok
        return Ops.get_string(new_name, "text", "")
      else
        return ""
      end
    end


    # Display backup summary
    # @return [Symbol] Symbol for wizard sequencer - pressed button

    def SummaryDialog
      br = "<BR>"
      p = "<P>"
      __p = "</P>"

      em = "<B>"
      __em = "</B>"

      if Backup.cron_mode == true
        br = "\n"
        p = ""
        __p = "\n"

        em = ""
        __em = ""
      end

      backup_result = ""
      backup_details = ""

      if Backup.archive_type == :txt
        # For translators: %1 is entered archive file name (summary text)
        backup_result = Ops.add(
          Ops.add(
            p,
            @stored_list ?
              Builtins.sformat(
                _("List of files saved to file %1"),
                Backup.archive_name
              ) :
              # part of summary text
              # summary text
              Ops.add(Ops.add(em, _("Error storing list of files")), __em)
          ),
          __p
        )
      else
        # part of summary text
        backup_result = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(Ops.add(p, _("Modified Files Found: ")), @modified_num),
                br
              ),
              # part of summary text
              _("Total Size: ")
            ),
            String.FormatSize(@modified_size)
          ),
          __p
        )

        if Backup.do_search
          # part of summary text
          backup_result = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(backup_result, p),
                      _("Files Not in a Package Found: ")
                    ),
                    @nopkg_num
                  ),
                  br
                ),
                # part of summary text
                _("Total Size: ")
              ),
              String.FormatSize(@nopkg_size)
            ),
            __p
          )
        end

        if Backup.display
          # part of summary text
          backup_result = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(backup_result, p),
                _("Selected Files to Back Up: ")
              ),
              @selected_files_num
            ),
            __p
          )
        end

        # part of summary text
        backup_details = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            p,
                            @hostname_stored ?
                              _("Hostname stored successfully") :
                              # part of summary text
                              Ops.add(
                                Ops.add(em, _("Storing hostname failed")),
                                __em
                              )
                          ),
                          br
                        ),
                        @date_stored ?
                          _("Date stored successfully") :
                          # part of summary text
                          Ops.add(Ops.add(em, _("Storing date failed")), __em)
                      ),
                      br
                    ),
                    @file_list_stored ?
                      _("File list stored successfully") :
                      # part of summary text
                      Ops.add(Ops.add(em, _("Storing file list failed")), __em)
                  ),
                  br
                ),
                @comment_stored ?
                  _("Comment stored successfully") :
                  # part of summary text
                  Ops.add(Ops.add(em, _("Storing comment failed")), __em)
              ),
              br
            ),
            # part of summary text
            @packages_list_stored ?
              _("List of installed packages stored successfully") :
              # part of summary text
              Ops.add(
                Ops.add(em, _("Storing list of installed packages failed")),
                __em
              )
          ),
          __p
        )


        if Ops.greater_than(Builtins.size(@not_readable_files), 0) ||
            !@hostname_stored ||
            !@date_stored ||
            !@file_list_stored ||
            !@comment_stored ||
            !@packages_list_stored
          # part of summary text, 'Details' is button label
          backup_result = Ops.add(
            Ops.add(
              Ops.add(backup_result, p),
              _(
                "Some errors occurred during backup. Press Details for more information."
              )
            ),
            __p
          )
        end


        if Ops.greater_than(Builtins.size(@not_readable_files), 0)
          # part of summary text
          backup_details = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(Ops.add(Ops.add(backup_details, br), p), em),
                _("Errors Creating Archive:")
              ),
              __em
            ),
            br
          )

          Builtins.foreach(@not_readable_files) do |f|
            # For translators: %1 file name - part of summary text
            backup_details = Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(backup_details, em),
                  Builtins.sformat(_("Cannot read file %1"), f)
                ),
                __em
              ),
              br
            )
          end 


          backup_details = Ops.add(backup_details, __p)
        end

        if Backup.system
          Builtins.y2debug("Ext2 backup: %1", Backup.ext2_backup)
          Builtins.y2debug("Ext2 results: %1", @e2image_results)

          if Backup.backup_pt
            if !@read_ptables_info
              # part of summary text
              backup_details = Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(Ops.add(backup_details, p), em),
                    _("Detecting disk partitions failed")
                  ),
                  __em
                ),
                br
              )
            end

            Builtins.foreach(@failed_ptables) do |failed_pt|
              # For translators: %1 is device name of disk, e.g. hda - part of summary text
              backup_details = Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(backup_details, em),
                    Builtins.sformat(
                      _("Storing partition table of disk /dev/%1 failed"),
                      failed_pt
                    )
                  ),
                  __em
                ),
                br
              )
            end 


            Builtins.foreach(@stored_ptables) do |stored_pt|
              # For translators: %1 is device name of disk, e.g. hda - part of summary text
              backup_details = Ops.add(
                Ops.add(
                  backup_details,
                  Builtins.sformat(
                    _("Storing partition table of disk /dev/%1 was successful"),
                    stored_pt
                  )
                ),
                br
              )
            end
          end

          if Ops.greater_than(Builtins.size(Backup.ext2_backup), 0)
            index = 0

            Builtins.foreach(@e2image_results) do |r|
              tmp = Ops.get(Backup.ext2_backup, index)
              tmp = Ops.get_term(tmp, 0)
              partition_name = Ops.get_string(tmp, 0, "")
              if r
                backup_details = Ops.add(
                  Ops.add(
                    backup_details,
                    # For translators: %1 is partition name e.g. /dev/hda1 - part of summary text
                    Builtins.sformat(
                      _("Ext2 image of %1 stored successfully"),
                      partition_name
                    )
                  ),
                  br
                )

                @added_files = Ops.add(@added_files, 1)
              else
                backup_details = Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(backup_details, em),
                      # For translators: %1 is partition name e.g. /dev/hda1 - part of summary text
                      Builtins.sformat(
                        _("Storing ext2 image of %1 failed"),
                        partition_name
                      )
                    ),
                    __em
                  ),
                  br
                )
              end
              index = Ops.add(index, 1)
            end
          end

          backup_details = Ops.add(backup_details, __p)
        end

        @added_files = Ops.add(@added_files, 1) if @file_list_stored

        @added_files = Ops.add(@added_files, 1) if @hostname_stored

        @added_files = Ops.add(@added_files, 1) if @date_stored

        @added_files = Ops.add(@added_files, 1) if @comment_stored

        @added_files = Ops.add(@added_files, 1) if @packages_list_stored

        Builtins.y2debug("selected_files_num: %1", @selected_files_num)
        Builtins.y2debug("added_files: %1", @added_files)
        Builtins.y2debug("total_files: %1", @total_files)

        backup_result = Ops.add(
          Ops.add(
            Ops.add(backup_result, __p),
            # part of summary text
            br
          ),
          Ops.less_than(
            Ops.add(@selected_files_num, @added_files),
            @total_files
          ) ?
            Ops.add(
              Ops.add(
                Ops.add(em, _("Warning: Some files were not backed up")),
                __em
              ),
              br
            ) :
            ""
        )

        archive_created = ""

        if !Backup.multi_volume
          archname = Backup.target_type == :file ?
            Backup.archive_name :
            NFSfile(Backup.nfsserver, Backup.nfsexport, Backup.archive_name)
          # For translators: %1 is entered archive file name - part of summary text
          archive_created = Builtins.sformat(
            _("Archive %1 created successfully"),
            archname
          )
        else
          # part of summary text
          archive_created = _("Archive created successfully")
        end

        # part of summary text - %1 is file name
        profilesummary = Ops.get_boolean(@profilewritten, "result", false) == true ?
          Builtins.sformat(
            _("Autoinstallation profile saved to file %1."),
            Ops.get_string(@profilewritten, "profile", "")
          ) :
          Ops.add(
            Ops.add(em, _("Autoinstallation profile was not saved.")),
            __em
          )

        backup_result = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  backup_result,
                  # part of summary text
                  @tar_result == 0 ?
                    archive_created :
                    Ops.add(Ops.add(em, _("Archive creation failed")), __em)
                ),
                br
              ),
              profilesummary
            ),
            br
          ),
          __p
        )

        # part of summary text
        backup_details = Ops.add(
          Ops.add(
            Ops.add(Ops.add(backup_details, p), _("Total Archived Files: ")),
            @archived_num
          ),
          __p
        )


        if Backup.multi_volume
          if Ops.greater_than(Builtins.size(@created_archive_files), 0)
            # part of summary text
            backup_details = Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(Ops.add(backup_details, p), em),
                  "Created archive volumes:"
                ),
                __em
              ),
              br
            )

            Builtins.foreach(@created_archive_files) do |f|
              backup_details = Ops.add(Ops.add(backup_details, f), br)
            end 


            backup_details = Ops.add(backup_details, __p)
          end
        end
      end

      buttons = HBox(PushButton(Id(:details), Opt(:key_F2), _("&Details...")))
      if Backup.selected_profile == nil
        buttons = HBox(
          PushButton(Id(:details), Opt(:key_F2), _("&Details...")),
          PushButton(Id(:profile), _("&Save as Profile..."))
        )
      end

      # cron mode
      if Backup.cron_mode == true
        if Backup.mail_summary == true
          SendSummary(
            Backup.remove_result,
            Backup.selected_profile,
            backup_result,
            backup_details
          )
        end

        return :finish
      end

      # dialog header
      Wizard.SetContents(
        _("Backup Summary"),
        VBox(
          VSpacing(0.5),
          RichText(backup_result),
          VSpacing(0.5),
          # push button label
          buttons,
          VSpacing(1.0)
        ),
        backup_help_summary,
        true,
        true
      )

      if Backup.archive_type == :txt
        UI.ChangeWidget(Id(:details), :Enabled, false)
      end

      Wizard.SetNextButton(:finish, Label.OKButton)
      UI.SetFocus(Id(:finish))

      ret = Convert.to_symbol(UI.UserInput)

      while ret != :finish && ret != :back
        if ret == :details
          # popup dialog header
          Popup.LongText(
            _("Backup Summary Details"),
            RichText(backup_details),
            70,
            15
          )
        elsif ret == :abort || ret == :cancel
          ret = :abort
          if AbortConfirmation(:changed)
            break
          else
            ret = nil
          end
        elsif ret == :profile
          new_name = AskNewProfileName(nil)

          #if no cancel, store
          Backup.StoreSettingsToBackupProfile(new_name) if new_name != ""
        end

        ret = Convert.to_symbol(UI.UserInput)
      end

      Wizard.RestoreNextButton
      ret
    end

    def RedrawScriptsTable(selected_item)
      counter = -1

      items = Builtins.maplist(Backup.backup_helper_scripts) do |one_item|
        counter = Ops.add(counter, 1)
        # before
        Item(
          Id(counter),
          Ops.get_string(one_item, "type", "before") == "before" ?
            # Script type
            _("Run before backup") :
            # Script type
            _("Run after backup"),
          Ops.get_string(one_item, "path", "")
        )
      end

      UI.ChangeWidget(Id("table_of_scripts"), :Items, items)

      if Ops.greater_than(
          Builtins.size(Backup.backup_helper_scripts),
          selected_item
        )
        UI.ChangeWidget(Id("table_of_scripts"), :CurrentItem, selected_item)
      end

      button_state = Ops.greater_than(Builtins.size(items), 0)

      UI.ChangeWidget(Id(:delete_script), :Enabled, button_state)
      UI.ChangeWidget(Id(:edit_script), :Enabled, button_state)

      nil
    end

    def InitScriptContent
      file = Convert.to_string(UI.QueryWidget(Id("script_name"), :Value))

      # the default content is taken from UI (might be already defined)
      script_content = Convert.to_string(
        UI.QueryWidget(Id("script_content"), :Value)
      )

      # if a file exists, the content is taken from there
      if FileUtils.Exists(file)
        script_content = Convert.to_string(
          SCR.Read(path(".target.string"), file)
        )

        if script_content == nil
          Builtins.y2error("Cannot read file %1", file)
          script_content = ""
        end
      else
        Builtins.y2warning("File %1 does not exist (yet)", file)
      end

      # adjust UI
      UI.ChangeWidget(Id("script_content"), :Value, script_content)

      nil
    end

    def StoreScriptContent(filename)
      script_content = Convert.to_string(
        UI.QueryWidget(Id("script_content"), :Value)
      )

      if !FileUtils.Exists(filename)
        pos = Builtins.findlastof(filename, "/")

        if pos == nil
          UI.SetFocus(Id("script_content"))
          Report.Error(_("Invalid file name."))
          return false
        end

        directory = Builtins.substring(filename, 0, Ops.add(pos, 1))

        cmd = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "mkdir -pv '%1' && touch '%2' && chmod 0700 '%2'",
              directory,
              filename
            )
          )
        )

        if Ops.get_integer(cmd, "exit", -1) != 0
          Report.Error(
            Builtins.sformat(
              _("Cannot create file %1.\nDetails: %2"),
              filename,
              Ops.get_string(cmd, "stderr", "")
            )
          )
          return false
        end
      end

      if SCR.Write(path(".target.string"), filename, script_content) != true
        Report.Error(Builtins.sformat(_("Cannot write to %1 file."), filename))
        return false
      end

      true
    end

    def AddEditScriptDialog(ret)
      current_item = -1
      editing = false

      default_run_before_backup = ""
      default_run_after_backup = ""

      # edit
      if ret == :edit_script
        current_item = Convert.to_integer(
          UI.QueryWidget(Id("table_of_scripts"), :CurrentItem)
        )
        editing = true 
        # add
      else
        if Convert.to_boolean(
            SCR.Execute(path(".target.mkdir"), Backup.backup_scripts_dir)
          ) != true
          Builtins.y2error("Cannot create %1", Backup.backup_scripts_dir)
        end
      end

      # >>> before backup - proposes a unique script name
      cmd = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "mktemp --dry-run -p '%1' -t run_before_backup.XXXXXXXXXXXXXXXX",
            String.Quote(Backup.backup_scripts_dir)
          )
        )
      )

      if Ops.get_integer(cmd, "exit", -1) == 0
        default_run_before_backup = Ops.get(
          Builtins.splitstring(Ops.get_string(cmd, "stdout", ""), "\n"),
          0,
          ""
        )
      else
        Builtins.y2warning("Cannot propose a script name: %1", cmd)
      end
      # <<<

      # >>> after backup - proposes a unique script name
      cmd = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "mktemp --dry-run -p '%1' -t run_after_backup.XXXXXXXXXXXXXXXX",
            String.Quote(Backup.backup_scripts_dir)
          )
        )
      )

      if Ops.get_integer(cmd, "exit", -1) == 0
        default_run_after_backup = Ops.get(
          Builtins.splitstring(Ops.get_string(cmd, "stdout", ""), "\n"),
          0,
          ""
        )
      else
        Builtins.y2warning("Cannot propose a script name: %1", cmd)
      end
      # <<<

      this_entry = Ops.get(Backup.backup_helper_scripts, current_item, {})

      UI.OpenDialog(
        VBox(
          MarginBox(
            1,
            0,
            Left(
              Heading(
                editing == true ?
                  _("Edit Backup Helper Script Options") :
                  _("Add Backup Helper Script")
              )
            )
          ),
          MarginBox(
            1,
            1,
            VBox(
              Frame(
                _("Script Type"),
                RadioButtonGroup(
                  Id("script_type"),
                  VBox(
                    Left(
                      RadioButton(
                        Id("before"),
                        Opt(:notify),
                        _("&Before Backup")
                      )
                    ),
                    Left(
                      RadioButton(Id("after"), Opt(:notify), _("&After Backup"))
                    )
                  )
                )
              ),
              VSpacing(0.5),
              VSquash(
                HBox(
                  Bottom(
                    ComboBox(
                      Id("script_name"),
                      Opt(:editable, :hstretch, :notify),
                      _("Script &Path"),
                      []
                    )
                  ),
                  Bottom(
                    PushButton(Id("browse_script_name"), Label.BrowseButton)
                  )
                )
              ),
              VSpacing(0.5),
              MinSize(
                80,
                12,
                MultiLineEdit(Id("script_content"), _("Script &Content"), "")
              )
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      current_script_type = ""
      default_script_path = ""

      # Adjusting the defaults
      if Ops.get_string(this_entry, "type", "before") == "before"
        current_script_type = "before"
        default_script_path = default_run_before_backup
      else
        current_script_type = "after"
        default_script_path = default_run_after_backup
      end

      initial_script_path = Ops.get_string(
        this_entry,
        "path",
        default_script_path
      )

      # Adjusting UI
      UI.ChangeWidget(Id("script_type"), :CurrentButton, current_script_type)
      UI.ChangeWidget(
        Id("script_name"),
        :Items,
        Builtins.toset(
          [
            Ops.get_string(this_entry, "path", default_script_path),
            default_script_path
          ]
        )
      )
      UI.ChangeWidget(Id("script_name"), :Value, initial_script_path)

      InitScriptContent()

      ret = nil
      dialog_ret = false
      path_changed_by_user = false

      while true
        ret = UI.UserInput

        if ret == :ok
          Ops.set(this_entry, "path", UI.QueryWidget(Id("script_name"), :Value))
          Ops.set(
            this_entry,
            "type",
            UI.QueryWidget(Id("script_type"), :CurrentButton)
          )

          if Ops.get_string(this_entry, "path", "") == ""
            UI.SetFocus(Id("script_name"))
            Report.Error(_("Script file name must be set."))
            next
          end

          next if !StoreScriptContent(Ops.get_string(this_entry, "path", ""))

          # a new entry
          if current_item == -1
            current_item = Builtins.size(Backup.backup_helper_scripts)
          end

          Ops.set(Backup.backup_helper_scripts, current_item, this_entry)

          dialog_ret = true
          break
        elsif ret == :cancel
          break 

          # Switching the script type
        elsif ret == "after" || ret == "before"
          if ret == "before"
            current_script_type = "before"
            default_script_path = default_run_before_backup
          else
            current_script_type = "after"
            default_script_path = default_run_after_backup
          end

          if path_changed_by_user != true
            UI.ChangeWidget(Id("script_name"), :Value, default_script_path)
          end

          InitScriptContent() 

          # Changed the script name
        elsif ret == "script_name"
          path_changed_by_user = true
          InitScriptContent() 

          # User pressed the [Browse] button
        elsif ret == "browse_script_name"
          file = UI.AskForExistingFile(
            Backup.backup_scripts_dir,
            "*",
            _("Choose a Script File Name")
          )

          next if file == nil

          UI.ChangeWidget(Id("script_name"), :Value, file)
          InitScriptContent()
          path_changed_by_user = true
        else
          Builtins.y2error("Ret %1 not handled", ret)
        end
      end

      UI.CloseDialog

      dialog_ret
    end

    # Display dialog with expert options (e.g. system area backup,
    # temporary location...)
    # @return [Symbol] user input - widget ID

    def ExpertOptionsDialog
      # dialog header
      Wizard.SetContents(
        _("Expert Backup Options"),
        VBox(
          VSpacing(0.5),
          # check box label
          Left(
            CheckBoxFrame(
              Id(:system),
              Opt(:notify),
              _("Back Up &Hard Disk System Areas"),
              Backup.system,
              HBox(HStretch(), PushButton(Id(:set_system), _("&Options...")))
            )
          ),
          # text entry label
          InputField(
            Id(:tmp),
            Opt(:hstretch),
            _("Temporary &Location of Archive Parts"),
            Backup.tmp_dir
          ),
          VSpacing(1),
          Left(Label(_("Pre and Post-Backup Scripts"))),
          Table(
            Id("table_of_scripts"),
            Header(
              # a header item
              _("Script Type"),
              # a header item
              _("Path")
            ),
            []
          ),
          Left(
            HBox(
              PushButton(Id(:add_script), Opt(:key_F3), _("&Add...")),
              PushButton(Id(:edit_script), Opt(:key_F4), _("&Edit...")),
              PushButton(Id(:delete_script), Opt(:key_F5), Label.DeleteButton)
            )
          ),
          VStretch()
        ),
        expert_options_help,
        true,
        true
      )

      RedrawScriptsTable(0)

      # enable/disable widges
      if Backup.archive_type == :txt
        UI.ChangeWidget(Id(:system), :Enabled, false)
        UI.ChangeWidget(Id(:set_system), :Enabled, false)
      else
        UI.ChangeWidget(Id(:set_system), :Enabled, Backup.system)
      end

      Wizard.SetNextButton(:finish, Label.OKButton)
      UI.SetFocus(Id(:finish))

      ret = nil
      current_item = nil

      while ret != :finish && ret != :back && ret != :abort &&
          ret != :set_system
        ret = Convert.to_symbol(UI.UserInput)
        current_item = Convert.to_integer(
          UI.QueryWidget(Id("table_of_scripts"), :CurrentItem)
        )

        if ret == :finish || ret == :set_system
          Backup.tmp_dir = Convert.to_string(UI.QueryWidget(Id(:tmp), :Value))
          Backup.system = Convert.to_boolean(
            UI.QueryWidget(Id(:system), :Value)
          )
        elsif ret == :system
          UI.ChangeWidget(
            Id(:set_system),
            :Enabled,
            Convert.to_boolean(UI.QueryWidget(Id(:system), :Value))
          )
        elsif ret == :add_script || ret == :edit_script
          if AddEditScriptDialog(ret) == true
            # Redraw table and select either the new or the edited script
            RedrawScriptsTable(
              ret == :add_script ?
                Ops.subtract(Builtins.size(Backup.backup_helper_scripts), 1) :
                current_item
            )
          end
        elsif ret == :delete_script
          next if Confirm.DeleteSelected != true
          Ops.set(Backup.backup_helper_scripts, current_item, nil)
          Backup.backup_helper_scripts = Builtins.filter(
            Backup.backup_helper_scripts
          ) { |one_item| one_item != nil }
          RedrawScriptsTable(0)
        end
      end

      Wizard.RestoreNextButton

      ret
    end

    # Displays a popup dialog asking for new name for the current profile.
    # If nil returned, no redraw is needed, no changes are done.
    #
    # @param string current profile
    # @param string name to be selected
    def RenameProfilePupupDialog(current_name)
      Backup.RestoreSettingsFromBackupProfile(current_name)
      new_name = AskNewProfileName(current_name)

      # no changes, the same name
      return nil if current_name == new_name

      # if not cancelled
      if new_name != "" && new_name != nil
        #map current_profile = (map)eval(Backup::backup_profiles[Backup::selected_profile]:$[]);
        #map current_settings = (map)eval(current_profile[`cron_settings]:$[]);

        Backup.StoreSettingsToBackupProfile(new_name)


        # "Renaming", Cron settings, It seems to be a hack }8->
        Ops.set(
          Backup.backup_profiles,
          [new_name, :cron_settings],
          Ops.get_map(
            Backup.backup_profiles,
            [current_name, :cron_settings],
            {}
          )
        )
        # Setting that cron settings were changed
        Ops.set(
          Backup.backup_profiles,
          [new_name, :cron_settings, "cron_changed"],
          true
        )
        Ops.set(
          Backup.backup_profiles,
          [current_name, :cron_settings, "cron_changed"],
          true
        )

        # Remove the backup profile, but do not remove cron file
        Backup.RemoveBackupProfile(current_name, false)

        return new_name
      end
      nil
    end

    # Dialog for selection of a profile before backup
    # @return [Symbol] Symbol for wizard sequencer - pressed button
    def SelectProfileDialog
      Wizard.SetNextButton(:finish, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      tableheader1 = _("Name")
      tableheader2 = _("Description")
      tableheader3 = _("Automatic Backup")

      Wizard.SetContents(
        _("System Backup"),
        VBox(
          Left(Label(_("Available Profiles"))),
          ReplacePoint(
            Id(:selectionBox),
            Table(
              Id(:profile),
              Header(tableheader1, tableheader2, tableheader3),
              Backup.BackupProfileDescriptions
            )
          ),
          HBox(
            PushButton(Id(:start), _("&Create Backup")),
            MenuButton(
              _("Profile Mana&gement"),
              [
                Item(Id(:add), Ops.add(Label.AddButton, "...")),
                Item(Id(:clone), _("&Duplicate...")),
                Item(Id(:edit), Ops.add(Label.EditButton, "...")),
                # TRANSLATORS: Menu button selection
                Item(Id(:rename), _("Re&name") + "..."),
                Item(Id(:delete), Label.DeleteButton),
                Item(Id(:cron), Ops.add(tableheader3, "..."))
              ]
            )
          ),
          PushButton(Id(:manual), _("Back Up &Manually...")),
          VSpacing(1.5)
        ),
        profile_help,
        false,
        true
      )

      sel_prof = Backup.selected_profile == nil ?
        Ops.get(Backup.BackupProfileNames, 0) :
        Backup.selected_profile

      if sel_prof != nil
        # select the first profile in the list
        UI.ChangeWidget(Id(:profile), :CurrentItem, sel_prof)
      end

      ret = nil
      Backup.no_interactive = false
      begin
        # select the first profile in the list
        UI.ChangeWidget(
          Id(:start),
          :Enabled,
          Builtins.size(Backup.backup_profiles) != 0
        )

        ret = Convert.to_symbol(UI.UserInput)

        # load corresponding settings
        if Builtins.size(Backup.backup_profiles) == 0
          Backup.RestoreDefaultSettings
        else
          Backup.RestoreSettingsFromBackupProfile(
            Convert.to_string(UI.QueryWidget(Id(:profile), :CurrentItem))
          )
        end

        if ret == :start
          Backup.no_interactive = true
        elsif ret == :clone || ret == :add
          # add a new profile with the current/default settings
          if ret == :add
            # restore default settings, don't care about selected profile
            Backup.RestoreDefaultSettings
          end

          new_name = AskNewProfileName(nil)

          # if the user didn't choose cancel
          if new_name != ""
            Backup.StoreSettingsToBackupProfile(new_name)
            UI.ReplaceWidget(
              Id(:selectionBox),
              Table(
                Id(:profile),
                Header(tableheader1, tableheader2, tableheader3),
                Backup.BackupProfileDescriptions
              )
            )

            # select the profile in the list
            UI.ChangeWidget(Id(:profile), :CurrentItem, new_name)

            if ret == :add
              # start config. workflow for the new profile
              ret = :edit
              Backup.RestoreSettingsFromBackupProfile(
                Convert.to_string(UI.QueryWidget(Id(:profile), :CurrentItem))
              )
              # adding new profile
              Backup.profile_is_new_one = true
            end
          end
        elsif ret == :rename
          current_name = Convert.to_string(
            UI.QueryWidget(Id(:profile), :CurrentItem)
          )
          current_name = RenameProfilePupupDialog(current_name)
          # redraw if any changes are done
          if current_name != nil
            UI.ReplaceWidget(
              Id(:selectionBox),
              Table(
                Id(:profile),
                Header(tableheader1, tableheader2, tableheader3),
                Backup.BackupProfileDescriptions
              )
            )
            UI.ChangeWidget(Id(:profile), :CurrentItem, current_name)
          end
        elsif ret == :delete
          # remove the selected profile
          if Popup.YesNo(_("Remove the selected profile?"))
            # remove backup profile also with cron file
            Backup.RemoveBackupProfile(
              Convert.to_string(UI.QueryWidget(Id(:profile), :CurrentItem)),
              true
            )
            UI.ReplaceWidget(
              Id(:selectionBox),
              Table(
                Id(:profile),
                Header(tableheader1, tableheader2, tableheader3),
                Backup.BackupProfileDescriptions
              )
            )

            # select the first profile in the list
            UI.ChangeWidget(
              Id(:profile),
              :CurrentItem,
              Ops.get(Backup.BackupProfileNames, 0)
            )
          end
        elsif ret == :manual
          # load defaults, clear selected_profile
          Backup.RestoreDefaultSettings
          Backup.selected_profile = nil
        elsif ret == :cron
          selprofile = Convert.to_string(
            UI.QueryWidget(Id(:profile), :CurrentItem)
          )

          if selprofile != nil
            Backup.selected_profile = selprofile
          else
            # no selected profile, wait for next UserInput
            ret = nil
          end
        elsif ret == :cancel
          ret = :abort
        end
      end while ret != :finish && ret != :manual && ret != :start && ret != :edit &&
        ret != :cron &&
        ret != :abort

      # save profiles before quit and
      # before starting backup
      # (modifications would be lost when backup is aborted
      if ret == :finish || ret == :start || ret == :manual
        Builtins.y2milestone(" *** Storing profiles ***")
        Backup.WriteBackupProfiles
      end

      Wizard.RestoreNextButton
      Wizard.RestoreBackButton

      Builtins.y2debug("SelectProfileDialog result: %1", ret)

      ret
    end

    # Choose the next step - start searching or return to the profile dialog.
    # @return [Symbol] Symbol for wizard sequencer - `next for searching, `next2 for return to profile dialog
    def PrepareSearching
      # if the user does not use profile, start searching
      if Backup.selected_profile == nil || Backup.no_interactive
        return :next
      else
        Backup.StoreSettingsToBackupProfile(Backup.selected_profile)
        return :ok
      end
    end

    # Directory selection dialog
    # @param [String] label dialog label
    # @param [String] dir start directory
    # @return [Hash] result $[ "input" : symbol (user input, `ok or `cancel), "dir" : string (selected directory) ];
    def DirPopup(label, dir)
      UI.OpenDialog(
        VBox(
          VSpacing(0.5),
          HBox(
            HSpacing(1.0),
            InputField(Id(:dir), Opt(:vstretch), label, dir),
            HSpacing(1),
            VBox(Label(""), PushButton(Id(:browse), _("&Browse..."))),
            HSpacing(1.0)
          ),
          VSpacing(1.0),
          HBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          ),
          VSpacing(0.3)
        )
      )

      UI.SetFocus(Id(:ok))

      input = Convert.to_symbol(UI.UserInput)

      while input != :ok && input != :cancel
        if input == :browse
          # title in the file selection dialog
          new = UI.AskForExistingDirectory(dir, _("Directory Selection"))

          if Ops.greater_than(Builtins.size(new), 0)
            UI.ChangeWidget(Id(:dir), :Value, new)
          end
        end

        input = Convert.to_symbol(UI.UserInput)
      end

      newval = Convert.to_string(UI.QueryWidget(Id(:dir), :Value))

      UI.CloseDialog

      { "input" => input, "dir" => newval }
    end

    # Convert size in bytes to B, kiB, kB, MiB or MB
    # @param [Fixnum] sz size in bytes
    # @return [Hash] map $[ "string" : string (textual representation), "size" : integer (value), "unit" : symbol (unit of the value) ]
    def size2map(sz)
      ret = ""
      ret_unit = :B
      unit_descr = {}

      return nil if sz == nil

      Builtins.foreach(Backup.units_description) do |m|
        s = Ops.get_symbol(m, "symbol")
        label = Ops.get_string(m, "label")
        if s != nil && Ops.greater_than(Builtins.size(label), 0)
          Ops.set(unit_descr, s, label)
        end
      end 


      if Ops.modulo(sz, 1024) == 0
        # size in kiB
        sz = Ops.divide(sz, 1024)

        if Ops.modulo(sz, 1024) == 0
          # size in MiB
          sz = Ops.divide(sz, 1024)

          # return MiB
          ret = Ops.add(
            Ops.add(Builtins.sformat("%1", sz), " "),
            Ops.get(unit_descr, :MiB, "")
          )
          ret_unit = :MiB
        else
          # return kiB
          ret = Ops.add(
            Ops.add(Builtins.sformat("%1", sz), " "),
            Ops.get(unit_descr, :kiB, "")
          )
          ret_unit = :kiB
        end
      elsif Ops.modulo(sz, 1000) == 0
        # size in kB
        sz = Ops.divide(sz, 1000)

        if Ops.modulo(sz, 1000) == 0
          # size in MB
          sz = Ops.divide(sz, 1000)

          # return MB
          ret = Ops.add(
            Ops.add(Builtins.sformat("%1", sz), " "),
            Ops.get(unit_descr, :MB, "")
          )
          ret_unit = :MB
        else
          # return kB
          ret = Ops.add(
            Ops.add(Builtins.sformat("%1", sz), " "),
            Ops.get(unit_descr, :kB, "")
          )
          ret_unit = :kB
        end
      else
        ret = Ops.add(
          Ops.add(Builtins.sformat("%1", sz), " "),
          Ops.get(unit_descr, :B, "")
        )
        ret_unit = :B
      end

      { "string" => ret, "size" => sz, "unit" => ret_unit }
    end

    # Convert size description to string
    # @param [Symbol] s volume size
    # @param [Fixnum] user_size user defined size
    # @return [String] result
    def symbol2string(s, user_size)
      Builtins.y2milestone("s: %1, user_size: %2", s, user_size)

      ret = ""

      return ret if s == nil

      if s == :user
        tmp = size2map(user_size)
        return Ops.get_string(tmp, "string", "")
      end

      Builtins.foreach(Backup.media_descriptions) do |m|
        sym = Ops.get_symbol(m, "symbol")
        cap = Ops.get_integer(m, "capacity")
        label = Ops.get_string(m, "label", "")
        Builtins.y2milestone("symbol: %1", Ops.get(m, "symbol"))
        if sym == s
          ret = label

          if Ops.greater_than(cap, 0)
            tmp = size2map(cap)
            ret = Ops.add(
              ret,
              Builtins.sformat(" (%1)", Ops.get_string(tmp, "string", ""))
            )
          end
        end
      end 


      ret
    end

    # Convert list of strings to list of items
    # @param [Fixnum] start_id identification of the first item
    # @param [String] type description of item
    # @param [Array<String>] input input
    # @return [Array<Yast::Term>] result
    def list2items(start_id, type, input)
      input = deep_copy(input)
      ret = []
      i = start_id

      Builtins.foreach(input) do |itm|
        ret = Builtins.add(ret, Item(Id(i), itm, type))
        i = Ops.add(i, 1)
      end if Ops.greater_than(
        Builtins.size(input),
        0
      )

      deep_copy(ret)
    end

    def RedrawIncludeTable
      items = []

      # If no include_dir is defined, use the entire root "/"
      if Backup.include_dirs == nil || Backup.include_dirs == []
        Backup.include_dirs = [Backup.default_include_dir]
      end

      enable_include_table = true
      Builtins.foreach(Backup.include_dirs) do |include_dir|
        # The entire file system is included
        if include_dir == Backup.default_include_dir
          # TRANSLATORS: informative text in the multiline select-box
          items = [
            Item(Id(include_dir), _("Entire file system will be searched"))
          ]
          enable_include_table = false
          raise Break 
          # Other directories are included
        else
          items = Builtins.add(items, Item(Id(include_dir), include_dir))
        end
      end

      if items != [] && items != nil && enable_include_table
        UI.ChangeWidget(Id(:include), :Items, items)
        UI.ChangeWidget(Id(:edit_include), :Enabled, true)
        UI.ChangeWidget(Id(:delete_include), :Enabled, true)
      else
        UI.ChangeWidget(Id(:include), :Items, items)
        UI.ChangeWidget(Id(:edit_include), :Enabled, false)
        UI.ChangeWidget(Id(:delete_include), :Enabled, false)
      end

      nil
    end

    # Redraws contstraints table content -
    # directories, regular expressions and
    # file systems to exclude
    def RedrawConstraintsTable
      items = []

      items = Builtins.merge(
        items,
        list2items(Builtins.size(items), @directory_text, Backup.dir_list)
      )
      items = Builtins.merge(
        items,
        list2items(Builtins.size(items), @regexp_text, Backup.regexp_list)
      )
      items = Builtins.merge(
        items,
        list2items(Builtins.size(items), @filesystem_text, Backup.fs_exclude)
      )

      if items != [] && items != nil
        UI.ChangeWidget(Id(:const), :Items, items)
        UI.ChangeWidget(Id(:edit), :Enabled, true)
        UI.ChangeWidget(Id(:delete), :Enabled, true)
      else
        UI.ChangeWidget(Id(:const), :Items, [])
        UI.ChangeWidget(Id(:edit), :Enabled, false)
        UI.ChangeWidget(Id(:delete), :Enabled, false)
      end

      nil
    end

    # Initialize the "Search Constraints" dialog
    def InitConstraintDialog
      # initialize excluded directories
      Backup.dir_list = [] if Backup.dir_list == nil

      # initialize excluded filesystems
      if Backup.detected_fs == nil
        # busy message
        Wizard.SetContents(
          "",
          Label(_("Detecting file system types...")),
          "",
          false,
          false
        )
        Backup.detected_fs = GetMountedFilesystems()
        Backup.ExcludeNodevFS
      end

      # do not allow manual changes of configuration
      return :next if Backup.no_interactive

      # dialog header
      Wizard.SetContents(
        _("Search Constraints"),
        VBox(
          VSquash(
            MinHeight(
              6,
              # selection box
              SelectionBox(
                Id(:include),
                Opt(:shrinkable),
                _("&Directories Included in Search"),
                []
              )
            )
          ),
          HBox(
            # push button label
            PushButton(Id(:add_include), _("&Add...")),
            # push button label
            PushButton(Id(:edit_include), _("&Edit...")),
            # push button label
            PushButton(Id(:delete_include), _("De&lete"))
          ),
          VSpacing(1.0),
          # table label
          Left(Label(_("Items Excluded from Search"))),
          # table header
          Table(Id(:const), Opt(:vstretch), Header(_("Value"), _("Type")), []),
          Left(
            HBox(
              # push button label
              MenuButton(
                Id(:add_menu),
                _("A&dd"),
                [
                  Item(Id(:dir), _("&Directory...")),
                  Item(Id(:fs), _("&File System...")),
                  Item(Id(:regexp), _("&Regular Expression..."))
                ]
              ),
              # push button label
              PushButton(Id(:edit), Opt(:key_F4), _("&Edit...")),
              # push button label
              PushButton(Id(:delete), Opt(:key_F5), _("De&lete"))
            )
          )
        ),
        backup_help_constraints,
        true,
        true
      )

      RedrawConstraintsTable()
      RedrawIncludeTable()

      if Backup.selected_profile != nil
        # replace 'Next' button with 'OK' if profile is configured
        Wizard.SetNextButton(:next, Label.OKButton)
        UI.SetFocus(Id(:next))
      end

      nil
    end

    def AddExcludeItem_Regexp
      # textentry label
      result = ShowEditDialog(_("&Add New Expression"), "", nil, [])

      if Ops.get(result, "clicked") == :ok
        new_regexp = Ops.get_string(result, "text")

        # add item only if it's not empty and it isn't already in list
        if new_regexp != "" && new_regexp != nil
          if Builtins.contains(Backup.regexp_list, new_regexp)
            # error poup message - %1 is an entered regular expression
            Popup.Error(
              Builtins.sformat(
                _("Expression %1 is already in the list."),
                new_regexp
              )
            )
          else
            Backup.regexp_list = Builtins.add(Backup.regexp_list, new_regexp)

            RedrawConstraintsTable()
          end
        end
      end

      nil
    end

    def AddExcludeItem_Dir
      # textentry label
      result = ShowEditDialog(_("&Add New Directory"), "", nil, [])

      if Ops.get(result, "clicked") == :ok
        new = Ops.get_string(result, "text")

        # add item only if it's not empty and it isn't already in list
        if new != "" && new != nil
          if Builtins.contains(Backup.dir_list, new)
            # error poup message - %1 is a directory name
            Popup.Error(
              Builtins.sformat(_("Directory %1 is already in the list."), new)
            )
          else
            Backup.dir_list = Builtins.add(Backup.dir_list, new)

            RedrawConstraintsTable()
          end
        end
      end

      nil
    end

    def AddExcludeItem_Fs(all_fss)
      # combobox label
      result = ShowEditDialog(_("&Add New File System"), "", all_fss.value, [])

      if Ops.get(result, "clicked") == :ok
        new = Ops.get_string(result, "text")

        # add item only if it's not empty and it isn't already in list
        if new != "" && new != nil
          if Builtins.contains(Backup.fs_exclude, new)
            # error poup message - %1 is a directory name
            Popup.Error(
              Builtins.sformat(_("File system %1 is already in the list."), new)
            )
          else
            Backup.fs_exclude = Builtins.add(Backup.fs_exclude, new)

            RedrawConstraintsTable()
          end
        end
      end

      nil
    end

    def ExcludeItemEdit(value, type, all_fss)
      # textentry label
      result = ShowEditDialog(
        Label.EditButton,
        value,
        type == @filesystem_text ? all_fss.value : nil,
        []
      )

      if Ops.get(result, "clicked") == :ok
        new_txt = Ops.get_string(result, "text")

        if new_txt != nil && new_txt != value
          if type == @regexp_text
            if Builtins.contains(Backup.regexp_list, new_txt)
              # error popup message
              Popup.Error(
                Builtins.sformat(
                  _("Expression %1 is already in the list."),
                  new_txt
                )
              )
            else
              # refresh regexp_list content
              Backup.regexp_list = Builtins.maplist(Backup.regexp_list) do |i|
                i == value ? new_txt : i
              end
            end
          elsif type == @directory_text
            if Builtins.contains(Backup.dir_list, new_txt)
              # error popup message
              Popup.Error(
                Builtins.sformat(
                  _("Directory %1 is already in the list."),
                  new_txt
                )
              )
            else
              # refresh regexp_list content
              Backup.dir_list = Builtins.maplist(Backup.dir_list) do |i|
                i == value ? new_txt : i
              end
            end
          elsif type == @filesystem_text
            if Builtins.contains(Backup.fs_exclude, new_txt)
              # error popup message
              Popup.Error(
                Builtins.sformat(
                  _("File system %1 is already in the list."),
                  new_txt
                )
              )
            else
              # refresh regexp_list content
              Backup.fs_exclude = Builtins.maplist(Backup.fs_exclude) do |i|
                i == value ? new_txt : i
              end
            end
          end

          # refresh table content
          RedrawConstraintsTable()
        end
      end

      nil
    end

    def ExcludeItemDelete(value, type)
      # remove selected constraint
      if type == @regexp_text
        Backup.regexp_list = Builtins.filter(Backup.regexp_list) do |i|
          i != value
        end
      elsif type == @directory_text
        Backup.dir_list = Builtins.filter(Backup.dir_list) { |i| i != value }
      elsif type == @filesystem_text
        Backup.fs_exclude = Builtins.filter(Backup.fs_exclude) { |i| i != value }
      end

      # refresh table content
      RedrawConstraintsTable()

      nil
    end

    # Managing Include dirs -->

    def AddIncludeItemNow(new_dir)
      # Removing "/" if present
      if Builtins.contains(Backup.include_dirs, Backup.default_include_dir)
        Backup.include_dirs = Builtins.filter(Backup.include_dirs) do |one_dir|
          one_dir != Backup.default_include_dir
        end
      end

      # Removing the last slash
      if Builtins.regexpmatch(new_dir, "^.+/$")
        new_dir = Builtins.regexpsub(new_dir, "^(.+)/$", "\\1")
      end

      if new_dir == Backup.default_include_dir
        Builtins.y2milestone("Selecting the whole fs '/'")
        Backup.include_dirs = [Backup.default_include_dir]
      else
        # Adding new directory
        Backup.include_dirs = Builtins.toset(
          Builtins.add(Backup.include_dirs, new_dir)
        )
      end

      nil
    end

    def AddIncludeItem
      while true
        # return $[ "text" : text, "clicked" : input ];
        new_dir = ShowEditBrowseDialog(_("&Add New Directory"), "")

        if Ops.get(new_dir, "clicked") == :ok &&
            Ops.get_string(new_dir, "text", "") != "" &&
            Ops.get(new_dir, "text") != nil
          # bnc #395835
          if Mode.normal &&
              !FileUtils.Exists(Ops.get_string(new_dir, "text", "")) &&
              !Popup.AnyQuestion(
                _("Warning"),
                Builtins.sformat(
                  _(
                    "Directory %1 does not exist.\n" +
                      "\n" +
                      "Use it anyway?"
                  ),
                  Ops.get_string(new_dir, "text", "")
                ),
                _("Yes, Use It"),
                Label.NoButton,
                :focus_yes
              )
            next
          end

          AddIncludeItemNow(Ops.get_string(new_dir, "text", ""))

          RedrawIncludeTable()
        end

        break
      end

      nil
    end

    def DeleteIncludeItem(delete_dir)
      if Confirm.DeleteSelected &&
          Builtins.contains(Backup.include_dirs, delete_dir)
        Backup.include_dirs = Builtins.filter(Backup.include_dirs) do |one_dir|
          one_dir != delete_dir
        end

        RedrawIncludeTable()
      end

      nil
    end

    def EditIncludeItem(old_item)
      new_dir = ShowEditBrowseDialog(_("&Edit Included Directory"), old_item)

      if Ops.get(new_dir, "clicked") == :ok &&
          Ops.get_string(new_dir, "text", "") != "" &&
          Ops.get(new_dir, "text") != nil
        # item changed
        if Ops.get_string(new_dir, "text", "") != old_item
          DeleteIncludeItem(old_item)
          AddIncludeItemNow(Ops.get_string(new_dir, "text", ""))

          RedrawIncludeTable()
        end
      end

      nil
    end

    # <-- Managing Include dirs

    # Dialog for setting excluded directories, file systems and reg. expressions
    # @return [Symbol] Symbol for wizard sequencer - pressed button
    def ConstraintDialog
      ret = InitConstraintDialog()
      return ret if ret != nil

      foundfilesystems = Convert.convert(
        SCR.Read(path(".proc.filesystems")),
        :from => "any",
        :to   => "map <string, string>"
      )
      all_fss = []

      if Ops.greater_than(Builtins.size(foundfilesystems), 0)
        Builtins.foreach(foundfilesystems) do |fsname, flag|
          all_fss = Builtins.add(all_fss, fsname)
        end
      end

      curr = nil
      type = nil
      value = nil
      line = nil

      # --> while
      while ret != :next && ret != :back && ret != :abort
        ret = Convert.to_symbol(UI.UserInput)
        Builtins.y2milestone("Ret: %1", ret)

        # Managing Exclude items
        if Builtins.contains([:edit, :delete, :dir, :fs, :regexp], ret)
          curr = Convert.to_integer(UI.QueryWidget(Id(:const), :CurrentItem))
          if curr != nil
            Builtins.y2milestone("current item: %1", curr)
            line = Convert.to_term(
              UI.QueryWidget(Id(:const), term(:Item, curr))
            )
            Builtins.y2milestone("current option: %1", line)

            value = Ops.get_string(line, 1)
            Builtins.y2milestone("value: %1", value)

            type = Ops.get_string(line, 2)
            Builtins.y2milestone("type: %1", type)
          end 
          # Managing Include items
        elsif Builtins.contains(
            [:add_include, :edit_include, :delete_include],
            ret
          )
          value = Convert.to_string(UI.QueryWidget(Id(:include), :CurrentItem))
          Builtins.y2milestone("value: %1", value)
        end

        # Exclude item - delete
        if ret == :delete && type != nil && value != nil
          ExcludeItemDelete(value, type) 
          # Exclude item - edit
        elsif ret == :edit && type != nil && value != nil
          all_fss_ref = arg_ref(all_fss)
          ExcludeItemEdit(value, type, all_fss_ref)
          all_fss = all_fss_ref.value 
          # Exclude item - add regexp
        elsif ret == :regexp
          AddExcludeItem_Regexp() 
          # Exclude item - add directory
        elsif ret == :dir
          AddExcludeItem_Dir() 
          # Exclude item - add filesystem
        elsif ret == :fs
          all_fss_ref = arg_ref(all_fss)
          AddExcludeItem_Fs(all_fss_ref)
          all_fss = all_fss_ref.value 
          # Include Directory - add
        elsif ret == :add_include
          AddIncludeItem() 
          # Include Directory - delete
        elsif ret == :delete_include
          DeleteIncludeItem(value) 
          # Include Directory - edit
        elsif ret == :edit_include
          EditIncludeItem(value) 
          # Unknown
        elsif ret != :next && ret != :back && ret != :abort
          Builtins.y2error("Unknown ret %1", ret)
        end
      end
      # <-- while

      if Backup.selected_profile != nil
        # Restore 'next' button
        Wizard.RestoreNextButton
      end

      ret
    end
  end
end
