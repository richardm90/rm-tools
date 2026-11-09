# rm-tools: Third Party Projects

The `tpp` directory holds the source of third party projects that rm-tools
builds and binds in.

* [UNIXCMD](https://www.scottklement.com/unixcmd/) from Scott Klement, v1.3.
  The `UNIXCMDOA` and `UNIXPIPER4` modules are built into the rm-tools library
  and bound by copy alongside `RMPASE` (through the `RMTOOLS` binding
  directory). No `UNIXCMD` service program or program is created.

  Copyright (c) 2009-2016 Scott C. Klement. Redistributed under its original
  BSD-2-Clause licence, which is retained in full at the top of each source
  file in `tpp/unixcmd`.
