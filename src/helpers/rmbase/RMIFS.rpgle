**free

//==============================================================================
// RMIFS      - IBM i IFS Helper Module
//
// 11/11/2024 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: IBM i IFS Helper Module');
ctl-opt bnddir('QC2LE');

///
// Copybook definitions
///

/include 'include/RMIFS_D.rpgleinc'
/include 'include/RMJOB_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//========================================================================
// Declare data structures
//========================================================================

// Directory entry structure
//   Used by IFS_readdir
dcl-ds dir_entry_t  qualified template;
  reserved1      char(16);
  fileno_gen_id  like(UNSIGNED_INTEGER_t);
  fileno         like(UNSIGNED_INTEGER_t);
  reclen         like(UNSIGNED_INTEGER_t);
  reserved3      like(INTEGER_t);
  reserved4      char(8);
  nlsinfo        char(12);
  nls_ccsid      like(INTEGER_t)    overlay(nlsinfo:1);
  nls_cntry      char(2)    overlay(nlsinfo:5);
  nls_lang       char(3)    overlay(nlsinfo:7);
  nls_reserv     char(3)    overlay(nlsinfo:10);
  namelen        like(UNSIGNED_INTEGER_t);
  name           char(640);
end-ds;

dcl-s dir_entry_p pointer;
dcl-ds dir_entry_g  likeds(dir_entry_t) based(dir_entry_p);

// Stream file stats
//   Used by IFS_readdir
dcl-ds stats_g  qualified;
  st_mode        like(UNSIGNED_INTEGER_t);
  st_ino         like(UNSIGNED_INTEGER_t);
  st_nlink       like(UNSIGNED_SMALLINT_t);
  st_reserved2   like(UNSIGNED_SMALLINT_t);
  st_uid         like(UNSIGNED_INTEGER_t);
  st_gid         like(UNSIGNED_INTEGER_t);
  st_size        like(INTEGER_t);
  st_atime       like(INTEGER_t);
  st_mtime       like(INTEGER_t);
  st_ctime       like(UNSIGNED_INTEGER_t);
  st_dev         like(UNSIGNED_INTEGER_t);
  st_blksize     like(UNSIGNED_INTEGER_t);
  st_allocsize   like(UNSIGNED_INTEGER_t);
  st_objtype     char(11);
  st_reserved3   char(1);
  st_codepage    like(UNSIGNED_SMALLINT_t);
  st_ccsid       like(UNSIGNED_SMALLINT_t);
  st_rdev        like(UNSIGNED_INTEGER_t);
  st_nlink32     like(UNSIGNED_INTEGER_t);
  st_rdev64      like(UNSIGNED_BIGINT_t);
  st_dev64       like(UNSIGNED_BIGINT_t);
  st_reserved1   char(32);
  st_ino_gen_id  like(UNSIGNED_INTEGER_t);
end-ds;

//========================================================================
// Declare indicators and fields
//========================================================================

dcl-s error_g        like(BOOLEAN_t);
dcl-ds error_data_g  likeds(IFS_ERROR_DATA_T) inz;
dcl-s feof_g         like(BOOLEAN_t);


//========================================================================
// Define global constants
//========================================================================

dcl-c EPOCH z'1970-01-01-00.00.00';

dcl-c CCSID_UTF8  const(1208);

//========================================================================
// initialise
//   Initialisation procedure
//   - Resets error status
//========================================================================

dcl-proc initialise;

  reset error_g;
  reset error_data_g;

  return;
end-proc;

//========================================================================
// IFS_crtdir
//   A simple frontend to the mkdir prototype that grants full
//   authority to all users
//========================================================================

dcl-proc IFS_crtdir export;
  dcl-pi IFS_crtdir;
    path varchar(1024) const;
  end-pi;

  dcl-s mode like(UNSIGNED_INTEGER_t);

  dcl-pr mkdir like(INTEGER_t) extproc('mkdir');
    path        pointer value options(*string);
    pMode       like(UNSIGNED_INTEGER_t) value;
  end-pr;

  // Initialisation
  initialise();

  mode = S_IRUSR + S_IWUSR + S_IXUSR +
         S_IRGRP + S_IWGRP + S_IXGRP +
         S_IROTH + S_IWOTH + S_IXOTH;

  if (mkdir(%trimr(path): mode) < 0);
    set_error();
  endif;

  return;
end-proc;


//========================================================================
// IFS_dltdir
//   ???
//========================================================================

dcl-proc IFS_dltdir export;
  dcl-pi IFS_dltdir;
    path like(STMF_t) const;
  end-pi;

  dcl-s dir_p        pointer;
  dcl-s filename_l   like(IFS_DIR_FILENAME_t);
  dcl-s stmf_l       like(STMF_t);
  dcl-s error_l      like(BOOLEAN_t);

  dcl-pr rmdir like(INTEGER_t) extproc('rmdir');
    path       pointer value options(*string);
  end-pr;

  // Initialisation
  initialise();

  // Open the directory
  dir_p = IFS_opendir(%trimr(path));
  if ( IFS_error() );
    return;
  endif;

  // Read through all entries in the directory, removing
  // the contents
  dow IFS_readdir(dir_p);
    filename_l = IFS_direntry_filename();
    if ( filename_l <> '.'  and filename_l <> '..' );
      stmf_l = %trimr(IFS_format_ifs_path(path)) + filename_l;
      IFS_dltstmf(stmf_l);
      if ( IFS_error() );
        error_l = true;
        leave;
      endif;
    endif;
  enddo;

  // Close the directory
  IFS_closedir(dir_p);
  if ( IFS_error() );
    return;
  endif;

  // If an error occurred in the read loop then exit, now
  // that the directory has been closed
  if ( error_l );
    return;
  endif;

  // Now remove the directory
  if ( rmdir(%trimr(path)) > 0 );
    set_error();
    return;
  endif;

  return;
end-proc;

//========================================================================
// IFS_opendir
//   A simple frontend over the opendir procedure
//   - Opens an IFS directory, ready for reading
//========================================================================

dcl-proc IFS_opendir export;
  dcl-pi IFS_opendir pointer;
    path  like(STMF_t) const;
  end-pi;

  dcl-pr opendir pointer extproc('opendir');
    path  pointer value options(*string);
  end-pr;

  dcl-s dir_p      pointer;

  initialise();

  dir_p = opendir(%trimr(path));
  if dir_p = *null;
    set_error();
  endif;

  return dir_p;
end-proc;

//========================================================================
// IFS_readdir
//   A simple frontend over the readdir procedure
//   - Reads the next entry from an open directory handler
//   - A call to IFS_readdir() overwrites data produced by a previous
//     call to IFS_readdir() on the same directory stream. Calls for
//     different directory streams do not overwrite the data of each
//     other.
//========================================================================

dcl-proc IFS_readdir export;
  dcl-pi IFS_readdir  like(BOOLEAN_t);
    dir_handle   pointer    value;
    filename like(IFS_DIR_FILENAME_t) options(*nopass);
  end-pi;

  dcl-pr readdir pointer extproc('readdir');
    dir_handle   pointer    value;
  end-pr;

  dcl-s filename_l like(IFS_DIR_FILENAME_t);
  dcl-s eof like(BOOLEAN_t);

  dow not eof;
    dir_entry_p = readdir(dir_handle);

    if dir_entry_p = *null;
      return false;
    endif;

    filename_l = IFS_direntry_filename();
    if filename_l <> '.' and filename_l <> '..';
      leave;
    endif;
  enddo;

  if %passed(filename);
    filename = filename_l;
  endif;

  return true;
end-proc;

//========================================================================
// IFS_direntry_filename
//   Returns the file name from the current IFS directory entry
//========================================================================

dcl-proc IFS_direntry_filename export;
  dcl-pi IFS_direntry_filename like(IFS_DIR_FILENAME_t) end-pi;

  return %subst(dir_entry_g.name: 1: dir_entry_g.namelen);
end-proc;

//========================================================================
// IFS_closedir
//   A simple frontend over the closedir procedure
//   - Closes an IFS directory
//========================================================================

dcl-proc IFS_closedir export;
  dcl-pi IFS_closedir;
    dir_handle   pointer    value;
  end-pi;

  dcl-pr closedir like(INTEGER_t) extproc('closedir');
    dir_handle   pointer    value;
  end-pr;

  initialise();

  if closedir(dir_handle) < 0;
    set_error();
  endif;

  return;
end-proc;

///
// Rename a file or directory.
//
// @param Path name of the file to be renamed.
// @param Path name of the new name of the file.
// @param Optional boolean indicating that any existing file is replaced,
//          defaults to false meaning an existing file is not replaced.
// @return Boolean value indicating success. If the rename was not successful
//          the error number and messag are captured.
///

dcl-proc IFS_rename export;
  dcl-pi IFS_rename like(BOOLEAN_t);
    old_name       pointer    value options(*string);
    new_name       pointer    value options(*string);
    replace        like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-pr rename_keep like(INTEGER_t) extproc('Qp0lRenameKeep');
    old_name       pointer    value options(*string);
    new_name       pointer    value options(*string);
  end-pr;

  dcl-pr rename_unlink like(INTEGER_t) extproc('Qp0lRenameUnlink');
    old_name       pointer    value options(*string);
    new_name       pointer    value options(*string);
  end-pr;

  dcl-s success like(BOOLEAN_t) inz(true);
  dcl-s rc like(INTEGER_t);

  // Initialisation
  initialise();

  // Rename and keep existing file
  if not %passed(replace) or not replace;
    rc = rename_keep(old_name: new_name);
  else;
    rc = rename_unlink(old_name: new_name);
  endif;

  if rc < 0;
    set_error();
    success = false;
  endif;

  return success;
end-proc;

//========================================================================
// IFS_dltstmf
//   Deletes the passed stream file, testing if the stream file is a
//   directory and deleting accordingly
//========================================================================

dcl-proc IFS_dltstmf export;
  dcl-pi IFS_dltstmf;
    path like(STMF_t) const;
  end-pi;

  dcl-pr unlink pointer extproc('unlink');
    path        pointer value options(*string);
  end-pr;

  // If the stream file is a directory then delete the directory
  // otherwise delete the file
  if ( IFS_isa_directory(%trimr(path)) );
    IFS_dltdir(%trimr(path));
  else;
    unlink(%trimr(path));
  endif;

  return;
end-proc;

//========================================================================
// IFS_isa_directory
//   Returns a boolean identifying whether the passed stream file pointer
//   is a directory
//========================================================================

dcl-proc IFS_isa_directory export;
  dcl-pi IFS_isa_directory like(BOOLEAN_t);
    stmf like(STMF_t) const;
  end-pi;

  initialise();

  IFS_stats(stmf);
  if IFS_error();
    return false;
  endif;

  return (S_ISDIR(stats_g.st_mode) = true);
end-proc;

//========================================================================
// IFS_stats_modified
//   Retrieve the stream file stats modified timestamp
//========================================================================

dcl-proc IFS_stats_modified export;
  dcl-pi IFS_stats_modified  like(TIMESTAMP_t);
    stmf         pointer    value options(*string);
  end-pi;

  dcl-s timestamp_l   like(TIMESTAMP_t);

  dcl-ds timezone_l;
    tzDir     char(1);
    tzHour    zoned(2:0);
    tzFrac    zoned(2:0);
  end-ds;

  initialise();

  IFS_stats(stmf);
  if IFS_error();
    return timestamp_l;
  endif;

  // Times in statds are seconds from the "epoch" (Jan 1, 1970)
  //   and are in GMT (Greenwich Mean Time
  timestamp_l = EPOCH + %seconds(stats_g.st_mtime);

  // Adjust timestamps for timezone
  timezone_l = GetTimeZone();
  if tzdir = '-';
    timestamp_l -= %hours(tzHour);
  else;
    timestamp_l += %Hours(tzHour);
  endif;

  return timestamp_l;
end-proc;


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  This gets the offset from Universal Coordinated Time (UTC)
//    from the system value QUTCOFFSET
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
dcl-proc GetTimeZone;
  dcl-pi GetTimeZone char(5) end-pi;

  dcl-s peRcvVar     char(1) dim(100);
  dcl-s peRVarLen    like(INTEGER_t);
  dcl-s peNumVals    like(INTEGER_t);
  dcl-s peSysValNm   char(10);
  dcl-s p_Offset     pointer;
  dcl-s wkOffset     like(INTEGER_t)    based(p_Offset);
  dcl-s p_SV         pointer;

  dcl-ds dsSV  based(P_SV);
    dsSVSysVal     char(10);
    dsSVDtaTyp     char(1);
    dsSVDtaSts     char(1);
    dsSVDtaLen     like(INTEGER_t);
    dsSVData       char(5);
  end-ds;

  dcl-ds dsErrCode;
    dsBytesPrv     Bindec(9)  Pos(1) inz(256);
    dsBytesAvl     Bindec(9)  Pos(5) inz(0);
    dsExcpID       char(7)    Pos(9);
    dsReserved     char(1)    Pos(16);
    dsExcpData     char(240)  Pos(17);
  end-ds;

  dcl-pr QWCRSVAL extpgm('QWCRSVAL');
    rcvvar    char(1) dim(100);
    lenrcvvar int(10) const;
    numvals   int(10) const;
    valname   char(10) const;
    error     like(dsErrCode);
  end-pr;

  peRVarLen = 100;
  peNumVals = 1;
  peSysValNm = 'QUTCOFFSET';
  QWCRSVAL(peRcvVar:peRVarLen:peNumVals:peSysValNm:dsErrCode);

  if dsBytesAvl > 0;
    return '';
  endif;

  p_Offset = %addr(peRcvVar(5));
  p_SV = %addr(peRcvVar(wkOffset+1));

  return dsSVData;
end-proc;


//========================================================================
// IFS_stats
//   Retrieve the stream file stats
//========================================================================

dcl-proc IFS_stats export;
  dcl-pi *n likeds(IFS_stats_t);
    stmf    pointer value options(*string);
  end-pi;

  dcl-pr stat like(INTEGER_t) extproc('stat');
    stmf      pointer value options(*string);
    stats     pointer value;
  end-pr;

  dcl-ds stats likeds(IFS_stats_t) inz(*likeds);

  initialise();

  if stat(stmf: %addr(stats)) < 0;
    set_error();
  else;
    stats_g = stats;
  endif;

  return stats;
end-proc;

//========================================================================
// set_error
//   Sets the global error status and records the error message id
//========================================================================

dcl-proc set_error;

  dcl-pr strerror pointer extproc('strerror');
    errnum like(INTEGER_t) value;
  end-pr;

  error_g = true;
  error_data_g.error_number = errno();
  error_data_g.error_msg = %str(strerror(error_data_g.error_number));

end-proc;


//========================================================================
// IFS_error
//   Returns a boolean specifying whether an error condition occurred
//   during the last operation
//========================================================================

dcl-proc IFS_error export;
  dcl-pi IFS_error like(BOOLEAN_t) end-pi;

  return error_g;
end-proc;


//========================================================================
// IFS_get_error_data
//   Returns the error data structure
//========================================================================

dcl-proc IFS_get_error_data export;
  dcl-pi *n likeds(IFS_ERROR_DATA_T) end-pi;

  return error_data_g;
end-proc;


//========================================================================
// IFS_format_ifs_path
//   Format the IFS path, appending a trailing '/' if appropriate
//========================================================================

dcl-proc IFS_format_ifs_path export;
  dcl-pi *n like(STMF_t);
    path like(STMF_t) const;
  end-pi;

  dcl-s path_l like(STMF_t);

  // Append a trailing '/'
  path_l = %trimr(path);
  if path_l = ''
    or %subst(path_l: %len(path_l): 1) <> '/';
    path_l += '/';
  endif;

  return path_l;
end-proc;


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  This tests a file mode to see if a file is a directory.

// Here is the C code we're trying to duplicate:
//      #define _S_IFDIR    0040000                                       *
//      #define S_ISDIR(mode) (((mode) & 0370000) == _S_IFDIR)

// 1) ((mode) & 0370000) takes the file's mode and performs a
//      bitwise AND with the octal constant 0370000.  In binary,
//      that constant looks like: 00000000000000011111000000000000
//      The effect of this code is to turn off all bits in the
//      mode, except those marked with a '1' in the binary bitmask.

// 2) ((result of #1) == _S_IFDIR)  What this does is compare
//      the result of step 1, above with the _S_IFDIR, which
//      is defined to be the octal constant 0040000.  In decimal,
//      that octal constant is 16384.
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
dcl-proc S_ISDIR;
  dcl-pi *n like(BOOLEAN_t);
    mode    like(UNSIGNED_INTEGER_t)    value;
  end-pi;

  dcl-ds *N;
    dirmode        like(UNSIGNED_INTEGER_t)    Pos(1);
    byte1          char(1)    Pos(1);
    byte2          char(1)    Pos(2);
    byte3          char(1)    Pos(3);
    byte4          char(1)    Pos(4);
  end-ds;

  // Turn off bits in the mode, as in step (1) above.
  dirmode = mode;

    //  C                   BITOFF    x'FF'         BYTE1
    //  C                   BITOFF    x'FE'         BYTE2
    //  C                   BITOFF    x'0F'         BYTE3
    //  C                   BITOFF    x'FF'         BYTE4

  byte1 = %bitand(x'00': byte1);
  byte2 = %bitand(x'01': byte2);
  byte3 = %bitand(x'F0': byte3);
  byte4 = %bitand(x'00': byte4);

  // Compare the result to 0040000, and return true or false.
  if dirmode = 16384;
    return *ON;
  else;
    return *OFF;
  endif;
end-proc;

dcl-proc errno;
  dcl-pi errno like(INTEGER_t) end-pi;

  dcl-s errno_p      pointer;
  dcl-s retval       like(INTEGER_t)    based(errno_p);
  dcl-pr extproc_errno pointer extproc('__errno');

  end-pr;

  errno_p = extproc_errno();

  return retval;
end-proc;

//========================================================================
// IFS_close_file
//   Close an IFS file
//========================================================================

dcl-proc IFS_close_file export;
  dcl-pi IFS_close_file;
    p_handle                  like(INTEGER_t) const;
  end-pi;

  callp close(p_handle);

end-proc;

//========================================================================
// IFS_remove_file
//   Remove an IFS file
//========================================================================

dcl-proc IFS_remove_file export;
  dcl-pi *n;
    stmf like(STMF_t) const;
  end-pi;

  // Remove the file
  unlink(stmf);

end-proc;

//========================================================================
// IFS_open
//   Open IFS file
//   - The file handle is returned
//========================================================================

dcl-proc IFS_open export;
  dcl-pi *n  like(INTEGER_t);
    stmf          like(STMF_t) const;
    flags         like(INTEGER_t) const;
    mode          like(UNSIGNED_INTEGER_t) const options(*nopass);
    ccsid         like(UNSIGNED_INTEGER_t) const options(*nopass);
    txtcreatid    like(UNSIGNED_INTEGER_t) const options(*nopass);
  end-pi;

  dcl-s handle  like(INTEGER_t);

  initialise();

  select;

    when %parms() <= %parmnum(flags);
      handle = open(stmf: flags);

    when %parms() <= %parmnum(mode);
      handle = open(stmf: flags: mode);

    when %parms() <= %parmnum(ccsid);
      handle = open(stmf: flags: mode: ccsid);

    when %parms() <= %parmnum(txtcreatid);
      handle = open(stmf: flags: mode: ccsid: txtcreatid);

  endsl;

  if handle < 0;
    set_error();
  endif;

  return handle;
end-proc;

//========================================================================
// IFS_open_file
//   Open IFS file
//   - The file handle is returned
//========================================================================

dcl-proc IFS_open_file export;
  dcl-pi *n           like(INTEGER_t);
    path              like(STMF_t) const;
    open_type_in      like(INTEGER_t) const options(*nopass);
  end-pi;

  dcl-s open_type     like(INTEGER_t) inz(IFS_OPEN_TYPE_READ);
  dcl-s oflag         like(INTEGER_t);
  dcl-s mode          like(UNSIGNED_INTEGER_t);
  dcl-s ccsid_l       like(UNSIGNED_INTEGER_t) inz(1208);
  dcl-s handle        like(INTEGER_t);

  // Handle optional parameters
  if %parms() > 1;
    open_type = open_type_in;
  endif;

  initialise();

  select;

    // Open for read
    when open_type = IFS_OPEN_TYPE_READ;
      oflag  = O_RDONLY + O_TEXTDATA + O_CCSID;
      handle = open(%trimr(path): oflag: 0: 0);
      if handle < 0;
        set_error();
      endif;

    // Open for read
    when open_type = IFS_OPEN_TYPE_READ_UTF8;
      oflag  = O_RDONLY + O_TEXTDATA + O_CCSID;
      handle = open(%trimr(path): oflag: 1208: 1208);
      if handle < 0;
        set_error();
      endif;

    // Open for write
    when open_type = IFS_OPEN_TYPE_WRITE;

      // Remove the file, if it already exists
      unlink(%trimr(path));

      // Create the file
      oflag = O_WRONLY + O_CREAT + O_CCSID + O_TEXTDATA + O_INHERITMODE;
      mode = 0;
      handle = open(path: oflag: mode: ccsid_l);
      if handle < 0;
        set_error();
      endif;

    // Invalid file open type provided
    other;
      handle = -1;
      error_g = true;
      reset error_data_g.error_number;
      error_data_g.error_msg = 'Invalid file open type provided ('
                          + %char(open_type)
                          + ')';

  endsl;

  return handle;
end-proc;


//========================================================================
// IFS_write
//   Writes the given data to the given file handle
//========================================================================

dcl-proc IFS_write export;
  dcl-pi *n;
    handle   like(INTEGER_t) const;
    data     like(STRING_t) value;
  end-pi;

  callp write(handle: %addr(data: *data): %len(data));

end-proc;



//========================================================================
// IFS_write_utf8
//   Writes the given data to the given file handle
//========================================================================

dcl-proc IFS_write_utf8 export;
  dcl-pi *n;
    handle   like(INTEGER_t) const;
    data     like(STRING_t) ccsid(*utf8) value;
  end-pi;

  callp write(handle: %addr(data: *data): %len(data));

end-proc;


//========================================================================
// IFS_error_text
//   Returns the error data structure as a formatted text string
//========================================================================

dcl-proc IFS_error_text export;
  dcl-pi *n  like(IFS_ERROR_MSG_t);
  end-pi;

  dcl-s w_text like(IFS_ERROR_MSG_t);

  if IFS_error();
    w_text = 'errno='
          + %char(error_data_g.error_number)
          + ' '
          + error_data_g.error_msg;
  endif;

  return %trimr(w_text);
end-proc;


//========================================================================
// IFS_read
//   Return the contents of the given IFS file
//========================================================================

dcl-proc IFS_read export;
  dcl-pi *n  like(STRING_t) ccsid(*utf8);
    stmf     like(STMF_t) const;
  end-pi;

  dcl-s w_data       char(MAX_STRING_LEN) ccsid(*utf8);
  dcl-s w_result     like(STRING_t) ccsid(*utf8);
  dcl-s w_handle     like(INTEGER_t);
  dcl-s w_len        like(INTEGER_t);

  reset w_result;

  w_handle = IFS_open_file(stmf: IFS_OPEN_TYPE_READ_UTF8);
  if w_handle >= 0;
    w_len = read(w_handle: %addr(w_data): %size(w_data));
    w_result = %subst(w_data: 1: w_len);
  endif;

  return w_result;
end-proc;

///
// Returns a temporary IFS file name.
//
// @param Optional path, if not provided defaults to /tmp.
// @return Temporary file name.
///

dcl-proc IFS_temp_filename export;
  dcl-pi *n like(STMF_t);
    path like(STMF_t) options(*nopass) const;
  end-pi;

  dcl-s stmf like(STMF_t);

  //-----------------------------------------------------------------
  // createTempSTMF():  Creates a file name for a temporary stream file
  //   filename = (input) path to file in the IFS
  //-----------------------------------------------------------------
  dcl-pr createTempSTMF pointer extproc('_C_IFS_tmpnam');
    string char(39) options(*omit);
  end-pr;

  stmf = %trim(%str(createTempSTMF(*omit)));

  if %passed(path);
    stmf = IFS_join_path(path: basename(stmf));
  endif;

  return stmf;
end-proc;

// TODO: all PATH stuff this should be in IFS service program

dcl-proc basename;
  dcl-pi *n like(STMF_t);
    path like(STMF_t) const;
  end-pi;

  dcl-c PATH_SEP '/';
  dcl-s basename like(STMF_t);
  dcl-s pos like(SMALLINT_t);

  monitor;
    pos = %scanr(PATH_SEP: path);
    basename = %subst(path: pos+1);
  on-error;
    basename = '';
  endmon;

  return basename;
end-proc;

//========================================================================
// IFS_join_path
//   Format the IFS path, appending a trailing '/' if appropriate
//========================================================================

dcl-proc IFS_join_path export;
  dcl-pi *n  like(STMF_t);
    p_path1                   like(STMF_t) const;
    p_path2                   like(STMF_t) const;
  end-pi;

  dcl-s w_path                  like(STMF_t);

  w_path = IFS_format_ifs_path(p_path1)
        + %trimr(p_path2);

  return w_path;
end-proc;

//========================================================================
// IFS_fopen
//   Open an IFS file using the fopen procedure
//   - The file handle is returned
//========================================================================

dcl-proc IFS_fopen export;

  dcl-pi IFS_fopen pointer;
    p_file                    like(STMF_t) const;
    p_open_type               like(INTEGER_t) const options(*nopass);
  end-pi;

  dcl-s w_open_type     like(INTEGER_t);
  dcl-s w_mode          char(128);
  dcl-s w_ccsid         like(UNSIGNED_INTEGER_t) inz(1208);
  dcl-s w_handle        pointer;

  dcl-pr fopen pointer extproc('_C_IFS_fopen');
    p_filename     pointer    value options(*string);
    p_mode         pointer    value options(*string);
  end-pr;

  // Handle optional parameters
  w_open_type = IFS_OPEN_TYPE_READ;
  if %parms() > 1;
    w_open_type = p_open_type;
  endif;

  initialise();

  select;

    // Open for read
    when w_open_type = IFS_OPEN_TYPE_READ;
      w_mode = 'r, o_ccsid=' + %char(JOB_ccsid());
      w_handle = fopen(%trimr(p_file): w_mode);
      if w_handle = *null;
        set_error();
      endif;

    // Open for write
    when w_open_type = IFS_OPEN_TYPE_WRITE;

      // Remove the file, if it already exists
      unlink(%trimr(p_file));

      // Create the file
      w_mode = 'w, o_ccsid=' + %char(w_ccsid);
      w_handle = fopen(%trimr(p_file): w_mode);
      if w_handle = *null;
        set_error();
      endif;

    // Invalid file open type provided
    other;
      w_handle = *null;
      error_g = true;
      reset error_data_g.error_number;
      error_data_g.error_msg = 'Invalid file open type provided ('
                          + %char(w_open_type)
                          + ')';

  endsl;

  return w_handle;
end-proc;


//========================================================================
// IFS_fgets
//   Read a line from the given IFS stream file handle
//========================================================================

dcl-proc IFS_fgets export;
  dcl-pi *n like(BOOLEAN_t);
    p_handle       pointer;
    p_line         like(STRING_t);
  end-pi;

  dcl-s w_data       char(65535);
  dcl-s w_result     pointer;
  dcl-s w_success    like(BOOLEAN_t);

  dcl-pr fgets pointer extproc('_C_IFS_fgets');
    p_string       pointer    value options(*string);
    p_size         like(INTEGER_t) value;
    p_file         pointer    value;
  end-pr;


  // The file is read in the job CCSID
  w_result = fgets(%addr(w_data): %size(w_data): p_handle);
  if w_result <> *null;
    p_line = %trimr(%scanrpl(LF: ' ': %str(%addr(w_data))));
    feof_g = false;
    w_success = true;
  else;
    feof_g = true;
    w_success = false;
  endif;

  return w_success;
end-proc;

//========================================================================
// IFS_feof
//   Determines whether the last IFS_fgets hit EOF
//========================================================================

dcl-proc IFS_feof export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return feof_g;
end-proc;

//========================================================================
// IFS_fputs
//   Write a line to the given IFS stream file handle
//========================================================================

dcl-proc IFS_fputs export;

  dcl-pi IFS_fputs;
    p_handle       pointer;
    p_line         like(STRING_t) const;
  end-pi;

  dcl-s w_line     like(STRING_t);
  dcl-s w_ccsid    like(UNSIGNED_INTEGER_t) inz(1208);

  dcl-pr fputs     like(INTEGER_t) extproc('_C_IFS_fputs');
    p_string       pointer    value options(*string);
    p_file         pointer    value;
  end-pr;

  // The file is read in the job CCSID and is converted to CCSID 1208
  w_line = %trimr(p_line) + LF;
  w_line = convert(w_line: w_ccsid);
  fputs(w_line: p_handle);

  return;
end-proc;

//========================================================================
// convert
//   Convert text from job CCSID to given CCSID
//========================================================================

dcl-proc convert;
  dcl-pi convert  like(STRING_t);
    p_input       like(STRING_t) const;
    p_toccsid     like(INTEGER_t) const;
  end-pi;

  dcl-pr QtqIconvOpen  like(iconv_t) extproc('QtqIconvOpen');
    p_toCode           likeds(qtqcode_t) const;
    p_fromCode         likeds(qtqcode_t) const;
  end-pr;

  dcl-pr iconv      like(INTEGER_t) extproc('iconv');
    p_cd            like(iconv_t) value;
    p_inbuf         pointer;
    p_inbytesleft   like(UNSIGNED_INTEGER_t);
    p_outbuf        pointer;
    p_outbytesleft  like(UNSIGNED_INTEGER_t);
  end-pr;

  dcl-pr iconv_close  like(INTEGER_t) extproc('iconv_close');
    p_cd              like(iconv_t) value;
  end-pr;

  dcl-ds iconv_t  qualified template;
    return_value      like(INTEGER_t) inz;
    cd                like(INTEGER_t) dim(12) inz;
  end-ds;

  dcl-ds qtqcode_t  qualified template;
    CCSID           like(INTEGER_t) inz;
    ConvAlt         like(INTEGER_t) inz;
    SubsAlt         like(INTEGER_t) inz;
    ShiftAlt        like(INTEGER_t) inz;
    InpLenOp        like(INTEGER_t) inz;
    ErrorOpt        like(INTEGER_t) inz;
    Reserved        char(8)    inz(*ALLX'00');
  end-ds;

  dcl-ds source  likeds(qtqcode_t) inz(*likeds);
  dcl-ds target  likeds(qtqcode_t) inz(*likeds);
  dcl-ds toEBC  likeds(iconv_t);

  dcl-s inputbuf     char(65535);
  dcl-s outputbuf    char(65535);
  dcl-s input_p      pointer;
  dcl-s output_p     pointer;
  dcl-s inputleft               like(UNSIGNED_INTEGER_t);
  dcl-s outputleft              like(UNSIGNED_INTEGER_t);
  dcl-s outputlen               like(UNSIGNED_INTEGER_t);
  dcl-s w_output                like(STRING_t);

  // -----------------------------------------------
  //   find the appropriate translation 'table'
  //   for converting UTF-8 to the job's CCSID
  //
  //  Note: 0 is a special value that means
  //        "job CCSID".  Better to use that than
  //        to hard-code 37.
  // -----------------------------------------------

  source.CCSID = 0;      //    0 = current job's CCSID
  target.CCSID = 1208;   // 1208 = UTF-8
  toEBC = QtqIconvOpen(target: source);

  if toEBC.return_value = -1;
    // TODO: handle error
    // die('QtqIconvOpen failed: ' + %char(toEBC.return_value));
    return '';
  endif;

  // -----------------------------------------------
  //   Translate data.
  //
  //   the iconv() API will increment/decrement
  //   the pointers and lengths, so make sure you
  //   do not use the original pointers...
  // -----------------------------------------------

  inputbuf   = p_input;
  input_p    = %addr(inputbuf);
  inputleft  = %len(p_input);

  outputbuf  = '';
  output_p   = %addr(outputbuf);
  outputleft = %size(outputbuf);

  iconv( toEBC
      : input_p
      : inputleft
      : output_p
      : outputleft );

  // -----------------------------------------------
  //  if needed, you can calculate the length of
  //  the decoded data by subtracting the amount
  //  of space left in the buffer from the total
  //  buffer size.
  //
  //  At this point, 'outputbuf' should contain
  //  the EBCDIC data.
  // -----------------------------------------------

  outputlen = %size(outputbuf) - outputleft;
  w_output = %subst(outputbuf: 1: outputlen);

  // -----------------------------------------------
  //  you can call iconv() many more times if you
  //  want, using the same 'toEBC' table for
  //  translation.
  //   - -
  //  when you are completely done, call iconv_close()
  //  to free up memory.
  // -----------------------------------------------

  iconv_close(toEBC);

  return w_output;
end-proc;


//========================================================================
// IFS_fclose
//   Close an IFS file using the fclose procedure
//========================================================================

dcl-proc IFS_fclose export;
  dcl-pi IFS_fclose;
    p_handle pointer;
  end-pi;

  dcl-pr fclose  extproc('_C_IFS_fclose');
    p_handle       pointer    value;
  end-pr;

  fclose(p_handle);

  return;
end-proc;

//========================================================================
// IFS_extension
//   Returns the file extension
//========================================================================

dcl-proc IFS_extension export;
  dcl-pi *n  like(IFS_EXTENSION_t);
    file     like(STMF_t) const;
  end-pi;

  dcl-s ext  like(IFS_EXTENSION_t);
  dcl-s pos  like(INTEGER_t);

  pos = scanr('.': file);
  if pos > 1;
    ext = %subst(file: pos);
  endif;

  return ext;
end-proc;

dcl-proc scanr;
  dcl-pi *n like(SMALLINT_t);
    search like(STRING_t) const;
    source like(STRING_t) const;
  end-pi;

  dcl-s pos like(SMALLINT_t);

  pos = %scanr(search: source);

  return pos;
end-proc;

dcl-proc IFS_stmf_ccsid export;
  dcl-pi *n like(UNSIGNED_SMALLINT_t);
    stmf like(STMF_t) const;
  end-pi;

  dcl-s stmf_ccsid like(UNSIGNED_SMALLINT_t);

  initialise();

  IFS_stats(stmf);
  if not IFS_error();
    stmf_ccsid = stats_g.st_ccsid;
  endif;

  return stmf_ccsid;
end-proc;

dcl-proc IFS_save_string export;
  dcl-pi *n like(BOOLEAN_t);
    str  like(STRING_t) ccsid(*utf8) value;
    stmf like(STMF_t) const;
  end-pi;

  dcl-s fd like(INTEGER_t);
  dcl-s success like(BOOLEAN_t);

  fd = open(
    stmf:
    O_WRONLY + O_CREAT + O_TRUNC + O_TEXTDATA + O_INHERITMODE + O_CCSID:
    0:
    CCSID_UTF8:
    CCSID_UTF8
  );

  if fd < 0;
    set_error();

  else;
    callp write(fd: %addr(str: *data): %len(str));
    success = true;
  endif;

  callp close(fd);

  return success;
end-proc;
