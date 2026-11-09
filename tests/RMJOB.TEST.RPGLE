**free

//==============================================================================
// RMJOB.TEST - RPGUnit suite for JOB_get_envvars.
//
// test_job_get_envvars_own_job_env's fixture technique (stage known values
// on the CURRENT job via ENVVAR_put, from RMENVVAR.rpgle) is why this is a
// fast unit suite rather than part of the slow RMFORKIT integration suite -
// no forking is involved anywhere in this file.
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMTOOLS');

/include 'include/RMJOB_D.rpgleinc'
/include 'include/RMENVVAR_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

dcl-c LONG_NAME const('RMJOBENVLONGTEST');
dcl-c LONG_LEN  const(400);
dcl-c OWN_NAME  const('RMJOBENVOWNTEST');
dcl-c OWN_VALUE const('rmjob-own-job-env-probe');

///
// A filler value of exactly len characters, built rather than written out
// literally.
///

dcl-proc long_value;
  dcl-pi *n varchar(512);
    len like(INTEGER_t) const;
  end-pi;

  dcl-c FILL const('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz');
  dcl-s v varchar(600);

  v = '';
  dow %len(v) < len;
    v += FILL;
  enddo;

  return %subst(v: 1: len);
end-proc;

///
// A syntactically valid but nonexistent job reports false, with a reason.
///

dcl-proc test_job_get_envvars_job_not_found export;
  dcl-ds env likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err like(STRING_t);
  dcl-s  jn  like(JOB_FULL_NAME_t);

  jn = '999999/NOBODY/NOSUCHJOB';

  if JOB_get_envvars(jn: env: err);
    fail('a syntactically valid but nonexistent job should not be readable');
    return;
  endif;

  if %len(%trimr(err)) = 0;
    fail('a reason should be given, rather than a bare false');
    return;
  endif;

  // A placeholder implementation that returns false with fixed text such as
  // "JOB_get_envvars is not yet implemented" for EVERY call would pass the
  // two checks above for the wrong reason - agreeing with "not found" by
  // accident rather than by actually detecting it. This rules that stub
  // text out, so the reason must genuinely be about this job.
  if %scan('not yet implemented': %trim(err)) > 0;
    fail('the reason must be about THIS job, not the fixed stub text - got [' +
      %trim(err) + ']');
  endif;
end-proc;

///
// The calling job's own live environment is read correctly.
//
// This test used to assert that QIBM_PASE_CCSID
// was present in the job's own environment, on the claimed grounds that it
// is set at the PASE job level itself regardless of launch mechanism. That
// turned out to be wrong - a job launched via VS Code's IBM i Testing
// extension does not have QIBM_PASE_CCSID set either, so the claim of
// universality was never actually true. Rather than depend on any
// system-level variable whose presence varies by how the job was launched,
// this stages a known value on the CURRENT job itself via ENVVAR_put (the
// same fixture technique test_job_get_envvars_long_value_not_split already
// uses below) and asserts that specific, self-controlled value comes back
// correctly.
///

dcl-proc test_job_get_envvars_own_job_env export;
  dcl-ds env likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err  like(STRING_t);
  dcl-s  jn   like(JOB_FULL_NAME_t);
  dcl-s  val  varchar(512);
  dcl-s  got  varchar(512);
  dcl-s  i    like(UNSIGNED_INTEGER_t);
  dcl-s  hits like(UNSIGNED_INTEGER_t);
  dcl-s  plen like(INTEGER_t);

  val = OWN_VALUE;

  if not ENVVAR_put(OWN_NAME: val);
    fail('could not stage a known job-level environment variable on this ' +
      'suite''s own job');
    return;
  endif;

  jn = JOB_full_job_name();

  if not JOB_get_envvars(jn: env: err);
    fail('this suite''s own job must be readable - ' + %trim(err));
    ENVVAR_dlt(OWN_NAME);
    return;
  endif;

  if env.count = 0;
    fail('at least one environment variable should be reported');
  endif;

  plen = %len(OWN_NAME) + 1;
  hits = 0;
  for i = 1 to env.count;
    if %len(%trimr(env.entry(i))) > plen
       and %subst(env.entry(i): 1: plen) = OWN_NAME + '=';
      hits += 1;
      got = %subst(env.entry(i): plen + 1);
    endif;
  endfor;

  assertEqual(1: hits);

  if %trimr(got) <> %trimr(val);
    fail('the value should come back correctly - expected [' +
      %trim(val) + '], got [' + %trim(got) + ']');
  endif;

  ENVVAR_dlt(OWN_NAME);
end-proc;

///
// A long value that would wrap across several printed DSPJOB lines must
// still come back as ONE unsplit entry.
//
// Staged on this suite's OWN job via ENVVAR_put, because the suite cannot
// control what is already in its real environment and cannot predict a
// value long enough to wrap by accident. 400 characters is comfortably past
// any plausible single printed line's worth of value text in a DSPJOB
// *ENVVAR report.
///

dcl-proc test_job_get_envvars_long_value_not_split export;
  dcl-ds env likeds(JOB_ENVVARS_t) inz(*likeds);
  dcl-s  err  like(STRING_t);
  dcl-s  jn   like(JOB_FULL_NAME_t);
  dcl-s  val  varchar(512);
  dcl-s  got  varchar(512);
  dcl-s  i    like(UNSIGNED_INTEGER_t);
  dcl-s  hits like(UNSIGNED_INTEGER_t);
  dcl-s  plen like(INTEGER_t);

  val = long_value(LONG_LEN);
  assertEqual(LONG_LEN: %len(val));

  if not ENVVAR_put(LONG_NAME: val);
    fail('could not stage a long job-level environment variable on this ' +
      'suite''s own job');
    return;
  endif;

  jn = JOB_full_job_name();
  if not JOB_get_envvars(jn: env: err);
    fail('this suite''s own job must be readable - ' + %trim(err));
    ENVVAR_dlt(LONG_NAME);
    return;
  endif;

  plen = %len(LONG_NAME) + 1;
  hits = 0;
  for i = 1 to env.count;
    if %len(%trimr(env.entry(i))) > plen
       and %subst(env.entry(i): 1: plen) = LONG_NAME + '=';
      hits += 1;
      got = %subst(env.entry(i): plen + 1);
    endif;
  endfor;

  assertEqual(1: hits);

  if %trimr(got) <> %trimr(val);
    fail('the value should come back whole - expected ' +
      %char(%len(%trimr(val))) + ' characters, got ' +
      %char(%len(%trimr(got))));
  endif;

  ENVVAR_dlt(LONG_NAME);
end-proc;
