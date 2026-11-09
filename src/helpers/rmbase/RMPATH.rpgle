**free

//==============================================================================
// RMPATH     - Path Helper Module
//
// 21/11/2020 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Path Helper Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Include copybooks
///

/include 'include/RMPATH_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==============================================================================
// PATH_basename
//   Returns the last portion of a path
//
//   e.g. /home/user/src/helpers/PATH.sqlrpgle
//        would return PATH.sqlrpgle
//==============================================================================

dcl-proc PATH_basename export;
  dcl-pi *n like(PATH_BASENAME_t);
    path like(STMF_t) const;
  end-pi;

  dcl-s basename like(PATH_BASENAME_t);
  dcl-s pos like(SMALLINT_t);

  monitor;
    pos = scanr(PATH_SEP: path);
    basename = %subst(path: pos+1);
  on-error;
    basename = '';
  endmon;

  return basename;
end-proc;

//==============================================================================
// PATH_name
//   Returns the last portion of a path without the extension
//
//   e.g. /home/user/src/helpers/PATH.sqlrpgle
//        would return PATH
//==============================================================================

dcl-proc PATH_name export;
  dcl-pi *n like(PATH_BASENAME_t);
    path like(STMF_t) const;
  end-pi;

  dcl-s basename like(PATH_BASENAME_t);
  dcl-s name like(PATH_BASENAME_t);
  dcl-s pos like(SMALLINT_t);

  monitor;
    basename = PATH_basename(path);
    pos = scanr(PATH_DOT: basename);
    if pos > 0;
      name = %subst(basename: 1: pos-1);
    else;
      name = basename;
    endif;
  on-error;
    name = '';
  endmon;

  return name;
end-proc;

//==============================================================================
// PATH_ext
//   Returns the extension
//
//   e.g. /home/user/src/helpers/PATH.sqlrpgle
//        would return sqlrpgle
//==============================================================================

dcl-proc PATH_ext export;
  dcl-pi *n like(PATH_EXT_t);
    path like(STMF_t) const;
  end-pi;

  dcl-s basename like(PATH_BASENAME_t);
  dcl-s ext like(PATH_EXT_t);
  dcl-s pos like(SMALLINT_t);

  monitor;
    basename = PATH_basename(path);
    pos = scanr(PATH_DOT: basename);
    if pos > 0;
      ext = %subst(basename: pos+1);
    else;
      ext = '';
    endif;
  on-error;
    ext = '';
  endmon;

  return ext;
end-proc;

//==============================================================================
// scanr
//   Reverse scan, required until V7R3M0 at which point the %scanr bif
//   can be used
//==============================================================================

dcl-proc scanr;
  dcl-pi *n like(SMALLINT_t);
    search like(STRING_t) const;
    source like(STRING_t) const;
  end-pi;

  /IF DEFINED(*V7R3M0)
  dcl-s pos like(SMALLINT_t);
  /ELSE
  dcl-s pos like(SMALLINT_t);
  dcl-s found like(BOOLEAN_t) inz(false);
  /ENDIF

  /IF DEFINED(*V7R3M0)
  pos = %scanr(search: source);
  /ELSE
  for pos = %len(source) downto 1;
    if %subst(source: pos: %len(search)) = search;
      found = true;
      leave;
    endif;
  endfor;
  if not found;
    pos = 0;
  endif;
  /ENDIF

  return pos;
end-proc;
