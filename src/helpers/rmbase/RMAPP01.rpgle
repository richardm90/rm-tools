**free

//==============================================================================
// RMAPP01    - Application Helper - Logger Module
//
// 30/10/2024 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Application Helper - Logger Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Copybook definitions
///

/include 'include/RMAPP_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

///
// Local definitions
///

dcl-ds caller_t qualified inz template;
  program   like(OBJ_NAME_t);
  module    like(OBJ_NAME_t);
  procedure varchar(256);
  statement char(10);
end-ds;

dcl-proc APP_log export;
  dcl-pi *n;
    message_text_in like(APP_MESSAGE_TEXT_t) const;
    message_type_in like(SMALLINT_t) options(*nopass:*omit) const;
    stack_offset_in like(SMALLINT_t) options(*nopass:*omit) const;
    add_pgm_info_in like(BOOLEAN_t) options(*nopass) const;
  end-pi;

  dcl-s message_text like(APP_MESSAGE_TEXT_t);
  dcl-s message_type like(SMALLINT_t) inz(APP_LOG_INFO);
  dcl-s stack_offset like(SMALLINT_t) inz(1);
  dcl-s add_pgm_info like(BOOLEAN_t) inz(false);

  if %passed(message_type_in);
    message_type = message_type_in;
  endif;

  if %passed(stack_offset_in);
    stack_offset = stack_offset_in;
  endif;

  if %passed(add_pgm_info_in);
    add_pgm_info = add_pgm_info_in;
  endif;

  message_text = message_text_in;
  if add_pgm_info;
    append_pgm_info(message_text);
  endif;

  select;

  when message_type = APP_LOG_INFO;
    snd-msg *info message_text %target(*caller:stack_offset);

  when message_type = APP_LOG_ESCAPE;
    snd-msg *escape %msg('APP2901':'RMMSGF':message_text) %target(*caller: stack_offset);

  endsl;

  return;
end-proc;

dcl-proc APP_escape export;
  dcl-pi *n;
    message_text like(APP_MESSAGE_TEXT_t) const;
    add_pgm_info_in like(BOOLEAN_t) options(*nopass) const;
  end-pi;

  dcl-s add_pgm_info like(BOOLEAN_t) inz(false);

  if %passed(add_pgm_info_in);
    add_pgm_info = add_pgm_info_in;
  endif;

  APP_log(message_text:APP_LOG_ESCAPE:*omit:add_pgm_info);

  return;
end-proc;

dcl-proc append_pgm_info;
  dcl-pi *n;
    message_text like(APP_MESSAGE_TEXT_t);
  end-pi;

  dcl-ds caller likeds(caller_t) inz(*likeds);

  caller = get_caller();

  message_text +=
    ' Program: '    + %trimr(caller.program) +
    ' Module: '     + %trimr(caller.module) +
    ' Procedure: '  + %trimr(caller.procedure) +
    ' Statement: '  + %trimr(caller.statement);

  return;
end-proc;

///
// Returns the caller of the current sub-procedure.
///

dcl-proc get_caller;
  dcl-pi *n likeds(caller_t) end-pi;

  dcl-ds CSTK0100  len(5000) qualified inz;
    BytesReturned bindec(9);
    BytesAvail    bindec(9);
    #ofEntries    bindec(9);
    StackOffset   bindec(9);
    #Returned     bindec(9);
  end-ds;

  dcl-ds JIDF0100  qualified;
    Name        char(10) inz('*');
    User        char(10) inz('');
    Number      char(6) inz('');
    Id          char(16);
    Reserved    char(2) inz(*loval);
    ThreadIndic bindec(9) inz(1);
    ThreadId    char(8) inz(*loval);
  end-ds;

  // API Error Data structure.
  dcl-ds APIError qualified inz;
    ByteProv bindec(9) inz(%size(APIError.msgdata));
    ByteAval bindec(9);
    MsgId    char(7);
    Filler   char(1);
    MsgData  char(100);
  end-ds;

  // Field definitions for retrieving the call stack entry.
  dcl-ds rtvCallStack qualified;
    Receiver      like(CSTK0100) inz;
    Length        bindec(9) inz(%size(rtvCallStack.Receiver));
    Format        char(8) inz('CSTK0100');
    JobId         like(JIDF0100) inz;
    JobIdFormat   char(8) inz('JIDF0100');
    Error         like(APIError) inz;
  end-ds;

  dcl-ds StackEntry len(256) qualified based(StackEntry_p);
    Length        int(10);
    StatementDisp int(10);
    #ofIds        int(10);
    ProcedureDisp int(10);
    LenProcedure  int(10);
    RequestLevel  int(10);
    ProgramName   char(10);
    ProgramLib    char(10);
    Instruction#  int(10);
    ModuleName    char(10);
    ModuleLib     char(10);
    Boundary      char(1);
    Reserved1     char(3);
    ActGroup#     uns(10);
    ActGroupName  char(10);
    Reserved2     char(2);
    PgmAspName    char(10);
    PgmLibAspName char(10);
    PgmAsp#       int(10);
    PgmLibAsp#    int(10);
    ActGrp#Long   uns(20:0);
  end-ds;

  dcl-ds Statement qualified based(Statement_p);
    identifier char(10) dim(100);
  end-ds;

  dcl-ds Procedure qualified based(Procedure_p);
    name char(128);
  end-ds;

  // Procedure definitions for the retrieve call stack entry API.
  dcl-pr QWVRCSTK extpgm('QWVRCSTK');
    Parm1 like(rtvCallStack.Receiver);
    Parm2 like(rtvCallStack.Length);
    Parm3 like(rtvCallStack.Format);
    Parm4 like(rtvCallStack.JobId);
    Parm5 like(rtvCallStack.JobIdFormat);
    Parm6 like(rtvCallStack.Error);
  end-pr;

  dcl-ds caller likeds(caller_t) inz(*likeds);
  dcl-ds caller_out likeds(caller_t) inz(*likeds);
  dcl-s index like(INTEGER_t);
  dcl-s offset like(INTEGER_t);

  // Get API to get the call stack
  rtvCallStack.Receiver = CSTK0100;
  rtvCallStack.JobId = JIDF0100;

  QWVRCSTK( rtvCallStack.Receiver
          : rtvCallStack.Length
          : rtvCallStack.Format
          : rtvCallStack.jobId
          : rtvCallStack.jobIdFormat
          : rtvCallStack.Error );

  CSTK0100 = rtvCallStack.Receiver;

  offset = CSTK0100.StackOffset;
  for index = 1 to CSTK0100.StackOffset;
    StackEntry_p = %addr(CSTK0100) + offset;
    Statement_p = StackEntry_p + StackEntry.StatementDisp;
    Procedure_p = StackEntry_p + StackEntry.ProcedureDisp;

    caller.program = StackEntry.ProgramName;
    caller.module = StackEntry.ModuleName;
    if StackEntry.LenProcedure <= %size(caller.procedure);
      caller.procedure = %subst(Procedure.name: 1: StackEntry.LenProcedure);
    else;
      caller.procedure = Procedure.name;
    endif;
    caller.statement = Statement.identifier(1);

    if (caller.module <> 'RMAPP01' or caller.procedure <> 'GET_CALLER')
      and (caller.module <> 'RMAPP01' or caller.procedure <> 'APPEND_PGM_INFO')
      and (caller.module <> 'RMAPP01' or caller.procedure <> 'APP_LOG')
      and (caller.module <> 'RMAPP01' or caller.procedure <> 'APP_ESCAPE')
      and (caller.module <> 'RMEMBSQL' or caller.procedure <> 'LOG_MESSAGE')
      and (caller.module <> 'RMEMBSQL' or caller.procedure <> 'EMBSQL_STATE');
      caller_out = caller;
      leave;
    endif;

    offset += StackEntry.Length;
  endfor;

  return caller_out;
end-proc;
