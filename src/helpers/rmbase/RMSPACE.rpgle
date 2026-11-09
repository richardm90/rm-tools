**free

//==============================================================================
// RMSPACE    - User Space Helper Module
//
// 16/11/2024 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: User Space Helper Module');
/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'

///
// Include copybooks
///

/include 'include/RMSPACE_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

//==============================================================================
// Declare data structures
//==============================================================================

// API Error DS
dcl-ds gAPIError  qualified;
  bytesProvided   int(10)    inz(%size(gAPIError));
  bytesAvailable  int(10)    inz(0);
  msgID           char(7);
  reserved        char(1);
  data            char(256);
end-ds;

dcl-ds t_list qualified inz template;
  handle     like(INTEGER_t)  inz(0);
  lib        like(OBJ_NAME_t) inz('');
  space      like(OBJ_NAME_t) inz('');
  pointer    pointer          inz(*null);
  row_size   like(INTEGER_t)  inz(0);
  entries    like(INTEGER_t)  inz(0);
  cursor     like(INTEGER_t)  inz(0);
end-ds;

dcl-ds g_lists likeds(t_list) dim(c_SPACE_MAX_LISTS);

//==============================================================================
// Declare global fields
//==============================================================================

dcl-s g_error             like(BOOLEAN_t);
dcl-s g_error_msg         like(STRING_t);
dcl-s g_lists_count       like(INTEGER_t);
dcl-s g_lists_last_handle like(INTEGER_t);

//==============================================================================
// Declare global constants
//==============================================================================

dcl-c C_SPACE_MAX_LISTS 20;
dcl-c C_SPACE_MAX_ROW_LENGTH 32767;

//==============================================================================
// Declare prototypes
//==============================================================================

// Create User Space
dcl-pr qUsCrtUS  extpgm('QUSCRTUS');
  qualifiedSpaceName char(20);
  extndAttr          char(10);
  initSize           int(10);
  initValue          char(1);
  pubAuth            char(10);
  textDesc           char(50);
  replace            char(10);
  APIError           likeds(gAPIError);
end-pr;

// Retrieve User Space
dcl-pr qUsRtvUS  extpgm('QUSRTVUS');
  qualifiedSpaceName char(20);
  startPos           int(10);
  dataLen            int(10);
  rcvrVar            char(32767);
  APIError           likeds(gAPIError);
end-pr;

// Retrieve User Space Pointer
dcl-pr qUsPtrUS  extpgm('QUSPTRUS');
  qualifiedSpaceName char(20);
  spacePtr           pointer;
  APIError           likeds(gAPIError) options(*nopass);
end-pr;

// Change User Space
dcl-pr qUsChgUS  extpgm('QUSCHGUS');
  qualifiedSpaceName   char(20);
  startPos             int(10);
  dataLen              int(10);
  data                 char(32767);
  forceChgToAuxStorage char(1);
  APIError             likeds(gAPIError);
end-pr;

// Delete User Space
dcl-pr qUsDltUS  extpgm('QUSDLTUS');
  qualifiedSpaceName char(20);
  APIError           likeds(gAPIError);
end-pr;

//------------------------------------------------------------------------
// @Name - SPACE_create
// @Description - Create an OS/400 User Space.
// @Author - Aaron Bartell
// @Usage - SPACE_create(
//            Library:
//            SpaceName: ExtendedAttr: InitialSize: InitialValue: PublicAu
//------------------------------------------------------------------------
dcl-proc SPACE_create EXPORT;
  dcl-pi *n;
    pLibName       char(10)   value;
    pSpaceName     char(10)   value;
    pExtndAttr     char(10)   value;
    pInitSize      int(10)    value;
    pInitValue     char(1)    value;
    pPubAuth       char(10)   value;
    pTextDesc      char(50)   value;
    pReplace       char(10)   value;
  end-pi;

  dcl-s qualifiedSpaceName char(20);
  qualifiedSpaceName = pSpaceName + pLibName;

  // Initial size cannot be 0 or else this message will be produced 'CPF3C2C'.
  if pInitSize = 0;
    pInitSize = 1;
  endif;

  qUsCrtUS(
    qualifiedSpaceName:
    pExtndAttr:
    pInitSize: pInitValue: pPubAuth: pTextDesc: pReplace: gAPIError);

  return;
end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_new
// @Description - Create an OS/400 User Space (simple version).
// @Author - Aaron Bartell
// @Usage - SPACE_new(Library: SpaceName: *On: 1: x'00')
//------------------------------------------------------------------------
dcl-proc SPACE_new export;
  dcl-pi *n;
    pLibName       char(10)   value;
    pSpaceName     char(10)   value;
    pInitSize      int(10)    value options(*nopass);
    pInitValue     char(32767) value options(*nopass);
  end-pi;

  dcl-s hexNull      char(1)    inz(x'00');
  dcl-s initSize     int(10);
  dcl-s initValue    char(32767);
  dcl-s qualifiedObject char(21);

  if %Parms < 3;
    initSize = 1;
  else;
    initSize = pInitSize;
  endif;

  if %Parms < 4;
    initValue = hexNull;
  else;
    initValue = pInitValue;
  endif;

  qualifiedObject = pLibName + '/' + pSpaceName;
  SPACE_create(
    pLibName:
    pSpacename: ' ': initSize: initValue: '*ALL': ' ': '*YES');

  // Make sure this user space is automatically extending.
  SPACE_set_extendable(pLibName: pSpaceName: *On);

  return;

end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_retrieve
// @Description - Retrieve an OS/400 User Space.
// @Author - Aaron Bartell
// @Usage - variable = SPACE_retrieve(LibraryName: SpaceName: StartPositio
//------------------------------------------------------------------------
dcl-proc SPACE_retrieve export;
  dcl-pi *n char(32767);
    pLibName       char(10)   value;
    pSpaceName     char(10)   value;
    pStartPos      int(10)    value;
    pDataLen       int(10)    value;
  end-pi;

  dcl-s qualifiedSpaceName char(20);
  dcl-s rcvrVar      char(32767);

  qualifiedSpaceName = pSpaceName + pLibName;
  gAPIError = ' ';
  qUsRtvUS(
    qualifiedSpaceName: pStartPos: pDataLen: rcvrVar: gAPIError);

  return rcvrVar;
end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_change
// @Description - Change an OS/400 User Space.
// @Author - Aaron Bartell
// @Usage - SPACE_change(
//            LibraryName: SpaceName: StartPosition: DataLength: Data: For
//------------------------------------------------------------------------
dcl-proc SPACE_change export;
  dcl-pi *n;
    pLibName       char(10)   Value;
    pSpaceName     char(10)   Value;
    pStartPos      int(10)    Value;
    pDataLen       int(10)    Value;
    pData          char(32767) Value;
    pForceChgToAuxStorage char(1) Value options(*nopass);
  end-pi;

  dcl-s qualifiedSpaceName char(20);
  dcl-s l_ForceChgToAuxStorage char(1) inz('0');

  if %parms() >= %parmnum(pForceChgToAuxStorage);
    l_ForceChgToAuxStorage = pForceChgToAuxStorage;
  endif;

  qualifiedSpaceName = pSpaceName + pLibName;

  gAPIError = ' ';
  qUsChgUS(
    qualifiedSpaceName:
    pStartPos: pDataLen: pData: l_ForceChgToAuxStorage: gAPIError);

  return;
end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_retrieve_pointer
// @Description - Retrieve Pointer to OS/400 UserSpace.
// @Author - Aaron Bartell
// @Usage - pointerToSpace = SPACE_retrieve_pointer(LibraryName: SpaceName
//------------------------------------------------------------------------
dcl-proc SPACE_retrieve_pointer export;
  dcl-pi *n pointer;
    pLibName       char(10)   Value;
    pSpaceName     char(10)   Value;
  end-pi;

  dcl-s spacePtr     pointer;
  dcl-s qualifiedSpaceName char(20);

  qualifiedSpaceName = pSpaceName + pLibName;

  qUsPtrUS(qualifiedSpaceName: spacePtr);

  return spacePtr;
end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_delete
// @Description - Delete OS/400 UserSpace.
// @Author - Aaron Bartell
// @Usage - SPACE_delete(LibraryName: SpaceName)
//------------------------------------------------------------------------
dcl-proc SPACE_delete export;
  dcl-pi *n;
    pLibName       char(10)   Value;
    pSpaceName     char(10)   Value;
  end-pi;

  dcl-s qualifiedSpaceName char(20);

  qualifiedSpaceName = pSpaceName + pLibName;

  gAPIError = ' ';
  qUsDltUS(qualifiedSpaceName: gAPIError);

  return;
end-proc;

//------------------------------------------------------------------------
// @Name - SPACE_changeAttributes
// @Description - Change the attributes of a user space.
// @Author - Aaron Bartell
// @Usage - ?? = SPACE_changeAttributes(LibraryName: SpaceName)
//------------------------------------------------------------------------
dcl-proc SPACE_set_extendable export;
  dcl-pi *n;
    pLibName       char(10)   Value;
    pSpaceName     char(10)   Value;
    pExtend        Ind        Value;
  end-pi;


  // Change User Space Attributes
  dcl-pr qUsCUSAt  extpgm('QUSCUSAT');
    lib            char(10);
    qualifiedSpaceName char(20);
    attrList                  Like(changeAttrs);
    APIError                  likeds(gAPIError);
  end-pr;

  dcl-s qualifiedSpaceName char(20);
  dcl-s returnLib    char(10);

  // Structure to change the USRSPC attr to extendable
  dcl-ds changeAttrs;
    // Description field-by-field
    //   Number_Attrs = Number of attributes (1)
    //   1-element array of attribute definitions as follows:
    //     Attr_Key1 = Identify attribute to change (3=Extendable attr.)
    //     Attr_Siz1 = Length of the attribute itself (1)
    //     Attr_Dta1 = New value for this attribute (1="yes")
    Number_Attr    int(10)    Inz(1);
    Attr_Key1      int(10)    Inz(3);
    Attr_Siz1      int(10)    Inz(1);
    Attr_Dta1      char(1)    Inz('1');
  end-ds;

  Attr_Dta1 = pExtend;

  gAPIError = ' ';
  qualifiedSpaceName = pSpaceName + pLibName;
  qUsCUSAt(returnLib: qualifiedSpaceName: changeAttrs: gAPIError);

  return;
end-proc;

//========================================================================
// SPACE_exists
//   Determines whether the passed user space exists
//   - This subprocedure uses the user space retrieve pointer api to
//     determine whether the user space exists
//   - http://www.ibmsystemsmag.com/ibmi/developer/general/...
//     ... User-Spaces-and-List-APIs/?page=4
//========================================================================
dcl-proc SPACE_exists export;
  dcl-pi *n ind;
    library_name    char(10)   value;
    user_space_name char(10)   value;
  end-pi;

  dcl-s qualified_name char(20);
  dcl-s user_space_p   pointer;
  dcl-s exists         ind        inz(false);


  qualified_name = user_space_name + library_name;
  qusptrus(qualified_name: user_space_p: gAPIError);
  // CPF9801 = Object &2 in library &3 not found.
  if gAPIError.msgID = 'CPF9801';
    exists = false;
  else;
    exists = true;
  endif;

  return exists;
end-proc;

//========================================================================
// SPACE_list_new
//   Create a new list user space
//   - The global error state and message are set if an error occurs, and
//     in such a case the returned handle will be zero
//   - The return parameter is the handle to the created list, a value
//     greater than 1 indicates success
//========================================================================

dcl-proc SPACE_list_new export;
  dcl-pi *n    like(SPACE_LIST_HANDLE_t);
    lib_name   like(OBJ_NAME_t) const;
    space_name like(OBJ_NAME_t) const;
    row_size   like(INTEGER_t) const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s handle like(SPACE_LIST_HANDLE_t);

  if g_lists_count >= c_SPACE_MAX_LISTS;
    error(true: 'Already using the maximum number of lists');

  else;
    reset list;
    list.lib        = lib_name;
    list.space      = space_name;
    list.row_size   = row_size;
    handle = add_list(list);

    SPACE_list_inz(handle);

    error(false);
  endif;

  return handle;
end-proc;

//========================================================================
// SPACE_list_inz
//   Initialize an existing list user space
//========================================================================

dcl-proc SPACE_list_inz export;
  dcl-pi *n;
    handle like(SPACE_LIST_HANDLE_t) const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s l_pointer pointer;

  list = get_list(handle);

  SPACE_new(list.lib: list.space);

  l_pointer = SPACE_retrieve_pointer(list.lib: list.space);

  list.pointer = l_pointer;
  list.entries = 0;
  list.cursor  = 0;
  update_list(list);

  return;
end-proc;

//==============================================================================
// SPACE_list_delete
//   Delete the user space list
//==============================================================================

dcl-proc SPACE_list_delete export;
  dcl-pi *n;
    handle like(SPACE_LIST_HANDLE_t) const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);

  list = get_list(handle);
  delete_list(list);

  SPACE_delete(list.lib: list.space);

  return;
end-proc;

//==============================================================================
// SPACE_list_row_add
//   Add a data row 'list size' to the user space list
//==============================================================================

dcl-proc SPACE_list_row_add export;
  dcl-pi *n;
    handle    like(SPACE_LIST_HANDLE_t) const;
    list_data pointer const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s start like(INTEGER_t);
  dcl-s l_data_pointer pointer;
  dcl-s l_data char(c_SPACE_MAX_ROW_LENGTH) based(l_data_pointer);

  list  = get_list(handle);

  list.entries += 1;

  start = ( (list.entries - 1) * list.row_size ) + 1;

  l_data_pointer = list_data;

  SPACE_change( list.lib
              : list.space
              : start
              : list.row_size
              : l_data );

  update_list(list);

  return;
end-proc;

//==============================================================================
// SPACE_list_row_pos
//   Position the user space list cursor ready for SPACE_list_next
//   - If the cursor is not passed then the position is set to the beginning
//     of the user space list
//   - The returned boolean value indicates the procedure was successful
//==============================================================================

dcl-proc SPACE_list_row_pos export;
  dcl-pi *n like(BOOLEAN_t);
    handle  like(SPACE_LIST_HANDLE_t) const;
    cursor  like(INTEGER_t) options(*nopass) const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s l_cursor like(INTEGER_t) inz(0);
  dcl-s success like(BOOLEAN_t) inz(false);

  if %parms() >= %parmnum(cursor);
    l_cursor = cursor;
  endif;

  list = get_list(handle);

  if l_cursor < 0 or l_cursor > list.entries;
    error(true: 'Invalid cursor position requested');

  else;
    list.cursor = l_cursor;
    update_list(list);

    success = true;
  endif;

  return success;
end-proc;

//==============================================================================
// SPACE_list_row_first
//   Returns the first row from the list user space
//   - This also positions the cursor at the first row so a subsequent call to
//     SPACE_list_next would return the second row and so on
//   - The returned boolean value indicates the procedure was successful and
//     the data parameter will point to the data row
//==============================================================================

dcl-proc SPACE_list_row_first export;
  dcl-pi *n like(BOOLEAN_t);
    handle  like(SPACE_LIST_HANDLE_t) const;
    data    pointer;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s found like(BOOLEAN_t) inz(false);

  list = get_list(handle);

  if list.entries < 1;
    error(true: 'User space list contains no rows');

  else;
    list.cursor = 1;

    data = get_list_data(list);
    found = true;

    update_list(list);
  endif;

  return found;
end-proc;

//==============================================================================
// SPACE_list_row_next
//   Returns the next row from the list user space
//   - This also positions the cursor at the next row, ready for a further call
//     to SPACE_list_next
//   - The returned boolean value indicates the procedure was successful and
//     the data parameter will point to the data row
//==============================================================================

dcl-proc SPACE_list_row_next export;
  dcl-pi *n like(BOOLEAN_t);
    handle  like(SPACE_LIST_HANDLE_t) const;
    data    pointer;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s found like(BOOLEAN_t) inz(false);

  list = get_list(handle);

  if list.cursor >= list.entries;
    error(true: 'User space list contains no more rows');

  else;
    list.cursor += 1;

    data = get_list_data(list);
    found = true;

    update_list(list);
  endif;

  return found;
end-proc;

//==============================================================================
// get_list_data
//   Returns a pointer to the given list cursor
//==============================================================================

dcl-proc get_list_data;
  dcl-pi *n pointer;
    list    likeds(t_list) const;
  end-pi;

  dcl-s data pointer;

  data = list.pointer
       + ( (list.cursor - 1) * list.row_size );

  return data;
end-proc;

//========================================================================
// add_list
//   Add the list the global list
//========================================================================

dcl-proc add_list;
  dcl-pi *n like(INTEGER_t);
    list    likeds(t_list);
  end-pi;

  dcl-s handle like(SPACE_LIST_HANDLE_t);

  g_lists_last_handle += 1;
  handle = g_lists_last_handle;
  list.handle = handle;

  g_lists_count += 1;
  g_lists(g_lists_count) = list;

  return handle;
end-proc;

//========================================================================
// get_list
//   Return details of the given list handle
//========================================================================

dcl-proc get_list;
  dcl-pi *n likeds(t_list);
    handle  like(SPACE_LIST_HANDLE_t) const;
  end-pi;

  dcl-ds list likeds(t_list) inz(*likeds);
  dcl-s index like(INTEGER_t);

  for index = 1 to g_lists_count;
    if g_lists(index).handle = handle;
      list = g_lists(index);
      leave;
    endif;
  endfor;

  return list;
end-proc;

//========================================================================
// update_list
//   Updates the given list
//========================================================================

dcl-proc update_list;
  dcl-pi *n;
    list    likeds(t_list) const;
  end-pi;

  dcl-s index like(INTEGER_t);

  for index = 1 to g_lists_count;
    if g_lists(index).handle = list.handle;
      g_lists(index) = list;
      leave;
    endif;
  endfor;

  return;
end-proc;

//========================================================================
// delete_list
//   Delete the given list
//========================================================================

dcl-proc delete_list;
  dcl-pi *n;
    list    likeds(t_list) const;
  end-pi;

  dcl-s index like(INTEGER_t);
  dcl-s shuffle_down like(BOOLEAN_t);

  for index = 1 to g_lists_count;
    if g_lists(index).handle = list.handle;
      shuffle_down = true;
    elseif shuffle_down;
      g_lists(index-1) = g_lists(index);
    endif;
  endfor;

  g_lists_count -= 1;

  return;
end-proc;

//========================================================================
// qualname
//   Return the qualified object name from the given object and library
//========================================================================

dcl-proc qualname;
  dcl-pi *n  like(QUAL_OBJ_NAME_t);
    lib_name like(OBJ_NAME_t) const;
    obj_name like(OBJ_NAME_t) const;
  end-pi;

  dcl-s l_qualname like(QUAL_OBJ_NAME_t);

  l_qualname = obj_name + lib_name;

  return l_qualname;
end-proc;

//========================================================================
// error
//   Global error state setter and getter
//   - If the p_error parameter is passed then g_error will be set
//   - If the p_error_msg parameter is passed then g_error_msg will be set
//   - The current g_error boolean is returned
//========================================================================
dcl-proc error;
  dcl-pi *n     like(BOOLEAN_t);
    p_error     like(BOOLEAN_t) options(*nopass) const;
    p_error_msg like(STRING_t)  options(*nopass) const;
  end-pi;

  if %parms() >= %parmnum(p_error);
    g_error = p_error;
  endif;

  if %parms() >= %parmnum(p_error_msg);
    g_error_msg = p_error_msg;
  endif;

  return g_error;
end-proc;

//========================================================================
// error_msg
//   Global error message state setter and getter
//   - If the
//   - The current g_error_msg string is returned
//========================================================================
dcl-proc error_msg;
  dcl-pi *n     like(STRING_t);
    p_error_msg like(STRING_t) options(*nopass) const;
  end-pi;

  if %parms() >= %parmnum(p_error_msg);
    g_error_msg = p_error_msg;
  endif;

  return g_error_msg;
end-proc;
