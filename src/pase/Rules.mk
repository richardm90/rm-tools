# RMFORK is PASE-only native code, not an ILE object - Qp2setenv_ile()/
# f_fork400() cannot be called from RPGLE or ILE C, both of which run in
# the ILE/MI machine environment rather than PASE. This directory is named
# pase/, not native/ (rm-sc's own term for this): rm-tools has no
# rm-sc-style precedent to inherit "native" from, and "native" risks being
# read as "native to IBM i", i.e. ILE - the opposite of what's meant.
#
# TOBi only accepts a target whose NAME carries a recognised object-type
# suffix - a made-up one is rejected ("Warning: Target '...' is not
# supported") - so a custom recipe has to be named after some real object.
#
# The target is a *DTAARA, and the recipe really creates it: after the
# compile it recreates <OBJLIB>/RMFORK, holding the deployed binary's path.
# That object is what make compares RMFORK.c's timestamp against, so the
# binary is rebuilt only when the source changes. A target that names an
# object nothing creates (rm-sc's native/ uses RMSC_FORK_HELPER.SRVPGM) is
# never found, so its recipe runs on every build. Consequence: deleting the
# binary alone does not trigger a rebuild - delete the data area as well
# (DLTDTAARA DTAARA(<OBJLIB>/RMFORK)), or touch RMFORK.c.
#
# Not listed as a prerequisite of anything: makei build's own `all` target
# reaches every target TOBi recorded, across every SUBDIRS directory.
#
# The deploy path (/QOpenSys/opt/rm-tools/bin/rmfork) is written literally:
# a plain Rules.mk variable does not survive into a custom recipe's command
# line (MEASURED in rm-sc - it expands to empty). TOBi's own $(OBJLIB) does.
# The source is named with its src/pase/ prefix because a custom recipe's
# commands run from the project root, not from this directory.
#
# /QOpenSys/opt/rm-tools/bin/ itself is NOT created by this build -
# creating it is a one-time installation step for a privileged profile
# (an ordinary build profile cannot create entries under /QOpenSys); see
# README.md "Installation".
#
# makei build's own "Build Successful!" banner can be wrong when this
# recipe's cc command fails (MEASURED in rm-sc) - check the command output,
# or the deployed binary's mtime, not just the banner. A failed cc stops
# the recipe before the data area is recreated, so the next build retries.
RMFORK.DTAARA: src/pase/RMFORK.c
	/QOpenSys/pkgs/bin/cc -o /QOpenSys/opt/rm-tools/bin/rmfork src/pase/RMFORK.c
	-system "DLTDTAARA DTAARA($(OBJLIB)/RMFORK)"
	system "CRTDTAARA DTAARA($(OBJLIB)/RMFORK) TYPE(*CHAR) LEN(64) VALUE('/QOpenSys/opt/rm-tools/bin/rmfork') TEXT('rm-tools: rmfork native helper build stamp')"
