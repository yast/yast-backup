# encoding: utf-8

#  File:
#    backup_save_profile.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Client for saving AutoYaST profile to file, profile contains
#  information about current system.
module Yast
  class BackupSaveProfileClient < Client
    def main
      Yast.import "UI"

      Yast.include self, "backup/functions.rb"

      Builtins.y2milestone(" *** backup_save_profile client started ***")
      Builtins.y2milestone("Arguments: %1", WFM.Args)

      if Ops.greater_or_equal(Builtins.size(WFM.Args), 4) &&
          Ops.is_string?(WFM.Args(0)) &&
          Ops.is_list?(WFM.Args(1)) &&
          Ops.is_string?(WFM.Args(2)) &&
          Ops.is_map?(WFM.Args(3))
        @filename = Convert.to_string(WFM.Args(0))
        @additional = Convert.convert(
          WFM.Args(1),
          :from => "any",
          :to   => "list <string>"
        )
        @extra_key = Convert.to_string(WFM.Args(2))
        @extra_options = Convert.to_map(WFM.Args(3))

        if Ops.greater_than(Builtins.size(@filename), 0)
          # create profile and save it to the file
          @res = CloneSystem(@filename, @additional, @extra_key, @extra_options)

          if !@res
            Builtins.y2error(
              "Cannot create or save autoinstallation to file %1",
              @filename
            )
          end
        end
      else
        Builtins.y2error("Missing arguments or they have wrong type")
      end

      Builtins.y2milestone(" *** backup_save_profile client finished ***")

      nil
    end
  end
end

Yast::BackupSaveProfileClient.new.main
