# encoding: utf-8

# Backup module - testsuite
#
# AddMissingExtension tests
#
# testedfiles: backup/functions.ycp
#
# $Id$
#
module Yast
  class AddMissingExtensionClient < Client
    def main
      Yast.import "UI"
      Yast.import "Testsuite"

      @readmap = {
        "target" => {
          "string" => "",
          "size"   => -1,
          "tmpdir" => "/tmp",
          "stat"   => {
            "atime"   => 1101890288,
            "ctime"   => 1101890286,
            "gid"     => 0,
            "inode"   => 29236,
            "isblock" => true,
            "ischr"   => false,
            "isdir"   => false,
            "isfifo"  => false,
            "islink"  => false,
            "isreg"   => false,
            "issock"  => false,
            "mtime"   => 1101890286,
            "nlink"   => 1,
            "size"    => 804,
            "uid"     => 0
          }
        },
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

      Testsuite.Test(lambda { AddMissingExtension(nil, nil) }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("", ".tar") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("file", nil) }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("file", ".ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("/dir/file", "") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda { AddMissingExtension("/dir/file", ".ext") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda { AddMissingExtension("file.ext", ".ext") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda { AddMissingExtension(".ext", ".ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("f", ".ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension(nil, ".ext") }, [{}, {}, {}], nil)
      Testsuite.Test(lambda { AddMissingExtension("/dir.ext/file", ".ext") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda { AddMissingExtension("/dir.ext/", ".ext") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda { AddMissingExtension("/dir.ext/file.ext", ".ext") }, [
        {},
        {},
        {}
      ], nil)
      Testsuite.Test(lambda do
        AddMissingExtension("/dir1.ext/dir2.ext/file", ".ext")
      end, [
        {},
        {},
        {}
      ], nil)

      # '/dev/' and block devices should not be bothered by adding an extension
      # bugzilla #185042
      # see "target" : $[ "stat" : $[] ]
      Testsuite.Test(lambda { AddMissingExtension("/dev/nst0", ".ext") }, [
        {},
        {},
        {}
      ], nil)

      # #180631 problems with non-ascii characters
      Testsuite.Test(lambda do
        AddMissingExtension("/foo/tu\u010D\u0148\u00E1k.png", ".png")
      end, [
        {},
        {},
        {}
      ], nil)

      nil
    end
  end
end

Yast::AddMissingExtensionClient.new.main
