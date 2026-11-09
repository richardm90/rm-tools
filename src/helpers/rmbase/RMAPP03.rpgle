**free

//==============================================================================
// RMAPP03    - Application Helper - Environment Module
//
// 11/11/2024 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: Application Helper - Environment Module');

///
// Copybook definitions
///

/include 'include/PSDS_D.rpgleinc'
/include 'include/RMAPP_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

///
// Return the current application user
//
// @return the current application user
///

dcl-proc APP_user export;
  dcl-pi *n like(USER_t) end-pi;

  return psds.current_user;
end-proc;

///
// Return the current application date
//
// @return the current application date
///

dcl-proc APP_date export;
  dcl-pi *n like(DATE_t) end-pi;

  dcl-s l_date like(DATE_t);

  l_date = %date();

  return l_date;
end-proc;

///
// Return the current application time
//
// @return the current application time
///

dcl-proc APP_time export;
  dcl-pi *n like(TIME_t) end-pi;

  dcl-s l_time like(TIME_t);

  l_time = %time();

  return l_time;
end-proc;

///
// Return the current application timestamp
//
// @return the current application timestamp
///

dcl-proc APP_timestamp export;
  dcl-pi *n like(TIMESTAMP_t) end-pi;

  dcl-s l_timestamp like(TIMESTAMP_t);

  l_timestamp = %timestamp();

  return l_timestamp;
end-proc;
