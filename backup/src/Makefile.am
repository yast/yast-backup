#
# Makefile.am for backup/src
#
# $Id$
#

SUBDIRS = scripts

yncludedir = @yncludedir@/backup

client_DATA =		\
	backup_save_profile.ycp		\
	backup_available_packages.ycp	\
	backup.ycp	

ynclude_DATA =		\
	functions.ycp	\
	ui.ycp		\
	help_texts.ycp

desktop_DATA = backup.desktop

module_DATA = Backup.ycp

include $(top_srcdir)/Makefile.am.common

backup:
	ln -sf . backup

ycpchook = backup

YCPCFLAGS=-I.


EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)
