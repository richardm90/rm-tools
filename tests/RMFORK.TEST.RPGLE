**free

//==============================================================================
// RMFORK.TEST - RPGUnit suite for FORK_build_cmdline/shell_quote/FORK_run_cmd.
//
// Scope, and why: this suite never calls PASE_run_cmd for real, and
// therefore never forks a real PASE process - a FORK_run_cmd call that fits
// would really fork/exec, which is not a safe unit-test boundary.
// FORK_build_cmdline is pure (no side effects), so every assembly/overflow
// case is tested through it directly. FORK_run_cmd itself is only
// exercised on the one path that's genuinely safe to unit-test - the
// early-rejection (overflow) path, where PASE_run_cmd is never reached.
// Everything past that hand-off (the real fork/exec, DSPJOB OPTION(*ENVVAR)
// checks) has no RPGUnit seam here and is covered instead by the RMFORKIT
// integration suite (tests/RMFORKIT.TEST.RPGLE).
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMTOOLS');

/include 'include/RMFORK_D.rpgleinc'
/include 'include/RMPASE_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

///
// shell_quote - plain string, no embedded quote/space, round-trips as-is
// except for the wrapping quotes.
///

dcl-proc test_shell_quote_plain export;
  aEqual('''hello''': shell_quote('hello'));
end-proc;

///
// shell_quote - a value containing an embedded space must come back as ONE
// shell word, not split - this is the specific case FORK_run_cmd exists
// to handle with no special escaping from the caller's side (a hand-built
// shell prefix needs careful quoting here; this is the point of building
// FORK_run_cmd at all).
///

dcl-proc test_shell_quote_embedded_space export;
  aEqual('''hello world''': shell_quote('hello world'));
end-proc;

///
// shell_quote - a value containing an embedded single quote must be
// escaped with the standard '\'' technique, not left to break out of the
// surrounding quotes. This is the case that actually matters most: an
// unescaped embedded quote here corrupts every argument after it on the
// assembled command line.
//
// Built from pieces rather than one hand-escaped literal - 'q' holds a
// single quote character, which is otherwise near-unreadable (and easy to
// get subtly wrong) doubled-and-nested inside an RPG string literal.
///

dcl-proc test_shell_quote_embedded_single_quote export;
  dcl-s q char(1) inz('''');
  dcl-s expected like(STRING_t);

  // Expected: 'can'\''t'  (can't, single-quoted, with the embedded quote
  // escaped as '\'')
  expected = q + 'can' + q + '\' + q + q + 't' + q;

  aEqual(expected: shell_quote('can''t'));
end-proc;

///
// shell_quote - empty string still comes back as a valid, empty shell word
// (two quotes, nothing between), not an empty RPG string that would vanish
// entirely when concatenated into the command line.
///

dcl-proc test_shell_quote_empty export;
  aEqual('''''': shell_quote(''));
end-proc;

///
// FORK_build_cmdline - a small, well-within-budget input must fit, and the
// assembled line must actually contain the deployed native binary path and
// the quoted job name - asserting the VALUE, not just that something came
// back, per references/writing-tests.md ("an assertion that cannot fail is
// not a test").
///

dcl-proc test_build_cmdline_small_input_fits export;
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits like(BOOLEAN_t);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline);

  if not fits;
    fail('small, well-within-budget input did not fit');
    return;
  endif;

  if %scan(FORK_NATIVE_PATH: cmdline) = 0;
    fail('assembled command line does not invoke the deployed native binary: [' +
      %trim(cmdline) + ']');
  endif;

  if %scan(shell_quote('TESTJOB01'): cmdline) = 0;
    fail('assembled command line does not contain the quoted job name: [' +
      %trim(cmdline) + ']');
  endif;
end-proc;

///
// FORK_build_cmdline - every envvars entry actually ends up in the
// assembled line, quoted, in order - the actual contract callers depend on.
///

dcl-proc test_build_cmdline_multiple_envvars_included export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits like(BOOLEAN_t);

  envvars(1) = 'LOGFILE=/tmp/svc.log';
  envvars(2) = 'STARTED=20261006120000';
  envvars(3) = 'SVCNAME=has a space';

  fits = FORK_build_cmdline('TESTJOB01': envvars: 3: 'sleep 1': cmdline);

  if not fits;
    fail('3 ordinary envvars entries did not fit');
    return;
  endif;

  if %scan(shell_quote(envvars(1)): cmdline) = 0;
    fail('envvars(1) missing from assembled command line: [' + %trim(cmdline) + ']');
  endif;
  if %scan(shell_quote(envvars(2)): cmdline) = 0;
    fail('envvars(2) missing from assembled command line: [' + %trim(cmdline) + ']');
  endif;
  if %scan(shell_quote(envvars(3)): cmdline) = 0;
    fail('envvars(3) (embedded space) missing from assembled command line: [' +
      %trim(cmdline) + ']');
  endif;
end-proc;

///
// FORK_build_cmdline - omitting envvars entirely must still fit (just
// jobname + cmd), not be mistaken for the overflow case.
///

dcl-proc test_build_cmdline_no_envvars_fits export;
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits like(BOOLEAN_t);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline);

  if not fits;
    fail('omitting envvars entirely was treated as the overflow case');
  endif;
end-proc;

///
// FORK_build_cmdline - a command line that would exceed PASE_CMD_SIZE once
// every argument is quoted and assembled must be rejected (false), not
// silently truncated. A handful of long envvars entries is enough, well
// short of FORK_MAX_ENVVARS (48).
///

dcl-proc test_build_cmdline_overflow_rejected export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s filler varchar(500);
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits like(BOOLEAN_t);
  dcl-s i like(UNSIGNED_INTEGER_t);

  // Build a 500-byte filler by doubling, rather than a hand-typed 500-char
  // literal - simpler to get right, and the exact character doesn't
  // matter for this test.
  filler = 'x';
  dow %len(filler) < 500;
    filler = filler + filler;
  enddo;
  filler = %subst(filler: 1: 500);

  // 10 entries x ~510 bytes each is already ~5100 bytes of raw value
  // alone, before quoting overhead or the job name/command - comfortably
  // over PASE_CMD_SIZE (5000) once assembled.
  for i = 1 to 10;
    envvars(i) = 'LONGVAR' + %char(i) + '=' + filler;
  endfor;

  fits = FORK_build_cmdline('TESTJOB01': envvars: 10: 'sleep 1': cmdline);

  if fits;
    fail('10 x ~510-byte envvars entries should have overflowed PASE_CMD_SIZE but fit');
  endif;
end-proc;

///
// FORK_build_cmdline - the exact PASE_CMD_SIZE boundary. The overflow test
// above only uses a comfortably-over-budget input, so an off-by-one in the
// `>` vs `>=` comparison would pass it and still be wrong.
//
// The needed filler length is COMPUTED, not guessed: measure the
// assembled line's length for an empty cmd first (the fixed overhead -
// path, jobname, nvars, separators, the 2 quote characters an empty cmd
// still gets), then derive exactly how much filler makes the total land
// on PASE_CMD_SIZE, and one byte past it.
///

dcl-proc test_build_cmdline_exact_boundary export;
  dcl-s cmdline   like(PASE_CMD_t);
  dcl-s fits      like(BOOLEAN_t);
  dcl-s baseline  like(UNSIGNED_INTEGER_t);
  dcl-s needed    like(UNSIGNED_INTEGER_t);
  dcl-s filler    varchar(8192);

  // Baseline: everything except cmd's own content (an empty cmd still
  // costs 2 bytes - the wrapping quotes shell_quote always adds).
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: '': cmdline);
  if not fits;
    fail('baseline (empty cmd) unexpectedly did not fit - cannot compute the boundary');
    return;
  endif;
  baseline = %len(cmdline);

  // Replacing the empty, 2-byte-quoted cmd with an N-byte filler (no
  // embedded quotes, so shell_quote only adds its own 2 wrapping quotes,
  // same as the baseline already accounted for) changes the total by
  // exactly N bytes - so `needed` filler bytes land the total exactly on
  // PASE_CMD_SIZE.
  needed = PASE_CMD_SIZE - baseline;

  filler = 'x';
  dow %len(filler) < needed;
    filler = filler + filler;
  enddo;
  filler = %subst(filler: 1: needed);

  // Exactly PASE_CMD_SIZE bytes: must fit.
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed): cmdline);
  if not fits;
    fail('assembled line at exactly PASE_CMD_SIZE (' + %char(PASE_CMD_SIZE) +
      ') bytes was rejected - should fit');
    return;
  endif;
  if %len(cmdline) <> PASE_CMD_SIZE;
    fail('expected the assembled line to measure exactly PASE_CMD_SIZE (' +
      %char(PASE_CMD_SIZE) + '), got ' + %char(%len(cmdline)));
  endif;

  // One byte past PASE_CMD_SIZE: must be rejected.
  filler = 'x';
  dow %len(filler) < needed + 1;
    filler = filler + filler;
  enddo;
  filler = %subst(filler: 1: needed + 1);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed+1): cmdline);
  if fits;
    fail('assembled line at PASE_CMD_SIZE + 1 (' + %char(PASE_CMD_SIZE + 1) +
      ') bytes fit - should have been rejected');
  endif;
end-proc;

///
// FORK_build_cmdline - envvars_n greater than FORK_MAX_ENVVARS must be
// rejected outright:
// envvars_n is an independent scalar, not derived from the array's own
// compile-time-fixed dim(FORK_MAX_ENVVARS), so a caller bug passing
// envvars_n too high must not silently read past the array. The request
// itself is otherwise tiny - well within PASE_CMD_SIZE on its own - so
// this can only pass for the right reason (the envvars_n guard), not by
// coincidentally also tripping the PASE_CMD_SIZE guard.
///

dcl-proc test_build_cmdline_envvars_n_over_max_rejected export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);
  dcl-s i       like(UNSIGNED_INTEGER_t);

  for i = 1 to FORK_MAX_ENVVARS;
    envvars(i) = 'A' + %char(i) + '=1';
  endfor;

  fits = FORK_build_cmdline('TESTJOB01': envvars: FORK_MAX_ENVVARS + 1: 'sleep 1': cmdline);

  if fits;
    fail('envvars_n = FORK_MAX_ENVVARS + 1 (' + %char(FORK_MAX_ENVVARS + 1) +
      ') should have been rejected outright, not treated as fitting');
  endif;
end-proc;

///
// FORK_run_cmd - the ONE path on this procedure that is safe to
// unit-test: a command line that the overflow guard rejects never reaches
// PASE_run_cmd, so this is a real unit test, not an accidental fork. Must
// return FORK_RC_CMDLINE_TOO_LONG, and must blank stdout (if passed)
// rather than leaving it holding whatever the caller's variable contained.
///

dcl-proc test_run_cmd_overflow_returns_distinct_rc_and_blanks_stdout export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s filler varchar(500);
  dcl-s stdout like(PASE_IO_t);
  dcl-s rc like(INTEGER_t);
  dcl-s i like(UNSIGNED_INTEGER_t);

  filler = 'x';
  dow %len(filler) < 500;
    filler = filler + filler;
  enddo;
  filler = %subst(filler: 1: 500);

  for i = 1 to 10;
    envvars(i) = 'LONGVAR' + %char(i) + '=' + filler;
  endfor;

  stdout = 'leftover garbage from a previous call';

  rc = FORK_run_cmd('TESTJOB01': envvars: 10: 'sleep 1': 0: false: stdout);

  // Numeric comparison - aEqual is for char/varchar; assertEqual's
  // overload dispatches numeric args to assertEqual_numeric.
  assertEqual(FORK_RC_CMDLINE_TOO_LONG: rc);

  if %len(%trimr(stdout)) > 0;
    fail('stdout was not blanked on the overflow-rejection path: [' + %trim(stdout) + ']');
  endif;
end-proc;

//==============================================================================
// v2.3.0: keep_stdio. External argv (stable, backward compatible):
//   rmfork <jobname> <nvars> [<envvar> ...] <cmd> [<resourceid> [<keep_stdio>]]
// FORK_build_cmdline emits a trailing ' <rid-or-0> 1' ONLY when keep_stdio is
// passed and true; false/omitted output must stay byte-identical to v2.2.0.
//
// The three "v2.2.0 byte-identical" tests below are regression guards that
// pin the pre-keep_stdio output; the keep_stdio=true tests check the new
// trailing token.
//==============================================================================

///
// v2.2.0 baseline text, assembled by hand (not via shell_quote), so these
// tests pin the exact bytes rather than echoing the implementation. The
// path itself comes from FORK_NATIVE_PATH, which changes with every
// release; it contains no quote characters, so wrapping it by hand is
// still exact.
///

dcl-proc q22;
  dcl-pi *n varchar(200);
    tail varchar(100) const;
  end-pi;

  return '''' + FORK_NATIVE_PATH + ''' ''TESTJOB01'' ' + tail;
end-proc;

dcl-proc test_build_cmdline_v220_none_byte_identical export;
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline);
  assert(fits: 'should fit');
  aEqual(q22('0 ''sleep 1'''): cmdline);
end-proc;

dcl-proc test_build_cmdline_v220_envvars_and_rid_byte_identical export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);

  envvars(1) = 'A=1';
  envvars(2) = 'B=two words';

  fits = FORK_build_cmdline('TESTJOB01': envvars: 2: 'sleep 1': cmdline: 7);
  assert(fits: 'should fit');
  aEqual(q22('2 ''A=1'' ''B=two words'' ''sleep 1'' 7'): cmdline);
end-proc;

///
// keep_stdio false, explicit, with and without resourceid: no extra token,
// identical to the omitted forms.
///

dcl-proc test_build_cmdline_keep_stdio_false_emits_nothing export;
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline: 0: false);
  assert(fits: 'rid + keep_stdio=false should fit');
  aEqual(q22('0 ''sleep 1'' 0'): cmdline);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline: 7: false);
  assert(fits: 'rid 7 + keep_stdio=false should fit');
  aEqual(q22('0 ''sleep 1'' 7'): cmdline);
end-proc;

///
// keep_stdio true with resourceid 0 (the usual case): ... <cmd> 0 1
///

dcl-proc test_build_cmdline_keep_stdio_true_rid0 export;
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: 'sleep 1': cmdline: 0: true);
  assert(fits: 'should fit');
  aEqual(q22('0 ''sleep 1'' 0 1'): cmdline);
end-proc;

///
// keep_stdio true with a real resourceid and envvars: ... <cmd> 7 1
///

dcl-proc test_build_cmdline_keep_stdio_true_envvars_and_rid export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s cmdline like(PASE_CMD_t);
  dcl-s fits    like(BOOLEAN_t);

  envvars(1) = 'A=1';
  envvars(2) = 'B=two words';

  fits = FORK_build_cmdline('TESTJOB01': envvars: 2: 'sleep 1': cmdline: 7: true);
  assert(fits: 'should fit');
  aEqual(q22('2 ''A=1'' ''B=two words'' ''sleep 1'' 7 1'): cmdline);
end-proc;

///
// Overflow boundary re-derived for keep_stdio true (adds ' 0 1' = 4 bytes
// over the no-resourceid form, which itself has no trailing rid). The
// baseline is MEASURED with keep_stdio true, and additionally pinned to be
// exactly the keep_stdio-omitted baseline + 4, so the test cannot pass by
// merely measuring whatever the implementation emits.
//   - cmd sized so the keep_stdio=true line is exactly PASE_CMD_SIZE: fits
//   - one byte more: rejected
//   - the cmd that exactly fills PASE_CMD_SIZE WITHOUT keep_stdio must be
//     rejected WITH keep_stdio (the 4 extra bytes tip it over)
///

dcl-proc test_build_cmdline_exact_boundary_keep_stdio export;
  dcl-s cmdline    like(PASE_CMD_t);
  dcl-s fits       like(BOOLEAN_t);
  dcl-s base_plain like(UNSIGNED_INTEGER_t);
  dcl-s base_keep  like(UNSIGNED_INTEGER_t);
  dcl-s needed     like(UNSIGNED_INTEGER_t);
  dcl-s filler     varchar(8192);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: '': cmdline);
  base_plain = %len(cmdline);

  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: '': cmdline: 0: true);
  if not fits;
    fail('baseline (empty cmd, keep_stdio) unexpectedly did not fit');
    return;
  endif;
  base_keep = %len(cmdline);

  assertEqual(base_plain + 4: base_keep);
  if base_keep <> base_plain + 4;
    return;
  endif;

  needed = PASE_CMD_SIZE - base_keep;
  filler = 'x';
  dow %len(filler) < needed + 5;
    filler = filler + filler;
  enddo;

  // Exactly PASE_CMD_SIZE with keep_stdio: fits.
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed):
                            cmdline: 0: true);
  if not fits;
    fail('keep_stdio line at exactly PASE_CMD_SIZE was rejected - should fit');
    return;
  endif;
  assertEqual(PASE_CMD_SIZE: %len(cmdline));

  // One past: rejected.
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed+1):
                            cmdline: 0: true);
  if fits;
    fail('keep_stdio line at PASE_CMD_SIZE + 1 fit - should be rejected');
  endif;

  // Fills the budget exactly WITHOUT keep_stdio (needed + 4 bytes of cmd):
  // fits plain, must be rejected with keep_stdio.
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed+4):
                            cmdline);
  if not fits;
    fail('plain line at exactly PASE_CMD_SIZE was rejected - should fit');
  endif;
  fits = FORK_build_cmdline('TESTJOB01': *omit: *omit: %subst(filler:1:needed+4):
                            cmdline: 0: true);
  if fits;
    fail('line that exactly fills PASE_CMD_SIZE without keep_stdio fit WITH ' +
      'keep_stdio - the extra " 0 1" must tip it over');
  endif;
end-proc;

///
// FORK_run_cmd overflow path with keep_stdio true and stdout in its new
// (7th) slot: still returns FORK_RC_CMDLINE_TOO_LONG and blanks stdout.
// Safe unit test (rejected before PASE_run_cmd) - the same input overflows
// with or without keep_stdio.
///

dcl-proc test_run_cmd_overflow_keep_stdio_blanks_stdout export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s filler varchar(500);
  dcl-s stdout like(PASE_IO_t);
  dcl-s rc like(INTEGER_t);
  dcl-s i like(UNSIGNED_INTEGER_t);

  filler = 'x';
  dow %len(filler) < 500;
    filler = filler + filler;
  enddo;
  filler = %subst(filler: 1: 500);

  for i = 1 to 10;
    envvars(i) = 'LONGVAR' + %char(i) + '=' + filler;
  endfor;

  stdout = 'leftover garbage from a previous call';

  rc = FORK_run_cmd('TESTJOB01': envvars: 10: 'sleep 1': 0: true: stdout);

  assertEqual(FORK_RC_CMDLINE_TOO_LONG: rc);
  if %len(%trimr(stdout)) > 0;
    fail('stdout was not blanked on the overflow path: [' + %trim(stdout) + ']');
  endif;
end-proc;
