#
# Makefile.am for backup/src
#
# $Id$
#

SUBDIRS = scripts

yncludedir = @yncludedir@/backup

client_DATA =		\
	backup.ycp	

ynclude_DATA =		\
	functions.ycp	\
	ui.ycp		\
	help_texts.ycp

config_DATA = backup.y2cc

module_DATA = Backup.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(config_DATA) $(module_DATA)
