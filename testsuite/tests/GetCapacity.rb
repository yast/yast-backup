# encoding: utf-8

# Backup module - testsuite
#
# GetCapacity function tests
#
# testedfiles: Backup.ycp
#
# $Id$
#
module Yast
  class GetCapacityClient < Client
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

      Testsuite.Dump(Backup.GetCapacity(nil, nil))
      Testsuite.Dump(Backup.GetCapacity([], :s))
      Testsuite.Dump(Backup.GetCapacity([{ "capacity" => 1440000 }], :s))

      Testsuite.Dump(
        Backup.GetCapacity(
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
          ],
          :fd12
        )
      )

      nil
    end
  end
end

Yast::GetCapacityClient.new.main
