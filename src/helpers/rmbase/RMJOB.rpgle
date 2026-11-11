**free

//==============================================================================
// RMJOB      - IBM i Job Helper Module
//
// 11/11/2024 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: IBM i Job Helper Module');

///
// Copybook definitions
///

/include 'include/PSDS_D.rpgleinc'
/include 'include/RMJOB_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'
/include 'include/RMQCMD_D.rpgleinc'
/include 'include/RMMSG_D.rpgleinc'
/include 'include/RMIFS_D.rpgleinc'
/include 'include/RMPASE_D.rpgleinc'
/include 'include/RMSTRING_D.rpgleinc'

// QSPRILSP format SPRL0100 - see last_spooled_file. Declared here because
// a dcl-ds cannot sit between procedures.
dcl-ds SPLF_ID_t qualified template;
  bytes_returned  int(10);
  bytes_available int(10);
  name            char(10);
  job_name        char(10);
  job_user        char(10);
  job_number      char(6);
  number          int(10);
  system_name     char(8);
  create_date     char(7);
  reserved        char(1);
  create_time     char(6);
end-ds;

//==============================================================================
// JOB_ccsid
//   Return the current job CCSID value
//     https://ilikerpgle.blogspot.com/2018/10/change-job-ccsid.html
//==============================================================================

dcl-proc JOB_ccsid export;
  dcl-pi *n like(CCSID_t) end-pi;

  // Retrieve Job Information (QUSRJOBI) API
  dcl-pr QUSRJOBI extpgm('QUSRJOBI');
    *N             Char(32767) options( *varsize );
    *N             Int(10)    const;
    *N             Char(8)    const;
    *N             Char(26)   const;
    *N             Char(16)   const;
    *N             Char(32767) options( *nopass: *varsize );
  end-pr;

  // Receiver Variable for JOBI0400 format of QUSRJOBI
  dcl-ds JOBI0400  qualified inz;
    Filler1        Char(8);
    JobName        Char(10);
    UserName       Char(10);
    JobNumber      Char(6);
    Filler2        Char(266);
    CcsId          Int(10);
  end-ds;

  // Data Structure of Return API Error Information
  dcl-ds ApiError  qualified;
    BytesProvide   Int(10);
    BytesAvail     Int(10);
    ExceptionID    Char(7);
    ReservedSpac   Char(1);
    ExceptionDat   Char(128);
  end-ds;

  dcl-s ccsid like(CCSID_t);

  // Retrieve Job Information (QUSRJOBI) API
  Qusrjobi( JOBI0400          // Receiver variable
          : %size( JOBI0400 ) // Length of receiver variable
          : 'JOBI0400'        // Format name
          : '*'               // Qualified job name
          : *blank            // Internal job identifier
          : ApiError );       // Error code

  if ApiError.BytesAvail = 0;
    ccsid = JOBI0400.Ccsid;     // 4.Job CcsId
  endif;

  return ccsid;
end-proc;

//==============================================================================
// JOB_name
//   Returns the current job name
//==============================================================================

dcl-proc JOB_name export;
  dcl-pi *n like(JOB_NAME_t) end-pi;

  return psds.job_name;
end-proc;

//==============================================================================
// JOB_user
//   Returns the current job user
//==============================================================================

dcl-proc JOB_user export;
  dcl-pi *n like(USER_t) end-pi;

  return psds.job_user;
end-proc;

//==============================================================================
// JOB_number
//   Returns the current job number
//==============================================================================

dcl-proc JOB_number export;
  dcl-pi *n like(JOB_NUMBER_t) end-pi;

  return psds.job_number;
end-proc;

//==============================================================================
// Returns the full job name
// - e.g. 025789/RICHARD/QPADEV0001
//==============================================================================

dcl-proc JOB_full_job_name export;
  dcl-pi *n like(JOB_FULL_NAME_t) end-pi;

  dcl-s job like(JOB_FULL_NAME_t);

  job = %editc(psds.job_number:'X') + '/'
      + %trimr(psds.job_user) + '/'
      + %trimr(psds.job_name);

  return job;
end-proc;

//==============================================================================
// Return the job user from the given full job name
// - e.g. 025789/RICHARD/QPADEV0001 --> RICHARD
//==============================================================================

dcl-proc JOB_extract_user export;
  dcl-pi *n like(USER_t);
    full_job_name like(JOB_FULL_NAME_t) const;
  end-pi;

  dcl-s user like(USER_t);
  dcl-s pos like(SMALLINT_t);
  dcl-s start like(SMALLINT_t);
  dcl-s finish like(SMALLINT_t);

  monitor;

    // Find the location of the first slash
    pos = %scan('/': full_job_name);
    if pos > 0;
      start = pos + 1;

      // Find the location of the second slash
      pos = %scan('/': full_job_name: start);
      if pos > 0;
        finish = pos - 1;

        user = %subst(full_job_name: start: (finish-start+1));
      endif;

    endif;

  on-error;
    user = '';
  endmon;

  return user;
end-proc;

//==============================================================================
// last_spooled_file
//
// The identity of the spooled file this job most recently created, from
// the Retrieve Identity of Last Spooled File Created (QSPRILSP) API,
// format SPRL0100. Blank when the job has not created one yet (the API's
// error is swallowed, not signalled).
//
// MEASURED: DSPJOB OUTPUT(*PRINT)'s spooled file is NOT owned by the job
// that ran DSPJOB - it goes to the user's QPRTJOB job (e.g.
// 040645/RICHARD/QPRTJOB), and spooled file numbers are counted per job.
// QSPRILSP still reports it correctly, so it is the only lookup used:
// nothing searches output queues, and no other user's spooled files can
// be mistaken for this call's.
//==============================================================================

dcl-proc last_spooled_file;
  dcl-pi *n likeds(SPLF_ID_t);
  end-pi;

  dcl-pr QSPRILSP extpgm('QSPRILSP');
    receiver     char(70);
    receiver_len int(10) const;
    format       char(8) const;
    error_code   likeds(api_err);
  end-pr;

  dcl-ds api_err qualified;
    provided  int(10) inz(%size(api_err));
    available int(10) inz(0);
    msgid     char(7);
    reserved  char(1);
    msgdata   char(64);
  end-ds;

  dcl-ds splf likeds(SPLF_ID_t) inz;
  dcl-s receiver char(70);

  QSPRILSP(receiver: %size(receiver): 'SPRL0100': api_err);
  if api_err.available = 0;
    splf = receiver;
  endif;

  return splf;

end-proc;

//==============================================================================
// value_chunk
//
// One physical line's VALUE field, starting at value_col (calibrated per
// report from its own header line, never a hardcoded column - see
// parse_envvar_report), with the single leading and (if present) single
// trailing quote DSPJOB wraps every chunk in stripped. A value that spans
// several physical lines is wrapped chunk by chunk, not once end to end -
// a genuine multi-line value carries a closing quote on its first line
// and a fresh opening quote on its continuation, not one quote pair
// spanning both.
//==============================================================================

dcl-proc value_chunk;
  dcl-pi *n like(STRING_t);
    text_line like(STRING_t) const;
    value_col like(INTEGER_t) const;
    // Where the field ENDS (the CCSID column, exclusive) - without this
    // cap, a single-line value's trailing CCSID digits are not
    // whitespace, so %TRIMR alone does not remove them.
    ccsid_col like(INTEGER_t) const;
  end-pi;

  dcl-s chunk like(STRING_t);
  dcl-s n     like(INTEGER_t);
  dcl-s width like(INTEGER_t);

  if %len(text_line) < value_col;
    return '';
  endif;

  width = %len(text_line) - value_col + 1;
  if ccsid_col > value_col;
    width = %min(width: ccsid_col - value_col);
  endif;

  chunk = %trimr(%subst(text_line: value_col: width));
  n = %len(chunk);

  if n > 0 and %subst(chunk: 1: 1) = '''';
    chunk = %subst(chunk: 2);
    n -= 1;
  endif;

  if n > 0 and %subst(chunk: n: 1) = '''';
    chunk = %subst(chunk: 1: n - 1);
  endif;

  return chunk;

end-proc;

//==============================================================================
// name_column_blank
//
// true when the NAME field (columns 2 to value_col-1) is all blank, which
// is how a continuation line of a wrapped value is told apart from a new
// entry.
//==============================================================================

dcl-proc name_column_blank;
  dcl-pi *n like(BOOLEAN_t);
    text_line like(STRING_t) const;
    value_col like(INTEGER_t) const;
  end-pi;

  if %len(text_line) < 2 or value_col <= 2;
    return true;
  endif;

  return %len(%trim(%subst(text_line: 2: %min(value_col - 2:
                                               %len(text_line) - 1)))) = 0;

end-proc;

//==============================================================================
// first_line_end
//
// The position of the first CR or LF in text, whichever comes first, or 0
// if neither appears. Both are checked rather than assuming one - a
// converted report's own line ending is NOT consistently CRLF (MEASURED:
// CRLF via a shell `cat -A`, but CR with no LF at all from the exact same
// CPYSPLF+iconv pipeline called from a compiled test).
//==============================================================================

dcl-proc first_line_end;
  dcl-pi *n like(INTEGER_t);
    text_in like(STRING_t) const;
  end-pi;

  dcl-s cr like(INTEGER_t);
  dcl-s lf like(INTEGER_t);

  cr = %scan(x'0D': text_in);
  lf = %scan(x'0A': text_in);

  if cr = 0;
    return lf;
  endif;
  if lf = 0;
    return cr;
  endif;
  return %min(cr: lf);

end-proc;

//==============================================================================
// parse_envvar_report
//
// Parses a DSPJOB OPTION(*ENVVAR) OUTPUT(*PRINT) report, already converted
// to UTF-8 text, into env. Fails loudly (returns false) rather than
// silently returning an empty env when either landmark ("Environment
// variables" / "E N D  O F  L I S T I N G") is missing. The title banner
// and "Job . . . :" identity line repeat at the top of EVERY page on a
// multi-page report, but "Environment variables" does not - so this and
// the header check are never gated on "only before the first header", or
// a second page's own repeated banner/header lines get mistaken for data.
//==============================================================================

dcl-proc parse_envvar_report;
  dcl-pi *n like(BOOLEAN_t);
    text like(STRING_t) const;
    env  likeds(JOB_ENVVARS_t);
  end-pi;

  dcl-s rest    like(STRING_t);
  dcl-s line    like(STRING_t);
  dcl-s nlpos   like(INTEGER_t);
  dcl-s term    char(1);
  dcl-s saw_marker like(BOOLEAN_t) inz(false);
  dcl-s saw_header like(BOOLEAN_t) inz(false);
  dcl-s saw_end     like(BOOLEAN_t) inz(false);
  dcl-s envname varchar(128);
  dcl-s value   like(STRING_t);
  dcl-s have_entry like(BOOLEAN_t) inz(false);
  // Calibrated from the header line's own "Value" position - the column
  // shifts between jobs (print-width/device settings differ), so a
  // hardcoded column is not reliable.
  dcl-s value_col like(INTEGER_t) inz(0);
  dcl-s ccsid_col like(INTEGER_t) inz(0);

  clear env;
  rest = text;

  dow %len(rest) > 0;
    nlpos = first_line_end(rest);
    if nlpos = 0;
      line = rest;
      rest = '';
    else;
      term = %subst(rest: nlpos: 1);
      line = %subst(rest: 1: nlpos - 1);
      rest = %subst(rest: nlpos + 1);
      // A CRLF or LFCR pair - skip the second byte of the pair too.
      if %len(rest) > 0
         and (%subst(rest: 1: 1) = x'0A' or %subst(rest: 1: 1) = x'0D')
         and %subst(rest: 1: 1) <> term;
        rest = %subst(rest: 2);
      endif;
    endif;

    if %scan('Environment variables': line) > 0;
      saw_marker = true;
      iter;
    endif;

    if %scan('Display Job': line) > 0 or %scan('Job . . . :': line) > 0;
      iter;
    endif;

    if %scan('Name': line) > 0
       and %scan('Value': line) > 0
       and %scan('CCSID': line) > 0;
      saw_header = true;
      value_col = %scan('Value': line);
      ccsid_col = %scan('CCSID': line);
      iter;
    endif;

    if %scan('E N D  O F  L I S T I N G': line) > 0;
      saw_end = true;
      if have_entry;
        env.count += 1;
        env.entry(env.count) = %trim(envname) + '=' + %trimr(value);
      endif;
      leave;
    endif;

    if not saw_header;
      // Banner / job-identity lines ahead of the FIRST header - not data.
      iter;
    endif;

    if name_column_blank(line: value_col);
      if have_entry and env.count < JOB_MAX_ENVVARS;
        value += value_chunk(line: value_col: ccsid_col);
      endif;
      iter;
    endif;

    // A new entry. Flush whichever one was being built.
    if have_entry and env.count < JOB_MAX_ENVVARS;
      env.count += 1;
      env.entry(env.count) = %trim(envname) + '=' + %trimr(value);
    endif;

    envname = %trim(%subst(line: 2: %min(value_col - 2: %len(line) - 1)));
    value = value_chunk(line: value_col: ccsid_col);
    have_entry = (%len(envname) > 0);

  enddo;

  if not saw_marker or not saw_header or not saw_end;
    clear env;
    return false;
  endif;

  return true;

end-proc;

//==================================================================================================
// JOB_get_envvars
//   Read a job's LIVE environment variables by scraping DSPJOB OPTION(*ENVVAR)
//   OUTPUT(*PRINT). There is no QSYS2 service exposing another job's
//   environment (QSYS2.ENVIRONMENT_VARIABLE_INFO has no JOB_NAME column).
//==================================================================================================

dcl-proc JOB_get_envvars export;
  dcl-pi *n like(BOOLEAN_t);
    job_name like(JOB_FULL_NAME_t) const;
    env      likeds(JOB_ENVVARS_t);
    err      like(STRING_t);
  end-pi;

  dcl-s owner_job like(JOB_FULL_NAME_t);
  dcl-ds qerr     likeds(QCMD_ERR_t);
  dcl-s raw_path  like(STMF_t);
  dcl-s utf8_path like(STMF_t);
  dcl-ds before   likeds(SPLF_ID_t);
  dcl-ds after    likeds(SPLF_ID_t);
  dcl-s have_splf like(BOOLEAN_t) inz(false);
  dcl-s text      like(STRING_t) ccsid(*utf8);
  // parse_envvar_report and its helpers work in the job's own CCSID, not
  // UTF-8 - the content being matched (job names, digits, quote
  // characters, the report's own fixed English wording) round-trips
  // between UTF-8 and the job CCSID without loss either way.
  dcl-s text_job  like(STRING_t);
  dcl-s pcmd      like(PASE_CMD_t);
  dcl-s stdout    like(PASE_IO_t);
  dcl-s ok        like(BOOLEAN_t);

  clear env;
  err = '';

  // What this job last created BEFORE the DSPJOB call, so a spooled file
  // created by it can be told apart from an older one (see
  // last_spooled_file).
  before = last_spooled_file();

  // Forced HELD before anything else runs, so the spooled file this is
  // about to generate can never print to a real printer on a profile
  // with one configured as default (MEASURED: without this
  // override, DSPJOB OPTION(*ENVVAR) OUTPUT(*PRINT)'s spooled file comes
  // up READY, not HELD). OVRSCOPE(*JOB): a plain OVRPRTF does not
  // survive past the call level that issued it - so it is also removed
  // with LVL(*JOB) below; LVL(*) does not find it ("Override not found
  // at specified level").
  if not QCMD_exc('OVRPRTF FILE(QPDSPJOB) HOLD(*YES) OVRSCOPE(*JOB)': qerr);
    err = 'Could not force the DSPJOB spooled file to HELD status';
    return false;
  endif;

  ok = QCMD_exc('DSPJOB JOB(' + %trim(job_name) +
                ') OPTION(*ENVVAR) OUTPUT(*PRINT)': qerr);
  if not ok;
    err = 'Job ' + %trim(job_name) + ' could not be read';
    if qerr.count > 0;
      err += ': ' + %trim(qerr.msgs(1).text);
    endif;
  endif;

  // Checked whether or not DSPJOB succeeded, so any spooled file it did
  // create is always deleted below.
  after = last_spooled_file();
  have_splf = after.name = 'QPDSPJOB'
              and (after.job_number <> before.job_number
                   or after.job_user <> before.job_user
                   or after.job_name <> before.job_name
                   or after.number <> before.number
                   or after.create_date <> before.create_date
                   or after.create_time <> before.create_time);

  if have_splf;
    owner_job = after.job_number + '/' + %trim(after.job_user) + '/' +
                %trim(after.job_name);
  elseif ok;
    ok = false;
    err = 'Could not locate the generated DSPJOB spooled file';
  endif;

  if ok;
    raw_path  = IFS_temp_filename();
    utf8_path = IFS_temp_filename();

    // CPYSPLF's TOSTMF form has no native CCSID-conversion parameter - a
    // raw copy followed by iconv, using THIS job's own real CCSID rather
    // than a hardcoded one. JOB(owner_job): the job QSPRILSP says owns
    // the spooled file, which is not this job.
    ok = QCMD_exc('CPYSPLF FILE(QPDSPJOB) TOFILE(*TOSTMF) JOB(' +
                  %trim(owner_job) + ') SPLNBR(' + %char(after.number) +
                  ') TOSTMF(''' + %trim(raw_path) +
                  ''') STMFOPT(*REPLACE) CTLCHAR(*NONE)': qerr);

    if ok;
      pcmd = 'iconv -f IBM-' + %char(JOB_ccsid()) + ' -t UTF-8 ' +
             %trim(raw_path) + ' > ' + %trim(utf8_path);
      ok = (PASE_run_cmd(*omit: pcmd: stdout) = PASE_RC_SUCCESS);
      if not ok;
        err = 'Could not convert the DSPJOB spooled file to text';
      endif;
    else;
      err = 'Could not copy the DSPJOB spooled file to a stream file';
    endif;

    if ok;
      text = IFS_read(utf8_path);
      text_job = text;
      ok = parse_envvar_report(text_job: env);
      if not ok;
        err = 'Unrecognised DSPJOB *ENVVAR report format for ' +
              %trim(job_name);
      endif;
    endif;

    IFS_remove_file(raw_path);
    IFS_remove_file(utf8_path);
  endif;

  // Every path from here on, success or failure: the spooled file (if
  // one was created) is deleted and the override removed - both
  // best-effort, not failures in their own right.
  if have_splf;
    QCMD_exc('DLTSPLF FILE(QPDSPJOB) JOB(' + %trim(owner_job) +
             ') SPLNBR(' + %char(after.number) + ')');
  endif;
  QCMD_exc('DLTOVR FILE(QPDSPJOB) LVL(*JOB)');

  return ok;

end-proc;
