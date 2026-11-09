**free

//==============================================================================
// RMQCMD     - QCMDEXC Helper Module
//
// 05/01/2025 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: QCMDEXC Helper Module');

///
// Copybook definitions
///

/include 'include/RMQCMD_D.rpgleinc'
/include 'include/RMMSG_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

// QCMDEXC API
dcl-pr qcmdexc extpgm('QCMDEXC');
  cmd_str char(1024) options(*varsize) const;
  cmd_len packed(15:5) const;
end-pr;

///
// Execute a CL command via QCMDEXC.
//
// Expected escape messages are captured.
//
// @param The CL command string to execute.
// @param Optional error structure, if the command did not execute successfully
//          then this structure will be populated with the job log messages.
// @return Boolean, set true if the command was successfully executed.
///

dcl-proc QCMD_exc export;
  dcl-pi *n like(BOOLEAN_t);
    cmd     like(QCMD_CMD_t)   const;
    err_out likeds(QCMD_ERR_t) options(*exact:*nopass);
  end-pi;

  dcl-ds err likeds(QCMD_ERR_t) inz(*likeds);
  dcl-ds msg likeds(MSG_MESSAGE_t) inz(*likeds);

  dcl-s last_msg_key like(MSG_MSG_KEY_t);
  dcl-s success like(BOOLEAN_t);

  sndmsg('RMQCMD cmd: >' + cmd + '<');

  get_last_jl_msg_key(last_msg_key);

  monitor;
    qcmdexc(cmd: %len(cmd));
    success = true;
  on-error;
    msg.msg_key = last_msg_key;
    dow rcv_nxtjlmsg(msg);
      err.count += 1;
      if err.count <= %elem(err.msgs);
        err.msgs(err.count) = msg;
      endif;
    enddo;
    success = false;
  endmon;

  if %passed(err_out);
    err_out = err;
  endif;

  return success;
end-proc;
