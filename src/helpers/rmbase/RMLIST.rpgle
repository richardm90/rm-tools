**free

//==============================================================================
// RMLIST     - List Helper Module
//
// 01/08/2023 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: List Helper Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Include copybooks
///

/include 'include/RMLIST_D.rpgleinc'
/include 'include/RMMSG_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==============================================================================
// Declare internal data structures
//==============================================================================

dcl-ds api_error_t qualified template inz;
  bytes_provided   int(10)    inz(%size(api_error_t));
  bytes_available  int(10)    inz(0);
  msgid            char(7);
  reserved         char(1);
  data             char(256);
end-ds;

// Structure to extend the size of the user space
dcl-ds QUSCUSAT_attrs qualified template inz;
  // Description field-by-field
  //   number_attrs = Number of attributes (1)
  //   1-element array of attribute definitions as follows:
  //     attr_key1  = Identify attribute to change (1=space size)
  //     attr_size1 = Length of the attribute itself
  //     attr_data1 = New value for this attribute
  number_attrs   int(10)    inz(0);
    attr_key1    int(10)    inz(0);
    attr_size1   int(10)    inz(0);
    attr_data1   int(10)    inz(0);
end-ds;

// Last error structure
dcl-ds last_api_error_g likeds(api_error_t) inz(*likeds);

// Key length used by the built-in compare_key_text comparator. The C
// qsort comparator cannot take a context argument, so LIST_sort_by_key
// passes the key length to it through module scope, setting it
// immediately before the qsort call. qsort drives the comparator
// synchronously and the comparator never re-enters the sort, so this is
// safe for normal single-threaded use (and each job has its own copy of
// module storage). Only matters if the module is ever run multithreaded,
// which it is not designed for.
dcl-s sort_key_size_g like(UNSIGNED_INTEGER_t) inz(0);

//==============================================================================
// Declare internal constants
//==============================================================================

dcl-c LIST_MAX_ROW_LENGTH 32767;
dcl-c LIST_MAX_SIZE_IN_BYTES 16773120;

//==============================================================================
// Declare internal prototypes
//==============================================================================

// Copy Bytes API
dcl-pr memcpy  extproc('memcpy');
  target       pointer  value;
  source       pointer  value;
  length       uns(10)  value;
end-pr;

// Compare Buffers API
dcl-pr memcmp  int(10) extproc('memcmp');
  target       pointer  value;
  source       pointer  value;
  length       uns(10)  value;
end-pr;

// Sort Array API (ILE C runtime)
// Sorts num_elems contiguous elements of elem_size bytes, starting at
// base, in place. The compare procedure is called with a pointer to two
// elements and must return <0, 0 or >0 (the memcmp convention).
dcl-pr qsort  extproc('qsort');
  base         pointer         value;
  num_elems    uns(10)         value;
  elem_size    uns(10)         value;
  compare      pointer(*proc)  value;
end-pr;

// Create User Space API
dcl-pr QUSCRTUS extpgm('QUSCRTUS');
  qual_user_space  char(20) const;
  ext_attr         char(10) const;
  init_size        int(10) const;
  init_value       char(1) const;
  pub_auth         char(10) const;
  text_desc        char(50) const;
  // Optional group 1
  replace          char(10) const options(*nopass);
  api_error        likeds(api_error_t) options(*nopass);
end-pr;

// Change User Space Attributes API
dcl-pr QUSCUSAT extpgm('QUSCUSAT');
  out_lib          char(10);
  qual_user_space  char(20) const;
  attr_list        likeds(QUSCUSAT_attrs) const;
  api_error        likeds(api_error_t);
end-pr;

// Retrieve Pointer to User Space API
dcl-pr QUSPTRUS  extpgm('QUSPTRUS');
  qual_user_space  char(20) const;
  user_space_p     pointer;
  // Optional group 1
  api_error        likeds(api_error_t) options(*nopass);
end-pr;

// Delete User Space API
dcl-pr QUSDLTUS extpgm('QUSDLTUS');
  qual_user_space  char(20) const;
  api_error        likeds(api_error_t);
end-pr;

///
// Create a list.
//
// This creates a list user space.
//
// @param list name, the user space name
// @param the size of each list entry data value
// @param optional, the size of each list entry key, if omiited then
//   no key value will be associated with the entry
// @param optional library name for the user space, if not specified
//   then defaults to QTEMP
// @return list structure
///

dcl-proc LIST_create export;
  dcl-pi *n        likeds(LIST_t);
    list_name      like(OBJ_NAME_t) const;
    val_size       like(INTEGER_t) const;
    key_size       like(INTEGER_t) const options(*omit:*nopass);
    lib_name       like(OBJ_NAME_t) const options(*nopass);
  end-pi;

  dcl-ds list likeds(LIST_t) inz(*likeds);
  dcl-s lib_name_l like(OBJ_NAME_t) inz('QTEMP');
  dcl-s key_size_l like(INTEGER_t);

  if %parms() >= %parmnum(key_size) and %addr(key_size) <> *null;
    key_size_l = key_size;
  endif;

  if %parms() >=  %parmnum(lib_name);
    lib_name_l = lib_name;
  endif;

  list.list_name = list_name;
  list.lib_name = lib_name_l;
  list.key_size = key_size_l;
  list.val_size = val_size;
  list.row_size = list.key_size + list.val_size;
  list.max_rows = %int(LIST_MAX_SIZE_IN_BYTES/list.row_size);

  create_user_space(list);

  return list;
end-proc;

///
// Set the size of the user space.
//
// @param list structure
// @param a pointer to the data row
// @return boolean indicating success
///

dcl-proc create_user_space;
  dcl-pi *n like(BOOLEAN_t);
    list likeds(LIST_t) const;
  end-pi;

  dcl-ds api_error likeds(api_error_t) inz(*likeds);
  dcl-s qualified_user_space char(20);
  dcl-s success like(BOOLEAN_t);

  qualified_user_space = list.list_name + list.lib_name;

  QUSCRTUS( qualified_user_space:
            '':
            1:
            x'00':
            '*ALL':
            '':
            '*YES':
            api_error );

  success = set_last_api_error(api_error);

  return success;
end-proc;

///
// Add a new row to a list user space.
//
// @param list structure
// @param a pointer to the row data value
// @param optional, a pointer to the row key value
// @return boolean indicating success
///

dcl-proc LIST_add export;
  dcl-pi *n  like(BOOLEAN_t);
    list     likeds(LIST_t);
    data_val pointer const;
    data_key pointer const options(*nopass);
  end-pi;

  dcl-s size like(INTEGER_t);
  dcl-s start like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s offset like(INTEGER_t);
  dcl-s success like(BOOLEAN_t);
  dcl-s data_key_l pointer;

  if %parms() >= %parmnum(data_key);
    data_key_l = data_key;
  endif;

  list.num_rows += 1;

  size = list.num_rows * list.row_size;
  set_user_space_size(list: size);

  retrieve_user_space_pointer(list: user_space_p);
  offset = ((list.num_rows - 1) * list.row_size);
  user_space_p += offset;

  // Store the key first
  // - copy the data key to the user space
  if %addr(data_key) <> *null;
    memcpy(user_space_p: data_key: list.key_size);
  endif;

  // Next store the value
  // - copy the data value to the user space
  user_space_p += list.key_size;
  memcpy(user_space_p: data_val: list.val_size);

  success = true;

  return success;
end-proc;

///
// Set the size of the user space.
//
// @param list structure
// @param a pointer to the data row
// @return boolean indicating success
///

dcl-proc set_user_space_size;
  dcl-pi *n like(BOOLEAN_t);
    list likeds(LIST_t) const;
    size like(INTEGER_t) const;
  end-pi;

  dcl-ds api_error likeds(api_error_t) inz(*likeds);
  dcl-ds attrs likeds(QUSCUSAT_attrs) inz(*likeds);
  dcl-s qualified_user_space char(20);
  dcl-s out_lib char(10);
  dcl-s success like(BOOLEAN_t);
  dcl-s size_l like(INTEGER_t);

  // Floor the user space size at 1, setting it to zero
  // will cause an MCH0601 exception
  size_l = size;
  if size_l < 1;
    size_l = 1;
  endif;

  qualified_user_space = list.list_name + list.lib_name;
  attrs.number_attrs = 1;
  attrs.attr_key1 = 1;
  attrs.attr_size1 = %size(INTEGER_t);
  attrs.attr_data1 = size_l;

  QUSCUSAT(out_lib: qualified_user_space: attrs: api_error);

  success = set_last_api_error(api_error);

  return success;
end-proc;

///
// Retrieve a pointer to the user space.
//
// @param list structure
// @param the returned pointer
// @return boolean indicating success
///

dcl-proc retrieve_user_space_pointer;
  dcl-pi *n like(BOOLEAN_t);
    list likeds(LIST_t) const;
    user_space_p pointer;
  end-pi;

  dcl-ds api_error likeds(api_error_t) inz(*likeds);
  dcl-s qualified_user_space char(20);
  dcl-s success like(BOOLEAN_t);

  qualified_user_space = list.list_name + list.lib_name;

  QUSPTRUS(qualified_user_space: user_space_p: api_error);

  success = set_last_api_error(api_error);

  return success;
end-proc;

///
// Retrieve a specific row from a list user space.
//
// @param list structure
// @param the row number (rrn) to retrieve
// @param a pointer to the row data value, the fetched row data
//   value will be placed here
// @param optional, a pointer to the row key value, if provided
//   the fetched row key value will be placed here
// @return boolean indicating success
///

dcl-proc LIST_get_by_rrn export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    rrn      like(INTEGER_t) const;
    data_val pointer const;
    data_key pointer const options(*nopass);
  end-pi;

  dcl-s offset like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s row_p pointer;

  retrieve_user_space_pointer(list: user_space_p);
  offset = ((rrn - 1) * list.row_size);

  // Retrieve the key first
  // - copy the data key from the user space
  if %parms() >= %parmnum(data_key);
    row_p = user_space_p + offset;
    memcpy(data_key: row_p: list.key_size);
  endif;

  // Next retrieve the value
  // - copy the data value from the user space
  row_p = user_space_p + offset + list.key_size;
  memcpy(data_val: row_p: list.val_size);

  list.cursor = rrn;

  return true;
end-proc;

///
// Retrieve a specific row from a list user space.
//
// @param list structure
// @param a pointer to the row data value, the fetched row data
//   value will be placed here
// @param a pointer to the row key value, this key value will
//   be used to fetch the row data value, the first matching
//   key will be matched
// @return boolean indicating success
///

dcl-proc LIST_get_by_key export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    data_val pointer const;
    data_key pointer const;
  end-pi;

  dcl-s offset like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s row_p pointer;
  dcl-s rrn like(INTEGER_t);
  dcl-s result int(10);
  dcl-s success like(BOOLEAN_t);

  retrieve_user_space_pointer(list: user_space_p);

  for rrn = 1 to list.num_rows;
    offset = ((rrn - 1) * list.row_size);

    // Compare the key
    row_p = user_space_p + offset;
    result = memcmp(data_key: row_p: list.key_size);
    if result = 0; // Identical
      // Copy the data value from the user space
      row_p = user_space_p + offset + list.key_size;
      memcpy(data_val: row_p: list.val_size);

      success = true;
      leave;
    endif;
  endfor;

  return success;
end-proc;

///
// Update a specific row from a list user space.
//
// @param list structure
// @param the row number (rrn) to update
// @param a pointer to the row data value, the list row data will
//   be updated with this value
// @param optional, a pointer to the row key value, the list row
//   key will be updated with this value
// @return boolean indicating success
///

dcl-proc LIST_update_by_rrn export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    rrn      like(INTEGER_t) const;
    data_val pointer const;
    data_key pointer const options(*nopass);
  end-pi;

  dcl-s offset like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s row_p pointer;

  retrieve_user_space_pointer(list: user_space_p);
  offset = ((rrn - 1) * list.row_size);

  // Update the key first
  // - copy the data key to the user space
  if %parms() >= %parmnum(data_key);
    row_p = user_space_p + offset;
    memcpy(row_p: data_key: list.key_size);
  endif;

  // Next update the value
  // - copy the data value to the user space
  row_p = user_space_p + offset + list.key_size;
  memcpy(row_p: data_val: list.val_size);

  return true;
end-proc;

///
// Update a specific row from a list user space.
//
// Note that the key value itself cannot be updated using this
// procedure, use the LIST_update_by_rrn procedure instead.
//
// @param list structure
// @param a pointer to the row data value, the list row data will
//   be updated with this value
// @param a pointer to the row key value, this key value will
//   be used to update the row data value, the first matching
//   key will be updated
// @return boolean indicating success
///

dcl-proc LIST_update_by_key export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    data_val pointer const;
    data_key pointer const;
  end-pi;

  dcl-s offset like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s row_p pointer;
  dcl-s rrn like(INTEGER_t);
  dcl-s result int(10);
  dcl-s success like(BOOLEAN_t);

  retrieve_user_space_pointer(list: user_space_p);

  for rrn = 1 to list.num_rows;
    offset = ((rrn - 1) * list.row_size);

    // Compare the key
    row_p = user_space_p + offset;
    result = memcmp(data_key: row_p: list.key_size);
    if result = 0; // Identical
      // Copy the data value to the user space
      row_p = user_space_p + offset + list.key_size;
      memcpy(row_p: data_val: list.val_size);

      success = true;
      leave;
    endif;
  endfor;

  return success;
end-proc;

///
// Delete a specific row from a list user space.
//
// @param list structure
// @param the row number (rrn) to delete
// @return boolean indicating success
///

dcl-proc LIST_delete_by_rrn export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    rrn      like(INTEGER_t) const;
  end-pi;

  dcl-s success like(BOOLEAN_t);

  if rrn < 1 or rrn > list.num_rows;
    success = false;
  else;
    success = delete_row(list: rrn);
  endif;

  return success;
end-proc;

///
// Delete a specific row from a list user space.
//
// @param list structure
// @param a pointer to the row key value, this key value will
//   be used to delete the row data value, the first matching
//   key will be deleted
// @return boolean indicating success
///

dcl-proc LIST_delete_by_key export;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    data_key pointer const;
  end-pi;

  dcl-s offset like(INTEGER_t);
  dcl-s user_space_p pointer;
  dcl-s row_p pointer;
  dcl-s rrn like(INTEGER_t);
  dcl-s result int(10);
  dcl-s success like(BOOLEAN_t);

  retrieve_user_space_pointer(list: user_space_p);

  for rrn = 1 to list.num_rows;
    offset = ((rrn - 1) * list.row_size);

    // Compare the key
    row_p = user_space_p + offset;
    result = memcmp(data_key: row_p: list.key_size);
    if result = 0; // Identical
      success = delete_row(list:rrn);
      leave;
    endif;
  endfor;

  return success;
end-proc;

///
// Delete a specific row from a list user space.
//
// @param list structure
// @param a pointer to the row key value, this key value will
//   be used to delete the row data value, the first matching
//   key will be deleted
// @return boolean indicating success
///

dcl-proc delete_row;
  dcl-pi *n like(BOOLEAN_t);
    list     likeds(LIST_t);
    rrn      like(INTEGER_t) const;
  end-pi;

  dcl-s user_space_p pointer;
  dcl-s to_p pointer;
  dcl-s from_p pointer;
  dcl-s rows_after like(INTEGER_t);
  dcl-s success like(BOOLEAN_t);
  dcl-s length like(UNSIGNED_INTEGER_t);
  dcl-s size like(INTEGER_t);

  retrieve_user_space_pointer(list: user_space_p);

  // Shuffle down trailing row data
  rows_after = list.num_rows - rrn;
  if rows_after > 0;
    to_p = user_space_p + ((rrn - 1) * list.row_size);
    from_p = to_p + list.row_size;
    length = rows_after * list.row_size;
    memcpy(to_p: from_p: length);
  endif;

  // Decrement list rows
  list.num_rows -= 1;

  // Reduce user space size
  size = list.num_rows * list.row_size;
  set_user_space_size(list: size);

  // Adjust cursor
  if list.cursor > rrn;
    list.cursor -= 1;
    if list.cursor < 0;
      list.cursor = 0;
    endif;
  endif;

  success = true;

  return success;
end-proc;

///
// Delete a list.
//
// This deletes the list user space.
//
// @param list structure
// @return boolean indicating success
///

dcl-proc LIST_delete export;
  dcl-pi *n like(BOOLEAN_t);
    list    likeds(LIST_t) const;
  end-pi;

  dcl-s success like(BOOLEAN_t);

  delete_user_space(list);

  success = true;

  return success;
end-proc;

///
// Position to a specific row in a list user space.
//
// Use in conjunction with LIST_fetch to position to a specific rrn. To
// position to the first row position pass a value of 1.
//
// @param list structure
// @param the row number to position to
// @return boolean indicating success
///

dcl-proc LIST_pos export;
  dcl-pi *n like(BOOLEAN_t);
    list    likeds(LIST_t);
    cursor  like(INTEGER_t) const;
  end-pi;

  if cursor < 0 or cursor > list.num_rows;
    return false;
  endif;

  list.cursor = cursor;

  return true;
end-proc;

///
// Fetch the next row from a list user space.
//
// @param list structure
// @param a pointer to the row data value, the fetched row data
//   value will be placed here
// @param optional, a pointer to the row key value, if provided
//   the fetched row key value will be placed here
// @return boolean indicating success
///

dcl-proc LIST_fetch export;
  dcl-pi *n like(BOOLEAN_t);
    list    likeds(LIST_t);
    data_val pointer const;
    data_key pointer const options(*nopass);
  end-pi;

  dcl-s found like(BOOLEAN_t);

  if list.cursor = 0;
    list.cursor = 1;
  endif;

  if list.cursor < 0 or list.cursor > list.num_rows;
    found = false;
  else;
    if %parms() >= %Parmnum(data_key);
      found = LIST_get_by_rrn(list: list.cursor: data_val: data_key);
    else;
      found = LIST_get_by_rrn(list: list.cursor: data_val);
    endif;
    list.cursor += 1;
  endif;

  return found;
end-proc;

///
// Sort a list user space in place.
//
// The rows of the list are reordered in place using the ILE C qsort
// API. The caller supplies a comparator procedure that receives a
// pointer to two rows and returns a value less than, equal to, or
// greater than zero when the first row sorts before, equal to, or
// after the second (the memcmp convention).
//
// Each row pointer addresses the raw row, laid out as the key value
// followed by the data value (key_size then val_size bytes). A keyless
// list has key_size 0, so the row pointer addresses the data value
// directly. Base a data structure on the pointer to compare fields.
//
// Sorting invalidates any prior cursor position, so the cursor is
// reset - fetch from the top afterwards.
//
// @param list structure
// @param a procedure pointer to the comparator, obtained with
//   %paddr, e.g. LIST_sort(list: %paddr(my_compare))
// @return boolean indicating success
///

dcl-proc LIST_sort export;
  dcl-pi *n like(BOOLEAN_t);
    list    likeds(LIST_t);
    compare pointer(*proc) const;
  end-pi;

  dcl-s user_space_p pointer;

  // Nothing to do for an empty or single row list
  if list.num_rows < 2;
    return true;
  endif;

  if not retrieve_user_space_pointer(list: user_space_p);
    return false;
  endif;

  qsort( user_space_p:
         list.num_rows:
         list.row_size:
         compare );

  // The rows have moved, so any cursor position is meaningless now
  list.cursor = 0;

  return true;
end-proc;

///
// Sort a keyed list user space by its key, in place.
//
// Convenience wrapper over LIST_sort that orders the list on its key
// value, compared as raw bytes (the natural order for character keys).
// The list must have been created with a key size; a keyless list
// returns false.
//
// Note the byte comparison is only a true ordering for character data
// and for unsigned big-endian numbers. Signed numeric keys, or any
// other ordering, need a caller-supplied comparator via LIST_sort.
//
// @param list structure
// @return boolean indicating success
///

dcl-proc LIST_sort_by_key export;
  dcl-pi *n like(BOOLEAN_t);
    list likeds(LIST_t);
  end-pi;

  if list.key_size <= 0;
    return false;
  endif;

  // Hand the key length to the comparator through module scope
  sort_key_size_g = list.key_size;

  return LIST_sort(list: %paddr(compare_key_text));
end-proc;

///
// Comparator for LIST_sort_by_key.
//
// Compares the leading key_size bytes of two rows as raw bytes. The
// key length is taken from sort_key_size_g, set by LIST_sort_by_key.
//
// @param a pointer to the first row
// @param a pointer to the second row
// @return negative, zero or positive per the memcmp convention
///

dcl-proc compare_key_text;
  dcl-pi *n int(10);
    row1 pointer value;
    row2 pointer value;
  end-pi;

  return memcmp(row1: row2: sort_key_size_g);
end-proc;

///
// Delete the user space.
//
// @param list structure
// @return boolean indicating success
///

dcl-proc delete_user_space;
  dcl-pi *n like(BOOLEAN_t);
    list likeds(LIST_t) const;
  end-pi;

  dcl-ds api_error likeds(api_error_t) inz(*likeds);
  dcl-s qualified_user_space char(20);
  dcl-s success like(BOOLEAN_t);

  qualified_user_space = list.list_name + list.lib_name;

  QUSDLTUS( qualified_user_space:
            api_error );

  success = set_last_api_error(api_error);

  return success;
end-proc;

///
// Set the last api error structure.
//
// @param api error structure
// @return boolean indicating success
///

dcl-proc set_last_api_error;
  dcl-pi *n like(BOOLEAN_t);
    api_error likeds(api_error_t) const;
  end-pi;

  dcl-s success like(BOOLEAN_t);

  last_api_error_g = api_error;

  success = (last_api_error_g.bytes_available = 0);

  if not success;
    sndmsg( '**ERROR: LIST service program -' +
            ' MSGID='+%trimr(last_api_error_g.msgid) +
            ', DATA='+%trimr(last_api_error_g.data) );
  endif;

  return success;
end-proc;
