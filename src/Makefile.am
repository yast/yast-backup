#
# Makefile.am for y2m_backup/src
#
# $Id$
#

SUBDIRS = scripts

clientsdir = $(YAST2DIR)/clients
yncludedir = $(YAST2DIR)/include/backup
menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/modules

clients_DATA =		\
	backup.ycp	
#	backup_write.ycp

ynclude_DATA =		\
	functions.ycp	\
	ui.ycp		\
	help_texts.ycp

menu_DATA = menuentry_backup.y2cc

modules_DATA = Backup.ycp

EXTRA_DIST = $(clients_DATA) $(ynclude_DATA) $(menu_DATA) $(modules_DATA)
