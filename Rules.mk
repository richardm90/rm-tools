# TOBi root Rules.mk. SUBDIRS only takes immediate child directories (a
# multi-level relative path makes makei crash with a KeyError), so each of
# these has its own Rules.mk that in turn sets its own SUBDIRS.
#
# tpp/ first: its unixcmd modules are listed in RMTOOLS.BNDDIR, which
# src/helpers/ creates.
SUBDIRS = tpp src
