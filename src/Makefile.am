#
# Makefile.am for y2m_backup/src
#
# $Id$
#

SUBDIRS = scripts

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/backup
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	backup.ycp	
#	backup_write.ycp

include_DATA =		\
	functions.ycp	\
	ui.ycp

menu_DATA = menuentry_backup.ycp

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA)
