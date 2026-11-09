# rm-tools Change Log


## v1.0.0

First public release, extracted from the private `rmtools` project at its v2.3.0.

- **Modules:** `RMSTRING01`, `RMSTRING02`, `RMIFS`, `RMPATH`, `RMLIST`, `RMSPACE`, `RMENVVAR`,
  `RMJOB`, `RMMSG`, `RMQCMD`, `RMPASE`, `RMFORK`, `RMAPP01`-`RMAPP03`, `RMEMBSQL`, plus Scott
  Klement's `UNIXCMDOA` and `UNIXPIPER4`.
- **Binding:** no service program. Consumers bind the modules by copy through the
  `RMTOOLS` binding directory, whose entries are now all `*MODULE` (in rmtools it held the
  `RMBASE` service program, bound by reference).
- **RMFORK:** the native helper is now deployed to `/QOpenSys/opt/rm-tools/bin/rmfork`
  (was `/QOpenSys/opt/rmtools/bin/rmfork`).
- **Tests:** `RMJOB.TEST`, `RMFORK.TEST` and `RMFORKIT.TEST` bind through `RMTOOLS`.
