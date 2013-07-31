# encoding: utf-8

# Backup module - testsuite
#
# ExcludeNodevFS function test
#
# testedfiles: Backup.ycp
#
# $Id$
#
module Yast
  class ExcludeNodevFSClient < Client
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

      @readmap = {}
      Testsuite.Test(lambda { Backup.ExcludeNodevFS }, [@readmap, {}, @execmap], nil)
      Testsuite.Dump(Backup.fs_exclude)

      @readmap = {
        "proc" => {
          "filesystems" => {
            "afs"      => "nodev",
            "iso9660"  => "\t",
            "minix"    => "\t",
            "nfs"      => "nodev",
            "pipefs"   => "nodev",
            "proc"     => "nodev",
            "ramfs"    => "nodev",
            "reiserfs" => "\t",
            "rootfs"   => "nodev"
          }
        }
      }
      Testsuite.Test(lambda { Backup.ExcludeNodevFS }, [@readmap, {}, @execmap], nil)
      Testsuite.Dump(Backup.fs_exclude)

      @readmap = {}
      Backup.fs_exclude = []
      Testsuite.Test(lambda { Backup.ExcludeNodevFS }, [@readmap, {}, @execmap], nil)
      Testsuite.Dump(Backup.fs_exclude)

      nil
    end
  end
end

Yast::ExcludeNodevFSClient.new.main
