create or replace package body "EDIT_FUNCTIONS" as
 
 /************************************************************************************
 *
 * internal parameter validations
 *
 ************************************************************************************/
 
 /*
  * is_app_editable
  *
  * Returns: true if the app with the given ID exists and is not marked as internal. Internal apps cannot be edited by the AI
  */
 function is_app_editable(p_app_id in number)
 return boolean
 is
  v_exists number;
 begin
 
  select count(*)
    into v_exists
    from APEX_APPLICATIONS
   where nvl(APPLICATION_GROUP, 'NONE') != 'INTERNAL'
     and upper(APPLICATION_ID) = upper(p_app_id);
  
   return v_exists > 0;
 end is_app_editable;
 
 /*
  * is_page_in_app
  *
  * Returns: an appropriate error message if the p_page_id is not in the app, or the app does not exist
  *          Or null, if the page exists inside that app
  */
 function check_page_is_in_app(p_app_id in number, p_page_id number)
 return varchar2
 is
  v_exists number;
 begin
 
  if not is_app_editable(p_app_id => p_app_id)
  then
    return 'There is no app with the given app_id';
  end if;

  select count(*)
    into v_exists
    from APEX_APPLICATION_PAGES
   where APPLICATION_ID = p_app_id
     and PAGE_ID = p_page_id;    
  
   if v_exists <= 0
   then
    return 'There is no page with the given id in that app';
   end if;
   
   return null;
 end check_page_is_in_app;
 
 /*
  * check_region_is_on_page
  *
  * Returns: an appropriate error message if the p_region_id is not on the page, or the app or page does not exist
  *          Or null, if the region exists on that page
  */ 
  function check_region_is_on_page(p_app_id in number, p_page_id in number, p_region_id in number)
  return varchar2
  is
    v_page_error varchar2(4000);
    v_exists number;
  begin
  
    v_page_error := check_page_is_in_app(p_app_id => p_app_id, p_page_id => p_page_id);
    if v_page_error is not null
    then 
      return v_page_error;
    end if;
    
    select count(*)
      into v_exists
      from APEX_APPLICATION_PAGE_REGIONS
     where APPLICATION_ID = p_app_id
       and PAGE_ID = p_page_id
       and REGION_ID = p_region_id;    
    
    if v_exists <= 0
    then
      return 'There is no region with the given id in that page';
    end if;
    
    return null;
  
  end check_region_is_on_page;
 
 /*
  * check_column_is_in_ir
  *
  * Returns: an appropriate error message if the column is not in the IR region, or the region, page or app does not exists
  *          Or null, if the column exists inside that IR region
  */ 
  function check_column_is_in_region(p_app_id in number, p_page_id in number, p_region_id in number, p_column_id in number)
  return varchar2
  is
    v_error varchar2(4000);
    v_exists number;
  begin
  
    v_error := check_region_is_on_page(p_app_id => p_app_id, p_page_id => p_page_id, p_region_id => p_region_id);
    if v_error is not null
    then
      return v_error;
    end if;
    
    select count(*)
      into v_exists
      from APEX_APPLICATION_PAGE_IR_COL
     where APPLICATION_ID = p_app_id
       and PAGE_ID = p_page_id
       and REGION_ID = p_region_id
       and COLUMN_ID = p_column_id; 
    
    if v_exists <= 0
    then
      return 'There is no column with the given id in that region';
    end if; 
    
    return null;
  
  end check_column_is_in_region; 
 
 
/************************************************************************************
 *
 * ID calculation Utitlity functions
 *
 ************************************************************************************/
 
  /*
   * get_region_id_by_name
   *
   * Returns: Json structure containing all region IDs on the given page that match the given region title
   */
  function get_region_id_by_name(p_region_title in varchar2, p_page_id in number, p_app_id in number) 
  return varchar2
  is
    v_result_count number := 0;
    v_result varchar2(4000) := '';
    v_page_error varchar2(4000);
  begin

    v_page_error := check_page_is_in_app(p_app_id => p_app_id, p_page_id => p_page_id);
    if v_page_error is not null
    then 
      return v_page_error;
    end if;
  
    for region in ( select REGION_ID,
                           REGION_NAME
                      from APEX_APPLICATION_PAGE_REGIONS
                     where APPLICATION_ID = p_app_id
                       and PAGE_ID = p_page_id
                       and upper(REGION_NAME) = upper(p_region_title))
    loop
      -- count how many pages were found
      v_result_count := v_result_count + 1;

      if v_result_count = 1
      then
        --Start JSON Array
        v_result := '[';
      else
        --Insert comma for next element in JSON Array
        v_result := v_result || ', ';
      end if;

      -- append the found region's info to the result
      v_result := v_result || '{"REGION_TITLE": "' || region.region_name || '", "REGION_ID": "' || region.region_id || '"}';

    end loop;

    if v_result_count > 0
    then
      return v_result || ']';
    else
      return 'I found no regions on the given page that match the given region title. Could there be a spelling error?';
    end if;

  end get_region_id_by_name;
 
  /*
   * get_page_id_by_name
   *
   * Returns: A json array with all pages (and the apps in which they lie) that have the given name or title
   */
  function get_page_id_by_name(p_page_name in varchar2, p_app_id in number) 
  return varchar2
  is
    v_result_count number := 0;
    v_result varchar2(4000) := '';
  begin

    for page in ( select p.APPLICATION_NAME app_name, 
                         p.APPLICATION_ID app_id,
                         p.PAGE_ID,
                         p.PAGE_NAME,
                         p.PAGE_TITLE
                    from APEX_APPLICATION_PAGES p
                    join APEX_APPLICATIONS app
                      on p.APPLICATION_ID = app.APPLICATION_ID
                   where p.APPLICATION_ID = p_app_id
                     and nvl(app.APPLICATION_GROUP, 'NONE') != 'INTERNAL'
                     and (upper(p.PAGE_NAME) = upper(p_page_name)
                          or upper(p.PAGE_TITLE) = upper(p_page_name)))
    loop
      -- count how many pages were found
      v_result_count := v_result_count + 1;

      if v_result_count = 1
      then
        --Start JSON Array
        v_result := '[';
      else
        --Insert comma for next element in JSON Array
        v_result := v_result || ', ';
      end if;

      -- append the found page's info to the result
      v_result := v_result || '{"APP": "' || page.app_name || '", "APP_ID": "' || page.app_id|| '", "PAGE_ID": "' || page.page_id || '", "PAGE_TITLE": "' || page.page_title || '"}';

    end loop;

    if v_result_count > 0
    then
      return v_result || ']';
    else
      return 'I found no pages that match the given page name. could there be a spelling error?';
    end if;

  end get_page_id_by_name;

  /*
   * get_page_and_app_id_by_name
   *
   * Returns: A json array with all pages (and the apps in which they lie) that have the given name or title. Only searches within the given app.
   */
  function get_page_and_app_id_by_name(p_page_name in varchar2) 
  return varchar2
  is
    v_result_count number := 0;
    v_result varchar2(4000) := '';
  begin

    for page in (select p.APPLICATION_NAME app_name, 
                        p.APPLICATION_ID app_id,
                         p.PAGE_ID,
                         p.PAGE_NAME,
                         p.PAGE_TITLE
                    from APEX_APPLICATION_PAGES p
                    join APEX_APPLICATIONS app
                      on p.APPLICATION_ID = app.APPLICATION_ID
                   where nvl(app.APPLICATION_GROUP, 'NONE') != 'INTERNAL'
                     and (upper(p.PAGE_NAME) = upper(p_page_name)
                          or upper(p.PAGE_TITLE) = upper(p_page_name)))
    loop
      -- count how many pages were found
      v_result_count := v_result_count + 1;

      if v_result_count = 1
      then
        --Start JSON Array
        v_result := '[';
      else
        --Insert comma for next element in JSON Array
        v_result := v_result || ', ';
      end if;

      -- append the found page's info to the result
      v_result := v_result || '{"APP": "' || page.app_name || '", "APP_ID": "' || page.app_id|| '", "PAGE_ID": "' || page.page_id || '", "PAGE_TITLE": "' || page.page_title || '"}';

    end loop;

    if v_result_count > 0
    then
      return v_result || ']';
    else
      return 'I found no pages that match the given page name. could there be a spelling error?';
    end if;

  end get_page_and_app_id_by_name;

  /*
   * Get APP ID by name
   *
   * Returns: 
   */
  function get_app_id_by_name(p_app_name in varchar2)
  return varchar2
  is
    v_result_count number := 0;
    v_result varchar2(4000) := '';
  begin

    --apex_debug.info();

    for app in (select APPLICATION_NAME app_name, 
                       APPLICATION_ID app_id
                  from APEX_APPLICATIONS
                 where nvl(APPLICATION_GROUP, 'NONE') != 'INTERNAL'
                   and upper(APPLICATION_NAME) = upper(p_app_name))
    loop
      -- count how many pages were found
      v_result_count := v_result_count + 1;

      if v_result_count = 1
      then
        --Start JSON Array
        v_result := '[';
      else
        --Insert comma for next element in JSON Array
        v_result := v_result || ', ';
      end if;

      -- append the found page's info to the result
      v_result := v_result || '{"APPLICATION_NAME": "' || app.app_name || '", "APP_ID": "' || app.app_id || '"}';

    end loop;

    if v_result_count > 0
    then
      return v_result || ']';
    else
      return 'There are no apps with that exact name. Check if there are similarly named apps.';
    end if;

  end get_app_id_by_name;
  
  /*
   * get_all_available_apps
   *
   * Returns: A json structure with all apps including their names and IDs that can be edited. This does not include apps in the "INTERNAL" app group.
   */
  function get_all_available_apps
  return clob
  is
    v_apps clob;
  begin
  
    select '[' || LISTAGG('{"app_name": ' || APPLICATION_NAME || ', "app_id": "' || APPLICATION_ID || '"}', ', ') WITHIN GROUP (ORDER BY APPLICATION_ID) || ']' apps
      into v_apps
      from APEX_APPLICATIONS
     where nvl(APPLICATION_GROUP, 'NONE') != 'INTERNAL';

    return v_apps;
  end get_all_available_apps;

  /*
   * set_current_page_and_app_id
   *
   * Returns: 
   */
  function set_current_page_and_app_id(p_app_id in number default null, p_page_id in number default null) 
  return varchar2
  is
  begin
    APEX_UTIL.set_session_state(p_name => 'P' || v('APP_PAGE_ID') ||'_APP_ID'
                               ,p_value => p_app_id);
    -- the _PAGE_ID_RETURN item is the relevant one. It is a hidden item that ensures the Page_ID Item's LOV is refreshed correctly (in case of a new page being selected)                          
    APEX_UTIL.set_session_state(p_name => 'P' || v('APP_PAGE_ID') || '_PAGE_ID_RETURN'
                               ,p_value => p_page_id);
    APEX_UTIL.set_session_state(p_name => 'P' || v('APP_PAGE_ID') || '_PAGE_ID'
                               ,p_value => p_page_id);                           
    return 'Successfully set the application and page IDs of the page that is supposed to be edited.';
  end set_current_page_and_app_id;

  /*
   * Get all Page IDs in Application
   *
   * Returns: A comma separated list of all Page IDs in the given Application that are already used
   */
  function get_used_pageids_in_app(p_app_id in number)
  return clob
  is 
    v_page_ids clob;
  begin
    select LISTAGG(PAGE_ID, ', ') WITHIN GROUP (ORDER BY PAGE_ID) page_ids
      into v_page_ids
      from APEX_APPLICATION_PAGES
     where APPLICATION_ID = p_app_id;

    return v_page_ids;
  end get_used_pageids_in_app;
  
  /*
   * get_regions_on_page
   *
   * Returns: A JSON Array of objects that each list the region title and ID of one region on the given page
   */
  function get_regions_on_page(p_app_id in number, p_page_id in number)
  return clob
  is
    v_regions clob;
    v_page_error varchar2(4000);
  begin
  
    apex_debug.info('p_app_id: ' || p_app_id);
    apex_debug.info('p_page_id: ' || p_page_id);
    
    v_page_error := check_page_is_in_app(p_app_id => p_app_id, p_page_id => p_page_id);
    if v_page_error is not null
    then 
      return v_page_error;
    end if;
  
    select '[' || LISTAGG('{"region_id": ' || region_id || ', "region_title": "' || region_name || '"}', ', ') WITHIN GROUP (ORDER BY region_id) || ']' regions
      into v_regions
      from APEX_APPLICATION_PAGE_REGIONS
     where application_id = p_app_id
       and page_id = p_page_id;

    return v_regions;
  end get_regions_on_page;
  
  /*
   * get_column_id_by_label
   *
   * Returns: A JSON Array of objects that each list the column ID, its label and its region's title for all columns on the given page that have the given label
   */
  function get_column_id_by_label(p_app_id in number, p_page_id in number, p_column_label in varchar2)
  return clob
  is
    v_columns clob;
  begin
    
    select '[' || LISTAGG('{"column_id": ' || column_id || ', "column_label": ' || report_label || ', "column_alias": ' || column_alias || ', "column_type: "' || display_text_as || ', "region_title": "' || region_name || '"}', ', ') WITHIN GROUP (ORDER BY column_id) || ']' col
      into v_columns
      from APEX_APPLICATION_PAGE_IR_COL
     where application_id = p_app_id
       and page_id = p_page_id
       and (upper(p_column_label) = upper(report_label) or upper(p_column_label) = upper(form_label) or upper(p_column_label) = upper(column_alias));

    return v_columns;
  end get_column_id_by_label;
  
  /*
   * get_displayed_columns_in_region
   *
   * Returns: A JSON Array of objects that each list the column ID, its label, alias and display type in the given region
   */
  function get_displayed_columns_in_region(p_app_id in number, p_page_id in number, p_region_id in number)
  return clob
  is
    v_columns clob;
    v_error varchar2(4000);
  begin
  
    v_error := check_region_is_on_page(p_app_id => p_app_id, p_page_id => p_page_id, p_region_id => p_region_id);
    if v_error is not null
    then
      return v_error;
    end if;
    
    select '[' || LISTAGG('{"column_id": ' || column_id || ', "column_label": ' || report_label || ', "column_alias": ' || column_alias || ', "column_type: "' || display_text_as || '"}', ', ') WITHIN GROUP (ORDER BY column_id) || ']' col
      into v_columns
      from APEX_APPLICATION_PAGE_IR_COL
     where application_id = p_app_id
       and page_id = p_page_id
       and region_id = p_region_id;

    return v_columns;
  end get_displayed_columns_in_region;  
  
  /*
   * get_page_item_by_label
   *
   * Returns: A JSON Array of objects that each list the region, item name and item label for all page_items on the given page that have the given label
   */  
  function get_page_item_by_label(p_app_id in number, p_page_id in number, p_item_label in varchar2)
  return clob
  is
    v_pageitems clob;
  begin
    select '[' || LISTAGG('{"region": ' || region || ', "item_name": ' || item_name || ', "item_label": "' || label || '"}', ', ') WITHIN GROUP (ORDER BY region, item_name) || ']' items
      into v_pageitems
      from APEX_APPLICATION_PAGE_ITEMS
     where application_id = p_app_id
       and page_id = p_page_id
       and (upper(p_item_label) = upper(label) 
            or upper(p_item_label) = upper(item_name));
       
      return v_pageitems;
  end get_page_item_by_label; 
  
  /*
   * get_page_items_on_page
   *
   * Returns: A JSON Array with all page items on the given page
   */  
  function get_page_items_on_page(p_app_id in number, p_page_id in number)
  return clob
  is
    v_pageitems clob;
  begin
    select '[' || LISTAGG('{"region": ' || region || ', "item_name": ' || item_name || ', "item_label": "' || label || '"}', ', ') WITHIN GROUP (ORDER BY region, item_name) || ']' items
      into v_pageitems
      from APEX_APPLICATION_PAGE_ITEMS
     where application_id = p_app_id
       and page_id = p_page_id;
       
      return v_pageitems;
  end get_page_items_on_page;

/************************************************************************************
 *
 * DB retrieval functions
 *
 ************************************************************************************/

  /*
   * get_existing_table_names
   *
   * Returns: A commaseparated list of all table names in the DB that do not belong to the APEX_GPT App
   */
  function get_existing_table_names
  return clob
  is
    v_table_desc clob;
  begin
  
    select listagg(table_name, ', ') within group (order by table_name) 
      into v_table_desc
      from user_tables 
     where upper(table_name) not like 'TCH%' and upper(table_name) not like 'DEBUG%';
     
    return v_table_desc;
  end get_existing_table_names;
  
  
  /*
   * desc_db_table
   *
   * Param: p_table_name: the name of the table to be described 
   * Returns: The description of the database table with the given name as a commaseparated list of the column names with the respective datatype in parentheses behind each name 
   */
  function desc_db_table(p_table_name in varchar2)
  return clob
  is
    v_table_desc clob;
  begin
    /* --simple description
    select listagg(column_name || ' (' || data_type || ')', ', ') within group (order by column_name)
      into v_table_desc
      from user_tab_columns 
     where upper(table_name) = upper(p_table_name);
     */
     
     -- exclude the storage and segment attributes from the ddl statement
     dbms_metadata.set_transform_param(transform_handle => dbms_metadata.session_transform
                                      ,name => 'STORAGE'
                                      ,value => false);
     dbms_metadata.set_transform_param(transform_handle => dbms_metadata.session_transform
                                      ,name => 'SEGMENT_ATTRIBUTES'
                                      ,value => false);
     -- get complete DDL (create table) statement as a table description
     v_table_desc := dbms_metadata.get_ddl('TABLE', upper(p_table_name));
     apex_debug.info('DDL of table ' || p_table_name);
     apex_debug.info(lower(v_table_desc));
    
     -- return lower case version of ddl statement because lower case takes up less tokens
     return lower(v_table_desc);
     
  exception when others  
  then
    return 'error while calling function desc_db_table. It is likely that there was no table with that name found. error message: ' || lower(SQLERRM);
  end desc_db_table;
  
  /*
   * get_region_sql_statement
   * 
   * returns a table region's sql statement
   */
  function get_region_sql_statement(p_region_id in number)
  return clob
  is
    v_sql_query clob;
  begin
    select sql_query
      into v_sql_query
      from APEX_APPLICATION_PAGE_IR
     where region_id = p_region_id;
     
     return v_sql_query;
  exception when no_data_found
  then
    return 'the region with that id could not be found';   
  when others
  then
    return 'error while calling function. error message: ' || lower(SQLERRM);
  end get_region_sql_statement;

/************************************************************************************
 *
 * Create functions
 *
 ************************************************************************************/
 
  /*
   * create_new_page
   * 
   * Creates a new empty page in the given APEX application with a given ID and title.
   * 
   * Returns: A confirmation text if the import was successful or an error text otherwise
   */
  function create_new_page(p_app_id in number, p_page_id in number, p_page_title in varchar2) 
  return clob
  is
    v_forget_result varchar2(4000);
    v_exists number;
  begin

    -- check that app exists
    select count(*)
      into v_exists
      from apex_applications
     where application_id = p_app_id;
     
    if v_exists <= 0
    then
      return 'error: there is no application with this id';
    end if;
    
    select count(*)
      into v_exists
      from apex_application_pages
     where application_id = p_app_id
       and page_id = p_page_id;
     
    if v_exists > 0
    then
      return 'error: this page id is already taken';
    end if;
    
    -- Check that page alias isn't taken yet
    select count(*)
      into v_exists
      from apex_application_pages 
     where application_id = p_app_id
       and lower(page_alias) = replace(trim(lower(p_page_title)), ' ', '-');
    
    if v_exists > 0
    then
      return 'error: a page with this title already exists';
    end if;
    
    apex_editor.create_new_empty_page (p_app_id        => p_app_id
                                      ,p_page_id      => p_page_id
                                      ,p_page_title   => p_page_title);

    v_forget_result := edit_functions.set_current_page_and_app_id (p_app_id   => p_app_id
                                                                  ,p_page_id  => p_page_id);

    apex_debug.info('Page ' || p_page_title || ' in application ' || p_app_id || ' was created.');


    return 'Page successfully created.';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_page. error message: ' || lower(SQLERRM); -- old msg: Could it be that the page title is already taken?
  end create_new_page; 
 
  /*
   * create_new_text_region
   *
   * Creates a new simple text region (static content region) with the given title in the given application on the given page.
   */
  function create_new_text_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_region_text in clob default '')
  return clob
  is 
  begin
    
    apex_editor.create_new_text_region(p_app_id       => p_app_id
                                      ,p_page_id      => p_page_id
                                      ,p_region_title => p_region_title
                                      ,p_region_text  => p_region_text);  
    
    return 'Region successfully created';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_text_region. error message: ' || lower(SQLERRM); 
  end create_new_text_region;
  
  
  /*
   * create_new_table_region
   *
   * Creates a new table (interactive report) on the given page in the given app based on the columns and data returned by the SQL statement 
   */
  function create_new_table_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_sql_statement clob)
  return clob
  is
    v_columns_desc db_utils.t_sql_desc := db_utils.t_sql_desc();
    v_region_id number;
  begin
  
    apex_debug.info('Create table region called! Source SQL:');
    apex_debug.info(p_sql_statement);
    
    --Test the SQL statement and return an error message if it does not work
    begin
      v_columns_desc := db_utils.get_sql_columns_desc(p_sql_stmt => p_sql_statement);
    exception when others
    then
      return 'error while testing the SQL statement. It is likely that it contains syntax errors. error message: ' || lower(SQLERRM);
    end;  
    
    --debug log the columns returned by the SQL statement
    for i in v_columns_desc.first .. v_columns_desc.last
    loop
      dbms_output.put_line(v_columns_desc(i).column_name || ' (' || v_columns_desc(i).column_type || ')');
    end loop;
  
   -- create the new region
   v_region_id := apex_editor.create_new_table_region (p_app_id => p_app_id, 
                                        p_page_id => p_page_id,
                                        p_region_title => p_region_title, 
                                        p_sql_statement => p_sql_statement, 
                                        p_columns_desc => v_columns_desc);
  
  
    return 'The new table region with id ' || v_region_id || ' was created';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_table_region. error message: ' || lower(SQLERRM);     
  end create_new_table_region;
  
  /*
   * create_new_form_region
   *
   * Creates a form region based on the given table along with an automatic row process and a form initialization process
   */
  function create_new_form_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_source_table_name in varchar2)
  return clob
  is
    v_columns_desc db_utils.t_sql_desc := db_utils.t_sql_desc();
    v_region_id number;
    v_page_error varchar2(4000);
  begin
  
    v_page_error := check_page_is_in_app(p_app_id => p_app_id, p_page_id => p_page_id);
    if v_page_error is not null
    then 
      return v_page_error;
    end if;
    --Test the SQL statement and return an error message if it does not work
    begin
      v_columns_desc := db_utils.get_table_columns_desc(p_table_name => p_source_table_name);  
    exception when others
    then
      return 'error while testing the database table. It is likely that there is no table of this name.';
    end;  
  
   -- create the new region
   v_region_id := apex_editor.create_new_form_region (p_app_id => p_app_id, 
                                        p_page_id => p_page_id,
                                        p_region_title => p_region_title, 
                                        p_source_table_name => p_source_table_name, 
                                        p_columns_desc => v_columns_desc);
                                        
    return 'new form region with id ' || v_region_id || ' was created';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_form_region. error message: ' || lower(SQLERRM);      
  end create_new_form_region; 


  /*
   * create_new_button
   *
   * creates a new button
   * Param: p_button_type: must have one of the following values: 'form_button_create', 'form_button_save', 'form_button_cancel', 'form_button_delete'
   * Param: p_target_page_id_on_cancel: If the button is a form_button_cancel, this must contain the page ID to which the cancel button should lead
   * Param: p_primary_key_form_item_name: If this is a create, save, delete or cancel button on a form region, this must contain the item name of the form's primary key item
   */
  function create_new_button(p_app_id in number, p_page_id in number, p_parent_region_id in number, p_button_name in varchar2, p_button_type in varchar2, p_primary_key_form_item_name in varchar2 default null, p_target_page_id_on_cancel in number default null)
  return clob
  is
    v_exists number;
  begin
    
    if p_parent_region_id is null
    then
      return 'error: p_parent_region_id must have a value';
    end if;
    
    -- check that the parent region exists on that page
    select count(*)
      into v_exists
      from apex_application_page_regions
     where page_id = p_page_id
       and region_id = p_parent_region_id;
      
    if v_exists <= 0
    then
      return 'error: there is no region with id ' || p_parent_region_id || ' on that page';
    end if;
    
    -- check that primary key item name is an existing item on the page. 
    -- If the button is a form_button_cancel the item name is optional and is ignored anyways, so no need for the check in this case
    if p_button_type != 'form_button_cancel'
    then
      select count(*)
        into v_exists
        from apex_application_page_items
       where application_id = p_app_id
         and page_id = p_page_id
         and upper(item_name) = upper(p_primary_key_form_item_name);
         
      if v_exists <= 0
      then
        return 'error: there is no item named ' || p_primary_key_form_item_name || ' on that page';
      end if;
    end if;
    
    -- check if the p_target_page_id_on_cancel is a valid page in the application, if this is a cancel button.
    -- If it is not a cancel button, the content of the parameter is ignored, so no need for the check in that case
    if p_button_type = 'form_button_cancel'
    then
      select count(*)
        into v_exists
        from apex_application_pages
       where application_id = p_app_id
         and page_id = p_target_page_id_on_cancel;
         
      if v_exists <= 0
      then
        return 'error: p_target_page_id_on_cancel is not a page-id in this app. You must supply a valid page ID to return to when the cancel button is clicked';
      end if;   
    end if;
    
    apex_editor.create_new_button (p_app_id                       => p_app_id
                                  ,p_page_id                      => p_page_id
                                  ,p_parent_region_id             => p_parent_region_id
                                  ,p_button_name                  => p_button_name
                                  ,p_button_type                  => p_button_type
                                  ,p_primary_key_form_item_name   => p_primary_key_form_item_name
                                  ,p_target_page_id_on_cancel     => p_target_page_id_on_cancel);
    return 'the new button was created';                              
    
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_button. error message: ' || lower(SQLERRM);       
  end create_new_button;   
  
  /*
   * create_new_link_button
   *
   * creates a new link button that leads to another page
   */
  function create_new_link_button(p_app_id in number, p_page_id in number, p_parent_region_id in number, p_button_name in varchar2, p_target_page_id in number, p_button_position in varchar2)
  return clob
  is
    v_exists number;
  begin  
    if p_parent_region_id is null
    then
      return 'error: p_parent_region_id must have a value';
    end if;
    
    -- check that the parent region exists on that page
    select count(*)
      into v_exists
      from apex_application_page_regions
     where page_id = p_page_id
       and region_id = p_parent_region_id;
      
    if v_exists <= 0
    then
      return 'error: there is no region with id ' || p_parent_region_id || ' on that page';
    end if;
    
    if upper(p_button_position) not in ('REGION_BODY', 'SORT_ORDER', 'NEXT', 'PREVIOUS', 'RIGHT_OF_IR_SEARCH_BAR')
    then
      return 'error: p_button_position has an illegal value.';
    end if;
    
    apex_editor.create_new_link_button(p_app_id             => p_app_id
                                      ,p_page_id            => p_page_id
                                      ,p_button_name        => p_button_name
                                      ,p_parent_region_id   => p_parent_region_id
                                      ,p_target_page_id     => p_target_page_id
                                      ,p_button_position    => p_button_position);
    return 'the new link-button was created';
    
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_link_button. error message: ' || lower(SQLERRM);     
  end create_new_link_button;
  /*
   * create_new_branch
   *
   * Creates a branch on a page that leads to the target page
   */
  function create_new_branch(p_app_id in number, p_page_id in number, p_target_page_id in number)
  return clob
  is
  begin 
    apex_editor.create_new_branch (p_app_id => p_app_id
                                  , p_page_id => p_page_id
                                  , p_target_page_id => p_target_page_id);
    return 'branch was created';                              
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function create_new_branch. error message: ' || lower(SQLERRM);    
  end create_new_branch;   

/************************************************************************************
 *
 * Delete functions
 *
 ************************************************************************************/

  /*
   * delete_page
   *
   * Deletes an existing page in the given application with the given page ID
   */
  function delete_page(p_app_id in number, p_page_id in number)
  return clob
  is
    v_page_error varchar2(4000);
    v_exists number;
  begin
  
    --check the given IDs for existanc
    v_page_error := check_page_is_in_app(p_app_id => p_app_id, p_page_id => p_page_id);
    if v_page_error is not null
    then 
      return v_page_error;
    end if;
  
    apex_editor.delete_page(p_app_id => p_app_id, p_page_id => p_page_id);
    
    return 'Page deleted';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function delete_page. error message: ' || lower(SQLERRM);    
  end delete_page;
 
 /************************************************************************************
 *
 * Edit functions
 *
 ************************************************************************************/
  /*
   * change_page_title
   *
   * Changes the title of an apex page using APEX's import API
   *
   * Returns: a confirmation text if the import was successful or an error text otherwise
   */
  function change_page_title(p_app_id in number, p_page_id in number, p_new_title in varchar2) 
  return clob
  is
  begin
  
    apex_editor.set_page_title (p_app_id          => p_app_id, 
                                p_page_id         => p_page_id, 
                                p_page_title      => p_new_title, 
                                p_apex_session_id => v('APP_SESSION'));
    return 'Page title of page ' || p_page_id || ' in application ' || p_app_id || ' was changed to ' || p_new_title;
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_page_title.  error message: ' || lower(SQLERRM);--old msg: Could it be that the given page does not exist?
  end change_page_title;

  /*
   * change_region_title
   *
   * Changes the title of an apex region using APEX's import API
   *
   * Returns: a confirmation text if the import was successful or an error text otherwise
   */
  function change_region_title(p_app_id in number, p_page_id in number, p_region_id in number, p_new_title in varchar2) 
  return clob
  is
  begin
    apex_editor.set_region_title (p_app_id          => p_app_id, 
                                  p_page_id         => p_page_id, 
                                  p_region_id         => p_region_id, 
                                  p_region_title      => p_new_title, 
                                  p_apex_session_id => v('APP_SESSION'));
    return 'The Region title of region ' || p_region_id || ' on page ' || p_page_id || ' in application ' || p_app_id || ' was changed to ' || p_new_title;
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_region_title. error message: ' || lower(SQLERRM);      
  end change_region_title;
  
  /*
   * change_region_text
   *
   * Changes the text shown in the region with the given region_id on the page with the given page_id inside the application with the given app_id
   */
  function change_region_text(p_app_id in number, p_page_id in number,  p_region_id in number, p_new_region_text in varchar2)
  return clob
  is 
  begin
    apex_editor.set_region_text(p_app_id          => p_app_id, 
                                p_page_id         => p_page_id,  
                                p_region_id       => p_region_id, 
                                p_region_text     => p_new_region_text, 
                                p_apex_session_id => v('APP_SESSION'));
    return 'The text in region ' || p_region_id || ' on page ' || p_page_id || ' in application ' || p_app_id || ' was changed to ' || p_new_region_text;
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_region_text. error message: ' || lower(SQLERRM);     
    
  end change_region_text;
 
/************************************************************************************
 *
 * Interactive Report Editing
 *
 ************************************************************************************/ 
  
  
  /*
   * change_page_item_label
   *
   * Changes the label of a page item on the page with the given page_id inside the application with the given app_id
   */
  function change_page_item_label(p_app_id in number, p_page_id in number, p_page_item_name in varchar2, p_new_label in varchar2)
  return clob
  is
  begin
    apex_editor.set_page_item_label(p_app_id          => p_app_id, 
                                    p_page_id         => p_page_id,  
                                    p_page_item_name  => p_page_item_name,
                                    p_new_label       => p_new_label, 
                                    p_apex_session_id => v('APP_SESSION'));
    return 'the item label was changed.';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_page_item_label. error message: ' || lower(SQLERRM);     
        
  end change_page_item_label;
  
  /*
   * change_region_column_label
   *
   * Changes the label of a table region's column on the page with the given page_id inside the application with the given app_id
   */
  function change_region_column_label(p_app_id in number, p_page_id in number, p_column_id in number, p_new_label in varchar2)
  return clob
  is
  begin
    apex_editor.set_region_column_label(p_app_id          => p_app_id, 
                                        p_page_id         => p_page_id,  
                                        p_column_id       => p_column_id,
                                        p_new_label       => p_new_label, 
                                        p_apex_session_id => v('APP_SESSION'));
    return 'The label of column ' || p_column_id || ' was changed to ' || p_new_label;
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_region_column_label. error message: ' || lower(SQLERRM);     
        
  end change_region_column_label;

  /*
   * change_column_format_mask
   * 
   * Changes the format mask of a table region's column
   */
  function change_column_format_mask(p_app_id in number, p_page_id in number, p_column_id in number, p_new_format_mask in varchar2)
  return clob
  is
  begin
    apex_editor.set_column_format_mask(p_app_id          => p_app_id, 
                                       p_page_id         => p_page_id,  
                                       p_column_id       => p_column_id,
                                       p_new_format_mask => p_new_format_mask, 
                                       p_apex_session_id => v('APP_SESSION'));
                                       
    return 'the column''s formatmask was changed';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_column_format_mask. error message: ' || lower(SQLERRM);     
  end change_column_format_mask;

  /*
   * change_table_column_type
   *
   * Changes the type of a column in a table region
   * 
   * Param p_page_id: the page on which the region is
   * Param p_new_column_type: The new type of the column. Must be 'PLAIN_TEXT', 'LINK', or 'HIDDEN' 
   *
   * If the p_new_column_type is 'LINK' the following parameters must be given:   
   * Param p_link_target_page_id: the page ID to which the link should point
   * Param p_link_target_page_item_name: The page item name on the target page that should be filled with a value
   * Param p_region_column_name: The columnname from the region whose value should be used to fill the target page item 
   */
  function change_table_column_type(p_app_id in number, p_page_id in number, p_region_id in number, p_column_id in number, p_new_column_type in varchar2, p_link_target_page_id in number default null, p_link_target_page_item_name in varchar2 default null, p_region_column_name in varchar2 default null)
  return clob
  is
    v_error varchar2(4000);
    v_exists number;
  begin
  
    v_error := check_column_is_in_region(p_app_id => p_app_id, p_page_id => p_page_id, p_region_id => p_region_id, p_column_id => p_column_id);
    if v_error is not null
    then
      return v_error;
    end if;
    
    if p_new_column_type = 'LINK'
    then
      -- ensure that p_link_target_page_id, p_link_target_page_item_name and p_region_column_name are not null
      if p_link_target_page_id is null or p_link_target_page_item_name is null or p_region_column_name is null
      then
        return 'error: p_link_target_page_id, p_link_target_page_item_name and p_link_page_item_values must have a value when the new column type is LINK';
      end if;
    
      -- check if the item exists on the target page, because the LLM makes errors here sometimes
      select count(*)
        into v_exists
        from apex_application_page_items
       where application_id = p_app_id
         and page_id = p_link_target_page_id
         and upper(item_name) = upper(p_link_target_page_item_name);
         
      if v_exists <= 0
      then
        return 'error: there is no item with the name ' || p_link_target_page_item_name || ' on the given target page.';
      end if;
    end if;
  
    apex_editor.set_table_column_type (p_app_id => p_app_id
                                      ,p_page_id => p_page_id
                                      ,p_region_id => p_region_id
                                      ,p_column_id => p_column_id
                                      ,p_new_column_type => p_new_column_type
                                      ,p_apex_session_id => v('APP_SESSION')
                                      ,p_link_target_page_id => p_link_target_page_id
                                      ,p_link_target_page_items => p_link_target_page_item_name
                                      ,p_link_page_item_values => '#' || upper(p_region_column_name) || '#');
    return 'Changed column type.';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_table_column_type. error message: ' || lower(SQLERRM);
  end change_table_column_type;


  /*
   * change_table_region_sql_statement
   *
   * changes the sql statement that defines which columns exist in a table region (interactive report)
   */
  function change_table_region_sql_statement(p_app_id in number, p_page_id in number, p_region_id in number, p_new_sql_statement in clob)
  return clob
  is
    v_error varchar2(4000);
    v_columns_desc db_utils.t_sql_desc := db_utils.t_sql_desc();
  begin
  
    -- ensure the app, page and region exist
    v_error := check_region_is_on_page(p_app_id => p_app_id, p_page_id => p_page_id, p_region_id => p_region_id);
    if v_error is not null
    then
      return v_error;
    end if;
  
    apex_debug.info('change_table_region_sql_statement! New SQL:');
    apex_debug.info(p_new_sql_statement);
    
    --Test the SQL statement and return an error message if it does not work
    begin
      v_columns_desc := db_utils.get_sql_columns_desc(p_sql_stmt => p_new_sql_statement);
    exception when others
    then
      return 'error while testing the SQL statement. It is likely that it contains syntax errors. error message: ' || lower(SQLERRM);
    end;  
    
    --debug log the columns returned by the SQL statement
    for i in v_columns_desc.first .. v_columns_desc.last
    loop
      dbms_output.put_line(v_columns_desc(i).column_name || ' (' || v_columns_desc(i).column_type || ')');
    end loop;
  
  
    --set_table_region_sql_statement(p_app_id in number, p_page_id in number, p_region_id in number, p_new_sql_statement in clob, p_new_columns_desc in db_utils.t_sql_desc, p_apex_session_id in number)
  
   -- create the new region
   apex_editor.set_table_region_sql_statement(p_app_id              => p_app_id, 
                                              p_page_id             => p_page_id,
                                              p_region_id           => p_region_id, 
                                              p_new_sql_statement   => p_new_sql_statement, 
                                              p_new_columns_desc    => v_columns_desc,
                                              p_apex_session_id     => v('APP_SESSION'));
  
  
    return 'The table regions sql statement was changed';
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_table_region_sql_statement. error message: ' || lower(SQLERRM);     
  end change_table_region_sql_statement;

  /*
   * set_link_to_page_in_table_region
   * 
   * Changes the link column in a table region to point to the given target 
   */  
  function set_link_to_page_in_table_region(p_app_id in number, p_page_id in number, p_region_id in number, p_link_target_page_id in number, p_link_target_page_item_name in varchar2, p_region_column_name in varchar2)
  return clob
  is
    v_exists number;
  begin
  
    
    --check if the item exists on the target page, because the LLM makes errors here sometimes
    select count(*)
      into v_exists
      from apex_application_page_items
     where application_id = p_app_id
       and page_id = p_link_target_page_id
       and upper(item_name) = upper(p_link_target_page_item_name);
       
    if v_exists <= 0
    then
      return 'error: there is no item with the name ' || p_link_target_page_item_name || ' on the given target page.';
    end if;
  
    apex_editor.set_table_region_link_to_page (p_app_id                   => p_app_id
                                              ,p_page_id                  => p_page_id
                                              ,p_region_id                => p_region_id
                                              ,p_link_target_page_id      => p_link_target_page_id
                                              ,p_link_target_page_items   => p_link_target_page_item_name
                                              ,p_link_page_item_values    => '#' || upper(p_region_column_name) || '#'
                                              ,p_apex_session_id          => v('APP_SESSION'));  
    return 'the table''s column-link was changed';                                          
  exception 
  when others
  then
    apex_debug.error('SQL Code: ' || SQLCODE);
    apex_debug.error('Error: ' || SQLERRM);
    apex_debug.error('Backtrace => '||dbms_utility.format_error_backtrace);
    return 'error while calling the function change_table_region_link_to_page. error message: ' || lower(SQLERRM);                                               
  end set_link_to_page_in_table_region;

end "EDIT_FUNCTIONS";
/