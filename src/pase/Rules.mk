# RMFORK is PASE-only native code, not an ILE object - Qp2setenv_ile()/
# f_fork400() cannot be called from RPGLE or ILE C, both of which run in
# the ILE/MI machine environment rather than PASE. This directory is named
# pase/, not native/, because "native" risks being read as "native to
# IBM i", i.e. ILE - the opposite of what's meant.
#
# TOBi only accepts a target whose NAME carries a recognised object-type
# suffix - a made-up one is rejected ("Warning: Target '...' is not
# supported") - so a custom recipe has to be named after some real object.
#
# The target is a *DTAARA, and the recipe really creates it: after the
# compile it recreates <OBJLIB>/RMFORK, holding the deployed binary's path.
# That object is what make compares the prerequisites' timestamps against,
# so the binary is rebuilt only when RMFORK.c or RMFORK_D changes. A target
# that names an object nothing creates (e.g. RMFORK.SRVPGM) is never found,
# so its recipe would run on every build. Consequence: deleting the
# binary alone does not trigger a rebuild - delete the data area as well
# (DLTDTAARA DTAARA(<OBJLIB>/RMFORK)), or touch RMFORK.c.
#
# Not listed as a prerequisite of anything: makei build's own `all` target
# reaches every target TOBi recorded, across every SUBDIRS directory.
#
# The deploy path - /QOpenSys/opt/rm-tools/<release>/bin/rmfork - is read
# from FORK_NATIVE_PATH in include/RMFORK_D.rpgleinc, the one place the
# release number is written, and compiled into the binary with
# -DRMFORK_DEPLOYED_PATH, so the RPG side, the binary and the deploy
# location can never disagree. It is read in the recipe itself because a
# plain Rules.mk variable does not survive into a custom recipe's command
# line (MEASURED - it expands to empty); TOBi's own $(OBJLIB) does. The
# recipe is one shell command (joined with \) so the path, held in a shell
# variable, is still set on every step.
# Paths are named with their prefix from the project root (src/pase/...,
# include/...) because a custom recipe's commands run from the project
# root, not from this directory.
#
# The recipe creates the <release>/bin directories, but NOT
# /QOpenSys/opt/rm-tools itself - creating that is a one-time installation
# step for a privileged profile (an ordinary build profile cannot create
# entries under /QOpenSys), which also makes it writable by the build
# profile's group; see README.md "Installation".
#
# makei build's own "Build Successful!" banner can be wrong when this
# recipe's cc command fails (MEASURED) - check the command output,
# or the deployed binary's mtime, not just the banner. A failed step stops
# the recipe before the data area is recreated, so the next build retries.
RMFORK.DTAARA: src/pase/RMFORK.c include/RMFORK_D.rpgleinc
	P=$$(sed -n "s/^dcl-c FORK_NATIVE_PATH const('\(.*\)');.*$$/\1/p" include/RMFORK_D.rpgleinc) && \
	test -n "$$P" && \
	mkdir -p "$${P%/rmfork}" && \
	/QOpenSys/pkgs/bin/cc -DRMFORK_DEPLOYED_PATH="\"$$P\"" -o "$$P" src/pase/RMFORK.c && \
	{ system "DLTDTAARA DTAARA($(OBJLIB)/RMFORK)" >/dev/null 2>&1 ; true ; } && \
	system "CRTDTAARA DTAARA($(OBJLIB)/RMFORK) TYPE(*CHAR) LEN(64) VALUE('$$P') TEXT('rm-tools: rmfork native helper build stamp')"
