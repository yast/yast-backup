# encoding: utf-8

# Backup module - testsuite
#
# WriteBackupProfiles function test
#
# testedfiles: Backup.ycp
#
# $Id$
#
module Yast
  class WriteBackupProfilesClient < Client
    def main
      Yast.import "Testsuite"

      @readmap = {
        "target" => { "string" => "", "size" => -1, "tmpdir" => "/tmp" },
        "proc"   => { "cpuinfo" => { "value" => { "0" => { "flags" => "" } } } },
        "probe"  => {
          "has_smp" => false,
          "is_uml"  => false,
          "cdrom"   => { "manual" => [] }
        }
      }

      @execmap = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stderr" => "",
            "stdout" => "charmap=\"ISO-8859-1\"\n"
          }
        }
      }

      Testsuite.Init([@readmap, {}, @execmap], nil)

      Yast.import "Pkg" # override packamanager

      Yast.import "Backup"

      Testsuite.Dump(Backup.backup_profiles)

      Backup.StoreSettingsToBackupProfile("default profile")

      # setup global settings
      Backup.archive_name = "Does not work"
      Backup.description = "Does not work - profile"
      Backup.archive_type = nil
      Backup.multi_volume = nil
      Backup.volume_size = nil
      Backup.user_volume_size = nil
      Backup.user_volume_unit = nil
      Backup.do_search = nil
      Backup.system = nil
      Backup.display = nil
      Backup.do_md5_test = nil
      Backup.default_dir = nil
      Backup.dir_list = nil
      Backup.fs_exclude = nil
      Backup.detected_fs = nil
      Backup.detected_ext2 = nil
      Backup.ext2_backup = nil
      Backup.backup_pt = nil
      Backup.backup_all_ext2 = nil
      Backup.backup_none_ext2 = nil
      Backup.backup_selected_ext2 = nil
      Backup.unselected_files = nil

      Backup.selected_files = nil
      Backup.backup_files = {}

      Backup.StoreSettingsToBackupProfile("empty profile")

      Testsuite.Dump(Backup.backup_profiles)

      nil
    end
  end
end

Yast::WriteBackupProfilesClient.new.main
