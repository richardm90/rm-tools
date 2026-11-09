SUBDIRS = rmbase

# Every module is a prerequisite so the binding directory is (re)created only
# after all of them exist. ADDBNDDIRE does not check that an entry exists, but
# a consumer binding against a half-built library would fail confusingly.
RMTOOLS.BNDDIR: RMTOOLS.bnddir RMAPP01.MODULE RMAPP02.MODULE RMAPP03.MODULE \
    RMEMBSQL.MODULE RMENVVAR.MODULE RMFORK.MODULE RMIFS.MODULE RMJOB.MODULE \
    RMLIST.MODULE RMMSG.MODULE RMPASE.MODULE RMPATH.MODULE RMQCMD.MODULE \
    RMSPACE.MODULE RMSTRING01.MODULE RMSTRING02.MODULE UNIXCMDOA.MODULE UNIXPIPER4.MODULE
