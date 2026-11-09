**free

//==============================================================================
// RMSTRING02 - String Helper - Builder Module
//
// 11/01/2025 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: String Helper - Builder Module');

///
// Copybook definitions
///

/include 'include/RMSTRING_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

///
// String builder definitions
///

dcl-c STRING_SB_MAX_CAPACITY 16776704;

///
// String builder instance structure.
///

dcl-ds sbi_t qualified template inz;
  data_len like(UNSIGNED_INTEGER_t) inz(0);
  data_ptr pointer inz(*null);
end-ds;

///
// String builder terminator.
// - each string appended to the instance will be terminated with
//   this constant value
///

dcl-c STRING_SB_TERMINTOR const(x'00');

dcl-proc STRING_sb_new_empty export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact);
  end-pi;

  dcl-ds sbi likeds(sbi_t) based(sbi_ptr);
  dcl-s sbi_ptr pointer;
  dcl-s success like(BOOLEAN_t);

  sbi_ptr = %alloc(%size(sbi));
  sbi.data_len = 0;
  sbi.data_ptr = *null;

  sb = sbi_ptr;
  success = true;

  return success;
end-proc;

dcl-proc STRING_sb_new_string export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact);
    str like(STRING_t) ccsid(*utf8) const;
  end-pi;

  dcl-s success like(BOOLEAN_t);

  if STRING_sb_new(sb)
    and STRING_sb_append(sb: str);

    success = true;
  endif;

  return success;
end-proc;

dcl-proc STRING_sb_length export;
  dcl-pi *n like(UNSIGNED_INTEGER_t);
    sb like(STRING_sb_t) options(*exact) value;
  end-pi;

  dcl-ds sbi likeds(sbi_t) based(sbi_ptr);
  dcl-s sbi_ptr pointer;

  sbi_ptr = sb;

  return sbi.data_len;
end-proc;

dcl-proc STRING_sb_append export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact) value;
    str like(STRING_t) ccsid(*utf8) const;
  end-pi;

  dcl-ds sbi likeds(sbi_t) based(sbi_ptr);
  dcl-s sbi_ptr pointer;
  dcl-s success like(BOOLEAN_t);

  dcl-s new_len like(UNSIGNED_INTEGER_t);
  dcl-s new_pos like(UNSIGNED_INTEGER_t);
  dcl-s new_data char(MAX_STRING_LEN) ccsid(*utf8) based(new_data_ptr);
  dcl-s new_data_ptr pointer;
  dcl-s new_str like(STRING_t) ccsid(*utf8);

  sbi_ptr = sb;
  new_str = str + STRING_SB_TERMINTOR;

  if sbi.data_ptr = *null;
    new_len = %len(new_str);
    sbi.data_ptr = %alloc(new_len);
    new_pos = 1;
  else;
    new_len = sbi.data_len + %len(new_str);
    sbi.data_ptr = %realloc(sbi.data_ptr: new_len);
    new_pos = sbi.data_len + 1;
  endif;

  new_data_ptr = sbi.data_ptr + (new_pos - 1);
  %subst(new_data:1:%len(new_str)) = new_str;
  sbi.data_len = new_len;
  success = true;

  return success;
end-proc;

dcl-proc STRING_sb_get export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact) value;
    str like(STRING_t) ccsid(*utf8);
    get_index_in like(UNSIGNED_INTEGER_t) const options(*nopass);
  end-pi;

  dcl-ds sbi likeds(sbi_t) based(sbi_ptr);
  dcl-s sbi_ptr pointer;
  dcl-s success like(BOOLEAN_t);
  dcl-s index like(UNSIGNED_INTEGER_t);
  dcl-s get_index like(UNSIGNED_INTEGER_t) inz(1);

  dcl-s str_start like(UNSIGNED_INTEGER_t);
  dcl-s str_len like(UNSIGNED_INTEGER_t);
  dcl-s str_offset like(UNSIGNED_INTEGER_t);
  dcl-s str_data char(MAX_STRING_LEN) ccsid(*utf8) based(str_data_ptr);
  dcl-s got_one like(BOOLEAN_t);
  dcl-s terminator char(1) based(terminator_ptr);

  // Handle optional params
  if %passed(get_index_in);
    get_index = get_index_in;
  endif;

  sbi_ptr = sb;

  if sbi.data_ptr <> *null;
    str_start = 1;
    for index = 1 to get_index;
      got_one = false;
      for str_offset = str_start to sbi.data_len;
        terminator_ptr = sbi.data_ptr + str_offset - 1;
        if terminator = STRING_SB_TERMINTOR;
          got_one = true;
          leave;
        endif;
        str_len += 1;
      endfor;
      if not got_one;
        success = false;
        leave;
      elseif index = get_index;
        if str_len > 1;
          str_data_ptr = sbi.data_ptr + str_start -1;
          str = %subst(str_data:1:str_len);
        else;
          str = '';
        endif;
        success = true;
      else;
        str_start = str_offset + %len(STRING_SB_TERMINTOR);
        str_len = 0;
      endif;
    endfor;
  endif;

  return success;
end-proc;

dcl-proc STRING_sb_delete export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact);
  end-pi;

  dcl-ds sbi likeds(sbi_t) based(sbi_ptr);
  dcl-s sbi_ptr pointer;
  dcl-s success like(BOOLEAN_t);

  sbi_ptr = sb;

  dealloc(n) sbi.data_ptr;
  dealloc(n) sb;

  return success;
end-proc;

dcl-proc STRING_sb_to_string export;
  dcl-pi *n like(BOOLEAN_t);
    sb like(STRING_sb_t) options(*exact) value;
    str like(STRING_t) ccsid(*utf8);
    sep_in varchar(10) ccsid(*utf8) const options(*nopass);
  end-pi;

  dcl-s success like(BOOLEAN_t);
  dcl-s index like(INTEGER_t) inz(1);
  dcl-s str_part like(STRING_t) ccsid(*utf8);
  dcl-s sep varchar(10) ccsid(*utf8) inz(ASCII_LF);
  dcl-s new_len like(UNSIGNED_INTEGER_t);

  // Handle optional params
  if %passed(sep_in);
    sep = sep_in;
  endif;

  // Initialize output parameter
  str = '';

  dow STRING_sb_get(sb:str_part:index);
    if index > 1;
      str += sep;
    endif;

    new_len = %len(str) + %len(str_part);
    str += str_part;

    if new_len > MAX_STRING_LEN;
      success = false;
      leave;
    endif;

    index += 1;
  enddo;

  return success;
end-proc;
