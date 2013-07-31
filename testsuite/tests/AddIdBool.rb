# encoding: utf-8

# Backup module - testsuite
#
# AddIdBool function tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class AddIdBoolClient < Client
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

      Testsuite.Dump(AddIdBool(nil, nil))
      Testsuite.Dump(AddIdBool([], true))
      Testsuite.Dump(AddIdBool([Item(Id("ext2"), "ext2", true)], false))
      Testsuite.Dump(AddIdBool(["abcd"], true))

      nil
    end
  end
end

Yast::AddIdBoolClient.new.main
