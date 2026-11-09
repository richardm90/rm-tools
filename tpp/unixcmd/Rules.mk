# Scott Klement's UNIXCMD. Both modules are consumed by copy through the
# RMTOOLS binding directory (src/helpers/) - not built into a service
# program or program here.
UNIXCMDOA.MODULE: UNIXCMDOA.rpgle tpp/unixcmd/QRNOPENACC.rpgleinc tpp/unixcmd/unixpipe_h.rpgle
UNIXCMDOA.MODULE: private TEXT := UNIXCMD: Open, close, read and write access

UNIXPIPER4.MODULE: UNIXPIPER4.rpgle tpp/unixcmd/spawn_h.rpgle tpp/unixcmd/unixpipe_h.rpgle \
    tpp/unixcmd/ifsio_h.rpgle
UNIXPIPER4.MODULE: private TEXT := UNIXCMD: Spawn and pipe helpers
