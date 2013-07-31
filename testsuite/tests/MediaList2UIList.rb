# encoding: utf-8

# Backup module - testsuite
#
# MediaList2UIList function tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class MediaList2UIListClient < Client
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

      Testsuite.Dump(MediaList2UIList(nil))
      Testsuite.Dump(MediaList2UIList([]))
      Testsuite.Dump(MediaList2UIList([{ "capacity" => 1440000 }]))

      Testsuite.Dump(
        MediaList2UIList(
          [
            {
              "label"    => "Floppy 1.44 MB",
              "symbol"   => :fd144,
              "capacity" => 1440000
            },
            {
              "label"    => "Floppy 1.2 MB",
              "symbol"   => :fd12,
              "capacity" => 1200000
            }
          ]
        )
      )

      nil
    end
  end
end

Yast::MediaList2UIListClient.new.main
