**free

//==============================================================================
// RMAPP02    - Application Helper - DAL Module
//
// 11/11/2024 - RM - created
//==============================================================================

/include 'include/RMCOMP_H.rpgleinc'
/define APP_SERVICE_PROGRAM
/include 'include/RMTOOLS_H.rpgleinc'
ctl-opt text('RMTOOLS: Application Helper - DAL Module');

///
// Copybook definitions
///

/include 'include/RMAPP_D.rpgleinc'
/include 'include/RMTOOLS_D.rpgleinc'

///
// Calculates the DAL paging data
//
// The following params are input values:
// - calc.req_page      (set before call to DAL proc)
// - calc.req_page_rows (set before call to DAL proc)
// - calc.total_rows    (set in the DAL proc, before fetch)
//
// The following params are output values:
// - calc.total_pages
// - row_offset
// - page_size
//
// The following params are not used and should not be used:
// - calc.got_rows      (set in the DAL proc, after fetch)
///

dcl-proc APP_calc_page_data export;
  dcl-pi *n;
    calc likeds(APP_paging_t);
    page_size  like(INTEGER_t);
    row_offset like(INTEGER_t);
  end-pi;

  // Check for valid params
  if calc.req_page <= 0
    or calc.req_page_rows <= 0
    or calc.total_rows <= 0;

    calc.total_pages = 0;
    row_offset = 0;
    page_size = 0;
  else;

    // Calculate total pages
    monitor;
      calc.total_pages = %div(calc.total_rows: calc.req_page_rows);
      if %rem(calc.total_rows: calc.req_page_rows) >= 1;
        calc.total_pages += 1;
      endif;
    on-error;
      calc.total_pages = 0;
    endmon;

    // Calculate row offset
    row_offset = ((calc.req_page - 1) * calc.req_page_rows) + 1;
    if row_offset > calc.total_rows or row_offset < 0;
      row_offset = 0;
    endif;

    // Calculate page size
    if calc.req_page < calc.total_pages;
      page_size = calc.req_page_rows;
    else;
      page_size = (calc.total_rows - row_offset) + 1;
    endif;
    if page_size < 0 or page_size > calc.req_page_rows;
      page_size = 0;
    endif;
  endif;

  return;
end-proc;

///
// Add a string field value selection to the SQL WHERE clause
//
// @param the field name e.g. SUPPLIER_CODE
// @param the field string value e.g. ABC123, if the field value
//          is empty then the return string will be empty
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @param optional, boolean value indicating whether the
//          value should be wrapped in quotes, defaults
//          to true
// @return the constructed text portion of the where clause
//           e.g. " AND SUPPLIER_CODE = 'ABC123'"
///

dcl-proc APP_where_add_string export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    field_value like(STRING_SQL_t) const;
    selections_added like(SMALLINT_t);
    wrap_in_quotes like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);
  dcl-s l_wrap_in_quotes like(BOOLEAN_t) inz(true);

  if %parms() >= %parmnum(wrap_in_quotes);
    l_wrap_in_quotes = wrap_in_quotes;
  endif;

  if field_value <> '';
    if l_wrap_in_quotes;
      selection_text += field + ' = ''' + field_value + '''';
    else;
      selection_text += field + ' = ' + field_value;
    endif;

    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

///
// Add an integer field value selection to the SQL WHERE clause
//
// @param the field name e.g. DUE_DAYS
// @param the field integer value e.g. 30, if the field value
//          is zero then the return string will be empty
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//           e.g. " AND DUE_DAYS = 30"
///

dcl-proc APP_where_add_integer export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    field_value like(INTEGER_t) const;
    selections_added like(SMALLINT_t);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);

  if field_value <> 0;
    selection_text = field + ' = ''' + %char(field_value) + '''';

    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

///
// Add a string field value starts with selection to the SQL
// WHERE clause.
//
// @param the field name e.g. SUPPLIER_CODE
// @param the partial field string value e.g. ABC, if the field value
//          is empty then the return string will be empty
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//           e.g. " AND SUPPLIER_CODE LIKE 'ABC%'"
///

dcl-proc APP_where_add_starts_with export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    field_value like(STRING_SQL_t) const;
    selections_added like(SMALLINT_t);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);

  if field_value <> '';
    selection_text = field + ' LIKE ''' + field_value + '%''';

    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

///
// Add a string field value contains selection to the SQL WHERE
// clause.
//
// The contains selection is case insensitive, the column and
// values are converted to lowercase for comparison.
//
// @param the field name e.g. SUPPLIER_CODE
// @param the partial field string value e.g. ABC, if the field value
//          is empty then the return string will be empty
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//           e.g. " AND LOWER(SUPPLIER_CODE) LIKE '%abc%'"
///

dcl-proc APP_where_add_contains export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    field_value like(STRING_SQL_t) const;
    selections_added like(SMALLINT_t);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);

  if field_value <> '';
    selection_text = 'LOWER('+field+') LIKE ''%'+%lower(field_value)+'%''';

    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

///
// Add a date field value range selection to the SQL WHERE
// clause.
//
// Only non-empty date selections will be constructed. If both dates
// are empty then an empty string will be returned.
//
// @param the field name e.g. DUE_DATE
// @param the from date value e.g. 2023-09-01
// @param the to date value e.g. 2023-09-30
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @param optional, boolean value indicating whether the date
//          range is inclusive, defaults to true
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//         e.g. " AND DUE_DATE >= '2023-09-01' AND DUE_DATE <= '2023-09-30'"
///

dcl-proc APP_where_add_date_range export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    date_from like(DATE_t) const;
    date_to like(DATE_t) const;
    selections_added like(SMALLINT_t);
    inclusive like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);
  dcl-s inclusive_l like(BOOLEAN_t) inz(true);

  if %parms() >= %parmnum(inclusive);
    inclusive_l = inclusive;
  endif;

  if date_from <> EMPTY_DATE;
    if inclusive_l;
      selection_text = field + ' >= ''' + %char(date_from) + '''';
    else;
      selection_text = field + ' > ''' + %char(date_from) + '''';
    endif;
    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  if date_to <> EMPTY_DATE;
    if inclusive_l;
      selection_text = field + ' <= ''' + %char(date_to) + '''';
    else;
      selection_text = field + ' < ''' + %char(date_to) + '''';
    endif;
    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

///
// Add an integer field value range selection to the SQL WHERE
// clause.
//
// Only non-empty integer selections will be constructed. If both
// integers are empty then an empty string will be returned.
//
// @param the field name e.g. PRIORITY
// @param the from integer value e.g. 30
// @param the to integer value e.g. 40
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @param optional, boolean value indicating whether the
//          range is inclusive, defaults to true
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//         e.g. " AND PRIORITY >= 30 AND PRIORITY <= 40"
///

dcl-proc APP_where_add_integer_range export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    range_from like(INTEGER_t) const;
    range_to like(INTEGER_t) const;
    selections_added like(SMALLINT_t);
    inclusive like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);
  dcl-s inclusive_l like(BOOLEAN_t) inz(true);

  if %parms() >= %parmnum(inclusive);
    inclusive_l = inclusive;
  endif;

  if range_from <> 0;
    if inclusive_l;
      selection_text = field + ' >= ' + %char(range_from);
    else;
      selection_text = field + ' > ' + %char(range_from);
    endif;
    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  if range_to <> 0;
    if inclusive_l;
      selection_text = field + ' <= ' + %char(range_to);
    else;
      selection_text = field + ' < ' + %char(range_to);
    endif;
    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;

dcl-proc add_where_selection_text;
  dcl-pi *n like(STRING_SQL_t);
    selection_text like(STRING_SQL_t) const;
    selections_added like(SMALLINT_t);
  end-pi;

  dcl-s statement like(STRING_SQL_t);

  if selection_text <> '';
    if selections_added = 0;
      statement = 'WHERE ';
    elseif selections_added >= 1;
      statement = ' AND ';
    endif;

    statement += selection_text;
    selections_added += 1;
  endif;

  return statement;
end-proc;

///
// Add a field value in list selection to the SQL WHERE clause.
//
// @param the field name e.g. STOCK_POINT
// @param the field string value e.g. "'ND','N2','N3'" if the field value
//          is empty then the return string will be empty
// @param the number of selections currently added to the
//          where clause, this value will be incremented
// @return the constructed text portion of the where clause
//           e.g. " AND STOCK_POINT IN('ND','N2','N3')"
///

dcl-proc APP_where_add_in_list export;
  dcl-pi *n like(STRING_SQL_t);
    field like(STRING_SQL_t) const;
    field_value like(STRING_SQL_t) const;
    selections_added like(SMALLINT_t);
  end-pi;

  dcl-s statement like(STRING_SQL_t);
  dcl-s selection_text like(STRING_SQL_t);

  if field_value <> '';
    selection_text += field + ' IN (' + field_value + ')';

    statement += add_where_selection_text(selection_text: selections_added);
  endif;

  return statement;
end-proc;
