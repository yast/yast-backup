# encoding: utf-8

#  File:
#    functions.ycp
#
#  Module:
#    Backup module
#
#  Authors:
#    Ladislav Slezak <lslezak@suse.cz>
#
#  $Id$
#
#  Functions used by backup module.
module Yast
  module BackupFunctionsInclude
    def initialize_backup_functions(include_target)
      Yast.import "UI"

      Yast.import "Label"
      Yast.import "Report"

      Yast.import "Nfs"
      Yast.import "Popup"
      Yast.import "FileUtils"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "String"

      textdomain "backup"
    end

    # Display abort confirmation dialog
    # @param [Symbol] type Select dialog type, possible values: `changed, `not_changed or `none for none dialog
    # @return [Boolean] False if user select to not abort, true otherwise.

    def AbortConfirmation(type)
      ret = nil

      # popup dialog header
      heading = _("Abort Confirmation")
      # popup dialog question
      question = _("Really abort the backup?")
      yes = Label.YesButton
      no = Label.NoButton

      if type == :changed
        ret = Popup.AnyQuestion(heading, question, yes, no, :focus_no)
      else
        if type == :not_changed
          ret = Popup.AnyQuestion(heading, question, yes, no, :focus_yes)
        else
          if type == :none
            ret = true
          else
            Builtins.y2warning(
              "Unknown type of abort confirmation dialog: %1",
              type
            )
          end
        end
      end

      ret
    end


    # Ask user for some value: display dialog with label, text entry and OK/Cancel buttons.
    # @param [String] label Displayed text above the text entry in the dialog
    # @param [String] value Default text in text entry, for empty text set value to "" or nil
    # @param [Array<String>] values - pre-defined values for combo-box
    # @param [Array<String>] forbidden_letters - letters that will be filtered out
    # @return [Hash] Returned map: $[ "text" : string, "clicked" : symbol ]. Value with key text is string entered by user, symbol is `ok or `cancel depending which button was pressed.

    def ShowEditDialog(label, value, values, forbidden_letters)
      values = deep_copy(values)
      forbidden_letters = deep_copy(forbidden_letters)
      label = "" if label == nil

      value = "" if value == nil

      combo_content = []

      if values != nil && Ops.greater_than(Builtins.size(values), 0)
        combo_content = Builtins.maplist(values) do |v|
          Item(Id(v), v, v == value)
        end
      end

      UI.OpenDialog(
        VBox(
          Ops.greater_than(Builtins.size(combo_content), 0) ?
            ComboBox(Id(:te), Opt(:hstretch, :editable), label, combo_content) :
            InputField(Id(:te), Opt(:hstretch), label, value),
          VSpacing(1.0),
          HBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          )
        )
      )

      UI.SetFocus(Id(:te))

      input = Convert.to_symbol(UI.UserInput)

      text = Convert.to_string(UI.QueryWidget(Id(:te), :Value))
      UI.CloseDialog

      if forbidden_letters != nil && forbidden_letters != []
        Builtins.foreach(forbidden_letters) do |one_letter|
          text = Builtins.mergestring(
            Builtins.splitstring(text, one_letter),
            ""
          )
        end
      end

      { "text" => text, "clicked" => input }
    end

    def ShowEditBrowseDialog(label, value)
      label = "" if label == nil

      value = "" if value == nil

      UI.OpenDialog(
        VBox(
          HBox(
            InputField(Id(:te), Opt(:hstretch), label, value),
            HSpacing(1.0),
            VBox(VSpacing(0.9), PushButton(Id(:browse), Label.BrowseButton))
          ),
          VSpacing(1.0),
          HBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          )
        )
      )

      UI.SetFocus(Id(:te))

      input = nil

      while true
        input = Convert.to_symbol(UI.UserInput)

        if input == :browse
          start_dir = value == "" ? "/" : value
          new_dir = UI.AskForExistingDirectory(
            start_dir,
            _("Select a directory to be included...")
          )
          UI.ChangeWidget(Id(:te), :Value, new_dir) if new_dir != nil
        elsif input == :ok || input == :cancel
          break
        end
      end

      text = Convert.to_string(UI.QueryWidget(Id(:te), :Value))
      UI.CloseDialog

      { "text" => text, "clicked" => input }
    end

    # Returns list of mounted file systems types.
    # @return [Array] List of strings, each mounted file system type is reported only onetimes, list is alphabetically sorted.
    # @example GetMountedFilesystems() -> [ "devpts", "ext2", "nfs", "proc", "reiserfs" ]

    def GetMountedFilesystems
      mounted = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      result = []

      return [] if mounted == nil

      Builtins.foreach(mounted) do |m|
        fs = Ops.get_string(m, "vfstype")
        Ops.set(result, Builtins.size(result), fs) if fs != nil
      end 


      Builtins.toset(result)
    end


    # Returns list of Ext2 mountpoints - actually mounted and from /etc/fstab file
    # @return [Array] List of strings
    # @example Ext2Filesystems() -> [ "/dev/hda1", "/dev/hda4" ]

    def Ext2Filesystems
      mounted = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      ext2mountpoints = []
      tmp_parts = []

      Builtins.foreach(mounted) do |m|
        fs = Ops.get_string(m, "vfstype")
        dev = Ops.get_string(m, "spec")
        file = Ops.get_string(m, "file")
        if fs == "ext2" && dev != nil && !Builtins.contains(tmp_parts, dev)
          ext2mountpoints = Builtins.add(
            ext2mountpoints,
            { "partition" => dev, "mountpoint" => file }
          )
          tmp_parts = Builtins.add(tmp_parts, dev)
        end
      end if mounted != nil

      fstab = Convert.convert(
        SCR.Read(path(".etc.fstab")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )

      Builtins.foreach(fstab) do |f|
        fs = Ops.get_string(f, "vfstype")
        dev = Ops.get_string(f, "spec")
        file = Ops.get_string(f, "file")
        if fs == "ext2" && dev != nil && !Builtins.contains(tmp_parts, dev)
          ext2mountpoints = Builtins.add(
            ext2mountpoints,
            { "partition" => dev, "mountpoint" => file }
          )
          tmp_parts = Builtins.add(tmp_parts, dev)
        end
      end if fstab != nil

      deep_copy(ext2mountpoints)
    end


    # This function reads two lists: full list and selection list (contains subset of items in full list). Returned list can be used in MultiSelectionBox widget.
    # @return [Array] List of alphabetically sorted strings
    # @param [Array<String>] in List of items
    # @param [Array<String>] selected List with subset of items from list in.
    # @example GetListWithFlags(["/dev", "/etc"], ["/etc"]) -> [`item (`id ("/dev"), "/dev", false), `item (`id ("/etc"), "/etc", true)]

    def GetListWithFlags(_in, selected)
      _in = deep_copy(_in)
      selected = deep_copy(selected)
      return [] if _in == nil

      Builtins.maplist(_in) do |i|
        Item(Id(i), i, Builtins.contains(selected, i) ? true : false)
      end
    end

    # Set boolean value val to all items in list.
    # @return [Array] List of items
    # @param [Array] in Input list of items
    # @param [Boolean] val Requested value
    # @example AddIdBool( [ `item(`id("ext2"), "ext2", true) ], false) ) -> [ `item (`id ("ext2"), "ext2", false) ]

    def AddIdBool(_in, val)
      _in = deep_copy(_in)
      val = false if val == nil

      return [] if _in == nil

      Builtins.maplist(_in) do |i|
        tmp_id = nil
        tmp_s = nil
        isterm = Ops.is_term?(i)
        if isterm
          ti = Convert.to_term(i)
          tmp_id = Ops.get_term(ti, 0)
          tmp_s = Ops.get_string(ti, 1)
        end
        isterm && tmp_id != nil && tmp_s != nil ? Item(tmp_id, tmp_s, val) : nil
      end
    end


    # Returns list of items from list of values.
    # @return [Array] List of items
    # @param [Array<String>] in Input list of values
    # @example AddId("abc", "123") -> [`item(`id("abc"), "abc"), `item(`id("123"), "123")]

    def AddId(_in)
      _in = deep_copy(_in)
      return [] if _in == nil

      Builtins.maplist(_in) { |i| Item(Id(i), i) }
    end


    # Returns list of items from list of values.
    # @return [Array] List of items
    # @param [Array<Hash{String => Object>}] in Input list of maps with keys "partition", "mountpoints" and strings as values
    # @example AddId([ $["partition" : "/dev/hda3", "mountpoint" : "/usr"] ]) -> [`item(`id("/dev/hda3"), "/dev/hda3", "/usr")]

    def AddIdExt2(_in)
      _in = deep_copy(_in)
      return [] if _in == nil

      Builtins.maplist(_in) do |i|
        pt = Ops.get_string(i, "partition")
        mp = Ops.get_string(i, "mountpoint")
        Item(Id(pt), pt, mp)
      end
    end

    # Convert media description list to ComboBox items list
    # @param [Array<Hash{String => Object>}] media Medium descriptions - list of maps with keys (and values): "label" (description string), "symbol" (identification symbol), "capacity" (size of free space on empty medium)
    # @return [Array] Items list for UI widgets

    def MediaList2UIList(media)
      media = deep_copy(media)
      result = []

      return [] if media == nil

      Builtins.foreach(media) do |v|
        i = Ops.get_symbol(v, "symbol")
        l = Ops.get_string(v, "label")
        result = Builtins.add(result, Item(Id(i), l)) if i != nil && l != nil
      end 


      deep_copy(result)
    end


    # Set state of depending widgets in Multiple volume options dialog
    # @return [void]

    def SetMultiWidgetsState
      tmp_multi = Convert.to_boolean(UI.QueryWidget(Id(:multi_volume), :Value))
      UI.ChangeWidget(Id(:vol), :Enabled, tmp_multi)

      user = tmp_multi &&
        Convert.to_symbol(UI.QueryWidget(Id(:vol), :Value)) == :user_defined
      UI.ChangeWidget(Id(:user_size), :Enabled, user)
      UI.ChangeWidget(Id(:user_unit), :Enabled, user)

      nil
    end

    # Return mount point for Ext2 partition. This function at first checks if partition is mounted. If yes it returns actual mout point, if no it searches mount point from /etc/fstab file.
    # @param [String] device_name Name of device
    # @return [String] Mount point of device or nil if device does not exist or there is other file system than Ext2
    # @example Ext2MountPoint("/dev/hda1") -> "/boot"

    def Ext2MountPoint(device_name)
      # chack if partition is now mounted
      mp = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      result = nil

      Builtins.foreach(mp) do |p|
        d = Ops.get_string(p, "file")
        dev = Ops.get_string(p, "spec")
        fs = Ops.get_string(p, "vfstype")
        result = d if fs == "ext2" && dev == device_name
      end if mp != nil

      # if partition is not mounted then search mount point from fstab
      if result == nil
        fstab = Convert.convert(
          SCR.Read(path(".etc.fstab")),
          :from => "any",
          :to   => "list <map <string, any>>"
        )

        Builtins.foreach(fstab) do |p|
          d = Ops.get_string(p, "file")
          dev = Ops.get_string(p, "spec")
          fs = Ops.get_string(p, "vfstype")
          result = d if fs == "ext2" && dev == device_name
        end if fstab != nil
      end

      result
    end


    # Add extension to the file name if it is missing.
    # This function skips adding when the file is under the /dev/ path
    # or when it is an existing device file.
    #
    # @param [String] file filname
    # @param [String] extension file extension (with dot)
    # @return [String] filename with extension
    # @example AddMissingExtension("filename", ".ext") -> "filename.ext"
    # @example AddMissingExtension("filename.tar", ".gz") -> "filename.tar.gz"
    # @example AddMissingExtension("filename.tar", ".tar") -> "filename.tar"
    def AddMissingExtension(file, extension)
      # input check
      return "" if file == nil

      return file if extension == nil

      # removing unneded slashes
      if Builtins.regexpmatch(file, "^/")
        file = Builtins.regexpsub(file, "^/+(.*)", "/\\1")
      end

      # skip if the file is a block device
      if FileUtils.Exists(file) && FileUtils.GetFileType(file) == "block"
        Builtins.y2milestone(
          "Leaving destination unchanged, '%1' is a block device",
          file
        )

        return file
      end

      # skipping /dev/ directory
      if Builtins.regexpmatch(file, "^/dev/")
        Builtins.y2milestone(
          "Leaving destination unchanged, '%1' is under the /dev/ directory",
          file
        )

        return file
      end

      dirs = Builtins.splitstring(file, "/")
      filename = Ops.get(dirs, Ops.subtract(Builtins.size(dirs), 1), file)

      result = ""

      # check if file can contain extension
      if Ops.greater_or_equal(Builtins.size(filename), Builtins.size(extension))
        extension_re = Builtins.regexpsub(extension, "\\.(.*)", "\\.\\1")
        extension_re = Ops.add(
          extension_re == nil ? extension : extension_re,
          "$"
        )
        # add extension only if it is missing
        # Using regexpmatch instead of substring+size because
        # of a bytes/characters bug #180631
        if !Builtins.regexpmatch(filename, extension_re)
          filename = Ops.add(filename, extension)
        end
      else
        filename = Ops.add(filename, extension)
      end

      if Ops.greater_than(Builtins.size(dirs), 0)
        dirs = Builtins.remove(dirs, Ops.subtract(Builtins.size(dirs), 1))
      end

      dirs = Builtins.add(dirs, filename)
      result = Builtins.mergestring(dirs, "/")

      result
    end

    # Get base file name without extension
    # @param [String] file file name
    # @return [String] base file name
    # @example GetBaseName("file.ext") -> "file"
    # @example GetBaseName("file") -> "file"
    # @example GetBaseName("dir/file.ext") -> "file"
    def GetBaseName(file)
      result = ""

      return result if file == nil || file == ""

      dirs = Builtins.splitstring(file, "/")
      filename = Ops.get(dirs, Ops.subtract(Builtins.size(dirs), 1), "")

      parts = Builtins.splitstring(filename, ".")

      if Ops.greater_than(Builtins.size(parts), 1)
        # remove last part (extension)
        parts = Builtins.remove(parts, Ops.subtract(Builtins.size(parts), 1))
        filename = Builtins.mergestring(parts, ".")
      end

      result = filename

      result
    end

    # Send mail to specified user
    # @param [String] user Target email address
    # @param [String] subject Subject string
    # @param [String] message Message body
    # @return [Boolean] True on success
    def SendMail(user, subject, message)
      # check user
      return false if user == "" || user == nil

      # get temporary directory
      d = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      if d == "" || d == nil
        Builtins.y2security("Using /tmp directory for temporary files!")
        d = "/tmp"
      end

      mail_file = Ops.add(d, "/mail")

      # write mail body to the temporary file
      if SCR.Write(path(".target.string"), mail_file, message) == false
        return false
      end

      # send mail - set UTF-8 charset for message text
      SCR.Execute(
        path(".target.bash"),
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    "export charset=UTF-8; export ttycharset=UTF-8; /bin/cat ",
                    mail_file
                  ),
                  " | /usr/bin/mail "
                ),
                user
              ),
              " -s '"
            ),
            subject
          ),
          "'"
        )
      ) == 0
    end

    # Create string from character ch with the same lenght as input
    # @param [String] input Input string
    # @param [String] ch String used in output
    # @return [String] String containg size(input) character
    def CreateUnderLine(input, ch)
      len = Builtins.size(input)
      ret = ""

      while Ops.greater_than(len, 0)
        ret = Ops.add(ret, ch)
        len = Ops.subtract(len, 1)
      end

      ret
    end

    # Send summary mail of the backup process to root.
    # @param [Hash] remove_result Result of removing/renaming of the old archives
    # @return [Boolean] True on success
    def SendSummary(remove_result, cron_profile, backup_result, backup_details)
      remove_result = deep_copy(remove_result)
      br = "\n"

      # e-mail subject - %1 is profile name
      subject = Builtins.sformat(_("YaST Automatic Backup (%1)"), cron_profile)

      # get all warnings and errors from Report module
      reported = Report.GetMessages(
        Ops.greater_than(Report.NumWarnings, 0),
        Ops.greater_than(Report.NumErrors, 0),
        false,
        false
      )
      # TODO: remove richtext tags from Report:: result

      if Ops.greater_than(Report.NumErrors, 0)
        # text added to the subject if an error occured
        subject = Ops.add(subject, _(": FAILED"))
      end

      Builtins.y2debug("remove_result: %1", remove_result)

      removed = ""
      if Ops.greater_than(
          Builtins.size(Ops.get_list(remove_result, "removed", [])),
          0
        )
        # header in email body followed by list of files
        removed = Ops.add(_("Removed Old Archives:"), br)

        Builtins.foreach(Ops.get_list(remove_result, "removed", [])) do |f|
          removed = Ops.add(Ops.add(removed, f), br)
        end
      end

      renamed = ""
      if Ops.greater_than(
          Builtins.size(Ops.get_map(remove_result, "renamed", {})),
          0
        )
        # header in email body followed by list of files
        renamed = Ops.add(_("Renamed Old Archives:"), br)

        Builtins.foreach(Ops.get_map(remove_result, "renamed", {})) do |from, to|
          renamed = Ops.add(
            Ops.add(Ops.add(Ops.add(renamed, from), " -> "), to),
            br
          )
        end
      end

      # header in email body
      oldarch = _("Changed Existing Archives:")
      ren_header = Ops.greater_than(Builtins.size(renamed), 0) ||
        Ops.greater_than(Builtins.size(removed), 0) ?
        Ops.add(Ops.add(oldarch, br), CreateUnderLine(oldarch, "=")) :
        ""

      # header in email body
      summary_heading = _("Summary:")
      # header in email body
      detail_heading = _("Details:")

      # header in email body
      body = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            Ops.add(
                              Ops.add(
                                Ops.add(
                                  Ops.add(
                                    Ops.add(
                                      Ops.add(
                                        Ops.add(
                                          Builtins.sformat(
                                            _("BACKUP REPORT for Profile %1"),
                                            cron_profile
                                          ),
                                          br
                                        ),
                                        br
                                      ),
                                      br
                                    ),
                                    # header in email body followed by errors or warnings
                                    Ops.greater_than(Builtins.size(reported), 0) ?
                                      Ops.add(
                                        Ops.add(
                                          Ops.add(
                                            Ops.add(
                                              _(
                                                "Problems During Automatic Backup:"
                                              ),
                                              br
                                            ),
                                            reported
                                          ),
                                          br
                                        ),
                                        br
                                      ) :
                                      ""
                                  ),
                                  summary_heading
                                ),
                                br
                              ),
                              CreateUnderLine(summary_heading, "=")
                            ),
                            br
                          ),
                          br
                        ),
                        backup_result
                      ),
                      br
                    ),
                    Ops.greater_than(Builtins.size(ren_header), 0) ?
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            Ops.add(
                              Ops.add(
                                Ops.add(
                                  Ops.add(Ops.add(ren_header, br), br),
                                  renamed
                                ),
                                br
                              ),
                              br
                            ),
                            removed
                          ),
                          br
                        ),
                        br
                      ) :
                      ""
                  ),
                  detail_heading
                ),
                br
              ),
              CreateUnderLine(detail_heading, "=")
            ),
            br
          ),
          br
        ),
        backup_details
      )

      if SendMail("root", subject, body) == false
        Builtins.y2error("Cannot send report")
        return false
      end

      true
    end

    # Convert number of second since 1.1.1970 to string. Result has format YYYYMMDDHHMMSS
    # @param [Fixnum] sec Number of seconds
    # @return [String] String representation of the time, returns input value (sec) if an error occured
    def SecondsToDateString(sec)
      # convert seconds to time string - use localtime function in perl
      result = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Ops.add(
            Ops.add(
              "/usr/bin/perl -e '($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(",
              Builtins.sformat("%1", sec)
            ),
            ");\n" +
              "$mon++;\n" +
              "$year += 1900;\n" +
              "printf (\"%d%02d%02d%02d%02d%02d\", $year, $mon, $mday, $hour, $min, $sec);'"
          )
        )
      )

      ret = Ops.get_integer(result, "exit", -1) == 0 ?
        Ops.get_string(result, "stdout", Builtins.sformat("%1", sec)) :
        Builtins.sformat("%1", sec)
      Builtins.y2debug("time string: %1", ret)

      ret
    end



    # Read packages available on the installation sources
    # (Requires at least one installation source, otherwise return empty list)
    # @return [Array<String>] available packages
    def GetInstallPackages
      # function returns empty list
      return []

      Builtins.y2milestone("--- backup_get_packages ---")
      # was: return (list <string>) WFM::call("backup_get_packages", []);
      # bugzilla #224899, saves memory occupied by zypp data (packager)

      temporary_file = Builtins.sformat(
        "%1/backup-list-of-packages",
        Directory.tmpdir
      )
      if FileUtils.Exists(temporary_file)
        SCR.Execute(path(".target.remove"), temporary_file)
      end

      yastbin = ""
      if FileUtils.Exists("/sbin/yast")
        yastbin = "/sbin/yast"
      elsif FileUtils.Exists("/sbin/yast2")
        yastbin = "/sbin/yast2"
      else
        Builtins.y2error("Neither /sbin/yast nor /sbin/yast2 exist")
        return []
      end

      # breaks ncurses
      cmd = Builtins.sformat(
        "%1 backup_get_packages %2 1>/dev/null 2>/dev/null",
        yastbin,
        temporary_file
      )
      Builtins.y2milestone("Running command: '%1'", cmd)
      command = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      ret = []

      if Ops.get(command, "exit") != 0
        Builtins.y2error("Unexpected error: %1", command)
        ret = []
      else
        if FileUtils.Exists(temporary_file)
          ret = Convert.convert(
            SCR.Read(path(".target.ycp"), temporary_file),
            :from => "any",
            :to   => "list <string>"
          )
          SCR.Execute(path(".target.remove"), temporary_file)

          if ret == nil
            ret = []
            Builtins.y2error("Error while reading %1", temporary_file)
          else
            Builtins.y2milestone("backup_get_packages found %1 packages", ret)
          end
        end
      end
      Builtins.y2debug("Client returned %1", ret)

      Builtins.y2milestone("--- backup_get_packages ---")

      deep_copy(ret)
    end

    # Store autoyast profile of the system to file
    # @param [String] filename where setting will be saved
    # @param [Array<String>] additional additional part of system to clone
    # @param [String] extra_key name of the extra configuration
    # @param [Hash] extra_options options for extra_key
    # @return [Boolean] true on success
    def CloneSystem(filename, additional, extra_key, extra_options)
      additional = deep_copy(additional)
      extra_options = deep_copy(extra_options)
      Yast.import "AutoinstClone"
      Yast.import "Profile"

      ret = false

      if Ops.greater_than(Builtins.size(filename), 0)
        if Ops.greater_than(Builtins.size(additional), 0)
          # clonne additional system parts
          AutoinstClone.additional = deep_copy(additional)
        end

        # create profile with with currently available resources (partitioning, software etc.)
        Builtins.y2milestone("Clonning system started...")
        if Mode.test
          AutoinstClone.Process
          Builtins.y2milestone("SKIPPING")
        end
        Builtins.y2milestone("System clonned")

        if Ops.greater_than(Builtins.size(extra_options), 0) &&
            Ops.greater_than(Builtins.size(extra_key), 0)
          Ops.set(Profile.current, extra_key, extra_options)
        end

        return Profile.Save(filename)
      end

      false
    end

    # Detect mount points
    # @return [Hash] map of mount points
    def DetectMountpoints
      if Mode.test
        Builtins.y2milestone("SKIPPING")
        return {}
      end

      Yast.import "Storage"

      targetmap = Convert.convert(
        Storage.GetTargetMap,
        :from => "map <string, map>",
        :to   => "map <string, map <string, any>>"
      )
      Builtins.y2debug("targetmap: %1", targetmap)

      devices = {}

      Builtins.foreach(targetmap) do |disk, info|
        partitions = Ops.get_list(info, "partitions", [])
        Builtins.foreach(partitions) do |part_info|
          device = Ops.get_string(part_info, "device")
          mpoint = Ops.get_string(part_info, "mount")
          fs = Ops.get_symbol(part_info, "detected_fs")
          Builtins.y2debug("device: %1, mount: %2, fs: %3", device, mpoint, fs)
          # check for valid device and mount point name, ignore some filesystems
          if device != nil && mpoint != nil && fs != :swap && fs != :lvm &&
              fs != :raid &&
              fs != :xbootpdisk &&
              fs != :xhibernate
            Ops.set(devices, device, { "mpoint" => mpoint, "fs" => fs })
          end
        end
      end 


      Builtins.y2milestone("Detected mountpoints: %1", devices)
      deep_copy(devices)
    end

    # Create table content with detected mount points
    # @param [Array<String>] selected selected mount points to use
    # @param [Array<String>] all all detected mount points + user defined dirs
    # @param [Hash{String => map}] description detected mount points
    # @return [Array] table content
    def MpointTableContents(selected, all, description)
      selected = deep_copy(selected)
      all = deep_copy(all)
      description = deep_copy(description)
      Builtins.y2milestone(
        "selected: %1, description: %2",
        selected,
        description
      )

      Yast.import "FileSystems"

      ret = []
      processed = {}

      if Ops.greater_than(Builtins.size(description), 0)
        Builtins.foreach(description) do |device, info|
          dir = Ops.get_string(info, "mpoint", "")
          fs = FileSystems.GetName(
            Ops.get_symbol(info, "fs", :unknown),
            _("Unknown file system")
          )
          mark = Builtins.contains(selected, dir) ? "X" : " "
          Ops.set(processed, dir, true)
          ret = Builtins.add(
            ret,
            Item(Id(dir), mark, Ops.add(dir, " "), Ops.add(device, " "), fs)
          )
        end
      end

      if Ops.greater_than(Builtins.size(all), 0)
        # check for user defined directories
        Builtins.foreach(all) do |d|
          if Ops.get_boolean(processed, d, false) == false
            ret = Builtins.add(
              ret,
              Item(Id(d), Builtins.contains(selected, d) ? "X" : " ", d, "", "")
            )
          end
        end
      end

      deep_copy(ret)
    end

    # Check whether file on the NFS server exists
    # @param [String] server remote server name
    # @param [String] share exported directory
    # @param [String] filename name of the file
    # @return [Boolean] true - file exists, false - file doesn't exist, nil - error (mount failed)

    def NFSFileExists(server, share, filename)
      if Builtins.size(server) == 0 || Builtins.size(share) == 0 ||
          Builtins.size(filename) == 0
        return nil
      end

      mpoint = Nfs.Mount(server, share, nil, "", "")

      return nil if mpoint == nil

      ret = Ops.greater_or_equal(
        Convert.to_integer(
          SCR.Read(
            path(".target.size"),
            Ops.add(Ops.add(mpoint, "/"), filename)
          )
        ),
        0
      )

      Nfs.Unmount(mpoint)

      ret
    end

    # Create NFS file description string
    # @param [String] server server name
    # @param [String] share exported directory name
    # @param [String] filename remote file name
    # @return [String] result (nil if any of the parameter is nil)
    def NFSfile(server, share, filename)
      if Builtins.size(server) == 0 || Builtins.size(share) == 0 ||
          Builtins.size(filename) == 0
        return nil
      end

      # check if filename begins with '/' character
      slash = Builtins.substring(filename, 0, 1) == "/" ? "" : "/"

      Ops.add(Ops.add(Ops.add(Ops.add(server, ":"), share), slash), filename)
    end

    # Get available space in the directory
    # @param [String] directory selected directory
    # @return [Hash] on success returns parsed df output in a map
    # $["device" : string(device), "total" : integer(total), "used" : integer(used), "free" : integer(free) ]

    def get_free_space(directory)
      if Builtins.size(directory) == 0
        Builtins.y2warning("Wrong parameter directory: %1", directory)
        return {}
      end

      cmd = Builtins.sformat("/bin/df -P '%1'", String.Quote(directory))
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      exit = Ops.get_integer(result, "exit", -1)

      if exit != 0
        Builtins.y2warning("Command %1 failed, exit: %2", cmd, exit)
        return {}
      end

      out = Builtins.splitstring(Ops.get_string(result, "stdout", ""), "\n")

      # ignore header on the first line
      line = Ops.get_string(out, 1, "")

      device = Builtins.regexpsub(
        line,
        "^([^ ]*) +([0-9]+) +([0-9]+) +([0-9]+) +[0-9]+%",
        "\\1"
      )
      total = Builtins.regexpsub(
        line,
        "^([^ ]*) +([0-9]+) +([0-9]+) +([0-9]+) +[0-9]+%",
        "\\2"
      )
      used = Builtins.regexpsub(
        line,
        "^([^ ]*) +([0-9]+) +([0-9]+) +([0-9]+) +[0-9]+%",
        "\\3"
      )
      free = Builtins.regexpsub(
        line,
        "^([^ ]*) +([0-9]+) +([0-9]+) +([0-9]+) +[0-9]+%",
        "\\4"
      )

      {
        "device" => device,
        "total"  => Builtins.tointeger(total),
        "used"   => Builtins.tointeger(used),
        "free"   => Builtins.tointeger(free)
      }
    end

    def IsPossibleToCreateDirectoryOrExists(directory)
      error_message = ""

      directory_path = Builtins.splitstring(directory, "/")
      tested_directory = ""
      Builtins.foreach(directory_path) do |dir|
        tested_directory = Ops.add(
          Ops.add(tested_directory, tested_directory != "/" ? "/" : ""),
          dir
        )
        Builtins.y2debug("TESTING: %1", tested_directory)
        # directory exists
        if FileUtils.Exists(tested_directory)
          # exists, but it isn't a directory, can't create archive 'inside'
          if !FileUtils.IsDirectory(tested_directory)
            Builtins.y2error(
              "Cannot create backup archive in '%1', '%2' is not a directory.",
              directory,
              tested_directory
            )
            error_message = Builtins.sformat(
              # Popup error message, %1 is a directory somewhere under %2, %2 was tested for existency
              _(
                "Cannot create backup archive in %1.\n" +
                  "%2 is not a directory.\n" +
                  "Enter another one or remove %2."
              ),
              directory,
              tested_directory
            )
            raise Break
          end 
          # directory doesn't exist, will be created
        else
          raise Break
        end
      end

      error_message
    end
  end
end
