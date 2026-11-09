**free

//==============================================================================
// RMPASE     - PASE Helper Module
//
// 18/11/2023 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: PASE Helper Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Copybook definitions
///

/include 'include/RMENVVAR_D.rpgleinc'
/include 'include/RMPASE_D.rpgleinc'
/include 'include/RMMSG_D.rpgleinc'
/include 'include/RMSTRING_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'
/include 'tpp/unixcmd/QRNOPENACC.rpgleinc'

///
// Standard output, string builder instance.
///

dcl-s stdout_sb like(STRING_sb_t);
dcl-s stdout_sb_active like(BOOLEAN_t);

///
// Run a PASE command.
//
// Expected escape messages are captured.
//
// @param optional, standard input, if provided will be piped to command
// @param PASE command to execute
// @param optional, returned standard output as a PASE_IO_t string
// @param optional, boolean indicating debugging is required, this will
//          send standard output to a spooled file
// @param optional, boolean indicating the provided standard input should be
//          converted from the job CCSID to 819, defaults to false
// @return result code, 0 = success, note that certain commands may return a
//           non-zero result code even when the command has run successfully
///

dcl-proc PASE_run_cmd export;
  dcl-pi *n   like(INTEGER_t);
    stdin     like(PASE_IO_t)   const  options(*omit);
    cmd_in    like(PASE_CMD_t)  const;
    stdout    like(PASE_IO_t)          options(*omit:*nopass);
    debug     like(BOOLEAN_t)   const  options(*omit:*nopass);
    cnv_stdin like(BOOLEAN_t)   const  options(*nopass);
  end-pi;

  dcl-f UNIX disk(PASE_RCD_SIZE) usage(*input:*output) handler(UNIXCMDOA: cmd) usropn;
  dcl-f QSYSPRT printer(132) oflind(*in49) usage(*output) usropn;

  dcl-pr UNIXCMDOA;
    io   likeds(QRNOPENACCESS_T);
  end-pr;

  dcl-s cmd char(PASE_CMD_SIZE);
  dcl-s rc like(INTEGER_t);
  dcl-ds record len(PASE_RCD_SIZE) end-ds;
  dcl-ds outrec len(132) end-ds;
  dcl-s errmsg varchar(80);
  dcl-s str like(STRING_t) ccsid(*utf8);

  // Initialise output parameters
  rc = 0;
  if %passed(stdout);
    stdout = '';
  endif;

  // Initialise stdout string builder instance
  if stdout_sb_active;
    STRING_sb_delete(stdout_sb);
  endif;
  STRING_sb_new(stdout_sb);
  stdout_sb_active = true;

  // Unset environment variables, required by UNIXCMDOA
  // - if not set UNIXCMDOA sets accordingly
  ENVVAR_dlt('QIBM_USE_DESCRIPTOR_STDIO');
  ENVVAR_dlt('QIBM_PASE_DESCRIPTOR_STDIO');

  // Set command to run
  if %passed(cnv_stdin) and cnv_stdin and %passed(stdin) and %len(stdin) > 0;
    cmd = 'iconv -f 0 -t 819 | ' + cmd_in;
  else;
    cmd = cmd_in;
  endif;

  if %passed(stdin) and %len(stdin) > 0;
    sndmsg('RMPASE stdin: >' + %trimr(stdin) + '<');
  endif;
  sndmsg('RMPASE cmd: >' + %trimr(cmd) + '<');

  // Open UNIX handler
  open UNIX;

  // Send standard input
  if %passed(stdin) and %len(stdin) > 0;
    record = stdin;
    write UNIX record;
  endif;

  // Receive standard output
  read UNIX record;
  dow not %eof(UNIX);
    if %parms() >= %parmnum(debug) and debug;
      if not %open(QSYSPRT);
        open QSYSPRT;
      endif;
      outrec = record;
      write QSYSPRT outrec;
    endif;

    STRING_sb_append(stdout_sb:%trimr(record));

    read UNIX record;
  enddo;

  if %open(QSYSPRT);
    close QSYSPRT;
  endif;

  monitor;
    close UNIX;
    rc = 0;
  on-error;
    rc = error_handling();
  endmon;

  if %passed(stdout);
    STRING_sb_to_string(stdout_sb:str);
    stdout = str;
  endif;

  return rc;
end-proc;

///
// Handle errors when closing the UNIX pipe.
//
// Errors are reported when the handler is closed.
//
// If the UNIX command end status is not 0 then an error will
// be raised, different cmds can return a status other than
// zero to signify different things, not necessarily an error
//
// @return return code, the command end status
///

dcl-proc error_handling;
  dcl-pi *n like(INTEGER_t) end-pi;

  dcl-ds msg1 likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-ds msg2 likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-s rc like(INTEGER_t);
  dcl-s pos_l like(INTEGER_t);

  // Expect message #1 to be RNX1217=Error message appeared during CLOSE
  // Expect message #2 to be CPF9897=Child process ended with status 127
  if rcv_jlmsg(msg1: *omit: true) and msg1.msgid='RNX1217'
    and rcv_jlmsg(msg2) and msg2.msgid='CPF9897';

    // Extract status code from message #2
    monitor;
      pos_l = %scanr(' ': msg2.text);
      rc = %int(%trim(%subst(msg2.text: pos_l)));
    on-error;
      rc = 0;
    endmon;

    // If the messages are as expected then remove them from the job log
    if rc <> 0;
      rmvmsg(msg1);
      rmvmsg(msg2);
    endif;
  endif;

  return rc;
end-proc;

///
// Send standard output, from the last PASE command, to the job log.
//
// Each line of the standard output is sent to the job log as a separate
// information message.
//
// @param Optional PASE command return code, if supplied this will be output
//          as a message in the job log.
///

dcl-proc PASE_log_stdout export;
  dcl-pi *n;
    rc like(INTEGER_t) const options(*nopass);
  end-pi;

  dcl-s index   like(SMALLINT_t);
  dcl-s rownum  like(SMALLINT_t);
  dcl-s row     like(STRING_t) ccsid(*utf8);

  if %parms() >= %parmnum(rc);
    sndmsg('RMPASE return code: ' + %char(rc));
  endif;

  if stdout_sb_active;
    index = 1;
    rownum = 0;
    dow STRING_sb_get(stdout_sb:row:index);
      index += 1;
      rownum += 1;
      sndmsg(%trimr(row));
    enddo;
  endif;

  sndmsg('RMPASE stdout row count: ' + %char(rownum));

  return;
end-proc;

///
// Return the first row of the standard output, from the last PASE command.
//
// @param The returned first row from standard output.
// @return Boolean, set true if the first row was returned.
///

dcl-proc PASE_stdout_get_first_row export;
  dcl-pi *n like(BOOLEAN_t);
    stdout_row like(STRING_t) ccsid(*utf8);
  end-pi;

  dcl-s stdout_index like(UNSIGNED_INTEGER_t);
  dcl-s got_row like(BOOLEAN_t);

  if stdout_sb_active;
    stdout_index = 1;
    if STRING_sb_get(stdout_sb:stdout_row:stdout_index);
      got_row = true;
    endif;
  endif;

  return got_row;
end-proc;

///
// Return the requested row of the standard output, from the last PASE command.
//
// @param The returned row from standard output.
// @param The index value of 1, if a row was found.
// @return Boolean, set true if the first row was returned.
///

dcl-proc PASE_stdout_get_row export;
  dcl-pi *n like(BOOLEAN_t);
    stdout_index like(UNSIGNED_INTEGER_t) const;
    stdout_row like(STRING_t) ccsid(*utf8);
  end-pi;

  dcl-s got_row like(BOOLEAN_t);

  if stdout_sb_active;
    if STRING_sb_get(stdout_sb:stdout_row:stdout_index);
      got_row = true;
    endif;
  endif;

  return got_row;
end-proc;

///
// Return the last line of the standard output, from the last PASE command.
//
// @param The returned last row from standard output.
// @return Boolean, set true if the last row was returned.
///

dcl-proc PASE_stdout_get_last_row export;
  dcl-pi *n like(BOOLEAN_t);
    stdout_row like(STRING_t) ccsid(*utf8);
  end-pi;

  dcl-s stdout_index like(UNSIGNED_INTEGER_t);
  dcl-s got_row like(BOOLEAN_t);

  if stdout_sb_active;
    stdout_index = 1;
    dow STRING_sb_get(stdout_sb:stdout_row:stdout_index);
      stdout_index += 1;
      got_row = true;
    enddo;
  endif;

  return got_row;
end-proc;
