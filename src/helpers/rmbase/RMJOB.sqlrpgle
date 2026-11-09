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

// Matches rm-sc's own SCQRY.SQLRPGLE SET OPTION exactly - this module
// becomes embedded-SQL (.sqlrpgle, converted from .rpgle) only because
// JOB_get_envvars' ported helpers need QSYS2.OUTPUT_QUEUE_ENTRIES_BASIC
// to locate the DSPJOB spooled file; every other proc in this module is
// unchanged.
exec sql SET OPTION COMMIT = *NONE, CLOSQLCSR = *ENDMOD, DATFMT = *ISO;

// Bare libc extproc, used only by JOB_get_envvars below. Declared here,
// in this module's top-level declarations area, not between procedures -
// MEASURED: a dcl-pr placed between two dcl-proc/end-proc blocks is
// rejected (RNF0256 "Specification found between procedures", RNF7030
// "name not defined" at every call site). Ported from rm-sc's
// SCQRY.SQLRPGLE, which declares it at the same top-level position.
dcl-pr c_fflush int(10) extproc('fflush');
  stream pointer value;
end-pr;

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
// highest_qpdspjob_number
//
// The highest existing QPDSPJOB FILE_NUMBER right now, or 0 if there is
// none - a "before" snapshot (see find_new_qpdspjob below). Ported from
// rm-sc's SCQRY.SQLRPGLE unchanged.
//==============================================================================

dcl-proc highest_qpdspjob_number;
  dcl-pi *n like(INTEGER_t);
  end-pi;

  dcl-s highest int(10);

  exec sql
    SELECT COALESCE(MAX(FILE_NUMBER), 0) INTO :highest
      FROM QSYS2.OUTPUT_QUEUE_ENTRIES_BASIC
     WHERE SPOOLED_FILE_NAME = 'QPDSPJOB';

  if sqlcode <> 0;
    return 0;
  endif;

  return highest;

end-proc;

//==============================================================================
// find_new_qpdspjob
//
// MEASURED (rm-sc, 5 October 2026), ported here unchanged: the spooled
// file DSPJOB produces is NOT reliably owned by the calling job - every
// OUTPUT(*PRINT) QPDSPJOB entry observed there, across many separate
// jobs, carried the SAME JOB_NAME (a long-lived job that was neither the
// interactive session nor the test runner that actually issued the
// DSPJOB call). So this does not search by job identity at all:
// before_number is a snapshot taken immediately before the DSPJOB call,
// and this finds the one new QPDSPJOB entry with a FILE_NUMBER greater
// than that snapshot - identity-agnostic. Returns the entry's OWN
// job_name (read back from the row, never assumed) alongside its
// file_number, for CPYSPLF/DLTSPLF to target.
//==============================================================================

dcl-proc find_new_qpdspjob;
  dcl-pi *n like(BOOLEAN_t);
    before_number like(INTEGER_t) const;
    job_name       like(JOB_FULL_NAME_t);
    file_number    like(INTEGER_t);
  end-pi;

  dcl-s before_l int(10);
  dcl-s name_l   varchar(28);
  dcl-s number   int(10);

  file_number = 0;
  before_l = before_number;

  exec sql
    DECLARE c_dspjob_splf CURSOR FOR
    SELECT JOB_NAME, FILE_NUMBER
      FROM QSYS2.OUTPUT_QUEUE_ENTRIES_BASIC
     WHERE SPOOLED_FILE_NAME = 'QPDSPJOB' AND FILE_NUMBER > :before_l
     ORDER BY FILE_NUMBER ASC
     FETCH FIRST 1 ROW ONLY;

  exec sql OPEN c_dspjob_splf;
  if sqlcode <> 0;
    return false;
  endif;

  exec sql FETCH c_dspjob_splf INTO :name_l, :number;
  if sqlcode <> 0;
    exec sql CLOSE c_dspjob_splf;
    return false;
  endif;

  exec sql CLOSE c_dspjob_splf;
  job_name = name_l;
  file_number = number;
  return true;

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
// spanning both. Ported from rm-sc's SCQRY.SQLRPGLE unchanged.
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
// entry. Ported from rm-sc's SCQRY.SQLRPGLE unchanged.
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
// converted report's own line ending is NOT consistently CRLF (MEASURED,
// rm-sc: CRLF via a shell `cat -A`, but CR with no LF at all from the
// exact same CPYSPLF+iconv pipeline called from a compiled test). Ported
// from rm-sc's SCQRY.SQLRPGLE unchanged.
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
// Ported from rm-sc's SCQRY.SQLRPGLE unchanged.
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
//   OUTPUT(*PRINT) - ported from rm-sc's SCQRY_job_envvars (QRPGLESRC/SCQRY.SQLRPGLE)
//   unchanged in mechanism. There is no QSYS2 service exposing another job's
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
  dcl-s before_number like(INTEGER_t);
  dcl-s file_number like(INTEGER_t);
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

  // MEASURED (rm-sc, 6 October 2026), ported here unchanged: without
  // this, a caller whose own first write to either stream happens AFTER
  // this procedure's internal DSPJOB round trip gets NO output at all
  // afterwards, on EITHER stream, under some invocation paths. An early
  // flush (no visible byte written to anything) fixes it - the minimal,
  // non-polluting fix, not fully understood beyond that.
  c_fflush(*null);

  before_number = highest_qpdspjob_number();

  // Forced HELD before anything else runs, so the spooled file this is
  // about to generate can never print to a real printer on a profile
  // with one configured as default (MEASURED, rm-sc: without this
  // override, DSPJOB OPTION(*ENVVAR) OUTPUT(*PRINT)'s spooled file comes
  // up READY, not HELD). OVRSCOPE(*JOB): a plain OVRPRTF does not
  // survive past the call level that issued it.
  if not QCMD_exc('OVRPRTF FILE(QPDSPJOB) HOLD(*YES) OVRSCOPE(*JOB)': qerr);
    err = 'Could not force the DSPJOB spooled file to HELD status';
    return false;
  endif;

  if not QCMD_exc('DSPJOB JOB(' + %trim(job_name) +
                  ') OPTION(*ENVVAR) OUTPUT(*PRINT)': qerr);
    // Best-effort - a DLTOVR failure here is not treated as a failure in
    // its own right.
    QCMD_exc('DLTOVR FILE(QPDSPJOB) LVL(*)');
    err = 'Job ' + %trim(job_name) + ' could not be read';
    if qerr.count > 0;
      err += ': ' + %trim(qerr.msgs(1).text);
    endif;
    return false;
  endif;

  if not find_new_qpdspjob(before_number: owner_job: file_number);
    QCMD_exc('DLTOVR FILE(QPDSPJOB) LVL(*)');
    err = 'Could not locate the generated DSPJOB spooled file';
    return false;
  endif;

  raw_path  = IFS_temp_filename();
  utf8_path = IFS_temp_filename();

  // CPYSPLF's TOSTMF form has no native CCSID-conversion parameter - a
  // raw copy followed by iconv, using THIS job's own real CCSID rather
  // than a hardcoded one, ported unchanged. JOB(owner_job): whichever
  // job the entry actually belongs to - read back from the row itself,
  // never assumed (see find_new_qpdspjob).
  ok = QCMD_exc('CPYSPLF FILE(QPDSPJOB) TOFILE(*TOSTMF) JOB(' +
                %trim(owner_job) + ') SPLNBR(' + %char(file_number) +
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

  // Unconditional, including on every failure path above: the spooled
  // file is deleted and the override removal is attempted (best-effort).
  IFS_remove_file(raw_path);
  IFS_remove_file(utf8_path);
  QCMD_exc('DLTSPLF FILE(QPDSPJOB) JOB(' + %trim(owner_job) +
           ') SPLNBR(' + %char(file_number) + ')');
  QCMD_exc('DLTOVR FILE(QPDSPJOB) LVL(*)');

  return ok;

end-proc;
