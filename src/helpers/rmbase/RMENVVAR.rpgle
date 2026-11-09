**free

//==============================================================================
// RMENVVAR   - Environment Variables Helper Module
//
// 11/11/2024 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: Environment Variables Helper Module');

///
// Copybook definitions
///

/include 'include/RMENVVAR_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==================================================================================================
// ENVVAR_get
//   Retrieve an environment variable value, either job or system. First checks
//   for a job environment variable then system.
//==================================================================================================

dcl-proc ENVVAR_get export;
  dcl-pi *n like(ENVVAR_value_t);
    p_key like(ENVVAR_key_t) const;
  end-pi;

  // Get Value of Environment Variable (Extended)
  dcl-pr qp0zgetenv pointer extproc('Qp0zGetEnv');
    p_envvar pointer value options(*string);
    p_ccsid  like(INTEGER_t);
  end-pr;

  // Get Value of System-Level Environment Variable
  dcl-pr qp0zgetsysenv like(INTEGER_t) extproc('Qp0zGetSysEnv');
    p_envvar    pointer value options(*string);
    p_value     char(65535) options(*varsize);
    p_value_len like(INTEGER_t);
    p_ccsid     like(INTEGER_t);
    p_reserved  pointer options(*omit);
  end-pr;

  dcl-s w_value_p   pointer;
  dcl-s w_value     like(ENVVAR_value_t);
  dcl-s w_ccsid     like(ENVVAR_ccsid_t);
  dcl-s w_result    like(INTEGER_t);
  dcl-s w_value_sys char(1024);
  dcl-s w_value_len like(INTEGER_t) inz(%len(w_value_sys));

  w_value_p = qp0zgetenv(%trimr(p_key): w_ccsid);
  if w_value_p <> *null;
    w_value = %str(w_value_p);
  else;
    w_result = qp0zgetsysenv( %trimr(p_key)
                            : w_value_sys
                            : w_value_len
                            : w_ccsid
                            : *omit );
    if w_result = 0;
      w_value_p = %addr(w_value_sys);
      w_value   = %str(w_value_p);
    endif;
  endif;

  return w_value;
end-proc;

//==================================================================================================
// ENVVAR_put
//   Change or add environment variable, either job or system. First checks
//   for a job environment variable then system.
//   - The return boolean indicates success
//==================================================================================================

dcl-proc ENVVAR_put export;
  dcl-pi *n like(BOOLEAN_t);
    p_key   like(ENVVAR_key_t) const;
    p_value like(ENVVAR_value_t) const;
    p_level like(ENVVAR_level_t) const options(*nopass);
  end-pi;

  // Change or Add Environment Variable (Extended)
  dcl-pr qp0zputenv like(INTEGER_t) extproc('Qp0zPutEnv');
    p_envvar pointer value options(*string);
    p_ccsid  like(INTEGER_t);
  end-pr;

  // Get Value of System-Level Environment Variable
  dcl-pr qp0zputsysenv like(INTEGER_t) extproc('Qp0zPutSysEnv');
    p_envvar    pointer value options(*string);
    p_ccsid     like(INTEGER_t);
    p_reserved  pointer options(*omit);
  end-pr;

  dcl-s w_envvar like(ENVVAR_key_value_t);
  dcl-s w_result like(INTEGER_t);
  dcl-s w_ccsid  like(ENVVAR_ccsid_t);
  dcl-s w_level  like(ENVVAR_level_t);

  if %parms() > 2;
    w_level = p_level;
  else;
    w_level = ENVVAR_LEVEL_JOB;
  endif;

  w_envvar = %trim(p_key) + '=' + %trim(p_value);

  if w_level = ENVVAR_LEVEL_JOB;
    w_result = qp0zputenv(w_envvar: w_ccsid);
  else;
    w_result = qp0zputsysenv(w_envvar: w_ccsid: *omit);
  endif;

  return (w_result=0);
end-proc;

//==================================================================================================
// ENVVAR_dlt
//   Delete an environment variable, either job or system.
//   - The return boolean indicates success
//==================================================================================================

dcl-proc ENVVAR_dlt export;
  dcl-pi *n like(BOOLEAN_t);
    p_key   like(ENVVAR_key_t) const;
    p_level like(ENVVAR_level_t) const options(*nopass);
  end-pi;

  // Delete an Environment Variable
  dcl-pr qp0zdltenv like(INTEGER_t)  extproc('Qp0zDltEnv');
    p_name pointer value options(*string);
  end-pr;

  // Get Value of System-Level Environment Variable
  dcl-pr qp0zdltsysenv like(INTEGER_t) extproc('Qp0zDltSysEnv');
    p_name    pointer value options(*string);
    p_reserved  pointer options(*omit);
  end-pr;

  dcl-s w_result like(INTEGER_t);
  dcl-s w_level  like(ENVVAR_level_t);

  if %parms() > 2;
    w_level = p_level;
  else;
    w_level = ENVVAR_LEVEL_JOB;
  endif;

  if w_level = ENVVAR_LEVEL_JOB;
    w_result = qp0zdltenv(p_key);
  elseif w_level = ENVVAR_LEVEL_SYS;
    w_result = qp0zdltsysenv(p_key: *omit);
  elseif w_level = ENVVAR_LEVEL_FIRST;
    w_result = qp0zdltenv(p_key);
    if w_result < 0;
      w_result = qp0zdltsysenv(p_key: *omit);
    endif;
  endif;

  return (w_result=0);
end-proc;
