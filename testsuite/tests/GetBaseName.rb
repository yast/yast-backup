# encoding: utf-8

# Backup module - testsuite
#
# GetBaseName tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class GetBaseNameClient < Client
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

      Testsuite.Test(lambda { GetBaseName(nil) }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("file") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("file.ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/file") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/file.ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/dir/") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/dir/dir2/file.ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/dir.1/dir.2/file") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { GetBaseName("/dir.1/dir.2/file.ext") }, [
        {},
        {},
        {}
      ], nil)

      nil
    end
  end
end

Yast::GetBaseNameClient.new.main
