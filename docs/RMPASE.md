# RMTOOLS: PASE Helper



## Building

`RMPASE` is one of the helper modules in `src/helpers/rmbase` and is built by
the normal project build (see the [README](../README.md)). Scott Klement's
`UNIXCMD` modules (`UNIXCMDOA`, `UNIXPIPER4`) are built alongside it from
`tpp/unixcmd`, and a consumer binds all three by copy through the `RMTOOLS`
binding directory - there is no external `UNIXCMD` dependency at runtime.


## UnixCmd

The source for the `UNIXCMD` utility lives in `tpp/unixcmd`, based on v1.3 of
`UNIXCMD`.



## Running a Command

Use the `PASE_run_cmd` to a run a PASE command.

The returned parameter is the [exit status](#exit-status).


### Exit Status

Each command has an exit status that can influence the behavior of other shell commands. By convention, a command exits with zero for normal or success, and non-zero for failure, error, or a false indication. The documentation for each command describes the exit codes it returns and what they mean.

When you enter the `cat myfile.text` command on a QShell interactive prompt you'll see the following.

```shell
$ cat myfile.text
cat: 001-0023 Error found opening file myfile.text. No such path or directory.
```

When you run the command `cat myfile.text` via `PASE_run_cmd`, as in this example program `PASE02`, you will see very similar output in the job log.

```shell
CALL PGM(PASE02)
RMPASE cmd: >cat myfile.text<
RMPASE return code: 1
cat: 001-0023 Error found opening file myfile.text. No such path or directory.
RMPASE stdout row count: 1
```

This shows the following.

* `RMPASE cmd: >cat myfile.text<` is the command that was run.
* `RMPASE return code: 1` the return code value from `PASE_run_cmd`, this is output to the job log via the `PASE_log_stdout` procedure.
* `cat: 001-0023 ...` the standard output from `PASE_run_cmd`, this is output to the job log via the `PASE_log_stdout` procedure.
* The `PASE_log_stdout` also outputs the standard output row count to the job log.

The return code (variable `rc` in `PASE02`) from `PASE_run_cmd` will be 1 in this example.

The `PASE_run_cmd` procedure monitors for any failure when processing the command via `UNIXCMDOA` and if the following messages are found these are removed from the job log.

* A `RNX1217` escape message e.g. `Error message  appeared during CLOSE.`
* A `CPF9897` diagnostic message e.g. `Child process ended with status 127`

The return code from `PASE_run_cmd` is determined from the `CPF9897` diagnostic message.

### Example: PASE03

```shell
CALL PGM(PASE03)
RMPASE cmd: >/QOpenSys/pkgs/bin/file -b /home/user/export.csv<
RMPASE return code: 0
UTF-8 Unicode text, with very long lines
RMPASE stdout row count: 1
```
