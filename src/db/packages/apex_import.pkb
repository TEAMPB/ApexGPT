create or replace package body "APEX_IMPORT" as

/************************************************************************************
 *
 * debugging utilities
 *
 ************************************************************************************/
 
  /*
   * debug_print_file_by_lines
   *
   * prints out the content of the import file using apex_debug.info including linenumbers.
   */
  procedure debug_print_file_by_lines(p_import_file in apex_t_clob)
  is
  begin
    for i in p_import_file.first .. p_import_file.count
    loop
      apex_debug.info(i || ':' || p_import_file(i));
    end loop;   
  end;

/************************************************************************************
 *
 * import file indexing utilities
 *
 ************************************************************************************/

  /*
   * get_app_import_file
   *
   * Returns: A clob containing the import file of the given page in the given application
   */ 
  function get_app_import_file(p_app_id in number, p_page_id in number, p_import_file_name in out varchar2)
  return clob
  is
    pragma autonomous_transaction;
  
    v_request_components  apex_t_varchar2 := apex_t_varchar2();
    v_files               apex_t_export_files;
    v_result_file         clob := null;
  begin
  
    if p_page_id is null
    then
      v_request_components := null;
    else
      v_request_components.extend;
      v_request_components(1) := 'PAGE:' || p_page_id;
    end if;
    
    v_files := apex_export.get_application(p_application_id => p_app_id
                                          --,p_split => true
                                          ,p_components=>v_request_components);

    --apex_debug.info('Number of files: ' || v_files.last)
    v_result_file       := v_files(1).contents;
    p_import_file_name  := v_files(1).name;
    
    if v_result_file is not null
    then 
      commit;
      return v_result_file;
    else
      rollback;
      raise_application_error(-20001, 'The page could not be found in the given application.');
    end if;
    

  end get_app_import_file;

  /*
   * get_proc_end_line_no
   *
   * Returns: the line number from the given file where the procedure, that begins at the line number, ends
   */
  function get_proc_end_line_no(p_search_file in apex_t_clob, p_proc_start_line in number)
  return number
  is
  begin
  
    apex_debug.info('get_proc_end_line_no: p_search_file.last: ' || p_search_file.last);
  
    -- loop returns the next line in the file starting from p_proc_start_line, that only contains a ); (not counting surrounding whitespaces)
    for i in p_proc_start_line..p_search_file.last
    loop 
      if trim(p_search_file(i)) = ');'
      then
        return i;
      end if;
    end loop;
    
    -- throw an error if no procedure-ending-line is found in the given procedure
    raise_application_error(-20001, 'error in get_proc_end_line_no: there was no end for the procedure found in the given file');
  end get_proc_end_line_no;

  /*
   * get_param_value_from_line
   *
   * Returns: the parameter value of the given parameter in that is present in the given line
   *          Or null if this line does not contain this parameter  
   */
  function get_param_value_from_line(p_line_content in clob, p_param_name in varchar2)
  return clob
  is
    v_param_begin     number;
    v_param_value     clob;  
  begin
    if lower(p_line_content) like '%' || lower(p_param_name) || '%'
    then
      --calculate where the parameter value begins in the line
      v_param_begin := instr(p_line_content, '=>', 1) + length('=>');
      
      --get the parameter value
      --length of the parameter value is calculated as "length(v_curr_line) - v_param_begin + 1" because v_param_begin is the first index of the param value, so just length(v_curr_line) - v_param_begin would not include the final character
      v_param_value :=  trim(substr(p_line_content, v_param_begin, length(p_line_content) - v_param_begin + 1));--
      return v_param_value;
    else
      return null;
    end if;
  end get_param_value_from_line;

  /*
   * get_param_string_value_from_line
   *
   * Returns: the parameter value of the given parameter that is present in the given line, it assumes this parameter is a string value and therefore removes the '-ticks that are around the parameter in the import file.
   *          Only works for single line values
   *          Or returns null if this line does not contain this parameter  
   */
  function get_param_string_value_from_line(p_line_content in clob, p_param_name in varchar2)
  return clob
  is
  begin
    return string_utils.remove_ticks_from_string(apex_import.get_param_value_from_line (p_line_content => p_line_content
                                                                                       ,p_param_name => p_param_name));
  end get_param_string_value_from_line;

  /*
   * get_param_string_value_from_line_as_varchar2
   *
   * Returns: the parameter value of the given parameter that is present in the given line, it assumes this parameter is a string value and therefore removes the '-ticks that are around the parameter in the import file.
   *          If the parameter is longer than 4000 bytes, only the first 4000 are returned as a varchar2. 
   *          Only works for single line values
   *          Returns null if this line does not contain this parameter  
   */
  function get_param_string_value_from_line_as_varchar2(p_line_content in clob, p_param_name in varchar2)
  return varchar2
  is 
  begin
    return dbms_lob.substr(string_utils.remove_ticks_from_string(apex_import.get_param_value_from_line(p_line_content => p_line_content
                                                                                                      ,p_param_name => p_param_name))
                          ,4000
                          ,1);
  end get_param_string_value_from_line_as_varchar2;

  /*
   * find_param_value_in_proc
   *
   * returns the parameter value of the given parameter in the procedure that starts at the given line in the p_search_file (an apex import file) 
   * Param p_proc_start_line: The line number in p_search_file where the procedure starts and thus the search should start
   */
  function find_param_value_in_proc(p_search_file in apex_t_clob, p_proc_start_line in number, p_param_name in varchar2)
  return clob
  is
    v_curr_line       varchar2(4000);
    v_param_begin     number;
    v_param_value     varchar2(4000);
  begin

    for i in p_proc_start_line..p_search_file.last
    loop 
      v_curr_line := p_search_file(i);
      exit when v_curr_line like '%);%';

      v_param_value := get_param_value_from_line(p_line_content   => v_curr_line
                                                ,p_param_name     => p_param_name);
      if v_param_value is not null
      then
        return v_param_value;
      end if;  
                                                
    end loop;

    return null;
  end find_param_value_in_proc;

  /*
   * parse_proc_params
   *
   * 
   */
  procedure parse_proc_params (p_search_file in apex_t_clob, p_proc_start_line in number, p_apex_session_id in tch_apex_app_struct.session_id%type, p_parent_apex_elem_id tch_apex_app_struct.parent_apex_elem_id%type)
  is
    v_curr_line       varchar2(4000);
    v_param_begin     number;
    v_param_end       number;
    v_param_name      TCH_APEX_APP_STRUCT.elem_name%type;
  begin
    for i in p_proc_start_line..p_search_file.last
    loop 
      v_curr_line := p_search_file(i);
      exit when v_curr_line like '%);%';

      -- lower case and trim whitespaces of the line, because we want to ignore parameter name capitalization and whitespaces that are the line
      v_curr_line := trim(lower(v_curr_line));
      --if line starts a new parameter
      if v_curr_line like ',%'
      then
        --calculate where the parameter name begins in the line (+1 needed, to not include the comma)
        v_param_begin := instr(v_curr_line, ',', 1) + 1;
        --calculate where the parameter name ends in the line
        v_param_end := instr(v_curr_line, '=>', 1);
        --get the parameter name
        v_param_name :=  trim(substr(v_curr_line, v_param_begin, v_param_end - v_param_begin));

        apex_app_struct.add_param(p_elem_name               => v_param_name,
                                  p_apex_elem_id            => null,
                                  p_parent_apex_elem_id     => p_parent_apex_elem_id, 
                                  p_import_file_start_line  => i,
                                  p_session_id              => p_apex_session_id);

      end if;
    end loop;
  end parse_proc_params;

  /*
   * parse_create_worksheet_column_proc
   *
   * Parses the create_worksheet_column procedure start starts at the line p_proc_start_line inside the import file p_import_lines
   * Parsing means entering the structure of the import file into the tch_apex_app_struct table
   */
  procedure parse_create_worksheet_column_proc(p_import_lines in apex_t_clob, p_proc_start_line in number, p_worksheet_id in tch_apex_app_struct.parent_apex_elem_id%type, p_apex_session_id in varchar2)
  is
    v_elem_id tch_apex_app_struct.parent_apex_elem_id%type;
  begin
  
    --apex_debug.info('parse_create_worksheet_column_proc');
    --apex_import.debug_print_file_by_lines(p_import_lines);
    --apex_debug.info('p_proc_start_line: ' || p_proc_start_line);
  
    if p_import_lines(p_proc_start_line) not like '%wwv_flow_imp_page.create_worksheet_column(%'
    then
      raise_application_error(-20001, 'error in parse_create_worksheet_column_proc: the given p_proc_start_line is not a line where a create_worksheet_column call starts.');
    end if;  
  
    v_elem_id := find_param_value_in_proc (p_search_file           => p_import_lines
                                          ,p_proc_start_line       => p_proc_start_line 
                                          ,p_param_name            =>'p_id');
    v_elem_id := string_utils.remove_flow_call_from_id(p_id_string => v_elem_id);
  
    -- The create worksheet_column calls always come directly after the worksheet that they belong to, so we can use the currently set worksheet_id as the parent ID for the column
    apex_app_struct.add_element (p_apex_elem_id            => v_elem_id,
                                 p_parent_apex_elem_id     => p_worksheet_id, 
                                 p_import_file_start_line  => p_proc_start_line,
                                 p_session_id              => p_apex_session_id,
                                 p_elem_type               => 'WORKSHEET_COLUMN');
                    
  
    -- insert all params of the create_worksheet_column procedure
    parse_proc_params (p_search_file => p_import_lines, 
                       p_proc_start_line => p_proc_start_line, 
                       p_apex_session_id => p_apex_session_id, 
                       p_parent_apex_elem_id => v_elem_id);
                       
  end parse_create_worksheet_column_proc;

  /*
   * parse_import_file
   *
   * Parses the given import file into the tch_apex_app_struct table
   */
  procedure parse_import_file(p_import_lines in apex_t_clob, p_apex_session_id in varchar2)
  is
    v_page_plug_id    tch_apex_app_struct.parent_apex_elem_id%type;
    v_worksheet_id    tch_apex_app_struct.parent_apex_elem_id%type;
    v_page_id         tch_apex_app_struct.parent_apex_elem_id%type;
    v_elem_id         tch_apex_app_struct.parent_apex_elem_id%type;

  begin

    -- clear previous import(s) that were made within the same session
    apex_debug.info('Session: ' || p_apex_session_id);
    apex_app_struct.clear_session(p_session_id => p_apex_session_id);

    for i in p_import_lines.first..p_import_lines.last
    loop
      
      case 
      --create_page
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_page(%'
      then
        -- get ID of the page
        v_page_id := find_param_value_in_proc(p_search_file           => p_import_lines
                                             ,p_proc_start_line       => i 
                                             ,p_param_name            =>'p_id');

        -- insert the page
        apex_app_struct.add_page(p_apex_elem_id           => v_page_id,
                                 p_parent_apex_elem_id     => null, 
                                 p_import_file_start_line  => i,
                                 p_session_id              => p_apex_session_id);

        -- insert all params of the create page procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_page_id);
    
      -- Base Region (page_plug)
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_page_plug(%'
      then
        -- get ID of the page_plug
        v_page_plug_id := find_param_value_in_proc(p_search_file           => p_import_lines
                                                    ,p_proc_start_line       => i 
                                                    ,p_param_name            =>'p_id');
        
        --remove the wwv_flow call around the actual ID
        v_page_plug_id := string_utils.remove_flow_call_from_id(p_id_string => v_page_plug_id);

        -- insert the page_plug
        apex_app_struct.add_page_plug (p_apex_elem_id           => v_page_plug_id,
                                       p_parent_apex_elem_id     => v_page_id, 
                                       p_import_file_start_line  => i,
                                       p_session_id              => p_apex_session_id);

        -- insert all params of the create page plug procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_page_plug_id);
        
      -- IR Column Container (worksheet)
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_worksheet(%'
      then
        -- get the worksheet's ID
        v_worksheet_id := find_param_value_in_proc(p_search_file           => p_import_lines
                                                  ,p_proc_start_line       => i 
                                                  ,p_param_name            =>'p_id');
        v_worksheet_id := string_utils.remove_flow_call_from_id(p_id_string => v_worksheet_id);
      
        -- The create worksheet always comes directly after the page plug that it belongs to, so we can use the currently set v_page_plug_id as the parent ID for the worksheet
        apex_app_struct.add_worksheet(p_apex_elem_id            => v_worksheet_id,
                                      p_parent_apex_elem_id     => v_page_plug_id, 
                                      p_import_file_start_line  => i,
                                      p_session_id              => p_apex_session_id);

        -- insert all params of the create worksheet procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_worksheet_id);
      -- IR Column (worksheet column)
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_worksheet_column(%'
      then
        apex_import.parse_create_worksheet_column_proc(p_import_lines       => p_import_lines
                                                      ,p_proc_start_line    => i
                                                      ,p_worksheet_id       => v_worksheet_id
                                                      ,p_apex_session_id    => p_apex_session_id);
        /*
         -- get the worksheet_column's ID
        v_elem_id := find_param_value_in_proc (p_search_file           => p_import_lines
                                              ,p_proc_start_line       => i 
                                              ,p_param_name            =>'p_id');
        v_elem_id := string_utils.remove_flow_call_from_id(p_id_string => v_elem_id);
      
        -- The create worksheet_column calls always come directly after the worksheet that they belong to, so we can use the currently set v_worksheet_id as the parent ID for the column
        apex_app_struct.add_element (p_apex_elem_id            => v_elem_id,
                                     p_parent_apex_elem_id     => v_worksheet_id, 
                                     p_import_file_start_line  => i,
                                     p_session_id              => p_apex_session_id,
                                     p_elem_type               => 'WORKSHEET_COLUMN');
                        

        -- insert all params of the create_worksheet_column procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_elem_id);
        */                    
      -- IR Worksheet Report 
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_worksheet_rpt(%'
      then    
      
        -- get the worksheet report's ID
        v_elem_id := find_param_value_in_proc (p_search_file           => p_import_lines
                                              ,p_proc_start_line       => i 
                                              ,p_param_name            =>'p_id');
        v_elem_id := string_utils.remove_flow_call_from_id(p_id_string => v_elem_id);                                      
      
        -- the create_worksheet_rpt call always comes after the column calls which come after the worksheet call. Thus, v_worksheet_id holds the worksheet ID, that the report belongs to
        apex_app_struct.add_element (p_apex_elem_id            => v_elem_id,
                                     p_parent_apex_elem_id     => v_worksheet_id, 
                                     p_import_file_start_line  => i,
                                     p_session_id              => p_apex_session_id,
                                     p_elem_type               => 'WORKSHEET_REPORT');
                                     
        -- insert all params of the create_worksheet_rpt procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_elem_id);
                           
      when lower(p_import_lines(i)) like '%wwv_flow_imp_page.create_page_item(%'
      then
      
        -- get the page item's ID
        v_elem_id := find_param_value_in_proc (p_search_file           => p_import_lines
                                              ,p_proc_start_line       => i 
                                              ,p_param_name            =>'p_name');
        v_elem_id := string_utils.remove_ticks_from_string(p_string => v_elem_id);                                     
        
        -- add the item to the previously created page plug (the form region)
        apex_app_struct.add_element (p_apex_elem_id            => v_elem_id,
                                     p_parent_apex_elem_id     => v_page_plug_id, 
                                     p_import_file_start_line  => i,
                                     p_session_id              => p_apex_session_id,
                                     p_elem_type               => 'PAGE_ITEM');
        
        -- insert all params of the create_page_item procedure
        parse_proc_params (p_search_file => p_import_lines, 
                           p_proc_start_line => i, 
                           p_apex_session_id => p_apex_session_id, 
                           p_parent_apex_elem_id => v_elem_id);
      
      --- TODO: add more supported procedures
      --when ...
      else
        continue;
      end case;
    end loop;

  end parse_import_file;


  /*
   * package_import_file
   *
   * packs an import file that was split linewise into one clob and inserts it into an apex_t_export_files structure alongside its file_name.
   */
  function package_import_file(p_file_name varchar2, p_file_by_lines apex_t_clob)
  return apex_t_export_files
  is
    v_import_files apex_t_export_files := apex_t_export_files();
    v_import_file apex_t_export_file;
  begin
    v_import_file := apex_t_export_file(p_file_name, apex_string.join_clobs (p_table => p_file_by_lines));
    
    v_import_files.extend;
    v_import_files(1) := v_import_file;

    return v_import_files;
  end;

  /*
   * package_import_file
   *
   * inserts an import file clob into an apex_t_export_files structure alongside its file_name.
   */
  function package_import_file(p_file_name varchar2, p_file clob)
  return apex_t_export_files
  is
    v_import_files apex_t_export_files := apex_t_export_files();
    v_import_file apex_t_export_file;
  begin
    v_import_file := apex_t_export_file(p_file_name, p_file);
    
    v_import_files.extend;
    v_import_files(1) := v_import_file;

    return v_import_files;
  end;

/************************************************************************************
 *
 * import file utilites
 *
 ************************************************************************************/

  /*
   * get_import_start_and_end
   *
   * Returns: An apex_t_export_files table that contains the file that needs to be executed to start an import procedure and the file needed to end the import.
   */
  function get_import_start_and_end(p_app_id in number)
  return apex_t_export_files
  is
    pragma autonomous_transaction;
  
    v_all_files             apex_t_export_files;
    v_result_files          apex_t_export_files := apex_t_export_files();
    v_start_or_end_file     apex_t_export_file;
  begin
    --export all files that make up the whole application import
    v_all_files := apex_export.get_application(p_application_id => p_app_id
                                              ,p_split => true);
                                 
    --find the files that start and end the import procedure and save them into v_result_files                                   
    for i in v_all_files.first .. v_all_files.last
    loop
      if v_all_files(i).name like '%end_environment.sql' 
          or v_all_files(i).name like '%set_environment.sql'
      then
      
        v_start_or_end_file := apex_t_export_file(v_all_files(i).name, v_all_files(i).contents);
      
        v_result_files.extend;
        v_result_files(v_result_files.last) := v_start_or_end_file;

      end if;  
    end loop;                             
    
    return v_result_files;
    
  end get_import_start_and_end;
  
  /*
   * get_proc_end_line
   *
   * Returns: The line number in the import file where the procedure that start on the given line ends
   */
  function get_proc_end_line(p_import_lines in apex_t_clob, p_proc_start_line in number)  
  return number
  is
    v_end_line number := -1;
  begin
  
    for i in p_proc_start_line..p_import_lines.last
    loop 
      if p_import_lines(i) like '%);%'
      then
        v_end_line := i;
        exit;
      end if;
    end loop;  
    
    if v_end_line <= 0
    then
      raise_application_error(-20001, 'Error while calling get_proc_end_line. There was no end found for the procedure or there is no procedure start on the given line.');
    end if;
    
    return v_end_line;
  end get_proc_end_line; 


/************************************************************************************
 *
 * Create procedures
 *
 ************************************************************************************/

  /*
   * get_import_create_new_page
   *
   * Returns: A clob that contains PL/SQL code for creating a new page with the given name, alias and title in the application that is currently being imported
   */    
  function get_import_create_new_page(p_page_id in number, p_page_name in varchar2, p_page_alias in varchar2,  p_page_title in varchar2)
  return clob  
  is 
    v_import_script clob;
  begin
    v_import_script := 
    q'~begin
wwv_flow_imp_page.create_page(
 p_id=>~' || p_page_id || q'~
,p_name=>'~' || p_page_name || q'~'
,p_alias=>'~' || p_page_alias || q'~'
,p_step_title=>'~' || p_page_title || q'~'
,p_autocomplete_on_off=>'OFF'
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
);
end;~';
--,p_last_updated_by=>'SIMON'
--,p_last_upd_yyyymmddhh24miss=>'20231110124706'

    return v_import_script;

  end get_import_create_new_page;

/************************************************************************************
 *
 * Delete procedures
 *
 ************************************************************************************/

  /*
   * get_import_delete_page
   *
   * Returns: A clob that contains PL/SQL code for deleting a page in the application that is currently being imported
   */    
  function get_import_delete_page(p_page_id in number)
  return clob  
  is 
    v_import_script clob;
  begin
    v_import_script := 
    q'~begin
wwv_flow_imp_page.remove_page (p_flow_id=>wwv_flow.g_flow_id, p_page_id=>~' || p_page_id || q'~);
end;~';

    return v_import_script;

  end get_import_delete_page;
  
/************************************************************************************
 *
 * Editing procedures
 *
 ************************************************************************************/

  /*
   * replace_value_single_line
   *
   * Replaces the value of the param in the given line with the given new_value.
   * ATTENTION: this only works for params that only cover a single line in the import file (including their value)
   *
   * Param: p_new_value: The new value that the parameter in the given line should receive. Note that this value needs to be a literal of the correct type, meaning varchar2 values need to include the surrounding ''.
   */  
  procedure replace_value_single_line (p_import_lines in out apex_t_clob, p_line_no number, p_new_value varchar2)
  is
    v_curr_line clob;
    v_valueless_line clob;
    v_param_value_begin number;
  begin

    v_curr_line := p_import_lines(p_line_no);
    v_param_value_begin := instr(v_curr_line, '=>', 1) + 2;
    
    --get the line without the value
    v_valueless_line :=  trim(substr(v_curr_line, 1, v_param_value_begin - 1));

    p_import_lines(p_line_no) := v_valueless_line || p_new_value;
  end replace_value_single_line;
  
  /*
   * replace_single_line_value
   *
   * Replaces the single line value at the line p_start_line_no by the given multiline value p_new_value in the import file p_import_lines.
   * This is intended only for internal use by replace_param_value. replace_param_value is designed to handle all different combinations of new & old values being multi or single line values
   */
  procedure replace_single_line_value(p_import_lines in out apex_t_clob, p_start_line_no in number, p_new_value in clob, p_is_new_value_string in boolean, p_removed_lines_count in number, p_apex_session_id in number)
  is
    v_split_new_value         apex_t_clob;
    v_added_lines_count       number;
    v_single_line_new_value   clob;
  begin
    -- Check if new value is a multiline value
    if not string_utils.is_clob_single_line(p_clob => p_new_value)
    then-- CASE: new value is multi line
    
      -- insert starting call for multiline value in the line where the parameter starts
      apex_import.replace_value_single_line(p_import_lines  => p_import_lines, 
                                            p_line_no       => p_start_line_no, 
                                            p_new_value     => 'wwv_flow_string.join(wwv_flow_t_varchar2(' || chr(10));
      
      -- insert the value lines one by one after the starting parameter line                          
      v_split_new_value := apex_string.split_clobs(string_utils.convert_clob_to_multiline_t_varchar2(p_clob => p_new_value)); 
      for new_line_no in v_split_new_value.first .. v_split_new_value.last                           
      loop                          
        string_utils.insert_line_into_array (p_clob_array => p_import_lines
                                            ,p_line => v_split_new_value(new_line_no) || case when new_line_no = v_split_new_value.last then '))' else '' end
                                            ,p_index => p_start_line_no + new_line_no);  
      end loop;  
             
      -- update the line numbers in tch_apex_app_struct
      -- number of value lines in the new value: v_split_new_value.count
      -- number of lines from the old value (they were already removed): p_removed_lines_count
      v_added_lines_count := v_split_new_value.count - p_removed_lines_count;-- the netto number of lines that were added (accounting for the lines removed if the old value was multiline), may be negative
      --update the line numbers in the parsing table, to account for the new added/removed lines
      update tch_apex_app_struct
         set import_file_start_line = import_file_start_line + v_added_lines_count
       where session_id = p_apex_session_id
         and import_file_start_line >= p_start_line_no + 1;
         
    else -- CASE: new value is single line
    
      if p_is_new_value_string
      then
        --add single quotes around value and escape single quotes inside the value because it is a single line string value
        v_single_line_new_value := q'~'~' || string_utils.escape_single_quotes(p_new_value) || q'~'~';
      else
        -- value is a number
        v_single_line_new_value := p_new_value;
      end if;
    
      -- replace the value in the line where the parameter starts, because it is single line
      replace_value_single_line(p_import_lines  => p_import_lines, 
                                p_line_no       => p_start_line_no, 
                                p_new_value     => v_single_line_new_value);
                                
      -- update the line numbers in the parsing table, to account for the removed lines, if the old value was multiline 
      update tch_apex_app_struct
         set import_file_start_line = import_file_start_line - p_removed_lines_count
       where session_id = p_apex_session_id
         and import_file_start_line >= p_start_line_no + 1;
    end if;
    
  end replace_single_line_value;
  
  /*
   * replace_param_value
   *
   * Replaces the value of the param in the given line with the given new_value. Properly handles if new value and/or old value are multiline values
   *
   * Param: p_new_value: The new value that the parameter in the given line should receive.
   *                     Multiline values are always strings, so in this case a regular multiline clob must be provided. Everything else is handled by the procedure internally.
   * Param: p_is_new_value_string: If p_new_value is a string (clob/varchar2) and not a number, this parameter must be true
   */  
  procedure replace_param_value  (p_import_lines in out apex_t_clob, p_start_line_no in number, p_new_value in clob, p_is_new_value_string in boolean, p_apex_session_id in number)
  is
    v_value_start_line number;
    v_value_end_line number;
    v_valueless_line clob;
    v_param_value_begin number;
    
    v_removed_lines_count   number;
  begin
  
    -- default is zero, because single line values only exist on the line with the parameter name, so no lines are removed for those
    v_removed_lines_count := 0;

    -- if the existing value is a multiline value
    if p_import_lines(p_start_line_no) like '%wwv_flow_string.join(wwv_flow_t_varchar2%'
    then
      -- to replace a multiline value with a new value, we remove the multiline portion first, so we can then treat it as single line
      apex_debug.info('replace_param_value: OLD VALUE = multiline');
      
      --find out from which line to which other line the value lies
      v_value_start_line := p_start_line_no + 1;
      for i in v_value_start_line..p_import_lines.last
      loop
        if p_import_lines(i) like q'~'%~' or p_import_lines(i) like q'~unistr('%~'
        then
          continue;
        else
          v_value_end_line := i - 1;
          exit;
        end if;
      end loop;
      
      --delete the value lines from back to front (to avoid problems from changing indices while deleting)
      --this does not include the line where the value starts, as this gets replaced later
      p_import_lines.DELETE(v_value_start_line, v_value_end_line);
      v_removed_lines_count := v_value_end_line - v_value_start_line + 1;
      
      -- remove the empty indices in the middle that were created by the delete statement
      p_import_lines := string_utils.make_dense_clob_collection(p_sparse_clobs => p_import_lines);
    end if;
    
    -- the existing value can now be assumed to be single line, so we replace it with the appropriate procedure
    apex_import.replace_single_line_value (p_import_lines         => p_import_lines
                                          ,p_start_line_no        => p_start_line_no
                                          ,p_new_value            => p_new_value
                                          ,p_is_new_value_string  => p_is_new_value_string
                                          ,p_removed_lines_count  => v_removed_lines_count
                                          ,p_apex_session_id      => p_apex_session_id);
    
  end replace_param_value;  

  /*
   * insert_or_replace_param
   *
   * replaces the given value of the given parameter. Both the existing and the new parameter value may have multiple lines. 
   * The procedure correctly handles all cases and updates the tch_apex_app_struct accordingly, if it changes the line number in the import file
   *
   * Param: p_parent_proc_type: A valid value of the column tch_apex_app_struct.elem_type, e.g. 'PAGE', 'PAGE_PLUG', 'PAGE_ITEM', 'WORKSHEET', 'WORKSHEET_COLUMN', 'WORKSHEET_REPORT', or 'PARAM'
   * Param: p_new_value: The new value that the parameter in the given line should receive.
   *                     Multiline values are always strings, so in this case a regular multiline clob must be provided. Everything else is handled by the procedure internally.
   * Param: p_is_new_value_string: If p_new_value is a string (clob/varchar2) and not a number, this parameter must be true
   */
  procedure insert_or_replace_param(p_import_lines in out apex_t_clob, p_param_name in varchar2, p_parent_proc_type in varchar2, p_parent_apex_elem_id in tch_apex_app_struct.parent_apex_elem_id%type, p_new_value in clob, p_is_new_value_string in boolean, p_apex_session_id in number)
  is
    v_line_no                 tch_apex_app_struct.import_file_start_line%type;
    v_column_exists           number;
    v_param_exists            number;
    
    v_param_starting_line_no  number;
    v_added_lines_count       number;
    v_split_new_value         apex_t_clob; 
    v_single_line_new_value   clob;
  begin
    
    -- check if the param is already present
    select count(*)
      into v_param_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = p_param_name
       and parent_apex_elem_id = p_parent_apex_elem_id;  
    
    if p_parent_proc_type = 'WORKSHEET_REPORT'
    then 
      apex_debug.info('######## insert or replace in WORKSHEET_REPORT #########');
      apex_debug.info('param: ' || p_param_name);
      apex_debug.info('found: ' || v_param_exists);
    end if;
    
    if v_param_exists = 0
    then
      -- CASE: parameter does not exist, so we must insert it
      
      if string_utils.is_clob_single_line(p_clob => p_new_value)
      then -- CASE: new value is single line
           
        if p_is_new_value_string
        then
          --add single quotes around value and escape single quotes inside the value because it is a single line string value
          v_single_line_new_value := q'~'~' || string_utils.escape_single_quotes(p_new_value) || q'~'~';
        else
          -- value is a number
          v_single_line_new_value := p_new_value;
        end if;
        
        -- get the line where the procedure starts
        select import_file_start_line
          into v_line_no
          from tch_apex_app_struct
         where session_id = p_apex_session_id
           and elem_type = p_parent_proc_type
           and apex_elem_id = p_parent_apex_elem_id;  
           
                    
        apex_debug.info('Inserting single line value, line: ' || (v_line_no+2));  
        apex_debug.info('p_param_name: ' || p_param_name);
        apex_debug.info('New value (original): ' || p_new_value);
        apex_debug.info('New value (updated): ' || v_single_line_new_value);
        
        -- insert the parameter into the next line after the ID (the ID is always the first line after the procedure start)
        string_utils.insert_line_into_array(p_clob_array => p_import_lines, 
                                            p_line => ',' || p_param_name || '=>' || v_single_line_new_value, 
                                            p_index => v_line_no + 2);
                                            
        --update the line numbers in the parsing table, to account for the new added line
        update tch_apex_app_struct
           set import_file_start_line = import_file_start_line + 1
         where session_id = p_apex_session_id
           and import_file_start_line >= v_line_no + 2;
      
      else -- CASE: new value is multiline
      
        -- insert the parameter's starting line into the next line after the ID (the ID is always the first line after the procedure start)
        v_param_starting_line_no := v_line_no + 2;
        string_utils.insert_line_into_array(p_clob_array => p_import_lines, 
                                            p_line => ',' || p_param_name || '=>' || 'wwv_flow_string.join(wwv_flow_t_varchar2(' || chr(10), 
                                            p_index => v_param_starting_line_no);
        
        -- insert the value lines one by one after the starting parameter line    
        v_split_new_value := apex_string.split_clobs(string_utils.convert_clob_to_multiline_t_varchar2(p_clob => p_new_value)); 
        for new_line_no in v_split_new_value.first .. v_split_new_value.last                           
        loop                          
          string_utils.insert_line_into_array (p_clob_array => p_import_lines
                                              ,p_line => v_split_new_value(new_line_no) || case when new_line_no = v_split_new_value.last then '))' else '' end
                                              ,p_index => v_param_starting_line_no + new_line_no);  
        end loop;                                      
                                            
        -- update the line numbers in the parsing table, to account for the newly added line(s)
        -- v_split_new_value.count holds the number of new lines that were added for the value. The  +1 is the line that holds the parameter name line (see the single insert_line_into_array call above)
        v_added_lines_count := v_split_new_value.count + 1;
        update tch_apex_app_struct
           set import_file_start_line = import_file_start_line + v_added_lines_count
         where session_id = p_apex_session_id
           and import_file_start_line >= v_param_starting_line_no;
           
      end if;
      
    else -- CASE: parameter exists, so we must replace its value
    
      -- get its line and replace its value
      select import_file_start_line
        into v_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'PARAM'
         and elem_name = p_param_name
         and parent_apex_elem_id = p_parent_apex_elem_id;
         
      apex_debug.info('Replacing single line value, line: ' || v_line_no);  
      apex_debug.info('p_param_name: ' || p_param_name);
      apex_debug.info('New value: ' || p_new_value);
      
      apex_import.replace_param_value (p_import_lines         => p_import_lines, 
                                       p_start_line_no        => v_line_no, 
                                       p_new_value            => p_new_value,
                                       p_is_new_value_string  => p_is_new_value_string,
                                       p_apex_session_id      => p_apex_session_id);
    end if;
  end insert_or_replace_param;

  /*
   * remove_proc_call
   *
   * removes the procedure call from the import file
   *
   * Param: p_parent_apex_elem_id: The apex elem ID from the tch_apex_app_struct table of the procedure call that contains the parameter
   * Param: p_proc_type: The type of procedure call that should be removed. A valid value of the column tch_apex_app_struct.elem_type, e.g. 'PAGE', 'PAGE_PLUG', 'PAGE_ITEM', 'WORKSHEET', 'WORKSHEET_COLUMN', 'WORKSHEET_REPORT'
   */
  procedure remove_proc_call(p_import_lines in out apex_t_clob, p_proc_type in varchar2, p_apex_elem_id in tch_apex_app_struct.parent_apex_elem_id%type, p_apex_session_id in number)
  is
    v_param_exists          number;
    v_proc_start_line       tch_apex_app_struct.import_file_start_line%type;
    v_proc_end_line         tch_apex_app_struct.import_file_start_line%type;
    v_removed_lines_count   number;
  begin
    
    -- check if the procedure exists
    select count(*)
      into v_param_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = p_proc_type
       and apex_elem_id = p_apex_elem_id;  
    
    if v_param_exists > 0
    then
      -- procedure call exists, so we must remove it 
         
      -- get the line that the procedure call is on 
      select import_file_start_line
        into v_proc_start_line
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = p_proc_type
         and apex_elem_id = p_apex_elem_id; 
      
      -- debug prints            
      apex_debug.info('Removeproc call, line: ' || (v_proc_start_line));  
      apex_debug.info('proc type: ' || p_proc_type);
      apex_debug.info('proc id: ' || p_apex_elem_id);
      
      -- get the line where the procedure ends
      v_proc_end_line := apex_import.get_proc_end_line(p_import_lines => p_import_lines
                                                      ,p_proc_start_line => v_proc_start_line);
      -- remove the procedure & its params from the import file                                                
      p_import_lines.DELETE(v_proc_start_line, v_proc_end_line);
      v_removed_lines_count := v_proc_end_line - v_proc_start_line + 1;                        
      --remove the empty index in the middle that were created by the delete statement.
      p_import_lines := string_utils.make_dense_clob_collection(p_sparse_clobs => p_import_lines);
                                      
      --delete the proc from the parsing table
      delete from tch_apex_app_struct
       where session_id = p_apex_session_id
         and import_file_start_line = v_proc_start_line
         and elem_type = p_proc_type
         and apex_elem_id = p_apex_elem_id;
         
      --delete all proc params from the parsing table
      delete from tch_apex_app_struct
       where session_id = p_apex_session_id
         and import_file_start_line = v_proc_start_line
         and elem_type = 'PARAM'
         and parent_apex_elem_id = p_apex_elem_id;
                                          
      --update the line numbers in the parsing table, to account for the removed line
      update tch_apex_app_struct
         set import_file_start_line = import_file_start_line - v_removed_lines_count
       where session_id = p_apex_session_id
         and import_file_start_line >= v_proc_start_line;
 
    end if;
  end remove_proc_call; 


  /*
   * remove_param_single_line
   *
   * removes the given parameter line
   *
   * Param: p_parent_apex_elem_id: The apex elem ID from the tch_apex_app_struct table of the procedure call that contains the parameter
   */
  procedure remove_param_single_line(p_import_lines in out apex_t_clob, p_param_name in varchar2, p_parent_apex_elem_id in tch_apex_app_struct.parent_apex_elem_id%type, p_apex_session_id in number)
  is
    v_param_exists number;
    v_param_line tch_apex_app_struct.import_file_start_line%type;
  begin
    
    -- check if the format mask param is already present
    select count(*)
      into v_param_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = p_param_name
       and parent_apex_elem_id = p_parent_apex_elem_id;  
    
    if v_param_exists > 0
    then
      -- parameter exists, so we must remove it 
         
      -- get the line that the parameter is on 
      select import_file_start_line
        into v_param_line
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'PARAM'
         and elem_name = p_param_name
         and parent_apex_elem_id = p_parent_apex_elem_id; 
      
      -- debug prints            
      apex_debug.info('Remove single line param, line: ' || (v_param_line));  
      apex_debug.info('p_param_name: ' || p_param_name);
      
      -- remove the line from the import file
      p_import_lines.DELETE(v_param_line);  
      --remove the empty index in the middle that were created by the delete statement.
      p_import_lines := string_utils.make_dense_clob_collection(p_sparse_clobs => p_import_lines);
                                      
      --delete the proc from the parsing table
      delete from tch_apex_app_struct
       where session_id = p_apex_session_id
         and import_file_start_line = v_param_line
         and elem_type = 'PARAM'
         and elem_name = p_param_name
         and parent_apex_elem_id = p_parent_apex_elem_id;
                                          
      --update the line numbers in the parsing table, to account for the removed line
      update tch_apex_app_struct
         set import_file_start_line = import_file_start_line - 1
       where session_id = p_apex_session_id
         and import_file_start_line >= v_param_line;
 
    end if;
  end remove_param_single_line;  


  
  /*
   * insert_or_replace_param_single_line
   *
   * replaces the given value of the given parameter. This is a legacy procedure from a time when multiline values were not supported in the package. 
   * You should use insert_or_replace_param instead, which properly handles single and multiline values
   *
   * Param: p_new_value: The new value that the parameter should receive. Note that this value needs to be a literal of the correct type, meaning varchar2 values need to include the surrounding ''.
   */
  procedure insert_or_replace_param_single_line(p_import_lines in out apex_t_clob, p_param_name in varchar2, p_parent_proc_type in varchar2, p_parent_apex_elem_id in tch_apex_app_struct.parent_apex_elem_id%type, p_new_value in varchar2, p_apex_session_id in number)
  is
    v_line_no tch_apex_app_struct.import_file_start_line%type;
    v_column_exists number;
    v_param_exists number;
  begin
    
    -- check if the param is already present
    select count(*)
      into v_param_exists
      from tch_apex_app_struct
     where session_id = p_apex_session_id
       and elem_type = 'PARAM'
       and elem_name = p_param_name
       and parent_apex_elem_id = p_parent_apex_elem_id;  
    
    if v_param_exists = 0
    then
      -- parameter does not exist, so we must insert it first
      
      -- get the line where the procedure starts
      select import_file_start_line
        into v_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = p_parent_proc_type
         and apex_elem_id = p_parent_apex_elem_id;  
         
                  
      apex_debug.info('Inserting single line value, line: ' || (v_line_no+2));  
      apex_debug.info('p_param_name: ' || p_param_name);
      apex_debug.info('New value: ' || p_new_value);
      
      -- insert the parameter into the next line after the ID (the ID is always the first line after the procedure start
      string_utils.insert_line_into_array(p_clob_array => p_import_lines, 
                                          p_line => ',' || p_param_name || '=>' || p_new_value, 
                                          p_index => v_line_no + 2);
                                          
      --update the line numbers in the parsing table, to account for the new added line
      update tch_apex_app_struct
         set import_file_start_line = import_file_start_line + 1
       where session_id = p_apex_session_id
         and import_file_start_line >= v_line_no + 2;
      
    else
      -- parameter exists, thus we can get its line and replace its value
      select import_file_start_line
        into v_line_no
        from tch_apex_app_struct
       where session_id = p_apex_session_id
         and elem_type = 'PARAM'
         and elem_name = p_param_name
         and parent_apex_elem_id = p_parent_apex_elem_id;
         
      apex_debug.info('Replacing single line value, line: ' || v_line_no);  
      apex_debug.info('p_param_name: ' || p_param_name);
      apex_debug.info('New value: ' || p_new_value);
      
      apex_import.replace_value_single_line (p_import_lines       => p_import_lines, 
                                             p_line_no            => v_line_no, 
                                             p_new_value          => p_new_value);
    end if;
  end insert_or_replace_param_single_line;  

/************************************************************************************
 *
 * Insert Procedures
 *
 ************************************************************************************/

  /*
   * insert_at_end
   * 
   * Inserts the given plsql import procedure call(s) at the end of the import file, just before the final 'end;'-statement of the import code block
   */
  procedure insert_at_end(p_import_file in out clob, p_insert_plsql in clob)
  is
    v_import_end_prompt_pos number;
    v_import_end_pos number;
    
    v_import_file_part1 clob;
    v_import_file_part2 clob;
  begin
  
    --calculate where the plsql call needs to be inserted
    v_import_end_prompt_pos   := instr(p_import_file, 'prompt --application/end_environment');
    v_import_end_pos          := instr(p_import_file, 'end;', v_import_end_prompt_pos - length(p_import_file));
    --split import file into the two parts, part 1 comes before the clob to be inserted, part 2 comes behind it
    v_import_file_part1 := substr(p_import_file, 1, v_import_end_pos - 1);
    v_import_file_part2 := substr(p_import_file, v_import_end_pos, length(p_import_file) - v_import_end_pos + 1);
    --insert the insert clob
    p_import_file := v_import_file_part1 || p_insert_plsql || v_import_file_part2;
  
  end insert_at_end;

  /*
   * insert_new_page_plug
   *
   * Inserts a create page plug call into the given import file clob (p_import_file).
   * Attention: The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */  
  procedure insert_new_page_plug (p_import_file in out clob, p_region_id in number, p_region_title in varchar2, p_template_id in number, p_display_sequence in number, p_text in clob)
  is
    v_insert_plsql clob;
    
    v_import_end_prompt_pos number;
    v_import_end_pos      number;
    
    v_import_file_part1   clob;
    v_import_file_part2   clob;
    v_split_text          apex_t_clob; 
  begin
   
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_plug(
p_id=>wwv_flow_imp.id(~' || p_region_id || q'~)
,p_plug_name=>'~' || p_region_title || q'~'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>wwv_flow_imp.id(~' || p_template_id || q'~)
,p_plug_display_sequence=>~' || p_display_sequence ;

    if string_utils.is_clob_single_line(p_clob => p_text)
    then -- CASE: text value is single line
           
        v_insert_plsql := v_insert_plsql || q'~
,p_plug_source=>'~' || string_utils.escape_single_quotes(p_text) || q'~'~'; 

    else -- CASE: new value is multiline
        
        --insert multiline string start
        v_insert_plsql := v_insert_plsql || q'~
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(~';
        
        -- insert the multiple lines of text one by one after the starting parameter line    
        v_split_text := apex_string.split_clobs(string_utils.convert_clob_to_multiline_t_varchar2(p_clob => p_text)); 
        
        for new_line_no in v_split_text.first .. v_split_text.last                           
        loop                          
          v_insert_plsql := v_insert_plsql || q'~
~' || v_split_text(new_line_no) || case when new_line_no = v_split_text.last then '))' else '' end;  
        end loop;                                      
         
    end if;
      
    v_insert_plsql := v_insert_plsql || q'~
,p_attribute_01=>'N'
,p_attribute_02=>'HTML'
);~';  

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

    apex_debug.info('FILE:');
    apex_debug.info(p_import_file);
  
  end insert_new_page_plug;


/************************************************************************************
 *
 * Worksheets & Worksheet Columns
 *
 ************************************************************************************/
  
  /*
   * get_create_worksheet_column_plsql
   *
   * Returns: the plsql import code for creating a worksheet column based on the given parameters. The last line is ');' it does not end with an empty newline 
   */
  function get_create_worksheet_column_plsql(p_is_hidden_column in boolean, p_is_primary_key in varchar2 default 'N', p_id in number, p_db_column_name in varchar2, p_display_order in number, p_column_identifier in varchar2, p_column_label in varchar2, p_column_type in varchar2)
  return clob
  is
    v_worksheet_column_plsql clob;
  begin
  
    --create basic column code for all kinds of columns
    v_worksheet_column_plsql := q'~
wwv_flow_imp_page.create_worksheet_column(
p_id=>wwv_flow_imp.id(~' || p_id || q'~)
,p_db_column_name=>'~' || p_db_column_name || q'~'
,p_display_order=>~' || p_display_order || q'~
,p_is_primary_key=>'~' || p_is_primary_key || q'~'
,p_column_identifier=>'~' || p_column_identifier || q'~'
,p_column_label=>'~' || p_column_label || q'~'
,p_column_type=>'~' || p_column_type || q'~'~';
  
    if p_is_hidden_column
    then
      -- create append parameter for hidden column 
      v_worksheet_column_plsql := v_worksheet_column_plsql || q'~
,p_display_text_as=>'HIDDEN_ESCAPE_SC'
);~';
      --return the column code, since hidden columns do not get more parameters
      return v_worksheet_column_plsql;
    end if;
  
    --add the basic parameters for a visible column
    v_worksheet_column_plsql := v_worksheet_column_plsql || q'~
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'~';
  
    --append date specific parameter if applicable
    if upper(p_column_type) = 'DATE'
    then
      v_worksheet_column_plsql := v_worksheet_column_plsql || q'~
,p_tz_dependent=>'N'~';
    end if;
    
    --append closing brace
    v_worksheet_column_plsql := v_worksheet_column_plsql || q'~
);~';
    --return finished import code for the column
    return v_worksheet_column_plsql;
  
  end get_create_worksheet_column_plsql;
  
  /*
   * insert_new_ir_region
   *
   * Inserts a new interactive report region in the given import file.
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   * - The sql statement p_sql_statement must not have more columns than there are letters in the alphabet (26)
   */  
  function insert_new_ir_region (p_import_file in out clob, p_region_title in varchar2, p_template_id in number, p_display_sequence in number, p_sql_statement in clob, p_columns_desc in db_utils.t_sql_desc)
  return number
  is
    v_insert_plsql clob;
    
    v_owner_name varchar2(4000);
    v_curr_column_identifier char(1);
    
    v_report_columns clob;
    v_linesplit_clob apex_t_clob;
    
    v_region_id number;
  begin
    
    
    -- determine v_owner_name
    v_owner_name := v('APP_USER');
    
    --get new region id
    v_region_id := apex_ids.get_id('#ir-' || p_region_title);
  
    -- build basic import code  
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_plug(
p_id=>wwv_flow_imp.id(~' || v_region_id || q'~)
,p_plug_name=>'~' || p_region_title || q'~'
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(~' || p_template_id || q'~)
,p_plug_display_sequence=>~' || p_display_sequence || q'~
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
~' || string_utils.convert_clob_to_multiline_t_varchar2(p_sql_statement) || q'~))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header=>'Dept SQL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);

wwv_flow_imp_page.create_worksheet(
p_id=>wwv_flow_imp.id(~' || apex_ids.get_id('#ir-worksheet-' || p_region_title) || q'~)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'~' || v_owner_name || q'~'
,p_internal_uid=>~' || apex_ids.get_id('#ir-worksheet-' || p_region_title) || q'~
);~';

    -- append all necessary worksheet columns
    v_curr_column_identifier := 'A';
    for i in p_columns_desc.first .. p_columns_desc.last
    loop
      v_insert_plsql := v_insert_plsql || get_create_worksheet_column_plsql (p_is_hidden_column   => false
                                                                            ,p_is_primary_key     => 'N' --interactive reports never need a primary key column
                                                                            ,p_id                 => apex_ids.get_id('#ir-worksheet-column-' || p_region_title || '-' || v_curr_column_identifier)
                                                                            ,p_db_column_name     => p_columns_desc(i).column_name
                                                                            ,p_display_order      => i * 10
                                                                            ,p_column_identifier  => v_curr_column_identifier
                                                                            ,p_column_label       => initcap(p_columns_desc(i).column_name)
                                                                            ,p_column_type        => upper(p_columns_desc(i).column_type));
      -- get next letter in alphabet                                                              
      v_curr_column_identifier := chr(ASCII(v_curr_column_identifier) + 1);                                                                
    end loop;
    
    --calculate report columns as colon separated list of all columns in the select
    select listagg(column_name, ':') within group (order by rownum)
    into v_report_columns
    from table(p_columns_desc);
    
    -- append final report creation call
    v_insert_plsql := v_insert_plsql || q'~
wwv_flow_imp_page.create_worksheet_rpt(
p_id=>wwv_flow_imp.id(~' || apex_ids.get_id('#ir-worksheet-rpt-' || p_region_title) || q'~)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'~' || apex_ids.get_id('#ir-worksheet-rpt-alias-' || p_region_title) || q'~'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'~' || v_report_columns || q'~'
);
~';

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

    /*
    apex_debug.info('############ IR Import FILE ###############');
    --split the clob into its individual lines
    v_linesplit_clob := apex_string.split_clobs(p_import_file);
    -- print file with linenumbers
    for i in v_linesplit_clob.first  .. v_linesplit_clob.last
    loop
      apex_debug.info(i || ':' || v_linesplit_clob(i));
    end loop;*/
      
    --apex_debug.info(p_import_file);
    return v_region_id;
  
  end insert_new_ir_region;


  /*
   * insert_new_worksheet_column
   *
   * Inserts a PLSQL procedure call after after the worksheet with the given ID or after one of its worksheet_columns.
   * Also updates the parsing table tch_apex_app_struct to include the new column
   */
  procedure insert_new_worksheet_column(p_import_file in out apex_t_clob, p_worksheet_id in number, p_column_desc in db_utils.column_desc, p_column_identifier in varchar2, p_display_order in number, p_apex_session_id in number)
  is
    v_proc_call_start_line        tch_apex_app_struct.import_file_start_line%type;
    v_proc_call_end_line          tch_apex_app_struct.import_file_start_line%type;
    v_insert_column_plsql         apex_t_clob;
    v_insert_column_plsql_length  number;
    v_new_column_start_line       tch_apex_app_struct.import_file_start_line%type;
  begin
  
    apex_debug.info('insert new workshet column: ' ||p_column_desc.column_name);
    apex_debug.info('p_worksheet_id: ' || p_worksheet_id);
    apex_debug.info('p_apex_session_id: ' || p_apex_session_id);
    
    -- get the line where the last existing worksheet column of the worksheet starts (or the worksheet itself, if it does not have any columns for some reason) 
    select max(import_file_start_line)
      into v_proc_call_start_line
      from tch_apex_app_struct
     where elem_type in ('WORKSHEET', 'WORKSHEET_COLUMN')
       and (parent_apex_elem_id = p_worksheet_id or apex_elem_id = p_worksheet_id)
       and session_id = p_apex_session_id;
       
    apex_debug.info('last worksheet column: v_proc_call_start_line: ' || v_proc_call_start_line);
    

    -- now get the line where that procedure ends  
    v_proc_call_end_line := get_proc_end_line_no(p_search_file      => p_import_file
                                                ,p_proc_start_line  => v_proc_call_start_line);
    
    -- get the plsql code for creating the new column
    v_insert_column_plsql := apex_string.split_clobs(get_create_worksheet_column_plsql(p_is_hidden_column   => false
                                                                                      ,p_is_primary_key     => 'N' --interactive reports never need a primary key column
                                                                                      ,p_id                 => apex_ids.get_id('#ir-worksheet-column-' || p_worksheet_id || '-' || p_column_identifier || '-' || v_proc_call_end_line)
                                                                                      ,p_db_column_name     => p_column_desc.column_name
                                                                                      ,p_display_order      => p_display_order
                                                                                      ,p_column_identifier  => p_column_identifier
                                                                                      ,p_column_label       => initcap(p_column_desc.column_name)
                                                                                      ,p_column_type        => upper(p_column_desc.column_type)));
    
    -- insert the new create worksheet column call behind the line calculated above 
    v_new_column_start_line := v_proc_call_end_line + 1;
    string_utils.insert_block_into_array(p_clob_array           => p_import_file
                                        ,p_insert_clob_block    => v_insert_column_plsql
                                        ,p_starting_index       => v_new_column_start_line);
    
    -- update the parsing table
    -- First: update the line numbers of the existing elements
    v_insert_column_plsql_length := v_insert_column_plsql.count;-- necessary because v_insert_column_plsql.count cannot be used in sql statements
    update tch_apex_app_struct
       set import_file_start_line = import_file_start_line + v_insert_column_plsql_length
     where session_id = p_apex_session_id
       and import_file_start_line >= v_new_column_start_line;
       
    -- Second: parse the newly inserted procedure  
    apex_import.parse_create_worksheet_column_proc(p_import_lines       => p_import_file
                                                  ,p_proc_start_line    => v_new_column_start_line
                                                  ,p_worksheet_id       => p_worksheet_id
                                                  ,p_apex_session_id    => p_apex_session_id);  
                                      
  end insert_new_worksheet_column;
  

  /*
   * change_sql_statement_in_region
   *
   * Changes the SQL statement in a page plug and updates the p_report_columns parameter in its worksheet report.
   * ATTENTION: This procedure does not change anything about the individual worksheet columns present in the import file. This has to be done seperately
   */
  procedure change_sql_statement_in_region(p_import_file in out apex_t_clob, p_region_id in number, p_sql_statement in clob, p_columns_desc in db_utils.t_sql_desc, p_apex_session_id number)
  is
    v_worksheet_report_id tch_apex_app_struct.apex_elem_id%type;
    v_report_columns varchar2(4000);
  begin
    /*
     * replace the p_query_type in the page plug
     */
    apex_import.insert_or_replace_param (p_import_lines         => p_import_file
                                        ,p_param_name           => 'p_query_type'
                                        ,p_parent_proc_type     => 'PAGE_PLUG'
                                        ,p_parent_apex_elem_id  => p_region_id
                                        ,p_new_value            => 'SQL'
                                        ,p_is_new_value_string  => true
                                        ,p_apex_session_id      => p_apex_session_id);
    
    
    /*
     * replace the p_plug_source param in the page plug
     */
    -- now replace the value
    apex_import.insert_or_replace_param (p_import_lines         => p_import_file
                                        ,p_param_name           => 'p_plug_source'
                                        ,p_parent_proc_type     => 'PAGE_PLUG'
                                        ,p_parent_apex_elem_id  => p_region_id
                                        ,p_new_value            => p_sql_statement
                                        ,p_is_new_value_string  => true
                                        ,p_apex_session_id      => p_apex_session_id);
                                    
     
    /*
     * replace the p_report_columns in the worksheet report
     */
     
    -- calculate the new column list for the reports based on the columns in the select 
    -- TODO: this overrrides the previous settings of the reports, a better solution would be to add new columns to the list and remove the columns from the list that were deleted
    --       this way, columns that weren't changed but were hidden in a report, would still be hidden in the new report
    select listagg(column_name, ':') within group (order by rownum)
      into v_report_columns
      from table(p_columns_desc);
 
    -- go through all worksheet reports that belong to the IR region, and replace their column lists
    for worksheet_report in ( select apex_elem_id
                                from tch_apex_app_struct
                               where session_id = p_apex_session_id
                                 and elem_type = 'WORKSHEET_REPORT'
                                 and parent_apex_elem_id = (select apex_elem_id
                                                              from tch_apex_app_struct
                                                             where session_id = p_apex_session_id
                                                               and elem_type = 'WORKSHEET'
                                                               and parent_apex_elem_id = p_region_id))
    loop        

      -- now replace the param value
      apex_import.insert_or_replace_param (p_import_lines         => p_import_file
                                          ,p_param_name           => 'p_report_columns'
                                          ,p_parent_proc_type     => 'WORKSHEET_REPORT'
                                          ,p_parent_apex_elem_id  => worksheet_report.apex_elem_id
                                          ,p_new_value            => v_report_columns
                                          ,p_is_new_value_string  => true
                                          ,p_apex_session_id      => p_apex_session_id);                                      
    end loop;
    
  end change_sql_statement_in_region;
  

/************************************************************************************
 *
 * Forms & Form Columns
 *
 ************************************************************************************/

  /*
   * get_create_page_item_plsql
   *
   * Returns: the plsql import code for creating a page item based on the given parameters
   */
  function get_create_page_item_plsql(p_app_id in number, p_page_id in number, p_id in number, p_column_name in varchar, p_item_type in varchar2, p_is_primary_key in varchar2 default 'N', p_display_order in number, p_region_id in number)
  return clob
  is
    v_page_item_plsql clob;
    v_template_id number;
    
    v_item_name varchar2(255);
  begin
  
    v_item_name := 'P' || p_page_id ||'_' || upper(p_column_name);
  
    --create basic column code for all kinds of columns
    v_page_item_plsql := q'~
wwv_flow_imp_page.create_page_item(
p_id=>wwv_flow_imp.id(~' || p_id || q'~)
,p_name=>'~' || v_item_name || q'~'
,p_is_primary_key=>~' || (case when p_is_primary_key = 'Y' then 'true' else 'false' end) || q'~
,p_is_query_only=>~' || (case when p_is_primary_key = 'Y' then 'true' else 'false' end) || q'~
,p_item_sequence=>~' || p_display_order || q'~
,p_item_plug_id=>wwv_flow_imp.id(~' || p_region_id || q'~)
,p_source=>'~' || upper(p_column_name) || q'~'
,p_item_source_plug_id=>wwv_flow_imp.id(~' || p_region_id || q'~)
,p_source_data_type=>'~' || p_item_type || q'~'~';
-- TODO: add ,p_is_required=>true/false based on whether the column has a not null constraint  
  
    -- if the column is a primary key, create a hidden column
    if p_is_primary_key = 'Y'
    then
   
      v_page_item_plsql := v_page_item_plsql || q'~
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attribute_01=>'Y'
);~';
     
      return v_page_item_plsql;
    end if;
    
    --calculate template ID
    SELECT template_id
      into v_template_id
      FROM apex_application_templates
      WHERE application_id = p_app_id
      and internal_name = 'OPTIONAL_FLOATING'
      AND template_type = 'Item Label';
    
    --add column type specific parameters
    case p_item_type
    when 'NUMBER' then
    
      v_page_item_plsql := v_page_item_plsql || q'~
,p_prompt=>'~' || initcap(p_column_name) || q'~'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(~' || v_template_id || q'~)
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attribute_03=>'left'
,p_attribute_04=>'decimal'
);~';

    when 'VARCHAR2' then
    
      v_page_item_plsql := v_page_item_plsql || q'~
,p_prompt=>'~' || initcap(p_column_name) || q'~'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_cMaxlength=>255
,p_field_template=>wwv_flow_imp.id(~' || v_template_id || q'~)
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);~';

    when 'CLOB' then
    
      v_page_item_plsql := v_page_item_plsql || q'~
,p_data_type=>'CLOB'
,p_prompt=>'~' || initcap(p_column_name) || q'~'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>30
,p_cHeight=>5
,p_field_template=>wwv_flow_imp.id(~' || v_template_id || q'~)
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attribute_01=>'Y'
,p_attribute_02=>'N'
,p_attribute_03=>'N'
,p_attribute_04=>'BOTH'
);~';

    when 'DATE' then
    
      v_page_item_plsql := v_page_item_plsql || q'~
,p_prompt=>'~' || initcap(p_column_name) || q'~'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(~' || v_template_id || q'~)
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attribute_01=>'N'
,p_attribute_02=>'POPUP'
,p_attribute_03=>'NONE'
,p_attribute_06=>'NONE'
,p_attribute_09=>'N'
,p_attribute_11=>'Y'
);~';

    else
    
      -- if it is a not supported type, make it a hidden column
      v_page_item_plsql := v_page_item_plsql || q'~
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attribute_01=>'Y'
);~';
    end case;
    --column_to_item_display_type(p_column_type => p_item_type)
  
    --return finished import code for the item
      return v_page_item_plsql;
  
  end get_create_page_item_plsql;
   
  /*
   * insert_new_form_region
   *
   * Inserts a new interactive report region in the given import file.
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */  
  function insert_new_form_region (p_import_file in out clob, p_app_id in number, p_page_id in number, p_region_title in varchar2, p_template_id in number, p_source_table_name in varchar2, p_display_sequence in number, p_columns_desc in db_utils.t_sql_desc)
  return number
  is
    v_insert_plsql clob;
    
    v_linesplit_clob apex_t_clob;
    v_region_id number;
  begin
  
    v_region_id := apex_ids.get_id('#form-' || p_region_title);
  
    -- build page plug import code  
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_plug(
p_id=>wwv_flow_imp.id(~' || v_region_id || q'~)
,p_plug_name=>'~' || p_region_title || q'~'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>wwv_flow_imp.id(~' || p_template_id || q'~)
,p_plug_display_sequence=>~' || p_display_sequence || q'~
,p_query_type=>'TABLE'
,p_query_table=>'~' || upper(p_source_table_name) || q'~'
,p_include_rowid_column=>false
,p_is_editable=>false
,p_plug_source_type=>'NATIVE_FORM'
);~';

    -- append all necessary page items
    for i in p_columns_desc.first .. p_columns_desc.last
    loop
      v_insert_plsql := v_insert_plsql || get_create_page_item_plsql(p_app_id             => p_app_id
                                                                    ,p_page_id            => p_page_id
                                                                    ,p_id                 => apex_ids.get_id('#form-item-' || p_region_title || '-' || p_columns_desc(i).column_name)
                                                                    ,p_column_name        => upper(p_columns_desc(i).column_name)
                                                                    ,p_item_type          => upper(p_columns_desc(i).column_type)
                                                                    ,p_is_primary_key     => p_columns_desc(i).is_primary
                                                                    ,p_display_order      => i * 10
                                                                    ,p_region_id          => v_region_id
                                                                    );
                                                      
    end loop;
    


    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

    apex_debug.info('############ Form Import FILE ###############');
    --split the clob into its individual lines
    v_linesplit_clob := apex_string.split_clobs(p_import_file);
    -- print file with linenumbers
    for i in v_linesplit_clob.first  .. v_linesplit_clob.last
    loop
      apex_debug.info(i || ':' || v_linesplit_clob(i));
    end loop;
      
    --apex_debug.info(p_import_file);
    return v_region_id;
  
  end insert_new_form_region;   
   
   
  /*
   * insert_new_page_process
   *
   * Inserts a new interactive report region in the given import file.
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */  
  procedure insert_new_page_process (p_import_file in out clob, p_region_id in varchar2, p_process_name in varchar2, p_process_type in varchar2, p_process_point in varchar2,  p_process_sequence in number default 10)
  is
    v_insert_plsql clob;
    
    v_curr_column_identifier char(1);
    
    v_report_columns clob;
    v_linesplit_clob apex_t_clob;
  begin
  
    -- build basic import code  
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(~' || apex_ids.get_id('#proc-' || p_process_type || '-' || p_process_name) || q'~)
,p_process_sequence=>~' || p_process_sequence || q'~
,p_process_point=>'~' || p_process_point || q'~'
,p_region_id=>wwv_flow_imp.id(~' || p_region_id || q'~)
,p_process_type=>'~' || p_process_type || q'~'
,p_process_name=>'~' || p_process_name || q'~'~';

    -- append type specific parameters to procedure call
    if p_process_type = 'NATIVE_FORM_DML'
    then
      v_insert_plsql := v_insert_plsql || q'~
,p_attribute_01=>'REGION_SOURCE'
,p_attribute_05=>'Y'
,p_attribute_06=>'Y'
,p_attribute_08=>'Y'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'~';
    
    end if;
    
    -- append final parameter
    v_insert_plsql := v_insert_plsql || q'~
,p_internal_uid=>~' || apex_ids.get_id('#proc-' || p_process_type || '-' || p_process_name) || q'~
);
~';

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

    --apex_debug.info(p_import_file);
  
  end insert_new_page_process;

  /*
   * insert_new_button
   *
   * Inserts a new button in the given import file.
   * Param: p_button_type: must have one of the following values: 'form_button_create', 'form_button_save', 'form_button_cancel', 'form_button_delete'
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */  
  procedure insert_new_button (p_import_file in out clob, p_parent_region_id in number, p_button_name in varchar2, p_button_type in varchar2, p_template_id in number, p_primary_key_form_item_name in varchar2, p_target_page_on_cancel in number default null)
  is
    v_insert_plsql clob;
    
    v_curr_column_identifier char(1);
    
    v_report_columns clob;
    v_linesplit_clob apex_t_clob;
    v_button_id number;
  begin
  
    v_button_id := apex_ids.get_id('#btn-' || p_parent_region_id || '-' || p_button_name);
    apex_debug.info('BUTTON-ID: ' || v_button_id);
    
    -- build basic import code  
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(~' || v_button_id || q'~)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(~' || p_parent_region_id || q'~)
,p_button_name=>'~' || upper(p_button_name)|| q'~'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>wwv_flow_imp.id(~' || p_template_id || q'~)
,p_button_image_alt=>'~' || initcap(p_button_name) || q'~'~';
    
    --append type specific parameters
    case p_button_type
    when 'form_button_create'
    then
      v_insert_plsql := v_insert_plsql || q'~
,p_button_action=>'SUBMIT'
,p_button_is_hot=>'Y'
,p_button_position=>'CREATE'
,p_button_condition=>'~' || p_primary_key_form_item_name || q'~'
,p_button_condition_type=>'ITEM_IS_NULL'
,p_database_action=>'INSERT'
);~';

    when 'form_button_save'
    then
      v_insert_plsql := v_insert_plsql || q'~
,p_button_action=>'SUBMIT'
,p_button_is_hot=>'Y'
,p_button_position=>'CHANGE'
,p_button_condition=>'~' || p_primary_key_form_item_name || q'~'
,p_button_condition_type=>'ITEM_IS_NOT_NULL'
,p_database_action=>'UPDATE'
);~';    

    when 'form_button_cancel'
    then
    
      if p_target_page_on_cancel is null
      then 
        raise_application_error(-20000, 'the parameter p_target_page_on_cancel must not be null when p_button_type is form_button_cancel');
      end if;
    
      v_insert_plsql := v_insert_plsql || q'~
,p_button_action=>'REDIRECT_PAGE'
,p_button_position=>'CLOSE'
,p_button_redirect_url=>'f?p=&APP_ID.:~' || p_target_page_on_cancel || q'~:&APP_SESSION.::&DEBUG.:::'
);~';    

    when 'form_button_delete'
    then
      v_insert_plsql := v_insert_plsql || q'~
,p_button_action=>'SUBMIT'
,p_button_position=>'DELETE'
,p_button_execute_validations=>'N'
,p_confirm_message=>'&APP_TEXT$DELETE_MSG!RAW.'
,p_confirm_style=>'danger'
,p_button_condition=>'~' || p_primary_key_form_item_name || q'~'
,p_button_condition_type=>'ITEM_IS_NOT_NULL'
,p_database_action=>'DELETE'      
);~';    
    else
      raise_application_error(-20001, 'The given p_button_type "' || p_button_type || '" is not a valid type.');
    end case;

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

    --apex_debug.info(p_import_file);
  
  end insert_new_button; 
  
  /*
   * insert_new_link_button
   *
   * Inserts a new button in the given import file.
   * Param: p_button_position: must have one of the following values: 'REGION_BODY', 'SORT_ORDER', 'NEXT', 'PREVIOUS', 'RIGHT_OF_IR_SEARCH_BAR'
   * Param: p_is_button_hot: must have one of the following values: 'Y', 'N'
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */   
  procedure insert_new_link_button(p_import_file in out clob, p_template_id in varchar2, p_button_name in varchar2, p_parent_region_id in number, p_target_page_id in number, p_button_position in varchar2, p_is_button_hot in varchar2, p_icon_css_class in varchar2)
  is
    v_insert_plsql clob;
    
    v_linesplit_clob apex_t_clob;
    v_button_id number;
  begin
    v_button_id := apex_ids.get_id('#btn-' || p_parent_region_id || '-' || p_button_name);
    
    
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_button(
p_id=>wwv_flow_imp.id(~' || v_button_id || q'~)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(~' || p_parent_region_id || q'~)
,p_button_name=>'~' || replace(upper(p_button_name), ' ', '_') || q'~'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#:t-Button--iconLeft:t-Button--hoverIconPush'
,p_button_template_id=>wwv_flow_imp.id(~' || p_template_id || q'~)
,p_button_is_hot=>'~' || p_is_button_hot || q'~'
,p_button_image_alt=>'~' || initcap(p_button_name) || q'~'~';

    if upper(p_button_position) is not null
    then
      v_insert_plsql := v_insert_plsql || q'~,p_button_position=>'~' || p_button_position || q'~'
~';
    end if;
    
    v_insert_plsql := v_insert_plsql || q'~,p_button_redirect_url=>'f?p=&APP_ID.:~' || p_target_page_id || q'~:&SESSION.::&DEBUG.:~' || p_target_page_id || q'~::'
,p_icon_css_classes=>'~' || p_icon_css_class  || q'~'
);~';

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);

  end insert_new_link_button;
  /*
   * insert_new_branch
   *
   * Inserts a new branch in the given import file.
   * Attention: 
   * - The import file must only contain a single page import, multiple pages or other components apart from pages are not supported
   */  
  procedure insert_new_branch (p_import_file in out clob, p_page_id in number, p_target_page_id in number, p_branch_point varchar2 default 'AFTER_PROCESSING', p_branch_sequence in number default 1)
  is
    v_insert_plsql clob;
    
    v_curr_column_identifier char(1);
    
    v_report_columns clob;
    v_linesplit_clob apex_t_clob;
  begin
  
    -- build basic import code  
    v_insert_plsql := q'~wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(~' || apex_ids.get_id('#branch-' || p_page_id || '-to-' || p_target_page_id) || q'~)
,p_branch_action=>'f?p=&APP_ID.:~' || p_target_page_id || q'~:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#'
,p_branch_name=>'Go To Page ~' || p_target_page_id ||  q'~'
,p_branch_point=>'~' || p_branch_point || q'~'
,p_branch_type=>'REDIRECT_URL'
,p_branch_sequence=>~' || p_branch_sequence || q'~
);~';

    -- insert the plsql call at the end of the import part of the file
    insert_at_end(p_import_file => p_import_file, p_insert_plsql => v_insert_plsql);
      
    --apex_debug.info(p_import_file);
  
  end insert_new_branch;  
  
end "APEX_IMPORT";
/