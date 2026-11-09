**free

//==============================================================================
// RMSTRING01 - String Helper - Base Module
//
// 11/11/2024 - RM - created
// 11/01/2025 - RM - renamed from RMSTRING to RMSTRING01
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: String Helper - Base Module');

///
// Copybook definitions
///

/include 'include/RMSTRING_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==============================================================================
// Convert a numeric value to a string
//==============================================================================

dcl-proc STRING_number_to_string export;
  dcl-pi *n like(STRING_t);
    number packed(3:0) const;
  end-pi;

  // work data structures
  dcl-ds frequencyNumbers;
    *N             Char(10)   inz('one');
    *N             Char(10)   inz('two');
    *N             Char(10)   inz('three');
    *N             Char(10)   inz('four');
    *N             Char(10)   inz('five');
    *N             Char(10)   inz('six');
    *N             Char(10)   inz('seven');
    *N             Char(10)   inz('eight');
    *N             Char(10)   inz('nine');
    *N             Char(10)   inz('ten');
    *N             Char(10)   inz('eleven');
    *N             Char(10)   inz('twelve');
    *N             Char(10)   inz('thirteen');
    *N             Char(10)   inz('fourteen');
    *N             Char(10)   inz('fifteen');
    *N             Char(10)   inz('sixteen');
    *N             Char(10)   inz('seventeen');
    *N             Char(10)   inz('eighteen');
    *N             Char(10)   inz('nineteen');
    *N             Char(10)   inz(' ');
    a_frequencyNumbers Char(10) dim(20) pos(1);
  end-ds;

  dcl-ds frequencyTens;
    *N             Char(10)   inz('ten');
    *N             Char(10)   inz('twenty');
    *N             Char(10)   inz('thirty');
    *N             Char(10)   inz('fourty');
    *N             Char(10)   inz('fifty');
    *N             Char(10)   inz('sixty');
    *N             Char(10)   inz('seventy');
    *N             Char(10)   inz('eighty');
    *N             Char(10)   inz('ninety');
    *N             Char(10)   inz(' ');
    a_frequencyTens Char(10) dim(10) pos(1);
  end-ds;

  // work fields
  dcl-s str like(STRING_t);
  dcl-s numericvalue Zoned(3:0);
  dcl-s numericvalueleft Zoned(3:0);

  // clear/reset work fields
  numericvalue = number;
  numericvalueleft = numericvalue;

  // convert a numeric value to a string
  if ( %rem( numericvalueleft : 100 ) < 20 and
      %rem( numericvalueleft : 100 ) > 0 );
    str = a_frequencynumbers( %rem( numericvalueleft : 100 ) ) ;
    numericvalueleft = %div( numericvalueleft : 100 );
  else;
    // 1 .. 9
    if ( %rem( numericvalueleft : 10 ) <> 0 );
      str = a_frequencynumbers( %rem( numericvalueleft : 10 ) );
    endif;
    numericvalueleft = %div( numericvalueleft : 10 );
    // tens
    if ( %rem( numericvalueleft : 10 ) <> 0 );
      str = %trim( a_frequencytens(
              %rem( numericvalueleft : 10 ))) + ' ' +
              %trim(str);
    endif;
    // hundereds
    numericvalueleft = %div( numericvalueleft : 10 );
  endif;

  if ( numericvalueleft <> 0 );
    str = %trim( a_frequencynumbers( numericvalueleft )) +
                ' hundered and ' + %trim(str);
  endif;

  // return string
  return str;
end-proc;

//==============================================================================
// Determine the next schedule date
//==============================================================================

dcl-proc STRING_day_to_string export;
  dcl-pi *n char(4);
    days packed(2:0) const;
  end-pi;

  // work fields
  dcl-s str char(4);

  // convert days into string
  select;
    when ( days = 1 or days = 21 or days = 31 );
      str = %char( days ) + 'st';
    when ( days = 2 or days = 22 );
      str = %char( days ) + 'nd';
    when ( days = 3 or days = 23 );
      str = %char( days ) + 'rd';
    other;
      str = %char( days ) + 'th';
  endsl;

  // return date
  return str;
end-proc;

//==============================================================================
// STRING_words
//   Returns the number of words in the passed string
//==============================================================================

dcl-proc STRING_words export;
  dcl-pi *n like(INTEGER_t);
    str     like(STRING_t) const;
  end-pi;

  dcl-s w_count                 like(INTEGER_t) inz(0);
  dcl-c W_SPACE    ' ';
  dcl-s w_string                like(str);
  dcl-s w_pos                   like(INTEGER_t);


  w_string = %trim(str);
  dow (%check(w_space: w_string) > 0);
    w_pos = %scan(w_space: w_string);
    if (w_pos = 0);
      w_string = '';
    else;
      w_string = %trim(%subst(w_string: w_pos));
    endif;
    w_count += 1;
  enddo;

  return w_count;
end-proc;

//==============================================================================
// STRING_replace
//   Replaces all instances of the passed string
//==============================================================================

dcl-proc STRING_replace export;
  dcl-pi *n like(STRING_t);
    p_string  like(STRING_t) const;
    p_find    like(STRING_t) const;
    p_replace like(STRING_t) const;
  end-pi;

  dcl-s w_string              like(STRING_t);
  dcl-s w_pos                 like(INTEGER_t);
  dcl-s w_exit                like(BOOLEAN_t);

  /IF DEFINED(*V7R1M0)

  w_string = %scanrpl(p_find: p_replace: p_string);

  /ELSE

  w_string = p_string;
  w_exit   = false;

  w_pos = 1;
  dou w_exit;
    w_pos = %scan( p_find
                 : w_string
                 : w_pos );
    if w_pos > 0;
      w_string = %replace( p_replace
                         : w_string
                         : w_pos
                         : %len(p_find) );
      w_pos += %len(p_replace);
      if w_pos > %len(w_string);
        leave;
      endif;
    else;
      leave;
    endif;
  enddo;

  /ENDIF

  return w_string;
end-proc;

//==============================================================================
// STRING_upper
//   Returns a copy of the passed string in uppercase
//==============================================================================

dcl-proc STRING_upper export;
  dcl-pi *n like(STRING_t);
    str like(STRING_t) const;
  end-pi;

  dcl-s str_out like(STRING_t);

  /IF DEFINED(*V7R3M0)

  str_out = %upper(str);

  /ELSE

  str_out = CvtCase(str: 0)

  /ENDIF

  return str_out;
end-proc;

//==============================================================================
// STRING_lower
//   Returns a copy of the passed string in lowercase
//==============================================================================

dcl-proc STRING_lower export;
  dcl-pi *n like(STRING_t);
    str like(STRING_t) const;
  end-pi;

  dcl-s str_out like(STRING_t);

  /IF DEFINED(*V7R3M0)

  str_out = %lower(str);

  /ELSE

  str_out = CvtCase(str: 1)

  /ENDIF

  return str_out;
end-proc;

//********************************************************
//*  C V T C A S E  - Convert between lower/upper case
//*      Parameters:
//*                  InString - (Input) Text to convert
//*                  nOption  - (Input) Control Option
//*                                     0 = To Upper
//*                                     1 = To Lower
//*      Return Value: Converted input text.
//*      (c) Copyright 2002 by Robert Cozzi, Jr.
//*          All rights reserved.
//********************************************************
//* http://www.rpgworld.com/news05.html
//********************************************************

dcl-proc CvtCase;
  dcl-pi *n like(STRING_t);
    InString       like(STRING_t) Const;
    nOption        Int(5)     Const OPTIONS(*NOPASS);
  end-pi;

  dcl-pr QlgCvtCase  ExtProc('QlgConvertCase');
    ctrlBlock                 Const Like(FRCB);
    inString       Char(65535) Const Options(*VARSIZE);
    OutString      Char(65535) Options(*VARSIZE);
    nLength        Int(10)    Const;
    APIErrorDS     Char(16);
  end-pr;

  //*  Control Block for the call to QglConvertCase.
  dcl-ds FRCB;
    ReqType        Int(10)    Inz(1);
    CCSID          Int(10)    Inz(0);
    CvtTo          Int(10)    Inz(0);
    Reserved       Char(10)   Inz(*ALLX'00');
  end-ds;

  dcl-s OutString    Char(65535);
  dcl-s nLen         Int(10);
  dcl-s APIERRORDS   Char(16)   INZ(*ALLX'00');

  nLen = %Len(InString);
  if nLen <= 0;
    return '';
  endif;

  //*  QlgCvtCase uses 0 to convert to upper case, and 1 for lower
  //*  which is passed into this procedure on the nOption parm.
  //*  The parm value is copied to the FRCB.CvtTo subfield.
  if %Parms >= 2;
    CvtTo = nOption;
  else;
    reset CvtTo;
  endif;
  QlgCvtCase(FRCB : InString : OutString : nLen : APIErrorDS);

  return %subst(OutString: 1: nLen);
end-proc;

///
// Convert a string encoded in the job CCSID to UTF-8.
//
// @param String to convert, in the job CCSID.
// @return String encoded in UTF-8.
///

dcl-proc STRING_utf8 export;
  dcl-pi *n like(STRING_t) ccsid(*utf8);
    str_job_ccsid like(STRING_t) const;
  end-pi;

  dcl-s str_utf8 like(STRING_t) ccsid(*utf8);

  str_utf8 = str_job_ccsid;

  return str_utf8;
end-proc;

///
// Convert a hex value to a string of hex characters.
//
// @param hex value
// @param format hex string for output, defaults to true
// @return hex value as a character string
///

// TODO: sort out hex_to_str in RMMSG

dcl-proc STRING_hex export;
  dcl-pi *n like(STRING_t);
    hex_value pointer value;
    hex_len like(UNSIGNED_INTEGER_t) const;
    format_in like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-s digits          char(16) inz('0123456789ABCDEF');
  dcl-s digit           like(UNSIGNED_SMALLINT_t);
  dcl-c STRING_HEX_BASE const(16);

  dcl-ds hex_char_ds    based(hex_char_ptr);
    hex_char            char(1);
    hex_number          uns(3) overlay(hex_char);
  end-ds;
  dcl-s hex_char_ptr    pointer;
  dcl-s format          like(BOOLEAN_t) inz(true);
  dcl-s hex_str         like(STRING_t);
  dcl-s index           like(INTEGER_t);

  // Handle optional parameters
  if %passed(format_in);
    format = format_in;
  endif;

  for index = 1 to hex_len;
    hex_char_ptr = hex_value + index - 1;

    digit = %div(hex_number: STRING_HEX_BASE);
    hex_str += %subst(digits: digit+1: 1);
    digit = %rem(hex_number: STRING_HEX_BASE);
    hex_str += %subst(digits: digit+1: 1);
  endfor;

  if hex_str = '';
    hex_str = '*NULL';
  else;
    if format;
      hex_str = 'x''' + hex_str + '''';
    endif;
  endif;

  return hex_str;
end-proc;

///
// Convert a pointer address to a string of hex characters.
//
// @param The pointer to convert.
// @return hex value as a character string
///

dcl-proc STRING_ptr_to_hex export;
  dcl-pi *n like(STRING_t);
    ptr_in pointer value;
    format_in like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-ds ptr_ds;
    ptr      pointer;
    ptr_num  uns(20) pos(9);
  end-ds;

  dcl-s format like(BOOLEAN_t) inz(true);

  // Handle optional parameters
  if %passed(format_in);
    format = format_in;
  endif;

  ptr = ptr_in;

  return STRING_hex(%addr(ptr_num):8:format);
end-proc;
