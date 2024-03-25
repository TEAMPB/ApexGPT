create or replace package body "APEX_APP_STRUCT" as

  /*
   * clear_session
   *
   * Deletes all entries for the given session_id in the tch_apex_app_struct table which is the parsed version of an apex import file
   */
  procedure clear_session(p_session_id  tch_apex_app_struct.session_id%type)
  is
  begin
    delete from tch_apex_app_struct
    where session_id = p_session_id;
  end clear_session;

  /*
   * add_page
   *
   * Adds an entry of type page to the tch_apex_app_struct table
   */
  procedure add_page (p_apex_elem_id              tch_apex_app_struct.apex_elem_id%type,
                      p_parent_apex_elem_id       tch_apex_app_struct.parent_apex_elem_id%type, 
                      p_import_file_start_line    tch_apex_app_struct.import_file_start_line%type,
                      p_session_id                tch_apex_app_struct.session_id%type)
  is
  begin
    insert into tch_apex_app_struct
    (	
      apex_elem_id,
      parent_apex_elem_id, 
      import_file_start_line, 
      elem_type,
      session_id
    )
    values
    (
      p_apex_elem_id,
      p_parent_apex_elem_id,
      p_import_file_start_line,
      'PAGE',
      p_session_id
    );
  end;

  /*
   * add_page_plug
   *
   * Adds an entry of type page_plug (a basic region) to the tch_apex_app_struct table
   */
  procedure add_page_plug(p_apex_elem_id              tch_apex_app_struct.apex_elem_id%type,
                          p_parent_apex_elem_id       tch_apex_app_struct.parent_apex_elem_id%type, 
                          p_import_file_start_line    tch_apex_app_struct.import_file_start_line%type,
                          p_session_id                tch_apex_app_struct.session_id%type)
  is
  begin
    insert into tch_apex_app_struct
    (	
      apex_elem_id,
      parent_apex_elem_id, 
      import_file_start_line, 
      elem_type,
      session_id
    )
    values
    (
      p_apex_elem_id,
      p_parent_apex_elem_id,
      p_import_file_start_line,
      'PAGE_PLUG',
      p_session_id
    );
  end;

  /*
   * add_worksheet
   *
   * Adds an entry of type worksheet (the container for IR columns) to the tch_apex_app_struct table
   */
  procedure add_worksheet(p_apex_elem_id              tch_apex_app_struct.apex_elem_id%type,
                          p_parent_apex_elem_id       tch_apex_app_struct.parent_apex_elem_id%type, 
                          p_import_file_start_line    tch_apex_app_struct.import_file_start_line%type,
                          p_session_id                tch_apex_app_struct.session_id%type)
  is
  begin
    insert into tch_apex_app_struct
    (	
      apex_elem_id,
      parent_apex_elem_id, 
      import_file_start_line, 
      elem_type,
      session_id
    )
    values
    (
      p_apex_elem_id,
      p_parent_apex_elem_id,
      p_import_file_start_line,
      'WORKSHEET',
      p_session_id
    );
  end add_worksheet;


  procedure add_element(p_elem_name                 tch_apex_app_struct.elem_name%type default null,
                      p_apex_elem_id              tch_apex_app_struct.apex_elem_id%type,
                      p_parent_apex_elem_id       tch_apex_app_struct.parent_apex_elem_id%type, 
                      p_import_file_start_line    tch_apex_app_struct.import_file_start_line%type,
                      p_session_id                tch_apex_app_struct.session_id%type,
                      p_elem_type                 tch_apex_app_struct.elem_type%type)
  is
  begin
    insert into tch_apex_app_struct
    (	
      elem_name,
      apex_elem_id,
      parent_apex_elem_id, 
      import_file_start_line, 
      elem_type,
      session_id
    )
    values
    (
      p_elem_name,
      p_apex_elem_id,
      p_parent_apex_elem_id,
      p_import_file_start_line,
      p_elem_type,
      p_session_id
    );
  end add_element;                      

  /*
   * add_param
   *
   * Adds an entry of type param to the tch_apex_app_struct table
   */
   procedure add_param (p_elem_name                 tch_apex_app_struct.elem_name%type,
                        p_apex_elem_id              tch_apex_app_struct.apex_elem_id%type,
                        p_parent_apex_elem_id       tch_apex_app_struct.parent_apex_elem_id%type, 
                        p_import_file_start_line    tch_apex_app_struct.import_file_start_line%type,
                        p_session_id                tch_apex_app_struct.session_id%type)
  is 
  begin
    insert into tch_apex_app_struct
    (	
      elem_name,
      apex_elem_id,
      parent_apex_elem_id, 
      import_file_start_line, 
      elem_type,
      session_id
    )
    values
    (
      p_elem_name,
      p_apex_elem_id,
      p_parent_apex_elem_id,
      p_import_file_start_line,
      'PARAM',
      p_session_id
    );
  end add_param;



end "APEX_APP_STRUCT";
/