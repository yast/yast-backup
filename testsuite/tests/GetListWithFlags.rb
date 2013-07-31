# encoding: utf-8

# Backup module - testsuite
#
# GetListWithFlags function tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class GetListWithFlagsClient < Client
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

      Testsuite.Dump(GetListWithFlags(nil, nil))
      Testsuite.Dump(GetListWithFlags([], []))
      Testsuite.Dump(GetListWithFlags([], ["/dev"]))
      Testsuite.Dump(GetListWithFlags(["/dev"], []))
      Testsuite.Dump(GetListWithFlags(["/dev", "/etc"], ["/etc"]))

      nil
    end
  end
end

Yast::GetListWithFlagsClient.new.main
