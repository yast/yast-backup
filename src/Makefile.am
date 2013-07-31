# Sources for backup

module_DATA = \
  modules/Backup.rb

client_DATA = \
  clients/backup.rb \
  clients/backup_available_packages.rb \
  clients/backup_save_profile.rb \
  clients/backup_get_packages.rb

yncludedir = @yncludedir@/backup
ynclude_DATA = \
  include/backup/ui.rb \
  include/backup/help_texts.rb \
  include/backup/functions.rb

scrconf_DATA = \
  scrconf/cfg_backup.scr \
  scrconf/proc_filesystems.scr

agent_SCRIPTS = \
  servers_non_y2/ag_file_append

ybin_SCRIPTS = \
  bin/backup_archive.pl \
  bin/backup_cron \
  bin/backup_search.pl

desktop_DATA = \
  desktop/backup.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(ybin_SCRIPTS) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common