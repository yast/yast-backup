# encoding: utf-8

# Backup module - testsuite
#
# RestoreBackupProfile function test
#
# testedfiles: Backup.ycp
#
# $Id$
#
module Yast
  class RestoreBackupProfileClient < Client
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

      @READ = {
        "target" => {
          "ycp" => {
            "ahoj"  => {
              :archive_name         => "/tmp/ahoj.tar",
              :archive_type         => :tgz,
              :backup_all_ext2      => false,
              :backup_none_ext2     => true,
              :backup_pt            => true,
              :backup_selected_ext2 => false,
              :default_dir          => [
                "/tmp",
                "/var/lock",
                "/var/run",
                "/var/tmp",
                "/var/cache"
              ],
              :description          => "",
              :detected_ext2        => nil,
              :detected_fs          => nil,
              :dir_list             => nil,
              :display              => true,
              :do_md5_test          => false,
              :ext2_backup          => [],
              :fs_exclude           => ["iso9660"],
              :multi_volume         => false,
              :search               => false,
              :system               => false,
              :unselected_files     => ["/etc/inittab"],
              :user_volume_size     => "",
              :user_volume_unit     => nil,
              :volume_size          => :fd144
            },
            "final" => {
              :archive_name         => "/tmp/ahoj.tar",
              :archive_type         => :tgz,
              :backup_all_ext2      => false,
              :backup_none_ext2     => true,
              :backup_pt            => true,
              :backup_selected_ext2 => false,
              :default_dir          => [
                "/tmp",
                "/var/lock",
                "/var/run",
                "/var/tmp",
                "/var/cache"
              ],
              :description          => "",
              :detected_ext2        => nil,
              :detected_fs          => [
                "devpts",
                "nfs",
                "proc",
                "reiserfs",
                "rootfs",
                "shm"
              ],
              :dir_list             => [
                "/tmp",
                "/var/lock",
                "/var/run",
                "/var/tmp",
                "/var/cache",
                "/usr",
                "/home",
                "/local",
                "/etc",
                "/var",
                "/opt"
              ],
              :display              => false,
              :do_md5_test          => true,
              :ext2_backup          => [],
              :fs_exclude           => [
                "bdev",
                "devpts",
                "futexfs",
                "iso9660",
                "nfs",
                "pipefs",
                "proc",
                "ramfs",
                "rootfs",
                "shm",
                "sockfs",
                "tmpfs",
                "usbfs"
              ],
              :multi_volume         => false,
              :search               => true,
              :system               => false,
              :unselected_files     => nil,
              :user_volume_size     => "",
              :user_volume_unit     => :B,
              :volume_size          => :fd144
            }
          }
        }
      }

      # read profiles
      Testsuite.Test(lambda { Backup.ReadBackupProfiles }, [@READ], nil)

      # restore settings from one of the profiles
      Testsuite.Test(lambda { Backup.RestoreSettingsFromBackupProfile("final") }, [], nil)

      # remove all profiles
      Backup.backup_profiles = {}

      # store the settings into profile
      Testsuite.Test(lambda { Backup.StoreSettingsToBackupProfile("final") }, [], nil)

      # dump the result
      Testsuite.Dump(Backup.backup_profiles)

      nil
    end
  end
end

Yast::RestoreBackupProfileClient.new.main
