# encoding: utf-8

# Backup module - testsuite
#
# AddIdExt function tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class AddIdExt2Client < Client
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

      Testsuite.Dump(AddIdExt2(nil))
      Testsuite.Dump(AddIdExt2([]))
      Testsuite.Dump(
        AddIdExt2([{ "partition" => "/dev/hda3", "mountpoint" => "/usr" }])
      )
      Testsuite.Dump(
        AddIdExt2(
          [
            { "partition" => "/dev/hda3", "mountpoint" => "/usr" },
            { "partition" => "/dev/hda1", "mountpoint" => "/" }
          ]
        )
      )

      nil
    end
  end
end

Yast::AddIdExt2Client.new.main
