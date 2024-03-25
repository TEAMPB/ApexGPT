create or replace package body "APEX_EDITOR" as

/************************************************************************************
 *
 * Edit History Management
 *
 ************************************************************************************/

  /*
   * begin_edit_operation
   *
   * Gets the import file of the given page and saves it to make reverting following editing operations possible.
   *
   * Returns: The import file to enable subsequent editing
   */
  function begin_edit_operation(p_app_id in number, p_page_id in number, p_import_file_name in out varchar2)
  return clob is
    v_import_file clob;
    v_forget_result varchar2(4000);
    
    v_exists number;
  begin
  
    -- check that the app exists, and that it is not an "internal" app (apps not editable by AI)
    select count(*)
      into v_exists
      from apex_applications
     where nvl(APPLICATION_GROUP, 'NONE') != 'INTERNAL'
       and application_id = p_app_id;
       
    if v_exists <= 0
    then
      raise_application_error(-20000, 'there is no application with the given id');
    end if;
    
    --check that the page exists
    select count(*)
      into v_exists
      from apex_application_pages
     where page_id = p_page_id;
    if v_exists <= 0
    then
      raise_application_error(-20000, 'there is no page with the given id');
    end if;
     
  
    v_import_file := apex_import.get_app_import_file (p_app_id            => p_app_id, 
                                                      p_page_id           => p_page_id, 
                                                      p_import_file_name  => p_import_file_name);
                                                      
    v_forget_result := edit_functions.set_current_page_and_app_id (p_app_id   => p_app_id
                                                                  ,p_page_id  => p_page_id);                                                  
                                                      
    insert into TCH_UNDO
    (
      IMPORT_FILE,
      IMPORT_FILE_NAME,
      USER_NAME
    )
    values
    (
      v_import_file,
      p_import_file_name,
      v('APP_USER')
    );
    
    return v_import_file;
  
  end begin_edit_operation;
  
  /*
   * begin_create_operation
   *
   * Saves the current state auf the given application, executes the import start code needed to import new components into the app 
   * and returns the code needed to end the import procedure after all components have been imported
   *
   */
  function begin_create_operation(p_app_id in number)
  return clob 
  is
    v_import_file       clob;
    v_import_file_name  varchar2(4000);
    
    v_start_end_files   apex_t_export_files;
    v_import_end_file   clob;
    v_plsql_params      apex_exec.t_parameters;
    
    v_code_start        number;
    v_code_end          number;
  begin
    -- save whole application import file, so it can be reverted later
    v_import_file := apex_import.get_app_import_file (p_app_id            => p_app_id, 
                                                      p_page_id           => null, 
                                                      p_import_file_name  => v_import_file_name);
    insert into TCH_UNDO
    (
      IMPORT_FILE,
      IMPORT_FILE_NAME,
      USER_NAME
    )
    values
    (
      v_import_file,
      v_import_file_name,
      v('APP_USER')
    );
    
    -- get set_environment and end_environment files, for starting and ending the import procedure
    v_start_end_files := apex_import.get_import_start_and_end(p_app_id => p_app_id);
    
    -- find and execute import start file and save import end file
    for i in v_start_end_files.first .. v_start_end_files.last
    loop
      
      if v_start_end_files(i).name like '%set_environment.sql'
      then
      
        --remove sqlcl specific parts from the import file
        v_code_start := instr(v_start_end_files(i).contents, 'wwv_flow_imp.import_begin', 1);
        v_start_end_files(i).contents := 'begin ' || substr(v_start_end_files(i).contents, v_code_start, length(v_start_end_files(i).contents) - v_code_start - 1);-- the -1 removes the / at the end of the file
        
        apex_debug.info('Execute Begin import:');
        apex_debug.info(v_start_end_files(i).contents);
        
        --execute import start file
        apex_exec.execute_plsql(p_plsql_code      => v_start_end_files(i).contents 
                            ,p_auto_bind_items    => false
                            ,p_sql_parameters     => v_plsql_params);
                            
      elsif v_start_end_files(i).name like '%end_environment.sql' 
      then
        --remove sql cl specific parts from the import file
        v_code_start := instr(v_start_end_files(i).contents, 'wwv_flow_imp.import_end', 1);
        v_code_end := instr(v_start_end_files(i).contents, 'commit;', 1) + length('commit;');
        v_start_end_files(i).contents := substr(v_start_end_files(i).contents, v_code_start, v_code_end - v_code_start);
        
        apex_debug.info('End import:');
        apex_debug.info(v_start_end_files(i).contents);
        
        --save import end file to return it
        v_import_end_file := v_start_end_files(i).contents;
      else
        continue;
      end if;
    
    end loop;
     
    return v_import_end_file;
  
  end begin_create_operation;

/************************************************************************************
 *
 * Editing Procedures
 *
 ************************************************************************************/

  /*
   * set_page_title
   *
   * Changes the page title of an existing page in the given app to the given title.
   */
  procedure set_page_title(p_app_id in number, p_page_id in number, p_page_title in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
  BEGIN

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);

    select import_file_start_line
      into v_line_no
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_step_title'
     start with elem_type = 'PAGE' and apex_elem_id = to_char(p_page_id)
    connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id;

    apex_import.replace_value_single_line(p_import_lines  => v_file_by_lines, 
                                          p_line_no       => v_line_no, 
                                          p_new_value     => q'~'~' || p_page_title || q'~'~');

    apex_debug.info('-----------------------------------------------');
    apex_debug.info('Split CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.last
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;
    
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

  end set_page_title;

  /*
   * set_region_title
   *
   * Changes the title of the region with the given region_id on the page with the given page_id inside the application with the given app_id
   */
  procedure set_region_title(p_app_id in number, p_page_id in number,  p_region_id in number, p_region_title in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
  BEGIN

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);

    select import_file_start_line
      into v_line_no
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_plug_name'
       and parent_apex_elem_id = to_char(p_region_id)
     start with elem_type = 'PAGE' and apex_elem_id = to_char(p_page_id)
    connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id;

    apex_import.replace_value_single_line(p_import_lines  => v_file_by_lines, 
                                          p_line_no       => v_line_no, 
                                          p_new_value     => q'~'~' || p_region_title || q'~'~');
    
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

  end set_region_title;

  /*
   * set_region_text
   *
   * Changes the text shown in the region with the given region_id on the page with the given page_id inside the application with the given app_id
   */
  procedure set_region_text(p_app_id in number, p_page_id in number,  p_region_id in number, p_region_text in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
    v_region_exists number;
    v_param_exists number;
  begin

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);
    
    -- check if the region exists
    select count(*)
      into v_region_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PAGE_PLUG'
       and apex_elem_id = to_char(p_region_id)
     start with elem_type = 'PAGE' and apex_elem_id = to_char(p_page_id)
    connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id;
      
    if v_region_exists = 0
    then
      raise_application_error(-20001, 'The specified region could not be found on the given page.');
    end if;
    
    
    apex_import.insert_or_replace_param (p_import_lines         => v_file_by_lines
                                        ,p_param_name           => 'p_plug_source'
                                        ,p_parent_proc_type     => 'PAGE_PLUG'
                                        ,p_parent_apex_elem_id  => p_region_id
                                        ,p_new_value            => p_region_text
                                        ,p_is_new_value_string  => true
                                        ,p_apex_session_id      => p_apex_session_id);
                                   
    --debug prints
    apex_debug.info('-----------------------------------------------');
    apex_debug.info('Split CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.count
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;
        
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

  end set_region_text;

  /*
   * set_region_column_label
   *
   * Changes the label of a table region's column on the page with the given page_id inside the application with the given app_id
   */  
  procedure set_region_column_label(p_app_id in number, p_page_id in number, p_column_id in number, p_new_label in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
  begin

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);

    select import_file_start_line
      into v_line_no
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_column_label'
       and parent_apex_elem_id = to_char(p_column_id)
     start with elem_type = 'PAGE' and apex_elem_id = to_char(p_page_id)
    connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id;

    apex_import.replace_value_single_line(p_import_lines  => v_file_by_lines, 
                                          p_line_no       => v_line_no, 
                                          p_new_value     => q'~'~' || p_new_label || q'~'~');
    
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

  end set_region_column_label;

  /*
   * set_table_column_type
   *
   * Sets the type of a column in an interactive report region
   *
   * 
   * Param p_page_id: the page on which the region is
   * Param p_new_column_type: The new type of the column. Must be 'PLAIN_TEXT', 'LINK', or 'HIDDEN' 
   *
   * If the p_new_column_type is 'LINK' the following parameters must be given:   
   * Param p_link_target_page_id: the page ID to which the link should point
   * Param p_link_target_page_items: The page item names on the target page that should be filled with values as a commaseparated list
   * Param p_link_page_item_values: The columnnames from the region whose values should be used to fill the target page items encapsulated by # as a commaseparated list, e.g. #column_name1#,#column_name2#
   */
  procedure set_table_column_type(p_app_id in number, p_page_id in number, p_region_id in number, p_column_id in number, p_new_column_type in varchar2, p_apex_session_id in varchar2, p_link_target_page_id in number default null, p_link_target_page_items in varchar2 default null, p_link_page_item_values in varchar2 default null)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);
    
    v_curr_line_no    tch_apex_app_struct.import_file_start_line%type;
    v_db_column_name  varchar2(255);    
  begin
  
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);

    case p_new_column_type
    when 'HIDDEN'
    then
      /*
       * Column Type: Hidden
       */
      -- set display type to hidden 
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_display_text_as'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'HIDDEN_ESCAPE_SC'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
    when 'PLAIN_TEXT'
    then
      /*
       * Column Type: PLAIN_TEXT
       */
      -- set default params for visible columns
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_heading_alignment'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'LEFT'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
                                                      
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_use_as_row_header'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'N'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
                                                      
      -- remove p_display_text_as to use its default value
      apex_import.remove_param_single_line(p_import_lines         => v_file_by_lines
                                          ,p_param_name           => 'p_display_text_as'
                                          ,p_parent_apex_elem_id  => p_column_id
                                          ,p_apex_session_id      => p_apex_session_id);
      
    when 'LINK'
    then
      /*
       * Column Type: LINK
       */
      -- set default params for visible columns
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_heading_alignment'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'LEFT'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
                                                      
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_use_as_row_header'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'N'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
                                                      
      -- set link
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_column_link'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'f?p=&APP_ID.:~' || p_link_target_page_id || ':&SESSION.::&DEBUG.::' || p_link_target_page_items || ':' || p_link_page_item_values || q'~'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
      
      -- get the line in the import file where the p_db_column_name parameter of the column is defined
      select import_file_start_line
        into v_curr_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'PARAM'
         and elem_name = 'p_db_column_name'
         and parent_apex_elem_id = p_column_id;
      --find the name of the select column the worksheet column is based on   
      v_db_column_name := string_utils.remove_ticks_from_string(apex_import.find_param_value_in_proc(p_search_file => v_file_by_lines, p_proc_start_line => v_curr_line_no, p_param_name => 'p_db_column_name'));
      
      --set link text
      apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                      ,p_param_name           => 'p_column_linktext'
                                                      ,p_parent_proc_type     => 'WORKSHEET_COLUMN'
                                                      ,p_parent_apex_elem_id  => p_column_id
                                                      ,p_new_value            => q'~'#~' || upper(v_db_column_name) || q'~#'~'
                                                      ,p_apex_session_id      => p_apex_session_id);
      --remove p_display_text_as param
      apex_import.remove_param_single_line(p_import_lines         => v_file_by_lines
                                          ,p_param_name           => 'p_display_text_as'
                                          ,p_parent_apex_elem_id  => p_column_id
                                          ,p_apex_session_id      => p_apex_session_id);
      
    else
      raise_application_error(-20001, 'The given column type is not valid.');
    end case;

    --debug prints
    apex_debug.info('-----------------------------------------------');
    apex_debug.info('Split CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.count
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;
        
    apex_debug.info('installing new app version');
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);
  end set_table_column_type;
  
  /*
   * set_column_format_mask
   *
   * Changes the format mask of a table region's column (or inserts it, if it does not have a format mask yet)
   */  
  procedure set_column_format_mask(p_app_id in number, p_page_id in number, p_column_id in number, p_new_format_mask in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
    v_column_exists number;
    v_param_exists number;
  begin

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);
    
    -- check if the column exists
    select count(*)
      into v_column_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'WORKSHEET_COLUMN'
       and apex_elem_id = to_char(p_column_id);
      
    if v_column_exists = 0
    then
      raise_application_error(-20001, 'The specified column could not be found.');
    end if;
    
    -- check if the format mask param is already present
    select count(*)
      into v_param_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_format_mask'
       and parent_apex_elem_id = to_char(p_column_id);  
    
    if v_param_exists = 0
    then
      -- parameter does not exist, so we must insert it first
      
      -- get the line where the procedure starts
      select import_file_start_line
        into v_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'WORKSHEET_COLUMN'
         and apex_elem_id = to_char(p_column_id);
      
      -- insert the parameter into the next line after the ID (the ID is always the first line after the procedure start
      string_utils.insert_line_into_array(p_clob_array => v_file_by_lines, 
                                          p_line => ',p_format_mask=>' || q'~'~' || p_new_format_mask || q'~'~', 
                                          p_index => v_line_no + 2);
      
    else
      -- parameter exists, thus we can get its line and replace its value
      select import_file_start_line
        into v_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'PARAM'
         and elem_name = 'p_format_mask'
         and parent_apex_elem_id = to_char(p_column_id);
      
      apex_import.replace_value_single_line (p_import_lines      => v_file_by_lines, 
                                             p_line_no     => v_line_no, 
                                             p_new_value         => q'~'~' || p_new_format_mask || q'~'~');
    end if;                                      
    --debug prints
    apex_debug.info('-----------------------------------------------');
    apex_debug.info('Split CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.count
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;
        
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

    
  end set_column_format_mask;


  /*
   * set_table_region_sql_statement
   *
   * Changes an Interactive Report's sql statement
   */  
  procedure set_table_region_sql_statement(p_app_id in number, p_page_id in number, p_region_id in number, p_new_sql_statement in clob, p_new_columns_desc in db_utils.t_sql_desc, p_apex_session_id in number)
  is
    v_old_sql_statement         clob;
    v_old_columns_desc          db_utils.t_sql_desc;
    
    v_curr_file                 clob;
    v_file_by_lines             apex_t_clob;
    v_import_file_name          varchar2(4000);
    
    v_deleted_columns           db_utils.t_sql_desc;
    v_deleted_column_names      apex_t_varchar2;
    v_added_columns             db_utils.t_sql_desc;
    v_worksheet_id              tch_apex_app_struct.apex_elem_id%type;
    v_used_column_identifiers   varchar2(4000);
    v_curr_column_identifier    varchar2(5);
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);
                                  
    -- get the old sql statement from the region
    begin
      
      select sql_query
        into v_old_sql_statement
        from APEX_APPLICATION_PAGE_IR
       where region_id = p_region_id;
       
      if v_old_sql_statement is null
      then
        raise_application_error(-20001, 'the given region does not have an sql statement');
      end if;
       
    exception when no_data_found
    then
      raise_application_error(-20001, 'the given region is not an interactive report region');
    end;
    
    -- parse the old sql statement
    declare
      v_old_sql_statement clob;
    begin
      -- get old sql_statement
      select sql_query
        into v_old_sql_statement
        from APEX_APPLICATION_PAGE_IR
       where region_id = p_region_id;
       
      v_old_columns_desc := db_utils.get_sql_columns_desc(p_sql_stmt => v_old_sql_statement);
    exception when others
    then
      raise_application_error(-20001, 'error while testing the current SQL statement of the region. this should not be possible, an apex developer might need to fix this. Error message: ' || lower(SQLERRM));
    end;

    -- compare the old and new sql statement's columns: Get which columns were added and deleted
    db_utils.get_changed_columns_in_descs (p_old_columns_desc   => v_old_columns_desc
                                          ,p_new_columns_desc   => p_new_columns_desc
                                          ,p_deleted_columns    => v_deleted_columns
                                          ,p_added_columns      => v_added_columns); 
    
    --get worksheet id of the IR region
    select apex_elem_id
      into v_worksheet_id
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'WORKSHEET'
       and parent_apex_elem_id = p_region_id; 
    
    -- Remove deleted columns from import file
    if v_deleted_columns.count > 0
    then
    
      v_deleted_column_names := db_utils.get_desc_columns_table(p_sql_desc => v_deleted_columns);
    
      for deleted_col in (select parent_apex_elem_id, import_file_start_line, elem_name --the parent apex elem of a PARAM is a WORKSHEET_COLUMN here, because we start the hierarchical query with a WORKSHEET as the root
                            from tch_apex_app_struct
                           where elem_type = 'PARAM' 
                             and elem_name = 'p_db_column_name'
                              -- get param lines, whose p_db_column_name parameter has a value that exists in the list of deleted columns
                             and upper(apex_import.get_param_string_value_from_line_as_varchar2(p_line_content =>  (select column_value 
                                                                                                                      from (select column_value, 
                                                                                                                                   rownum id 
                                                                                                                              from table(v_file_by_lines)) 
                                                                                                                     where id = import_file_start_line)
                                                                                               ,p_param_name => elem_name))
                                  in (select upper(column_value) from table(v_deleted_column_names))
                           start with elem_type = 'WORKSHEET' and apex_elem_id = v_worksheet_id and session_id = p_apex_session_id
                         connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id)
      loop
      
        -- debug
        /*
        declare
          v_column_value varchar2(4000);
          v_deleted_columns_list clob;
        begin
          v_column_value := v_file_by_lines(deleted_col.import_file_start_line);
          
          select listagg(upper(column_value), ',') within group (order by column_value)
          into v_deleted_columns_list
          from table(v_deleted_column_names) ;
           
           apex_debug.info('parent_apex_elem_id: ' || deleted_col.parent_apex_elem_id || chr(10) || 'import_file_start_line: ' || deleted_col.import_file_start_line || chr(10) || deleted_col.elem_name  ||  
                        upper(apex_import.get_param_value_from_line(p_line_content => v_column_value
                                                                            ,p_param_name => deleted_col.elem_name))
                          || chr(10) || 'deleted_columns: ' || v_deleted_columns_list                                                  
          );
        end;*/
        
        apex_import.remove_proc_call(p_import_lines     => v_file_by_lines
                                    ,p_proc_type        => 'WORKSHEET_COLUMN'
                                    ,p_apex_elem_id     => deleted_col.parent_apex_elem_id
                                    ,p_apex_session_id  => p_apex_session_id);
      end loop;  
    end if;
    
    declare
      v_column_value varchar2(4000);
      v_deleted_column_names apex_t_varchar2;
      v_deleted_columns_list clob;
    begin
      
      select column_value
      into v_column_value
      from (select dbms_lob.substr( column_value, 4000, 1 ) column_value,
            rownum id
            from table(v_file_by_lines))
      where id = 25;      
      
      apex_debug.info('v_column_value(25): ' || v_column_value);
      apex_debug.info('line(25): ' || v_file_by_lines(25));
    end; 
    
    -- get a list of all column identifiers used by columns in the worksheet
    select listagg(apex_import.get_param_string_value_from_line(p_line_content  => (select column_value 
                                                                                      from (select column_value, 
                                                                                                   rownum id 
                                                                                              from table(v_file_by_lines)) 
                                                                                     where id = import_file_start_line)
                                                               ,p_param_name => elem_name)
                  , ':') 
           within group (order by rownum)
           column_identifiers
      into v_used_column_identifiers    
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_column_identifier'
       and parent_apex_elem_id in (select apex_elem_id
                                    from tch_apex_app_struct
                                   where session_id = p_apex_session_id
                                     and elem_type = 'WORKSHEET_COLUMN'
                                     and parent_apex_elem_id = v_worksheet_id);
                                     
    apex_debug.info('v_used_column_identifiers: ' || v_used_column_identifiers);                                 

    -- get the next alphabet character from the worksheet column with the column identifier that is furthest down in the alphabet
    select chr(max(ASCII(column_value)) + 1)
      into v_curr_column_identifier
      from table(apex_string.split(v_used_column_identifiers, ':'));
    --v_curr_column_identifier := chr(ASCII(v_curr_column_identifier) + 1);
    
    -- Insert added columns into import file
    if v_added_columns.count > 0
    then
    
      apex_debug.info('next column identifier: ' || v_curr_column_identifier);
    
      for i in v_added_columns.first .. v_added_columns.last
      loop
        apex_import.insert_new_worksheet_column (p_import_file        => v_file_by_lines
                                                ,p_worksheet_id       => v_worksheet_id
                                                ,p_column_desc        => v_added_columns(i)
                                                ,p_column_identifier  => v_curr_column_identifier
                                                ,p_display_order      => 1000 + 10 * i
                                                ,p_apex_session_id    => p_apex_session_id);
        -- get next letter in alphabet                                                              
        v_curr_column_identifier := chr(ASCII(v_curr_column_identifier) + 1);                                           
      end loop;  
    end if;
    
    -- Update region's SQL statement & report creation call with updated column list
    apex_import.change_sql_statement_in_region(p_import_file      => v_file_by_lines
                                              ,p_region_id        => p_region_id
                                              ,p_sql_statement    => p_new_sql_statement
                                              ,p_columns_desc     => p_new_columns_desc
                                              ,p_apex_session_id  => p_apex_session_id);
    
    apex_debug.info('###### Final import file ######');
    apex_import.debug_print_file_by_lines(v_file_by_lines);                           
    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name           => v_import_file_name, 
                                                                                              p_file_by_lines       => v_file_by_lines),
                                      p_overwrite_existing => true);
    
  end set_table_region_sql_statement;
  /*
   * set_table_region_link_to_page
   *
   * Sets the link column of an interactive report region
   *
   * Param p_page_id: the page on which the region is
   * Param p_link_target_page_id: the page ID to which the link should point
   * Param p_link_target_page_items: The page item names on the target page that should be filled with values as a commaseparated list
   * Param p_link_page_item_values: The columnnames from the region whose values should be used to fill the target page items encapsulated by # as a commaseparated list, e.g. #column_name1#,#column_name2#
   */
  procedure set_table_region_link_to_page(p_app_id in number, p_page_id in number, p_region_id in number, p_link_target_page_id in number, p_link_target_page_items in varchar2, p_link_page_item_values in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);
    
    v_worksheet_id varchar2(4000);
  begin
  
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);
  
    apex_debug.info('-----------------------------------------------');
    apex_debug.info('PARSED CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.count
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;  

    -- calculate worksheet ID based on region id
    select apex_elem_id
      into v_worksheet_id
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'WORKSHEET'
       and parent_apex_elem_id = p_region_id;
    
    --example: p_detail_link=>'f?p=&APP_ID.:10:&SESSION.::&DEBUG.::P10_FILMNAME:#FILMNAME#'
    apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                    ,p_param_name           => 'p_detail_link'
                                                    ,p_parent_proc_type     => 'WORKSHEET'
                                                    ,p_parent_apex_elem_id  => v_worksheet_id
                                                    ,p_new_value            => q'~'f?p=&APP_ID.:~' || p_link_target_page_id || ':&SESSION.::&DEBUG.::' || p_link_target_page_items || ':' || p_link_page_item_values || q'~'~'
                                                    ,p_apex_session_id      => p_apex_session_id);
    
    --example: p_detail_link_text=>'<span role="img" aria-label="Edit" class="fa fa-edit" title="Edit"></span>'
    apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                    ,p_param_name           => 'p_detail_link_text'
                                                    ,p_parent_proc_type     => 'WORKSHEET'
                                                    ,p_parent_apex_elem_id  => v_worksheet_id
                                                    ,p_new_value            => q'~'<span role="img" aria-label="Edit" class="fa fa-edit" title="Edit"></span>'~'
                                                    ,p_apex_session_id      => p_apex_session_id);
    --example: p_show_detail_link=>'N'
    apex_import.insert_or_replace_param_single_line (p_import_lines         => v_file_by_lines
                                                    ,p_param_name           => 'p_show_detail_link'
                                                    ,p_parent_proc_type     => 'WORKSHEET'
                                                    ,p_parent_apex_elem_id  => v_worksheet_id
                                                    ,p_new_value            => q'~'C'~' --C for custom link target
                                                    ,p_apex_session_id      => p_apex_session_id);
    
    --debug prints
    apex_debug.info('-----------------------------------------------');
    apex_debug.info('Split CLOB file');
    apex_debug.info('-----------------------------------------------');
    for i in v_file_by_lines.first .. v_file_by_lines.count
    loop
      apex_debug.info(i || ':' || v_file_by_lines(i));
    end loop;
        
    apex_debug.info('installing new app version');
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);
  end set_table_region_link_to_page;
  
  
 /*
   * set_page_item_label
   *
   * Changes the label of a page item on the page with the given page_id inside the application with the given app_id
   */    
  procedure set_page_item_label(p_app_id in number, p_page_id in number, p_page_item_name in varchar2, p_new_label in varchar2, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);

    v_line_no tch_apex_app_struct.import_file_start_line%type;
  begin

    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);

    select import_file_start_line
      into v_line_no
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = 'p_prompt'
       and upper(parent_apex_elem_id )= upper(p_page_item_name)
     start with elem_type = 'PAGE' and apex_elem_id = to_char(p_page_id)
    connect by prior apex_elem_id = parent_apex_elem_id and prior session_id = session_id;

    apex_import.replace_value_single_line(p_import_lines  => v_file_by_lines, 
                                          p_line_no       => v_line_no, 
                                          p_new_value     => q'~'~' || p_new_label || q'~'~');
    
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name     => v_import_file_name, 
                                                                                              p_file_by_lines => v_file_by_lines),
                                      p_overwrite_existing => true);

  end set_page_item_label; 

/************************************************************************************
 *
 * Create Procedures
 *
 ************************************************************************************/

  /*
   * create_new_empty_page
   *
   * Creates a new empty page in the given application with the given page ID and title. The page's name is set identical to the title.
   */
  procedure create_new_empty_page(p_app_id in number, p_page_id in number, p_page_title in varchar2)
  is
    v_import_code       clob;
    v_import_end_code   clob;
    v_forget_result     clob;

    v_plsql_params      apex_exec.t_parameters;
  begin
    -- import begin
    v_import_end_code := apex_editor.begin_create_operation(p_app_id =>p_app_id);
    
    -- main importing of components
    apex_debug.info('Execute new Page import');
    v_import_code := apex_import.get_import_create_new_page (p_page_id      => p_page_id
                                                            ,p_page_name    => p_page_title
                                                            ,p_page_alias   => replace(trim(lower(p_page_title)), ' ', '-')
                                                            ,p_page_title   => p_page_title);
    apex_exec.execute_plsql(p_plsql_code          => v_import_code 
                            ,p_auto_bind_items    => false
                            ,p_sql_parameters     => v_plsql_params);

    -- import end
    apex_debug.info('Execute import End');
    apex_exec.execute_plsql(p_plsql_code          => v_import_end_code 
                            ,p_auto_bind_items    => false
                            ,p_sql_parameters     => v_plsql_params);
                            
    -- set page as last edited one
    v_forget_result := edit_functions.set_current_page_and_app_id (p_app_id   => p_app_id
                                                                  ,p_page_id  => p_page_id);
    
  end create_new_empty_page;  
  
  
  /*
   * create_new_text_region
   *
   * Creates a new simple text region with the given title in the given application on the given page.
   */
  procedure create_new_text_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_region_text in clob)
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id of Standard Region Template
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id and upper(internal_name) = 'STANDARD' and upper(template_type) = 'REGION';
    
    -- insert create new page_plug code into import file
    apex_import.insert_new_page_plug(p_import_file        => v_curr_file
                                    ,p_region_id          => apex_ids.get_id('#sc-' || p_region_title)
                                    ,p_region_title       => p_region_title
                                    ,p_template_id        => v_template_id
                                    ,p_display_sequence   => 10
                                    ,p_text               => p_region_text);

    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);

  end create_new_text_region;    
  
  
  /*
   * create_new_table_region
   *
   * Creates a new Interactive Report region with the given title based on the given select.
   * Returns: the ID of the newly created region
   */  
  function create_new_table_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_sql_statement in clob, p_columns_desc in db_utils.t_sql_desc)
  return number
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
    
    v_region_id number;
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id of IR Region Template
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id and upper(internal_name) = 'INTERACTIVE_REPORT' and upper(template_type) = 'REGION';
    
    -- insert new interactive report into import file
    v_region_id := apex_import.insert_new_ir_region(p_import_file        => v_curr_file
                                    ,p_region_title       => p_region_title
                                    ,p_template_id        => v_template_id
                                    , p_display_sequence  => 10
                                    , p_sql_statement     => string_utils.escape_single_quotes(p_input => p_sql_statement)
                                    , p_columns_desc      => p_columns_desc);

    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);
    
    return v_region_id;
  end create_new_table_region;

 /*
  * create_new_form_region
  *
  * Creates a form region based on the given table along with an automatic row process and a form initialization process
  */
  function create_new_form_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_source_table_name in varchar2, p_columns_desc in db_utils.t_sql_desc)
  return number
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
    v_region_id         number;
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id of the Standard Template
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id and upper(internal_name) = 'STANDARD' and upper(template_type) = 'REGION';
    
    -- insert new form page plug into import file
    v_region_id := apex_import.insert_new_form_region (p_import_file        => v_curr_file
                                                      ,p_app_id             => p_app_id
                                                      ,p_page_id            => p_page_id
                                                      ,p_region_title       => p_region_title
                                                      ,p_template_id        => v_template_id
                                                      ,p_source_table_name  => upper(p_source_table_name)
                                                      ,p_display_sequence   => 10
                                                      ,p_columns_desc       => p_columns_desc);
                                    
    -- insert new form init process
    apex_import.insert_new_page_process (p_import_file    => v_curr_file
                                        ,p_region_id      => v_region_id
                                        ,p_process_name   => 'Initialize Form ' || p_region_title
                                        ,p_process_type   => 'NATIVE_FORM_INIT'
                                        ,p_process_point  => 'BEFORE_HEADER');
    
    -- insert new automatic form processing process
    apex_import.insert_new_page_process (p_import_file    => v_curr_file
                                        ,p_region_id      => v_region_id
                                        ,p_process_name   => 'Process Form ' || p_region_title
                                        ,p_process_type   => 'NATIVE_FORM_DML'
                                        ,p_process_point  => 'AFTER_SUBMIT');
    
    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);
                                      
    return v_region_id;                                  
  end create_new_form_region;

  /*
   * create_new_button
   *
   * Creates a Button inside a region
   * Param: p_button_type: must have one of the following values: 'form_button_create', 'form_button_save', 'form_button_cancel', 'form_button_delete'
   */  
  procedure create_new_button(p_app_id in number, p_page_id in number, p_parent_region_id in number, p_button_name in varchar2, p_button_type in varchar2, p_primary_key_form_item_name in varchar2, p_target_page_id_on_cancel in varchar2 default null)
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id for buttons
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id  and upper(template_type) = 'BUTTON' and upper(internal_name) = 'TEXT';
    
    -- insert new button
    apex_import.insert_new_button (p_import_file                  => v_curr_file
                                  ,p_parent_region_id             => p_parent_region_id
                                  ,p_button_name                  => p_button_name
                                  ,p_button_type                  => p_button_type
                                  ,p_template_id                  => v_template_id
                                  ,p_primary_key_form_item_name   => p_primary_key_form_item_name
                                  ,p_target_page_on_cancel        => p_target_page_id_on_cancel);
                                  
    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);
  
  end create_new_button;

  /*
   * create_new_link_button
   *
   * Creates a linkbutton inside a region
   * Param: p_button_position: must have one of the following values: 'REGION_BODY', 'SORT_ORDER', 'NEXT', 'PREVIOUS', 'RIGHT_OF_IR_SEARCH_BAR'
   */  
  procedure create_new_link_button(p_app_id in number, p_page_id in number, p_button_name in varchar2, p_parent_region_id in number, p_target_page_id in number, p_button_position in varchar2)
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
    
    v_internal_button_pos varchar2(25);
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id for buttons
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id  and upper(template_type) = 'BUTTON' and upper(internal_name) = 'TEXT_WITH_ICON';
    
    if upper(p_button_position) = 'REGION_BODY'
    then
      -- REGION_BODY is the default, so we pass null to the apex_import call in this case, to signify that this parameter shouldn't be included in the import file
      v_internal_button_pos := null;
    else
      v_internal_button_pos := p_button_position;
    end if;
    
    -- insert new button
    apex_import.insert_new_link_button(p_import_file                  => v_curr_file
                                      ,p_template_id                  => v_template_id
                                      ,p_button_name                  => p_button_name
                                      ,p_parent_region_id             => p_parent_region_id
                                      ,p_target_page_id               => p_target_page_id
                                      ,p_button_position              => v_internal_button_pos
                                      ,p_is_button_hot                => 'Y'
                                      ,p_icon_css_class               => 'fa-plus-square-o');

    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);
  
  end create_new_link_button;

  /*
   * create_new_branch
   *
   * Creates a branch on a page that leads to the target page
   */   
  procedure create_new_branch(p_app_id in number, p_page_id in number, p_target_page_id in number)
  is
    v_curr_file         clob;
    v_import_file_name  varchar2(4000);
    v_template_id       apex_application_templates.template_id%type;
  begin
    v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);

    --get template_id for buttons
    select template_id 
      into v_template_id
      from APEX_APPLICATION_TEMPLATES 
     where application_id = p_app_id  and upper(template_type) = 'BUTTON' and upper(internal_name) = 'TEXT';
    
    -- insert new branch
    apex_import.insert_new_branch (p_import_file      => v_curr_file    
                                  ,p_page_id          => p_page_id
                                  ,p_target_page_id   => p_target_page_id
                                  ,p_branch_point     => 'AFTER_PROCESSING'
                                  ,p_branch_sequence  => 1);

    -- import the changed import file
    apex_application_install.install (p_source             => apex_import.package_import_file(p_file_name  => v_import_file_name, 
                                                                                              p_file       => v_curr_file),
                                      p_overwrite_existing => true);
  
  end create_new_branch;

/************************************************************************************
 *
 * Delete Procedures
 *
 ************************************************************************************/

  /*
   * delete_page
   *
   * Deletes an existing page in the given application with the given page ID
   */
  procedure delete_page(p_app_id in number, p_page_id in number)
  is
    v_import_code       clob;
    v_import_end_code   clob;
    v_forget_result     clob;

    v_plsql_params      apex_exec.t_parameters;
  begin
    -- the begin_create_operation can be reused for deleting pages because the necessary import start and end code is the same
    v_import_end_code := apex_editor.begin_create_operation(p_app_id =>p_app_id);
    
    -- get delete code and execute it
    v_import_code := apex_import.get_import_delete_page (p_page_id => p_page_id);
    
    apex_exec.execute_plsql(p_plsql_code          => v_import_code 
                            ,p_auto_bind_items    => false
                            ,p_sql_parameters     => v_plsql_params);

    -- import end
    apex_exec.execute_plsql(p_plsql_code          => v_import_end_code 
                            ,p_auto_bind_items    => false
                            ,p_sql_parameters     => v_plsql_params);
                            
    -- set the currently edited page to null, so the user does not try to navigate to the page that was just deleted
    v_forget_result := edit_functions.set_current_page_and_app_id (p_app_id   => p_app_id
                                                                  ,p_page_id  => null);  

  end delete_page; 


/************************************************************************************
 *
 * Debugging
 *
 ************************************************************************************/

  /*
   * debug_import
   *
   * parses a certain page import so it can be debugged afterwards
   */
  procedure debug_import(p_app_id in number, p_page_id in number, p_apex_session_id in varchar2)
  is
    v_curr_file clob;
    v_file_by_lines apex_t_clob;
    v_import_file_name varchar2(4000);
  begin
      v_curr_file := apex_editor.begin_edit_operation(p_app_id            => p_app_id, 
                                                    p_page_id           => p_page_id, 
                                                    p_import_file_name  => v_import_file_name);
    v_file_by_lines := apex_string.split_clobs(v_curr_file);
    --parse import file
    apex_import.parse_import_file(p_import_lines    => v_file_by_lines, 
                                  p_apex_session_id => p_apex_session_id);
  end debug_import;

end "APEX_EDITOR";
/