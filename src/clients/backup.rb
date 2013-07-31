# encoding: utf-8

#  File:
#    backup.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Main file for backup module - definition of workflow
#
module Yast
  class BackupClient < Client
    def main
      Yast.import "UI"

      Builtins.y2milestone(" *** Backup module started *** ")

      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "Backup"
      Yast.import "Report"
      Yast.import "Sequencer"
      Yast.import "Popup"
      Yast.import "CommandLine"

      Yast.include self, "backup/functions.rb"
      Yast.include self, "backup/ui.rb"

      textdomain "backup"

      @confirm_abort = false # confirm abort

      # sequence of dialogs
      @sequence = {
        "ws_start"       => "readprof",
        "readprof"       => {
          :edit   => "archive",
          :start  => "scripts_before",
          :start  => "constraint",
          :manual => "archive",
          :cron   => "cron",
          :abort  => :abort,
          :finish => :ws_finish
        },
        "cron"           => { :next => "readprof", :abort => :abort },
        "archive"        => {
          :next    => "backup",
          :tar_opt => "tar_opt",
          :abort   => :abort
        },
        "tar_opt"        => { :ok => "archive", :abort => :abort },
        "backup"         => {
          :next  => "constraint",
          :next2 => "scripts_before",
          :xpert => "options",
          :abort => :abort
        },
        "constraint"     => { :next => "searching", :abort => :abort },
        "options"        => {
          :finish     => "backup",
          :set_system => "system",
          :abort      => :abort
        },
        "system"         => { :finish => "options", :abort => :abort },
        "searching"      => { :next => "scripts_before", :ok => "readprof" },
        "scripts_before" => { :next => "do_searching", :abort => :abort },
        "do_searching"   => {
          :next       => "files",
          :next2      => "archiving",
          :maindialog => "readprof",
          :abort      => :abort
        },
        "files"          => {
          :next            => "archiving",
          :abort           => :abort,
          # from "files" <back points to "constraint"
          :back_from_files => "constraint"
        },
        "archiving"      => { :next => "scripts_after", :abort => :abort },
        "scripts_after"  => { :next => "summary", :abort => :abort },
        "summary"        => { :abort => :abort, :finish => "readprof" }
      }

      # aliases for dialogs
      @aliases = {
        "readprof"       => lambda { SelectProfileDialog() },
        "cron"           => [lambda { CronDialog() }, true],
        "files"          => lambda { FilesDialog() },
        "tar_opt"        => lambda { TarOptionsDialog() },
        "archive"        => lambda { ArchDialog() },
        "backup"         => lambda { BackupDialog() },
        "options"        => lambda { ExpertOptionsDialog() },
        "constraint"     => lambda { ConstraintDialog() },
        "system"         => lambda { SystemBackupDialog() },
        "searching"      => lambda { PrepareSearching() },
        "scripts_before" => lambda { CallScriptsBeforeBackup() },
        "do_searching"   => [lambda { SearchingModifiedDialog() }, true],
        "archiving"      => [lambda { ArchivingDialog() }, true],
        "scripts_after"  => lambda { CallScriptsAfterBackup() },
        "summary"        => lambda { SummaryDialog() }
      }

      @cmdline_description = { "id" => "backup" }

      @args = WFM.Args
      Builtins.y2milestone("args: %1", @args)

      # starting cron mode
      if Ops.get_string(@args, 0, "") == "cron"
        Builtins.y2milestone("Starting in cron mode")
        Backup.cron_mode = true

        # BNC #548427: Mode acts like it was in a testsuite
        #              if it actually running in cron mode
        Builtins.y2milestone("Adjusting Mode UI to: commandline")
        Mode.SetUI("commandline")

        if Ops.get(@args, 1) != nil
          Backup.cron_profile = Builtins.regexpsub(
            Ops.get_string(@args, 1, ""),
            "^[ \t]*profile[ \t]*=[ \t]*(.*)",
            "\\1"
          )
          Builtins.y2milestone("Using profile: '%1'", Backup.cron_profile)
        end 
        # starting CMDLine mode (!cron mode)
      elsif Ops.greater_than(Builtins.size(@args), 0)
        @ret = CommandLine.Run(@cmdline_description)
        return deep_copy(@ret)
      end

      if Backup.cron_mode != true
        Yast.import "Wizard"

        # create wizard dialog
        Wizard.CreateDialog
        # set icon
        Wizard.SetDesktopTitleAndIcon("backup")
      end

      Backup.ReadBackupProfiles

      if Backup.cron_mode == true
        if Backup.RestoreSettingsFromBackupProfile(Backup.cron_profile) == false
          Builtins.y2error(
            "Cannot read settings from profile '%1'",
            Backup.cron_profile
          )
          return false
        end

        # change workflow - start searching immediately, exit at summary stage
        Ops.set(@sequence, "ws_start", "scripts_before")
        Ops.set(@sequence, "summary", { :abort => :abort, :finish => :finish })

        # disable user interaction
        Backup.no_interactive = true

        # dont'display eny message - there is no UI in cron mode
        Report.DisplayMessages(false, 0)
        Report.DisplayWarnings(false, 0)
        Report.DisplayErrors(false, 0)

        @sel_profile = Builtins.eval(
          Ops.get(Backup.backup_profiles, Backup.cron_profile, {})
        )

        # prepare backup - e.g. mount NFS share
        Backup.PrepareBackup

        # check existing archive, remove old archives
        @localfilename = Backup.GetLocalArchiveName
        Backup.remove_result = Backup.RemoveOldArchives(
          @localfilename,
          Ops.get_integer(@sel_profile, [:cron_settings, "old"], 100000),
          Backup.multi_volume
        )
      end

      # start wizard sequencer
      Sequencer.Run(@aliases, @sequence)

      if Backup.cron_mode != true
        # close dialog
        Wizard.CloseDialog
      end

      Builtins.y2milestone(" *** Backup module finished *** ")

      nil
    end
  end
end

Yast::BackupClient.new.main
