# rm-tools

General-purpose RPGLE helper modules for IBM i: strings, IFS, paths, lists and user spaces,
environment variables, jobs, messages, `QCMDEXC`, PASE commands, and **RMFORK** (running a PASE
command in its own, named job).

| | |
|---|---|
| **Build** | [TOBi](https://ibm.github.io/ibmi-bob/) - `makei build` |
| **Tests** | IBM i Testing extension + [iRPGUnit](https://github.com/tools-400/irpgunit) |
| **Licence** | [MIT](LICENSE); bundled third party code keeps its own licence - see [`tpp/`](tpp/README.md) |

rm-tools builds **modules, not a service program**. A consumer binds them **by copy** through the
`RMTOOLS` binding directory, so the consumer needs neither the rm-tools library nor anything
else from it at runtime. The one exception is RMFORK's native helper binary (see
[Installation](#installation)).

## Modules

| Module | Copybook | Does |
|---|---|---|
| `RMSTRING01`, `RMSTRING02` | `RMSTRING_D` | String helpers and a string builder |
| `RMIFS` | `RMIFS_D` | IFS files and directories |
| `RMPATH` | `RMPATH_D` | Path name parsing |
| `RMLIST` | `RMLIST_D` | Lists held in a user space |
| `RMSPACE` | `RMSPACE_D` | User spaces |
| `RMENVVAR` | `RMENVVAR_D` | Environment variables |
| `RMJOB` | `RMJOB_D` | Job information, including another job's environment variables |
| `RMMSG` | `RMMSG_D` | Program messages |
| `RMQCMD` | `RMQCMD_D` | Running CL commands via `QCMDEXC` |
| `RMPASE` | `RMPASE_D` | Running PASE commands - see [docs/RMPASE.md](docs/RMPASE.md) |
| `RMFORK` | `RMFORK_D` | Running a PASE command in a separately named job |
| `RMAPP01`-`RMAPP03` | `RMAPP_D` | Application logging and escape messages, SQL `WHERE` clause building, current user/date/time |
| `RMEMBSQL` | `RMEMBSQL_D` | Embedded SQL state checking |
| `UNIXCMDOA`, `UNIXPIPER4` | - | Scott Klement's UNIXCMD, used by `RMPASE` |

`include/RMTOOLS_H.rpgleinc` holds standard control options and `include/RMTOOLS_D.rpgleinc` the
shared data types; `include/RMCOMP_H.rpgleinc` the compiler options (see
[docs/RMCOMP_H.md](docs/RMCOMP_H.md)).

## Installation

Tested on V7R4 TR11 and V7R5 TR5.

### Prerequisites

Once per system, as a user with `*ALLOBJ` authority:

```shell
# The default *PUBLIC authority is *EXCLUDE
system "GRTOBJAUT OBJ(QSYS/QCLSTMF) OBJTYPE(*PGM) USER(*PUBLIC) AUT(*USE)"

# TOBi, and a C compiler for RMFORK's native helper
yum install tobi gcc-6

# /QOpenSys/opt does not exist on a new system, and only a privileged
# profile can create it. If it is missing, create it and leave it readable
# by everyone (it may hold other products' directories too).
[ -d /QOpenSys/opt ] || { mkdir /QOpenSys/opt && chmod 755 /QOpenSys/opt; }

# The directory RMFORK's native helper is deployed under. Each build creates
# its release's own <release>/bin directory here (for example
# /QOpenSys/opt/rm-tools/1.0.0/bin/rmfork), so the group of the profile
# that runs the build must be able to add entries.
mkdir -p /QOpenSys/opt/rm-tools
chgrp qpgmr /QOpenSys/opt/rm-tools
chmod 2775 /QOpenSys/opt/rm-tools
```

Use the group of whichever profile will run `makei build` in place of `qpgmr`.

Every release deploys its native helper to a directory of its own, so releases can be installed
side by side and each program calls the helper from the release it was built with. A release's
directory is not needed once nothing built from that release is in use; remove it by hand with
`rm -r /QOpenSys/opt/rm-tools/<release>`.

### Build

All paths in `iproj.json` are relative to the project root, so the repository can be cloned to any
IFS directory. As a standard user:

```shell
git clone https://github.com/richardm90/rm-tools.git
cd rm-tools

# Create the target library, then build into it
system "CRTLIB LIB(RMTOOLS) TEXT('rm-tools')"
makei build -e OBJLIB=RMTOOLS
```

## Using rm-tools from another project

1. Put the rm-tools project root on your compile include path, so that
   `/include 'include/RMIFS_D.rpgleinc'` resolves - for TOBi, add it to `includePath` in your
   `iproj.json`.
2. Bind through the `RMTOOLS` binding directory - `ctl-opt bnddir('RMTOOLS')` in a `*PGM`
   (or `/define APP_BNDDIR_RMTOOLS` before including `RMTOOLS_H`, which emits it), or
   `BNDDIR = RMTOOLS` on the `*SRVPGM` target in your `Rules.mk` - with the rm-tools library on
   the build job's library list, or qualify the entry. An unqualified `RMTOOLS` resolves to the
   first one on the library list, so keep any other library holding an `RMTOOLS` binding
   directory (such as the private rmtools build, which binds `RMBASE` by reference) off it.
3. If you call `FORK_run_cmd`, the target system needs the native helper for the rm-tools
   release you built with, `/QOpenSys/opt/rm-tools/<release>/bin/rmfork`, deployed by an
   rm-tools build of that release.

[rm-sc](https://github.com/richardm90/rm-sc) is a working example.

## Development

Developed with the [Code for IBM i](https://codefori.github.io/docs/) VS Code extension: the code is
maintained locally and deployed to the IBM i for the build. `iproj.json`'s
`buildCommand`/`compileCommand` drive the Project Explorer's **Build** and **Compile** actions, and
`.vscode/actions.json` has equivalent Code for IBM i actions.

### Releasing

The release number appears in the code in one place only: `FORK_NATIVE_PATH` in
`include/RMFORK_D.rpgleinc` (`/QOpenSys/opt/rm-tools/<release>/bin/rmfork`). The build reads it
from there to decide where to deploy RMFORK's native helper. Update it, and `CHANGES.md`, for
every release.

### Tests

The RPGUnit suites in `tests/` are compiled by the IBM i Testing extension into the
`RMTOOLS` library (see `.vscode/testing.json`); they bind the modules under test through
`RMTOOLS`. `RMFORKIT.TEST` is an integration suite that really forks PASE jobs and needs the
native helper deployed.

[iRPGUnit](https://github.com/tools-400/irpgunit) is needed only for developing rm-tools or
running these suites - not for building the library, so `iproj.json` deliberately leaves it off
the build's library list. To work on rm-tools, install it (Code for IBM i - *Components* - *Add
Component* - RPGUnit) and add its library to `postUsrlibl` in your local `iproj.json`:

```json
"postUsrlibl": ["QGPL", "QTEMP", "RPGUNIT"],
```

## Troubleshooting

### Attempt to use permanent system object QCLSTMF without authority

Building CL pseudo-source (binding directories, the message file) or creating objects from stream
files fails with this message, or with "File QCDTEMPSRC in library QTEMP ... not found", until
`*PUBLIC` is given `*USE` to `QSYS/QCLSTMF` - see [Prerequisites](#prerequisites).
