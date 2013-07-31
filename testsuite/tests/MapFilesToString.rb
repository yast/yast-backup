# encoding: utf-8

# Backup module - testsuite
#
# Backup::MapFilesToString function tests
#
# testedfiles: Backup.ycp
#
# $Id$
#
module Yast
  class MapFilesToStringClient < Client
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

      # initialize variables from Backup module
      Backup.backup_files = nil
      Backup.selected_files = {
        "aaa_base-2001.5.22-0" =>
          #"install_prefixes" : "(none)"
          { "changed_files" => ["/etc/modules.conf"] }
      }

      Testsuite.Dump([Backup.MapFilesToString])

      Backup.backup_files = {}
      Testsuite.Dump([Backup.MapFilesToString])

      Backup.backup_files = {
        "pkg1"                 => {
          "changed_files"    => [],
          "install_prefixes" => []
        },
        "pkg2"                 => {
          "changed_files"    => nil,
          "install_prefixes" => nil
        },
        "aaa_base-2001.5.22-0" => {
          "changed_files" => ["/etc/inittab", "/etc/modules.conf"]
        },
        ""                     => {
          "changed_files" => ["/etc/fstab", "/etc/passwd"]
        },
        "pkg3"                 => nil
      }

      Backup.selected_files = Builtins.add(
        Backup.selected_files,
        "",
        { "changed_files" => ["/etc/fstab"] }
      )

      Testsuite.Dump([Backup.MapFilesToString])

      nil
    end
  end
end

Yast::MapFilesToStringClient.new.main
