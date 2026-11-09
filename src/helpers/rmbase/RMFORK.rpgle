**free

//==============================================================================
// RMFORK     - Fork Helper Module
//
// 06/10/2026 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

ctl-opt text('RMTOOLS: Fork Helper Module');

///
// Copybook definitions
///

/include 'include/RMFORK_D.rpgleinc'
/include 'include/RMPASE_D.rpgleinc'
/include 'include/RMSTRING_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==================================================================================================
// FORK_run_cmd
//   Thin wrapper: FORK_build_cmdline, then either reject (cmdline would overflow
//   PASE_CMD_SIZE) or delegate to PASE_run_cmd and return its rc unchanged. Never
//   duplicates FORK_build_cmdline's assembly logic.
//==================================================================================================

dcl-proc FORK_run_cmd export;
  dcl-pi *n like(INTEGER_t);
    jobname    like(FORK_JOBNAME_t)     const;
    envvars    like(FORK_ENVVAR_t)      const dim(FORK_MAX_ENVVARS) options(*omit);
    envvars_n  like(UNSIGNED_INTEGER_t) const options(*omit);
    cmd        like(PASE_CMD_t)         const;
    resourceid like(UNSIGNED_INTEGER_t) const options(*nopass);
    keep_stdio like(BOOLEAN_t)          const options(*nopass);
    stdout     like(PASE_IO_t)                options(*omit:*nopass);
  end-pi;

  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);
  dcl-s rc      like(INTEGER_t);
  dcl-s keep    like(BOOLEAN_t) inz(false);
  dcl-s rid     like(UNSIGNED_INTEGER_t) inz(0);

  if %passed(keep_stdio);
    keep = keep_stdio;
  endif;

  // *omit-ness cannot be forwarded by just passing the formal parameter - the
  // literal *omit has to appear at the call site, so this is branched on
  // %passed() rather than written once. keep_stdio=true forces resourceid to
  // be emitted too (the native argv is positional: keep_stdio only follows
  // resourceid); keep_stdio false/omitted takes the v2.2.0 branches
  // unchanged, so the command line is byte-identical to v2.2.0's.
  if keep;
    if %passed(resourceid);
      rid = resourceid;
    endif;
    if %passed(envvars);
      fits = FORK_build_cmdline(jobname: envvars: envvars_n: cmd: cmdline: rid: true);
    else;
      fits = FORK_build_cmdline(jobname: *omit: *omit: cmd: cmdline: rid: true);
    endif;
  elseif %passed(envvars) and %passed(resourceid);
    fits = FORK_build_cmdline(jobname: envvars: envvars_n: cmd: cmdline: resourceid);
  elseif %passed(envvars) and not %passed(resourceid);
    fits = FORK_build_cmdline(jobname: envvars: envvars_n: cmd: cmdline);
  elseif not %passed(envvars) and %passed(resourceid);
    fits = FORK_build_cmdline(jobname: *omit: *omit: cmd: cmdline: resourceid);
  else;
    fits = FORK_build_cmdline(jobname: *omit: *omit: cmd: cmdline);
  endif;

  if not fits;
    if %passed(stdout);
      stdout = '';
    endif;
    return FORK_RC_CMDLINE_TOO_LONG;
  endif;

  if %passed(stdout);
    rc = PASE_run_cmd(*omit: cmdline: stdout);
  else;
    rc = PASE_run_cmd(*omit: cmdline);
  endif;

  return rc;
end-proc;

//==================================================================================================
// FORK_build_cmdline
//   Pure, side-effect-free - never calls PASE_run_cmd. Assembles the shell-quoted
//   command line that invokes the deployed native binary (FORK_NATIVE_PATH):
//     <path> <jobname> <nvars> [<envvar> ...] <cmd> [<resourceid> [1]]
//   nvars is passed explicitly (rather than leaving the native binary to infer it
//   from argc) so a variable-length envvars list and an optional trailing
//   resourceid can both exist on the same command line with no ambiguity about
//   which argument is which - this is also the contract the native binary
//   (src/pase/RMFORK.c) parses against.
//
//   Assembled in a STRING_t-sized (65535) working buffer, not directly in a
//   PASE_CMD_t one, specifically so an over-length result can be measured and
//   rejected rather than raising a runtime size error on assignment.
//==================================================================================================

dcl-proc FORK_build_cmdline export;
  dcl-pi *n like(BOOLEAN_t);
    jobname    like(FORK_JOBNAME_t)     const;
    envvars    like(FORK_ENVVAR_t)      const dim(FORK_MAX_ENVVARS) options(*omit);
    envvars_n  like(UNSIGNED_INTEGER_t) const options(*omit);
    cmd        like(PASE_CMD_t)         const;
    cmdline    like(PASE_CMD_t);
    resourceid like(UNSIGNED_INTEGER_t) const options(*nopass);
    keep_stdio like(BOOLEAN_t)          const options(*nopass);
  end-pi;

  dcl-s assembled like(STRING_t);
  dcl-s n         like(UNSIGNED_INTEGER_t);
  dcl-s i         like(UNSIGNED_INTEGER_t);

  if %passed(envvars) and %passed(envvars_n);
    n = envvars_n;
  else;
    n = 0;
  endif;

  // envvars_n is an independent scalar, not derived from the array's own
  // compile-time-fixed dim(FORK_MAX_ENVVARS) - a caller passing a value
  // too high must be rejected outright (same "doesn't fit" path the
  // PASE_CMD_SIZE guard below already uses), not clamped or allowed to
  // index past the array. MEASURED: before this guard existed,
  // envvars_n = FORK_MAX_ENVVARS + 1 crashed with MCH0603 ("Range of
  // subscript value or character string error") at the `envvars(i)`
  // reference below - not silent corruption, a hard runtime abend.
  if n > FORK_MAX_ENVVARS;
    return false;
  endif;

  assembled = shell_quote(FORK_NATIVE_PATH) + ' ' +
              shell_quote(%trimr(jobname)) + ' ' +
              %char(n);

  if n > 0;
    for i = 1 to n;
      assembled += ' ' + shell_quote(envvars(i));
    endfor;
  endif;

  assembled += ' ' + shell_quote(cmd);

  // keep_stdio is positional after resourceid in the native argv, so a true
  // keep_stdio is always accompanied by a resourceid token. When
  // false/omitted nothing extra is emitted - identical to v2.2.0.
  if %passed(resourceid);
    assembled += ' ' + %char(resourceid);
  endif;
  if %passed(keep_stdio);
    if keep_stdio;
      // No "resourceid not passed" case here: keep_stdio is positional after
      // resourceid (a *nopass parameter, not *omit-able), so keep_stdio can
      // only be passed together with resourceid - that branch was unreachable
      // and has been removed.
      assembled += ' 1';
    endif;
  endif;

  if %len(assembled) > PASE_CMD_SIZE;
    return false;
  endif;

  cmdline = assembled;
  return true;
end-proc;

//==================================================================================================
// shell_quote
//   Wraps str in single quotes, escaping any embedded single quote via the
//   standard '\'' technique (close the quote, an escaped literal quote, reopen).
//   Built on STRING_replace rather than new character-scanning code.
//==================================================================================================

dcl-proc shell_quote export;
  dcl-pi *n like(STRING_t);
    str like(STRING_t) const;
  end-pi;

  dcl-s q             like(STRING_t);
  dcl-s escaped_quote like(STRING_t);

  q = '''';                    // one single-quote character
  escaped_quote = q + '\' + q + q;   // '\''

  return q + STRING_replace(str: q: escaped_quote) + q;
end-proc;
