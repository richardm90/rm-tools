# rmbase - the rm-tools helper modules. No service program is built from them:
# consumers bind them BY COPY through RMTOOLS.BNDDIR (src/helpers/).
# Copybook lists include indirect /includes (e.g. RMJOB_D via RMIFS).
RMAPP01.MODULE: RMAPP01.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMAPP_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMAPP01.MODULE: private TEXT := rm-tools: Application helper 01

RMAPP02.MODULE: RMAPP02.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMAPP_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMAPP02.MODULE: private TEXT := rm-tools: Application helper 02

RMAPP03.MODULE: RMAPP03.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/PSDS_D.rpgleinc include/RMAPP_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMAPP03.MODULE: private TEXT := rm-tools: Application helper 03

RMEMBSQL.MODULE: RMEMBSQL.sqlrpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMAPP_D.rpgleinc include/RMTOOLS_D.rpgleinc include/RMEMBSQL_D.rpgleinc
RMEMBSQL.MODULE: private TEXT := rm-tools: Embedded SQL helper

RMENVVAR.MODULE: RMENVVAR.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMENVVAR_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMENVVAR.MODULE: private TEXT := rm-tools: Environment variable helper

RMFORK.MODULE: RMFORK.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMFORK_D.rpgleinc include/RMPASE_D.rpgleinc include/RMSTRING_D.rpgleinc \
    include/RMTOOLS_D.rpgleinc
RMFORK.MODULE: private TEXT := rm-tools: Fork helper

RMIFS.MODULE: RMIFS.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMIFS_D.rpgleinc include/RMTOOLS_D.rpgleinc include/RMJOB_D.rpgleinc
RMIFS.MODULE: private TEXT := rm-tools: IFS helper

RMJOB.MODULE: RMJOB.sqlrpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/PSDS_D.rpgleinc include/RMJOB_D.rpgleinc include/RMTOOLS_D.rpgleinc \
    include/RMQCMD_D.rpgleinc include/RMMSG_D.rpgleinc include/RMIFS_D.rpgleinc \
    include/RMPASE_D.rpgleinc include/RMSTRING_D.rpgleinc
RMJOB.MODULE: private TEXT := rm-tools: Job helper

RMLIST.MODULE: RMLIST.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMLIST_D.rpgleinc include/RMTOOLS_D.rpgleinc include/RMMSG_D.rpgleinc
RMLIST.MODULE: private TEXT := rm-tools: List (user space) helper

RMMSG.MODULE: RMMSG.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMMSG_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMMSG.MODULE: private TEXT := rm-tools: Message helper

RMPASE.MODULE: RMPASE.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMENVVAR_D.rpgleinc include/RMPASE_D.rpgleinc include/RMSTRING_D.rpgleinc \
    include/RMTOOLS_D.rpgleinc include/RMMSG_D.rpgleinc tpp/unixcmd/QRNOPENACC.rpgleinc
RMPASE.MODULE: private TEXT := rm-tools: PASE helper

RMPATH.MODULE: RMPATH.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMPATH_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMPATH.MODULE: private TEXT := rm-tools: Path helper

RMQCMD.MODULE: RMQCMD.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMQCMD_D.rpgleinc include/RMMSG_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMQCMD.MODULE: private TEXT := rm-tools: QCMDEXC helper

RMSPACE.MODULE: RMSPACE.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMSPACE_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMSPACE.MODULE: private TEXT := rm-tools: User space helper

RMSTRING01.MODULE: RMSTRING01.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMSTRING_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMSTRING01.MODULE: private TEXT := rm-tools: String helper 01

RMSTRING02.MODULE: RMSTRING02.rpgle include/RMCOMP_H.rpgleinc include/RMTOOLS_H.rpgleinc \
    include/RMSTRING_D.rpgleinc include/RMTOOLS_D.rpgleinc
RMSTRING02.MODULE: private TEXT := rm-tools: String helper 02

# Pseudo-source (literal CL) - see RMMSGF.msgf. The original build has no
# source file for this either, just a raw CRTMSGF/ADDMSGD pair.
RMMSGF.MSGF: RMMSGF.msgf
