# RMCOMP_H

The `include/RMCOMP_H.rpgleinc` file defines the default control options used by the compiler.

ctl-opt option(*nodebugio:*noexpdds:*noext:*nounref:*noshowcpy:*noshowskp:*srcstmt);

## `*NODEBUGIO`

Indicates that no breakpoints are generated for IO specifications.


## `*NOEXPDDS`

Do not show the expansion of externally described files and key field information.


## `*NOEXT`

Do not show the list of external procedures and fields.


## `*NOUNREF`
Unreferenced variables are not generated.


## `*NOSHOWCPY`

Do not show source records of members included by `/COPY`.

## `*NOSHOWSKP`

Do not show skipped statements in the source part of the listing.

## `*SRCSTMT`

Statement numbers for the listing are generated from the source ID and SEU sequence numbers.

With `*SRCSTMT`:

```shell
CALL PGM(MYLIB/MYPGM)
Length of varying length variable is out of range.
Application error. RNX0115 unmonitored by MYPGM at statement 0000000051, instruction X'0000'.
```

With `*NOSRCSTMT`:

`*NOSRCSTMT` indicates that line numbers are assigned sequentially.

```shell
CALL PGM(MYLIB/MYPGM)
Length of varying length variable is out of range.
Application error. RNX0115 unmonitored by MYPGM at statement 0000000686, instruction X'0000'.
```
