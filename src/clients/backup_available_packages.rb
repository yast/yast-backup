# encoding: utf-8

#  File:
#    backup_available_packages.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Client for saving available packages on the installation sources
#  to file.
module Yast
  class BackupAvailablePackagesClient < Client
    def main
      Yast.import "UI"

      Yast.include self, "backup/functions.rb"

      Builtins.y2milestone(" *** backup_available_packages client started ***")

      # get list of packages on the installation source
      @ipackages = Builtins.sort(GetInstallPackages())

      Builtins.y2debug("installable packages: %1", @ipackages)
      Builtins.y2debug("Arguments: %1", WFM.Args)

      if Ops.is_string?(WFM.Args(0))
        # convert list to string
        @file_content = Builtins.mergestring(@ipackages, "\n")
        @filename = Convert.to_string(WFM.Args(0))

        if Ops.greater_than(Builtins.size(@filename), 0)
          # save string to the file
          @res = SCR.Write(path(".target.string"), @filename, @file_content)

          if !@res
            Builtins.y2error("Cannot save package list to file %1", @filename)
          end
        end
      else
        Builtins.y2error("Missing argument or it isn't string")
      end

      Builtins.y2milestone(" *** backup_available_packages client finished ***")

      nil
    end
  end
end

Yast::BackupAvailablePackagesClient.new.main
