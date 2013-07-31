# encoding: utf-8

# Backup module - testsuite
#
# Ext2Filesystems function tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class Ext2FilesystemsClient < Client
    def main
      Yast.import "UI"
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

      Yast.include self, "backup/functions.rb"

      @READ_mounts = {
        "proc" => {
          "mounts" => [
            {
              "file"    => "/",
              "freq"    => 0,
              "mntops"  => "rw",
              "passno"  => 0,
              "spec"    => "/dev/root",
              "vfstype" => "reiserfs"
            },
            {
              "file"    => "/proc",
              "freq"    => 0,
              "mntops"  => "rw",
              "passno"  => 0,
              "spec"    => "proc",
              "vfstype" => "proc"
            },
            {
              "file"    => "/dev/pts",
              "freq"    => 0,
              "mntops"  => "rw",
              "passno"  => 0,
              "spec"    => "devpts",
              "vfstype" => "devpts"
            },
            {
              "file"    => "/boot",
              "freq"    => 0,
              "mntops"  => "rw",
              "passno"  => 0,
              "spec"    => "/dev/hda1",
              "vfstype" => "ext2"
            },
            {
              "file"    => "/local",
              "freq"    => 0,
              "mntops"  => "rw",
              "passno"  => 0,
              "spec"    => "/dev/hda4",
              "vfstype" => "ext2"
            }
          ]
        },
        "etc"  => {
          "fstab" => [
            {
              "file"    => "/media/cdrom",
              "freq"    => 0,
              "mntops"  => "ro,noauto,user,exec",
              "passno"  => 0,
              "spec"    => "/dev/cdrom",
              "vfstype" => "auto"
            },
            {
              "file"    => "/unmountedk",
              "freq"    => 0,
              "mntops"  => "defaults",
              "passno"  => 0,
              "spec"    => "/dev/hdb1",
              "vfstype" => "ext2"
            }
          ]
        }
      }


      Testsuite.Test(lambda { Ext2Filesystems() }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { Ext2Filesystems() }, [@READ_mounts, {}, {}], nil)

      nil
    end
  end
end

Yast::Ext2FilesystemsClient.new.main
