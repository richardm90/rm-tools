**free

//==============================================================================
// RMFORKIT.TEST - integration suite for FORK_run_cmd.
//
// NOT one of the fast unit suites. Run it ONLY by deliberate, explicit,
// by-name invocation (a pre-release step, not an automatic build/CI step),
// with RMFORK's native helper deployed by a build of this checkout.
// <objlib> is the library rm-tools was built into:
//
//   ADDLIBLE RPGUNIT
//   ADDLIBLE <objlib>
//   RUCRTRPG SRCSTMF('<checkout>/tests/RMFORKIT.TEST.RPGLE')
//            TSTPGM(<objlib>/TRMFORKIT) TGTCCSID(*JOB) DBGVIEW(*SOURCE)
//            RPGPPOPT(*LVL2) INCDIR('<checkout>')
//   RUCALLTST TSTPGM(<objlib>/TRMFORKIT) ORDER(*API) LIBL(*CURRENT)
//             JOBD(*DFT) DETAIL(*BASIC) OUTPUT(*ALLWAYS) RCLRSC(*NO)
//             ONFAILURE(*CONTINUE)
//
// WHY THIS IS A SEPARATE SUITE: every test here calls
// the real, exported FORK_run_cmd - not FORK_build_cmdline - so every
// "happy" case here genuinely forks a real PASE process via the deployed
// native binary (FORK_NATIVE_PATH). That is an unsafe, non-deterministic
// thing to do from a routine unit-test run
// but is exactly the one thing only this suite can prove: whether
// Qp2setenv_ile() + f_fork400() nested inside a process itself spawned by
// PASE_run_cmd's own spawn()-based dispatch chain actually works - every
// fact behind the design was previously measured only from a directly
// invoked process (plain ssh/bash), never one arriving via that chain.
//
// Every exec'd command below is non-destructive and self-terminating
// (sleep N) - no cleanup step is needed, and none is attempted. Every job
// name is a disposable, run-specific literal that cannot collide across
// runs within any plausible test cadence on this box.
//
// JOB_get_envvars (RMJOB) is given the bare 10-character job name, NOT a
// full "number/user/name" JOB_FULL_NAME_t - its own implementation builds
// `DSPJOB JOB(%trim(job_name)) ...` directly from whatever string it is
// given, and DSPJOB's own JOB parameter resolves a bare, unqualified name
// by searching the active job table, which is reliable here specifically
// because every job name used below is freshly disposable and therefore
// unique on the box at the moment it is queried.
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMTOOLS');

/include 'include/RMFORK_D.rpgleinc'
/include 'include/RMJOB_D.rpgleinc'
/include 'include/RMPASE_D.rpgleinc'
/include 'include/RMQCMD_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

///
// Pause THIS job (the test runner), not the forked job under test, so a
// just-forked job has a moment to become visible to DSPJOB before we query
// it. QCMD_exc('DLYJOB ...') delays the caller, never the target.
///

dcl-proc delay_seconds;
  dcl-pi *n;
    secs like(INTEGER_t) const;
  end-pi;

  dcl-ds qerr likeds(QCMD_ERR_t);

  QCMD_exc('DLYJOB DLY(' + %char(secs) + ')': qerr);
end-proc;

///
// Find env.entry(i) by its "NAME=" prefix and return the VALUE half,
// trailing-trimmed only - leading/embedded content (e.g. an embedded space)
// must survive untouched. Returns '' and sets found to false if NAME= is
// not present exactly once.
///

dcl-proc find_envvar;
  dcl-pi *n varchar(512);
    env   likeds(JOB_ENVVARS_t) const;
    name  varchar(100) const;
    found like(BOOLEAN_t);
  end-pi;

  dcl-s prefix varchar(101);
  dcl-s plen   like(INTEGER_t);
  dcl-s i      like(UNSIGNED_INTEGER_t);
  dcl-s hits   like(UNSIGNED_INTEGER_t);
  dcl-s val    varchar(512);

  prefix = %trim(name) + '=';
  plen = %len(prefix);
  hits = 0;
  val = '';

  for i = 1 to env.count;
    if %len(%trimr(env.entry(i))) >= plen
       and %subst(env.entry(i): 1: plen) = prefix;
      hits += 1;
      val = %trimr(%subst(env.entry(i): plen + 1));
    endif;
  endfor;

  found = (hits = 1);
  return val;
end-proc;

///
// Scenario 1 (the one that proves the nested spawn() -> Qp2setenv_ile() +
// f_fork400() chain described in the header works): a job name plus 3
// NAME=VALUE pairs - one with an embedded space - published through the
// REAL FORK_run_cmd -> PASE_run_cmd -> deployed rmfork binary chain, not a
// standalone/direct invocation. Must return rc=0 (PASE_RC_SUCCESS), the job
// must genuinely exist, and JOB_get_envvars reading it back (not just
// confirming it exists) must show every published value correctly,
// embedded space intact.
///

dcl-proc test_fork_happy_path_envvars_land_in_job export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-ds env    likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err    like(STRING_t);
  dcl-s  jn     like(JOB_FULL_NAME_t);
  dcl-s  rc     like(INTEGER_t);
  dcl-s  val    varchar(512);
  dcl-s  found  like(BOOLEAN_t);

  jobname = 'RMFITHP01';

  envvars(1) = 'GREETING=hello world';
  envvars(2) = 'COLOR=blue';
  envvars(3) = 'NUM=42';

  rc = FORK_run_cmd(jobname: envvars: 3: 'sleep 30');

  assertEqual(PASE_RC_SUCCESS: rc);
  if rc <> PASE_RC_SUCCESS;
    return;
  endif;

  // Give the just-forked job a moment to become queryable via DSPJOB before
  // asking for its environment.
  delay_seconds(2);

  jn = %trimr(jobname);
  if not JOB_get_envvars(jn: env: err);
    fail('job ' + %trim(jobname) + ' should be readable after a successful ' +
      'FORK_run_cmd - ' + %trim(err));
    return;
  endif;

  val = find_envvar(env: 'GREETING': found);
  if not found;
    fail('GREETING should appear exactly once in ' + %trim(jobname) +
      '''s environment');
  elseif val <> 'hello world';
    fail('GREETING should read back as [hello world] (embedded space ' +
      'intact), got [' + val + ']');
  endif;

  val = find_envvar(env: 'COLOR': found);
  if not found;
    fail('COLOR should appear exactly once in ' + %trim(jobname) + '''s environment');
  elseif val <> 'blue';
    fail('COLOR should read back as [blue], got [' + val + ']');
  endif;

  val = find_envvar(env: 'NUM': found);
  if not found;
    fail('NUM should appear exactly once in ' + %trim(jobname) + '''s environment');
  elseif val <> '42';
    fail('NUM should read back as [42], got [' + val + ']');
  endif;
end-proc;

///
// Scenario 2: overwrite semantics. envvars carries the SAME name twice,
// with different values, in order - Qp2setenv_ile()'s own documented
// last-write-wins semantics (src/pase/RMFORK.c's header) means the forked
// job's environment must show exactly ONE entry for that name, holding the
// SECOND value, not the first and not both.
///

dcl-proc test_fork_overwrite_semantics_second_value_wins export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-ds env    likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err    like(STRING_t);
  dcl-s  jn     like(JOB_FULL_NAME_t);
  dcl-s  rc     like(INTEGER_t);
  dcl-s  val    varchar(512);
  dcl-s  found  like(BOOLEAN_t);

  jobname = 'RMFITOV01';

  envvars(1) = 'COLOR=red';
  envvars(2) = 'COLOR=blue';

  rc = FORK_run_cmd(jobname: envvars: 2: 'sleep 30');

  assertEqual(PASE_RC_SUCCESS: rc);
  if rc <> PASE_RC_SUCCESS;
    return;
  endif;

  delay_seconds(2);

  jn = %trimr(jobname);
  if not JOB_get_envvars(jn: env: err);
    fail('job ' + %trim(jobname) + ' should be readable after a successful ' +
      'FORK_run_cmd - ' + %trim(err));
    return;
  endif;

  val = find_envvar(env: 'COLOR': found);
  if not found;
    fail('COLOR should appear exactly ONCE (last-write-wins), not zero or ' +
      'more than once, in ' + %trim(jobname) + '''s environment');
  elseif val <> 'blue';
    fail('COLOR should read back as the SECOND published value [blue] ' +
      '(the one that overwrites), got [' + val + ']');
  endif;
end-proc;

///
// Scenario 3: forced fork failure (out-of-range resourceid 999999999,
// measured failing reliably on a direct invocation of the binary). Must return
// a distinct rc (the native binary's documented exit code 2 - f_fork400()
// itself failed) and no job must ever appear under the requested name -
// confirming a failed fork leaves nothing half-created, through the REAL
// nested chain, not just a direct invocation.
///

dcl-proc test_fork_forced_fork_failure_distinct_rc_no_job export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-ds env    likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err    like(STRING_t);
  dcl-s  jn     like(JOB_FULL_NAME_t);
  dcl-s  rc     like(INTEGER_t);

  jobname = 'RMFITFF01';

  rc = FORK_run_cmd(jobname: *omit: *omit: 'sleep 1': 999999999);

  // src/pase/RMFORK.c's own documented exit code: 2 = f_fork400() itself
  // failed (pid < 0). Distinct from PASE_RC_SUCCESS (0) - checked as its
  // own literal value, not merely "non-zero", so an accidental collision
  // with some other failure code would not pass this silently.
  assertEqual(2: rc);

  delay_seconds(2);

  jn = %trimr(jobname);
  if JOB_get_envvars(jn: env: err);
    fail('no job named ' + %trim(jobname) + ' should ever have appeared ' +
      'after a forced f_fork400() failure, but JOB_get_envvars could read one');
  endif;
end-proc;

///
// Scenario 4: forced exec failure - a cmd guaranteed not to exec.
//
// Without the self-pipe in src/pase/RMFORK.c this case returned
// rc=PASE_RC_SUCCESS and left an unqueryable job, because f_fork400() is a
// genuine fork and the parent returns before the child's own exec() is even
// attempted - an exec failure was indistinguishable from success.
//
// The self-pipe technique (pipe created before f_fork400(); child sets
// FD_CLOEXEC on the write end before execl(); a successful exec() closes
// that descriptor for free as part of replacing the process image; a
// FAILED exec() leaves the child able to write its own errno into the pipe
// before _exit(127)) lets the PARENT - the same process FORK_run_cmd's own
// nested PASE_run_cmd dispatch is waiting on - read() that pipe and learn
// the real outcome before it ever returns, without waiting for the child's
// actual lifetime. So FORK_run_cmd must return exactly 127
// (src/pase/RMFORK.c's own documented exit code for "exec() failed in the
// child, after a successful fork") for a cmd that cannot exec - genuinely distinct from PASE_RC_SUCCESS (0), checked as its own
// literal value, not merely "non-zero", through the REAL FORK_run_cmd ->
// PASE_run_cmd -> deployed rmfork binary chain, not a direct invocation.
//
// MEASURED (2026-10-06): against a binary without the self-pipe, rc comes
// back 0 (PASE_RC_SUCCESS), not 127 - so this test fails for the right
// reason if that fix ever regresses.
//
// No envvars canary and no post-fork JOB_get_envvars check here - scenario
// 1 already proves envvars publishing works, and the failed child's job is
// not reliably queryable afterward (MEASURED: a DSPJOB run immediately
// afterward already reports CPF1070, job not found - a failed exec is
// syscall-fast) regardless of the rc fix, so that is not this scenario's concern; rc
// alone is what the self-pipe fix makes observable, and rc alone is what
// this scenario asserts.
///

dcl-proc test_fork_forced_exec_failure_returns_127 export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-s  rc     like(INTEGER_t);

  jobname = 'RMFITEF01';

  // Guaranteed not to exec: no such path exists on this (or any) box.
  rc = FORK_run_cmd(jobname: *omit: *omit: '/no/such/rmfork-it-binary-xyz');

  // With the self-pipe in src/pase/RMFORK.c, a forced exec failure must
  // return 127 (src/pase/RMFORK.c's own documented exit code
  // for this exact case) - genuinely distinct from PASE_RC_SUCCESS (0).
  assertEqual(127: rc);
end-proc;

//==============================================================================
// v2.3.0 scenarios: env vars published inside the forked job (two-phase
// child) and the optional keep_stdio. Scenarios 5, 6 and 8 pin behaviour
// v2.2.0 already had and v2.3.0 must keep; scenario 7 (keep_stdio=true text
// reaches stdout) covers the new behaviour.
//
// MEASURED (2026-10-07, PASE_run_cmd directly): a command's
// stderr DOES reach PASE_run_cmd's stdout with no `2>&1`: `ls /no/such/dir`
// returns rc=2 and the 0653-341 message in stdout, identical with and
// without `2>&1`; `echo OUT; echo ERR 1>&2` returns both words.
// Scenario 7 therefore deliberately does NOT append 2>&1 to its failing
// command, so it also pins that the stderr text arrives under keep_stdio.
//==============================================================================

///
// Scenario 5: env vars are published into the FORKED job and
// are absent from the CALLING job. The calling job's own environment
// (JOB_get_envvars on JOB_full_job_name) must lack the name after
// FORK_run_cmd returns; the forked job must have it. The variable name is
// unique to this scenario so a leftover from another test cannot satisfy or
// break it. Guard test: under PASE_run_cmd the binary's parent is a
// disposable spawn() process, so this would pass even with the publish in
// the parent; it pins that publishing inside the forked child keeps the
// calling job clean. The strong proof (a long-lived login job as the
// parent) is a manual/scripted step, not this test.
///

dcl-proc test_fork_envvars_absent_from_calling_job export;
  dcl-s envvars like(FORK_ENVVAR_t) dim(FORK_MAX_ENVVARS);
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-ds env    likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-ds own    likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err    like(STRING_t);
  dcl-s  jn     like(JOB_FULL_NAME_t);
  dcl-s  rc     like(INTEGER_t);
  dcl-s  val    varchar(512);
  dcl-s  found  like(BOOLEAN_t);

  jobname = 'RMFITPA01';
  envvars(1) = 'RMFITPA_CANARY=only-in-the-fork';

  rc = FORK_run_cmd(jobname: envvars: 1: 'sleep 30');
  assertEqual(PASE_RC_SUCCESS: rc);
  if rc <> PASE_RC_SUCCESS;
    return;
  endif;

  delay_seconds(2);

  // Calling job: must NOT have it.
  jn = JOB_full_job_name();
  if not JOB_get_envvars(jn: own: err);
    fail('could not read the calling job''s own environment - ' + %trim(err));
    return;
  endif;
  val = find_envvar(own: 'RMFITPA_CANARY': found);
  if found;
    fail('RMFITPA_CANARY leaked into the CALLING job''s environment: [' + val + ']');
  endif;

  // Forked job: must have it.
  jn = %trimr(jobname);
  if not JOB_get_envvars(jn: env: err);
    fail('job ' + %trim(jobname) + ' should be readable - ' + %trim(err));
    return;
  endif;
  val = find_envvar(env: 'RMFITPA_CANARY': found);
  if not found;
    fail('RMFITPA_CANARY should be present in the forked job ' + %trim(jobname));
  elseif val <> 'only-in-the-fork';
    fail('RMFITPA_CANARY should read [only-in-the-fork], got [' + val + ']');
  endif;
end-proc;

///
// Scenario 6: keep_stdio omitted / false is unchanged
// v2.2.0 behaviour: stdio redirected to /dev/null so a long-lived command
// does not hold PASE_run_cmd's capture pipe open. FORK_run_cmd must return
// well inside the 30 s the command lives for, and the command's own output
// ('SHOULD-NOT-APPEAR') must not reach stdout. Run for both omitted and
// explicit false.
///

dcl-proc test_fork_keep_stdio_false_redirects_and_returns_quickly export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-s stdout  like(PASE_IO_t);
  dcl-s rc      like(INTEGER_t);
  dcl-s t0      timestamp;
  dcl-s ms      like(INTEGER_t);

  // Explicit false
  jobname = 'RMFITKF01';
  t0 = %timestamp();
  rc = FORK_run_cmd(jobname: *omit: *omit:
         'echo SHOULD-NOT-APPEAR; echo ALSO-NOT 1>&2; sleep 30': 0: false: stdout);
  ms = %diff(%timestamp(): t0: *mseconds) / 1000;

  assertEqual(PASE_RC_SUCCESS: rc);
  if ms >= 10000;
    fail('keep_stdio=false returned after ' + %char(ms) + ' ms - should be ' +
      'well under the 30 s the command lives (stdio not redirected?)');
  endif;
  if %scan('SHOULD-NOT-APPEAR': stdout) > 0 or %scan('ALSO-NOT': stdout) > 0;
    fail('keep_stdio=false: command output reached stdout: [' + %trim(stdout) + ']');
  endif;

  // Omitted entirely (no stdout possible: keep_stdio is not *omit-able, so
  // stdout cannot be passed positionally without it) - timing only.
  jobname = 'RMFITKF02';
  t0 = %timestamp();
  rc = FORK_run_cmd(jobname: *omit: *omit: 'sleep 30');
  ms = %diff(%timestamp(): t0: *mseconds) / 1000;
  assertEqual(PASE_RC_SUCCESS: rc);
  if ms >= 10000;
    fail('keep_stdio omitted returned after ' + %char(ms) + ' ms');
  endif;
end-proc;

///
// Scenario 7: keep_stdio=true with a SHORT-LIVED command (the only valid
// use - a long-running one would hold the caller's stdio and block
// PASE_run_cmd for its whole lifetime) must deliver the
// command's text to stdout. Two commands: a plain echo, and a failing
// command whose text is on STDERR (no 2>&1 appended - see header MEASURED
// note) and whose rc must still be PASE_RC_SUCCESS (the launcher's status,
// never the command's own exit status: the parent returns as soon as the
// final exec succeeds).
///

dcl-proc test_fork_keep_stdio_true_text_reaches_stdout export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-s stdout  like(PASE_IO_t);
  dcl-s rc      like(INTEGER_t);

  jobname = 'RMFITKT01';
  rc = FORK_run_cmd(jobname: *omit: *omit: 'echo KEEP-STDIO-MARKER': 0: true: stdout);
  assertEqual(PASE_RC_SUCCESS: rc);
  if %scan('KEEP-STDIO-MARKER': stdout) = 0;
    fail('keep_stdio=true: echo text should reach stdout, got [' + %trim(stdout) + ']');
  endif;
end-proc;

dcl-proc test_fork_keep_stdio_true_failing_cmd_stderr_reaches_stdout export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-s stdout  like(PASE_IO_t);
  dcl-s rc      like(INTEGER_t);

  jobname = 'RMFITKT02';
  rc = FORK_run_cmd(jobname: *omit: *omit: '/QOpenSys/usr/bin/ls /no/such/dir':
                    0: true: stdout);

  // rc is the launcher's status, NOT ls's exit status (2).
  assertEqual(PASE_RC_SUCCESS: rc);
  if %scan('/no/such/dir': stdout) = 0;
    fail('keep_stdio=true: the failing command''s own error text should reach ' +
      'stdout, got [' + %trim(stdout) + ']');
  endif;
end-proc;

///
// Scenario 8: keep_stdio=true must not break the exec-failure
// contract - a command that cannot exec is still rc 127.
///

dcl-proc test_fork_keep_stdio_true_exec_failure_returns_127 export;
  dcl-s jobname like(FORK_JOBNAME_t);
  dcl-s rc      like(INTEGER_t);

  jobname = 'RMFITKE01';
  rc = FORK_run_cmd(jobname: *omit: *omit: '/no/such/rmfork-it-binary-xyz': 0: true);
  assertEqual(127: rc);
end-proc;
