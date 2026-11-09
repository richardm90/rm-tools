**free

//==============================================================================
// RMMSG      - Message Helper Module
//
// 19/11/2023 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Message Helper Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Definition copybooks
///

/include 'include/RMMSG_D.rpgleinc'
/define IBM_API_DEFINITIONS
/include 'include/RMTOOLS_D.rpgleinc'

///
// Internal template definitions
///

// IBM API Call Stack Entry e.g. QMHRCVPM API
dcl-s CALL_STACK_ENTRY_t char(65535) template;

///
// Receive program message (QMHRCVPM API) definitions
///

// QMHRCVPM API RCVM0300 format message types
dcl-c RCVM0300_MSG_TYPE_COMPLETION         '01';
dcl-c RCVM0300_MSG_TYPE_DIAGNOSTIC         '02';
dcl-c RCVM0300_MSG_TYPE_INFORMATIONAL      '04';
dcl-c RCVM0300_MSG_TYPE_INQUIRY            '05';
dcl-c RCVM0300_MSG_TYPE_SENDERS_COPY       '06';
dcl-c RCVM0300_MSG_TYPE_REQUEST            '08';
dcl-c RCVM0300_MSG_TYPE_REQUEST_PROMPT     '10';
dcl-c RCVM0300_MSG_TYPE_NOTIFY             '14';
dcl-c RCVM0300_MSG_TYPE_ESCAPE             '15';
dcl-c RCVM0300_MSG_TYPE_NOTIFY_NOT_HANDLED '16';
dcl-c RCVM0300_MSG_TYPE_ESCAPE_NOT_HANDLED '17';
dcl-c RCVM0300_MSG_TYPE_REPLY_NOT_CHECKED  '21';
dcl-c RCVM0300_MSG_TYPE_REPLY_CHECKED      '22';
dcl-c RCVM0300_MSG_TYPE_REPLY_MSG_DEF_USED '23';
dcl-c RCVM0300_MSG_TYPE_REPLY_SYS_DEF_USED '23';
dcl-c RCVM0300_MSG_TYPE_REPLY_FROM_RPL_LST '25';
dcl-c RCVM0300_MSG_TYPE_REPLY_FROM_EXT_PGM '26';

// QMHRCVPM API RCVM0300 field templates
// - message type
dcl-s RCVM0300_MSG_TYPE_t char(2) template;
// - alert option
dcl-s RCVM0300_ALERT_OPTION_t char(9) template;
// - replacement data or impromptu message text
dcl-s RCVM0300_MSG_DATA_t char(MSG_MSG_DATA_SIZE) template;
// - date sent
dcl-s RCVM0300_DATE_SENT_t char(7) template;
// - time sent
dcl-s RCVM0300_TIME_SENT_t char(6) template;
// - sending/receiving type
dcl-s RCVM0300_SND_RCV_TYPE_t char(1) template;
// - sending program name
dcl-s RCVM0300_SND_PGM_NAME_t char(12) template;
// - procedure name
dcl-s RCVM0300_PROC_NAME_t char(256) template;
// - sending/receiving program statement or instruction number
dcl-s RCVM0300_STATEMENT_NUM_t char(30) template;
// - micro seconds
dcl-s RCVM0300_MICRO_SECONDS_t char(6) template;

// QMHRCVPM API RCVM0300 format
dcl-ds RCVM0300_t qualified template;
  bytes_returned       like(INTEGER_t);
  bytes_avail          like(INTEGER_t);
  msg_severity         like(INTEGER_t);
  msgid                like(MSG_MSGID_t);
  msg_type             like(RCVM0300_MSG_TYPE_t);
  msg_key              like(MSG_MSG_KEY_t);
  msg_file             like(OBJ_NAME_t);
  msg_file_lib_spec    like(OBJ_NAME_t);
  msg_file_lib_used    like(OBJ_NAME_t);
  alert_option         like(RCVM0300_ALERT_OPTION_t);
  ccsid_cnv_ind_text   like(INTEGER_t);
  ccsid_cnv_ind_data   like(INTEGER_t);
  ccsid_msg            like(INTEGER_t);
  ccsid_replace        like(INTEGER_t);
  len_replace1         like(INTEGER_t);
  len_replace2         like(INTEGER_t);
  len_msg_return       like(INTEGER_t);
  len_msg_avail        like(INTEGER_t);
  len_help_return      like(INTEGER_t);
  len_help_avail       like(INTEGER_t);
  len_send_inf_return  like(INTEGER_t);
  len_send_inf_avail   like(INTEGER_t);
  msg_data             like(RCVM0300_MSG_DATA_t);
end-ds;

// QMHRCVPM API RCVM0300 sender information format
dcl-ds RCVM0300_info_t qualified template;
  sending_job_name      like(JOB_NAME_t);
  sending_job_user      like(USER_t);
  sending_job_number    like(JOB_NUMBER_CHAR_t);
  date_sent             like(RCVM0300_DATE_SENT_t);
  time_sent             like(RCVM0300_TIME_SENT_t);
  sending_type          like(RCVM0300_SND_RCV_TYPE_t);
  receiving_type        like(RCVM0300_SND_RCV_TYPE_t);
  sending_pgm           like(RCVM0300_SND_PGM_NAME_t);
  sending_module        like(OBJ_NAME_t);
  sending_procedure     like(RCVM0300_PROC_NAME_t);
  reserved1             char(1);
  num_statements_send   like(INTEGER_t);
  statement_nums_send   like(RCVM0300_STATEMENT_NUM_t);
  receiving_pgm         like(OBJ_NAME_t);
  receiving_module      like(OBJ_NAME_t);
  receiving_procedure   like(RCVM0300_PROC_NAME_t);
  reserved2             char(10);
  num_statements_recv   like(INTEGER_t);
  receiving_statement   like(RCVM0300_STATEMENT_NUM_t);
  reserved3             char(2);
  long_send_pgm_offset  like(INTEGER_t);
  long_send_pgm_len     like(INTEGER_t);
  long_send_proc_offset like(INTEGER_t);
  long_send_proc_len    like(INTEGER_t);
  long_recv_proc_offset like(INTEGER_t);
  long_recv_proc_len    like(INTEGER_t);
  micro_seconds         like(RCVM0300_MICRO_SECONDS_t);
  sending_user          like(USER_t);
  long_names            char(4000);
end-ds;

// Receive program message (QMHRCVPM API)
dcl-pr QMHRCVPM extpgm('QMHRCVPM');
  msg_data            likeds(RCVM0300_t);
  msg_data_len        like(INTEGER_t)  const;
  format_name         like(IBM_API_FORMAT_t) const;
  call_stack_entry    like(CALL_STACK_ENTRY_t) const options(*varsize);
  call_stack_counter  like(INTEGER_t) const;
  msg_type            like(MSG_MSG_TYPE_t) const;
  msg_key             like(MSG_MSG_KEY_t) const;
  wait_time           like(INTEGER_t) const;
  msg_action          like(MSG_ACTION_t) const;
  error_code          likeds(ERRC0100_t);
end-pr;

///
// Send program message (QMHSNDPM API) definitions
///

// QMHSNDPM API field templates
// - replacement data or impromptu message text
dcl-s QMHSNDPM_MSG_DATA_t char(MSG_MSG_DATA_SIZE) template;

// Send program message (QMHSNDPM API)
dcl-pr QMHSNDPM extpgm('QMHSNDPM');
  msgid               like(MSG_MSGID_t) const;
  msg_file            like(QUAL_OBJ_NAME_t) const;
  msg_data            like(QMHSNDPM_MSG_DATA_t) const;
  msg_data_len        like(INTEGER_t) const;
  msg_type            like(MSG_MSG_TYPE_t) const;
  call_stack_entry    like(CALL_STACK_ENTRY_t) const options(*varsize);
  call_stack_counter  like(INTEGER_t) const;
  msg_key             like(MSG_MSG_KEY_t);
  error_code          likeds(ERRC0100_t);
end-pr;

///
// hex_to_str definitions
///

dcl-c MSG_HEX_MAX_SIZE                const(16);
dcl-s MSG_HEX_STR                     varchar(MSG_HEX_MAX_SIZE);

///
// rcv_jlmsg definitions
///

dcl-s MSG_msgkey_g like(MSG_MSG_KEY_t) inz(x'00000000');

///
// Remove program message (QMHRMVPM API) definitions
///

// QMHRMVPM API field templates
// - replacement data or impromptu message text
dcl-s QMHRMVPM_MSGS_TO_REMOVE_t char(10) template;

// Remove program message (QMHRMVPM API)
dcl-pr QMHRMVPM extpgm('QMHRMVPM');
  call_stack_entry    like(CALL_STACK_ENTRY_t) const options(*varsize);
  call_stack_counter  like(INTEGER_t) const;
  msg_key             like(MSG_MSG_KEY_t) const;
  msgs_to_remove      like(QMHRMVPM_MSGS_TO_REMOVE_t) const;
  error_code          likeds(ERRC0100_t);
end-pr;

///
// Catch a program message.
//
// A helper method over the QMHRCVPM API.
//
// @param Returned caught message structure.
// @param Optional message action, defaults to *REMOVE.
// @return Boolean indicating a message was caught.
///

dcl-proc catch export;
  dcl-pi *n like(BOOLEAN_t);
    msg likeds(MSG_MESSAGE_t);
    msg_action_in like(MSG_ACTION_t) const options(*nopass);
  end-pi;

  dcl-s caught like(BOOLEAN_t);
  dcl-s msg_action like(MSG_ACTION_t) inz(MSG_ACTION_REMOVE);

  if %passed(msg_action_in);
    msg_action = msg_action_in;
  endif;

  // Call stack counter set to 2 as already within one
  // procedure and just about to call another, rcv_msg
  caught = rcv_msg(msg: '*': 2: '*PRV': x'00000000':msg_action);

  return caught;
end-proc;

///
// Populate MSG message from a RCVM0300 received message.
//
// @param RCVM0300 message structure
// @param returned boolean indicating a message was caught
// @return MSG message structure
///

dcl-proc map_message;
  dcl-pi *n likeds(MSG_MESSAGE_t);
    // msg_rcvd likeds(RCVM0300_t) const;
    msg_rcvd_p pointer const;
    caught like(BOOLEAN_t);
  end-pi;

  dcl-ds msg likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-ds msg_rcvd likeds(RCVM0300_t) based(msg_rcvd_p);
  dcl-ds msg_rcvd_info likeds(RCVM0300_info_t) based(msg_rcvd_info_p);
  dcl-s msg_rcvd_info_p pointer;

  if msg_rcvd.bytes_avail > 0;
    caught = true;

    // Set pointer to sender information
    msg_rcvd_info_p  = %addr(msg_rcvd.msg_data)
                     + msg_rcvd.len_replace1
                     + msg_rcvd.len_msg_return
                     + msg_rcvd.len_help_return;

    msg.severity     = msg_rcvd.msg_severity;
    msg.msgid        = msg_rcvd.msgid;
    msg.msg_key      = msg_rcvd.msg_key;
    msg.msg_type     = map_msg_type(msg_rcvd.msg_type);
    msg.rcv_msg_type = msg_rcvd.msg_type;
    msg.msg_file     = msg_rcvd.msg_file;
    msg.msg_file_lib = msg_rcvd.msg_file_lib_used;
    msg.text         = get_msg_text(msg_rcvd);
    msg.help_text    = get_msg_help_text(msg_rcvd);
    msg.program      = msg_rcvd_info.receiving_pgm;
    msg.module       = msg_rcvd_info.receiving_module;
    msg.procedure    = %trimr(msg_rcvd_info.receiving_procedure);
    msg.statement    = %trimr(msg_rcvd_info.receiving_statement);
  else;
    caught = false;
  endif;

  return msg;
end-proc;

///
// Returns the message text from a RCVM0300 received message.
//
// @param RCVM0300 message structure
// @return message text
///

dcl-proc get_msg_text;
  dcl-pi *n like(MSG_TEXT_t);
    msg_rcvd likeds(RCVM0300_t) const;
  end-pi;

  dcl-s msg_text like(MSG_TEXT_t);

  // Impromptu message
  if msg_rcvd.msgid = '';
    msg_text = %subst( msg_rcvd.msg_data:
                       1:
                       msg_rcvd.len_replace1 );

  // Not an impromptu message
  else;
    msg_text = %subst( msg_rcvd.msg_data:
                       msg_rcvd.len_replace1 + 1:
                       msg_rcvd.len_msg_return );
  endif;

  return msg_text;
end-proc;

///
// Returns the message help text from a RCVM0300 received message.
//
// @param RCVM0300 message structure
// @return message help text
///

dcl-proc get_msg_help_text;
  dcl-pi *n like(MSG_HELP_TEXT_t);
    msg_rcvd likeds(RCVM0300_t) const;
  end-pi;

  dcl-s msg_help_text like(MSG_HELP_TEXT_t);

  // Impromptu message
  if msg_rcvd.msgid = '';
    msg_help_text = '';

  // Not an impromptu message
  else;
    msg_help_text = %subst( msg_rcvd.msg_data:
                            msg_rcvd.len_replace1 + msg_rcvd.len_msg_return + 1:
                            msg_rcvd.len_help_return );
  endif;

  return msg_help_text;
end-proc;

///
// Throw a new message.
//
// A helper method over the QMHSNDPM API.
//
// @param message text
// @param optional, call stack entry e.g. '*CTLBDY', defaults to '*'
///

dcl-proc throw export;
  dcl-pi *n;
    text like(MSG_TEXT_t) const;
    call_stack_entry like(MSG_CALL_STACK_ENTRY_t) const options(*nopass);
  end-pi;

  dcl-ds msg likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-ds error_code likeds(ERRC0100_t) inz(*likeds);
  dcl-s call_stack_entry_l like(MSG_CALL_STACK_ENTRY_t);
  dcl-s msg_key_l like(MSG_MSG_KEY_t);
  dcl-s qual_msg_file_l like(QUAL_OBJ_NAME_t);

  reset msg;
  msg.msgid        = 'CPF9897';
  msg.msg_file     = 'QCPFMSG';
  msg.msg_file_lib = '*LIBL';
  msg.text         = text;
  msg.msg_type     = MSG_TYPE_ESCAPE;

  // Handle input parameters
  if %parms() >= %parmnum(call_stack_entry);
    call_stack_entry_l = call_stack_entry;
  else;
    call_stack_entry_l = MSG_CSE_PGMBDY;
  endif;

  qual_msg_file_l = msg.msg_file + msg.msg_file_lib;

  QMHSNDPM(
    msg.msgid:
    qual_msg_file_l:
    msg.text:
    %len(%trimr(msg.text)):
    msg.msg_type:
    call_stack_entry_l:
    1:
    msg_key_l:
    error_code
  );

  rethrow(msg: call_stack_entry_l);

  return;
end-proc;

///
// Throw a previously received message.
//
// A helper method over the QMHSNDPM API.
//
// @param received message structure
// @param optional, call stack entry e.g. '*CTLBDY', defaults to '*'
// @param optional, returned message key
///

dcl-proc rethrow export;
  dcl-pi *n;
    msg likeds(MSG_MESSAGE_t) const options(*exact);
    call_stack_entry like(MSG_CALL_STACK_ENTRY_t) const options(*nopass);
    msg_key like(MSG_MSG_KEY_t) options(*nopass);
  end-pi;

  dcl-ds error_code likeds(ERRC0100_t) inz(*likeds);
  dcl-s call_stack_entry_l like(MSG_CALL_STACK_ENTRY_t);
  dcl-s msg_key_l like(MSG_MSG_KEY_t);
  dcl-s qual_msg_file_l like(QUAL_OBJ_NAME_t);

  // Handle input parameters
  if %parms() >= %parmnum(call_stack_entry);
    call_stack_entry_l = call_stack_entry;
  else;
    call_stack_entry_l = MSG_CSE_CURRENT;
  endif;

  qual_msg_file_l = msg.msg_file + msg.msg_file_lib;

  QMHSNDPM(
    msg.msgid:
    qual_msg_file_l:
    msg.text:
    %len(%trimr(msg.text)):
    msg.msg_type:
    call_stack_entry_l:
    1:
    msg_key_l:
    error_code
  );

  // Handle output parameters
  if %parms() >= %parmnum(msg_key) and %addr(msg_key) <> *null;
    msg_key = msg_key_l;
  endif;

  return;
end-proc;

///
// Maps a RCVM0300 message type to a MSG message type.
//
// The MSG message type is compatible with the QMHSNDPM API
// and the 'throw' procedure.
//
// @param RCVM0300 message type
// @return MSG message type
///

dcl-proc map_msg_type;
  dcl-pi *n like(MSG_MSG_TYPE_t);
    msg_type like(RCVM0300_MSG_TYPE_t) const;
  end-pi;

  dcl-s out_msg_type like(MSG_MSG_TYPE_t);

  select;

  when msg_type = RCVM0300_MSG_TYPE_COMPLETION;
    out_msg_type = MSG_TYPE_COMP;

  when msg_type = RCVM0300_MSG_TYPE_DIAGNOSTIC;
    out_msg_type = MSG_TYPE_DIAG;

  when msg_type = RCVM0300_MSG_TYPE_ESCAPE
    or msg_type = RCVM0300_MSG_TYPE_ESCAPE_NOT_HANDLED;
    out_msg_type = MSG_TYPE_ESCAPE;

  when msg_type = RCVM0300_MSG_TYPE_INFORMATIONAL;
    out_msg_type = MSG_TYPE_INFO;

  when msg_type = RCVM0300_MSG_TYPE_INQUIRY;
    out_msg_type = MSG_TYPE_INQ;

  when msg_type = RCVM0300_MSG_TYPE_NOTIFY
    or msg_type = RCVM0300_MSG_TYPE_NOTIFY_NOT_HANDLED;
    out_msg_type = MSG_TYPE_NOTIFY;

  when msg_type = RCVM0300_MSG_TYPE_REQUEST
    or msg_type = RCVM0300_MSG_TYPE_REQUEST_PROMPT;
    out_msg_type = MSG_TYPE_RQS;

  endsl;

  return out_msg_type;
end-proc;

///
// Send a program message.
//
// A helper method over the QMHSNDPM API.
//
// @param optional, message data/text
// @param optional, call stack entry e.g. '*CTLBDY', defaults to '*'
// @param optional, message type e.g. '*ESCAPE', defaults to '*INFO'
// @param optional, message id e.g. 'CPF9897', defaults to blank
// @param optional, message file e.g. 'QCPFMSG', defaults to blank
// @param optional, message file library e.g. 'QSYS', defaults to blank
// @param optional, returned message key
///

dcl-proc sndmsg export;
  dcl-pi *n;
    msg_data         like(MSG_MSG_DATA_t)         const options(*omit: *nopass);
    call_stack_entry like(MSG_CALL_STACK_ENTRY_t) const options(*omit: *nopass);
    msg_type         like(MSG_MSG_TYPE_t)         const options(*omit: *nopass);
    msgid            like(MSG_MSGID_t)            const options(*omit: *nopass);
    msg_file         like(OBJ_NAME_t)             const options(*omit: *nopass);
    msg_file_lib     like(OBJ_NAME_t)             const options(*omit: *nopass);
    msg_key          like(MSG_MSG_KEY_t)          options(*nopass);
  end-pi;

  dcl-ds error_code        likeds(ERRC0100_t) inz(*likeds);
  dcl-s msg_data_l         like(QMHSNDPM_MSG_DATA_t);
  dcl-s call_stack_entry_l like(MSG_CALL_STACK_ENTRY_t);
  dcl-s msg_type_l         like(MSG_MSG_TYPE_t);
  dcl-s msgid_l            like(MSG_MSGID_t);
  dcl-s msg_file_l         like(OBJ_NAME_t);
  dcl-s msg_file_lib_l     like(OBJ_NAME_t);
  dcl-s qual_msg_file_l    like(QUAL_OBJ_NAME_t);
  dcl-s msg_key_l          like(MSG_MSG_KEY_t);

  // Handle input parameters

  // - message data
  if %parms() >= %parmnum(msg_data) and %addr(msg_data) <> *null;
    msg_data_l = msg_data;
  endif;

  // - call stack entry
  if %parms() >= %parmnum(call_stack_entry) and %addr(call_stack_entry) <> *null;
    call_stack_entry_l = call_stack_entry;
  else;
    call_stack_entry_l = MSG_CSE_CURRENT;
  endif;

  // - message type
  if %parms() >= %parmnum(msg_type) and %addr(msg_type) <> *null;
    msg_type_l = msg_type;
  else;
    msg_type_l = MSG_TYPE_INFO;
  endif;

  // - message id
  if %parms() >= %parmnum(msgid) and %addr(msgid) <> *null;
    msgid_l = msgid;
  elseif msg_type_l = MSG_TYPE_ESCAPE
     or msg_type_l = MSG_TYPE_NOTIFY
     or msg_type_l = MSG_TYPE_STATUS;
    msgid_l = 'CPF9897';
    msg_file_l = 'QCPFMSG';
    msg_file_lib_l = '*LIBL';
  endif;

  // - message file
  if %parms() >= %parmnum(msg_file) and %addr(msg_file) <> *null;
    msg_file_l = msg_file;
    msg_file_lib_l = '*LIBL';
    qual_msg_file_l = msg_file_l + msg_file_lib_l;
  endif;

  // - message file library
  if %parms() >= %parmnum(msg_file_lib) and %addr(msg_file_lib) <> *null;
    msg_file_lib_l = msg_file_lib;
    qual_msg_file_l = msg_file_l + msg_file_lib_l;
  endif;

  QMHSNDPM( msgid_l
          : qual_msg_file_l
          : msg_data_l
          : %len(%trimr(msg_data_l))
          : msg_type_l
          : call_stack_entry_l
          : 1
          : msg_key_l
          : error_code );

  // Handle output parameters
  if %parms() >= %parmnum(msg_key) and %addr(msg_key) <> *null;
    msg_key = msg_key_l;
  endif;

 return;
end-proc;

///
// Convert a hex value to a string of hex characters.
//
// @param hex value
// @param format hex string for output, defaults to true
// @return hex value as a character string
///

dcl-proc hex_to_str;
  dcl-pi *n like(MSG_HEX_STR);
    hex_value varchar(8) const ccsid(*hex);
    format like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-ds hex_ds;
    hex_subf            char(8) inz(x'0000000000000000');
    number              like(UNSIGNED_BIGINT_t) overlay(hex_subf);
  end-ds;

  dcl-s size            like(UNSIGNED_SMALLINT_t);
  dcl-s hex_str         like(MSG_HEX_STR);
  dcl-s digits          char(16) inz('0123456789ABCDEF');
  dcl-s rem             like(UNSIGNED_SMALLINT_t);
  dcl-c RMMSG_BASE      const(16);
  dcl-s hex_str_len     like(UNSIGNED_SMALLINT_t);
  dcl-s format_l        like(BOOLEAN_t) inz(true);

  // Handle input parameters
  if %parms() >= %parmnum(format);
    format_l = format;
  endif;

  // The length of the hex string will be twice the length of
  // the passed hex value i.e. 2 charcters per byte
  hex_str_len = %len(hex_value) * 2;

  // hex_subf = x'0000000000000000';
  evalr hex_subf = hex_value;
  if number = *zero;
    hex_str = '*NULL';
  else;
    dow size < MSG_HEX_MAX_SIZE and size < hex_str_len;
      rem = %rem(number: RMMSG_BASE);
      hex_str = %subst(digits: rem+1: 1) + hex_str;
      number = %div(number: RMMSG_BASE);
      size += 1;
    enddo;

    // Format hex string for display?
    if format_l;
      hex_str = 'x''' + hex_str + '''';
    endif;
  endif;

  return hex_str;
end-proc;

///
// Dump the received message fields to the job log.
//
// Useful for debugging.
// Each field in the received message is output as a separate
// information message in the job log.
//
// @param received message structure
///

dcl-proc MSG_dump export;
  dcl-pi *n;
    msg likeds(MSG_MESSAGE_t) const;
  end-pi;

  sndmsg('severity:     ' + %char(msg.severity));
  sndmsg('msgid:        ' + msg.msgid);
  sndmsg('msg_key:      ' + hex_to_str(msg.msg_key));
  sndmsg('msg_type:     ' + msg.msg_type);
  sndmsg('rcv_msg_type: ' + msg.rcv_msg_type);
  sndmsg('msg_file:     ' + msg.msg_file);
  sndmsg('msg_file_lib: ' + msg.msg_file_lib);
  sndmsg('text:         ' + msg.text);
  sndmsg('help_text:    ' + msg.help_text);
  sndmsg('program:      ' + msg.program);
  sndmsg('module:       ' + msg.module);
  sndmsg('procedure:    ' + msg.procedure);
  sndmsg('statement:    ' + msg.statement);

  return;
end-proc;

///
// Return the last joblog message key.
//
// This is useful for tracking messages sent to the joblog within a given
// process - i.e. grab the last message key at the start then read all
// jl messages after the grabbed message key.
//
// @return The last joblog message key.
///

dcl-proc rcv_msg;
  dcl-pi *n               like(BOOLEAN_t);
    msg                   likeds(MSG_MESSAGE_t);
    call_stack_entry_in   like(CALL_STACK_ENTRY_t)  const options(*omit);
    call_stack_counter_in like(INTEGER_t)           const options(*omit);
    msg_type_in           like(MSG_MSG_TYPE_t)      const options(*omit);
    msg_key_in            like(MSG_MSG_KEY_t)       const options(*omit);
    msg_action_in         like(MSG_ACTION_t)        const options(*omit);
  end-pi;

  dcl-ds error_code likeds(ERRC0100_t) inz(*likeds);
  dcl-ds msg_rcvd likeds(RCVM0300_t) inz;
  dcl-s caught like(BOOLEAN_t);

  // dcl-s call_stack_entry    like(CALL_STACK_ENTRY_t)  inz('*');
  dcl-s call_stack_entry    like(MSG_CALL_STACK_ENTRY_t)  inz('*');
  dcl-s call_stack_counter  like(INTEGER_t)           inz(1);
  dcl-s msg_type            like(MSG_MSG_TYPE_t)      inz('*NXTJLMSG');
  dcl-s msg_key             like(MSG_MSG_KEY_t)       inz(x'00000000');
  dcl-s msg_action          like(MSG_ACTION_t)        inz(MSG_ACTION_REMOVE);

  if %passed(call_stack_entry_in);
    call_stack_entry = call_stack_entry_in;
  endif;

  if %passed(call_stack_counter_in);
    call_stack_counter = call_stack_counter_in;
  endif;

  if %passed(msg_type_in);
    msg_type = msg_type_in;
  endif;

  if %passed(msg_key_in);
    msg_key = msg_key_in;
  endif;

  if %passed(msg_action_in);
    msg_action = msg_action_in;
  endif;

  QMHRCVPM(
    msg_rcvd:
    %size(msg_rcvd):
    'RCVM0300':
    call_stack_entry:
    call_stack_counter:
    msg_type:
    msg_key:
    0:
    msg_action:
    error_code
  );

  msg = map_message(%addr(msg_rcvd): caught);

  return caught;
end-proc;

///
// Receive job log message.
//
// @param the returned message details
// @param optional, retrieve the next message, defaults to previous
// @param optional, retrieve the first message, defaults to the next
// @param optional, message action, defaults to *SAME
///

dcl-proc rcv_jlmsg export;
  dcl-pi *n       like(BOOLEAN_t);
    msg           likeds(MSG_MESSAGE_t);
    dir_next_in   like(BOOLEAN_t)  const options(*omit: *nopass);
    first_msg_in  like(BOOLEAN_t) const options(*nopass);
    msg_action_in like(MSG_ACTION_t) const options(*nopass);
  end-pi;

  dcl-ds error_code likeds(ERRC0100_t) inz(*likeds);
  dcl-s dir_next like(BOOLEAN_t) inz(false);
  dcl-s first_msg like(BOOLEAN_t) inz(false);
  dcl-s msg_action like(MSG_ACTION_t) inz('*SAME');
  dcl-s msg_type char(10) inz('*PRVJLMSG');
  dcl-ds message likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-ds msg_rcvd likeds(RCVM0300_t) inz;
  dcl-s caught like(BOOLEAN_t);

  // Deal with optional parameters
  if %parms() >= %parmnum(dir_next_in) and %addr(dir_next_in) <> *null;
    dir_next = dir_next_in;
  endif;
  if %parms() >= %parmnum(first_msg_in);
    first_msg = first_msg_in;
  endif;
  if %parms() >= %parmnum(msg_action_in);
    msg_action = msg_action_in;
  endif;

  // Retrieve next message, retrieval directions
  // - defaults to previous message
  if dir_next;
    msg_type = '*NXTJLMSG';
  endif;

  // Retrieve the first message
  // - if not the previous message will be retrieved
  if first_msg;
    MSG_msgkey_g = x'00000000';
  endif;

  caught = rcv_msg(msg: '*': 0: msg_type: MSG_msgkey_g: msg_action);

  if caught;
    MSG_msgkey_g = msg.msg_key;
  endif;

  return caught;
end-proc;

dcl-proc rcv_prvjlmsg export;
  dcl-pi *n like(BOOLEAN_t);
    msg likeds(MSG_MESSAGE_t);
  end-pi;

  dcl-s caught like(BOOLEAN_t);

  caught = rcv_msg(msg: '*': 0: '*PRVJLMSG': msg.msg_key: '*SAME');

  return caught;
end-proc;

dcl-proc rcv_nxtjlmsg export;
  dcl-pi *n like(BOOLEAN_t);
    msg likeds(MSG_MESSAGE_t);
  end-pi;

  dcl-s caught like(BOOLEAN_t);

  caught = rcv_msg(msg: '*': 0: '*NXTJLMSG': msg.msg_key: '*SAME');

  return caught;
end-proc;

///
// Remove a program message.
//
// A helper method over the QMHRMVPM API.
//
// @param the message to remove
// @return boolean value indicating the message was removed
///

dcl-proc rmvmsg export;
  dcl-pi *n like(BOOLEAN_t);
    msg likeds(MSG_MESSAGE_t) const;
  end-pi;

  dcl-ds error_code likeds(ERRC0100_t) inz(*likeds);
  dcl-s removed like(BOOLEAN_t);

  QMHRMVPM(
    '*':
    0:
    msg.msg_key:
    '*BYKEY':
    error_code
  );

  if error_code.available = 0;
    removed = true;
  endif;

  return removed;
end-proc;

dcl-proc get_last_jl_msg_key export;
  dcl-pi *n like(BOOLEAN_t);
    msg_key like(MSG_MSG_KEY_t);
  end-pi;

  dcl-ds msg likeds(MSG_MESSAGE_t) inz(*likeds);
  dcl-s caught like(BOOLEAN_t);

  msg_key = x'00000000';

  caught = rcv_msg(msg: *omit: 0: '*PRVJLMSG': msg_key: '*SAME');

  if caught;
    msg_key = msg.msg_key;
  endif;

  return caught;
end-proc;
