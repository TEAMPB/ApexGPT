create or replace package body "GPT_FUNCTION_DECLARATIONS" as

  /*
   * declare_all_functions_to_openai
   *
   * Defines all functions and their parameters including their explanation texts that are available for OpenAI's API to call via the TEAM_AI package.
   */
  procedure declare_all_functions_to_openai
  is
    v_enum_values apex_t_varchar2;
  begin

/************************************************************************************
 *
 * ID calculation Utitlity functions
 *
 ************************************************************************************/
 
  
    --get_region_id_by_name(p_region_title in varchar2, p_page_id in number, p_app_id in number) 
    team_ai.add_param('p_region_title','the title of the region','string',null,1);
    team_ai.add_param('p_page_id','ID of the page on which the region is','number',null,1);
    team_ai.add_param('p_app_id','the id of the APEX application that the page and region belong to','number',null,1);
    team_ai.add_function('get_region_id_by_name','returns a json strucutre with the region id and other information about the region with the given title if it exists on the given page','object','edit_functions.get_region_id_by_name');


    -- get_page_id_by_name(p_page_name in varchar2, p_app_id in number) 
    team_ai.add_param('p_page_name','the name or title of an APEX page','string',null,1);
    --team_ai.add_param('p_app_id','the id of the app that the page belongs to','number',null,1);
    team_ai.add_function('get_page_and_app_id_by_name','returns a json structure with the all pages and their app ids that have the given name or title','object','edit_functions.get_page_and_app_id_by_name');

    -- get_app_id_by_name(p_app_name in varchar2)
    team_ai.add_param('p_app_name','the name of the APEX application whose ID should be returned','string',null,1);
    team_ai.add_function('get_app_id_by_name','returns a json strucutre with the application_id and app_name of the APEX applications that match the given name','object','edit_functions.get_app_id_by_name');

    -- get_all_apps
    team_ai.add_function('get_all_apps','returns all available app names and app ids','object','edit_functions.get_all_available_apps');

    --get_used_pageids_in_app(p_app_id in number)
    team_ai.add_param('p_app_id','the id of the APEX application','number',null,1);
    team_ai.add_function('get_used_pageids_in_app','returns all page IDs that already exist in the application as a comma separated list.','object','edit_functions.get_used_pageids_in_app');

    -- set_app_id(p_app_id in number) 
    -- team_ai.add_param('p_app_id','the application id of the app that is supposed to be edited','string',null,1);
    -- team_ai.add_function('set_app_id','sets which application is supposed to be edited','object','edit_functions.set_app_id');


    -- set_page_id(p_page_id in number) 
    -- team_ai.add_param('p_page_id','the page id of the page that is supposed to be edited','string',null,1);
    -- team_ai.add_function('set_page_id','sets which page is supposed to be edited','object','edit_functions.set_app_id');

    -- set_current_page_and_app_id(p_app_id in number, p_page_id in number) 
    team_ai.add_param('p_app_id','the application id of the app that is supposed to be edited','number',null,1);--changed these two param's types from string to number on 24.11.2023
    team_ai.add_param('p_page_id','the page id of the page that is supposed to be edited','number',null,1);
    team_ai.add_function('set_current_page_and_app_id','sets which page in which application is supposed to be edited','object','edit_functions.set_current_page_and_app_id');

    --get_regions_on_page(p_app_id in number, p_page_id in number)
    team_ai.add_param('p_app_id','the id of the app that the page belongs to','number',null,1);--changed these two param's types from string to number on 24.11.2023
    team_ai.add_param('p_page_id','the id of the page on which the regions should be searched for','number',null,1);
    team_ai.add_function('get_regions_on_page','returns a json array containing one object per region on the given page in the given app with its region title and region id','object','edit_functions.get_regions_on_page');

    --get_column_id_by_label(p_app_id in number, p_page_id in number, p_column_label in string)
    team_ai.add_param('p_app_id','the id of the app that the page belongs to','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the table region and its column are','number',null,1);
    team_ai.add_param('p_column_label','The current label of the column whose ID should be returned','string',null,1);
    team_ai.add_function('get_column_id_by_label','returns a json strucutre with the column_id, label and its region''s title of the column on the given page that has the given label','object','edit_functions.get_column_id_by_label');
    
    --get_displayed_columns_in_region(p_app_id in number, p_page_id in number, p_region_id in number)    
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_region_id','','number',null,1);
    team_ai.add_function('get_displayed_columns_in_region','returns a json array of objects that each list the column ID, its label, alias and display type in the given region','object','edit_functions.get_displayed_columns_in_region');
    
    -- get_page_item_by_label(p_app_id in number, p_page_id in number, p_item_label in varchar2)
    team_ai.add_param('p_app_id','the id of the app that the page belongs to','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the page item is','number',null,1);
    team_ai.add_param('p_item_label','The current label of the page item whose name should be returned','string',null,1);
    team_ai.add_function('get_page_item_by_label','returns a json strucutre with the item name and other information about the page items on the given page that have the given label','object','edit_functions.get_page_item_by_label');
    
    -- get_page_items_on_page(p_app_id in number, p_page_id in number)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_function('get_page_items_on_page','returns a json array with all page items on the given page','object','edit_functions.get_page_items_on_page');
    
/************************************************************************************
 *
 * DB retrieval functions
 *
 ************************************************************************************/

    --get_db_table_names
    team_ai.add_function('get_existing_table_names','returns a commaseparated list of the names of all tables that exist in the database','object','edit_functions.get_existing_table_names');
    
    --desc_db_table(p_table_name in varchar2)
    team_ai.add_param('p_table_name','the name of the table to be described','string',null,1);
    team_ai.add_function('desc_db_table','returns a description of the database table as an sql create table statement','object','edit_functions.desc_db_table');
  
    --get_region_sql_statement(p_region_id in number)
    team_ai.add_param('p_region_id','','number',null,1);
    team_ai.add_function('get_region_sql_statement','returns a table region''s sql statement','object','edit_functions.get_region_sql_statement');
  
/************************************************************************************
 *
 * Create functions
 *
 ************************************************************************************/
 

    -- create_new_page(p_app_id in number, p_page_id in number, p_page_title in varchar2) 
    team_ai.add_param('p_app_id','the id of the APEX application in which the new page should be created','number',null,1);
    team_ai.add_param('p_page_id','the id of the new page. This id must not already exist in the application.','number',null,1);
    team_ai.add_param('p_page_title','the title of the new page','string',null,1);
    team_ai.add_function('create_new_page','Creates a new page','object','edit_functions.create_new_page');
    
    -- create_new_text_region(p_app_id in number, p_page_id in number, p_region_title in varchar2)
    team_ai.add_param('p_app_id','the id of the APEX application in which the new region should be created','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the new region should be created','number',null,1);
    team_ai.add_param('p_region_title','the title of the new region','string',null,1);
    team_ai.add_param('p_region_text','the text inside the region','string',null,0);
    team_ai.add_function('create_new_text_region','Creates a new text region','object','edit_functions.create_new_text_region');
    
    -- create_new_table_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_sql_statement clob)
    team_ai.add_param('p_app_id','the id of the APEX application in which the new region should be created','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the new region should be created','number',null,1);
    team_ai.add_param('p_region_title','the title of the new region','string',null,1);
    team_ai.add_param('p_sql_statement','the source SQL select-statement that is used to determine the columns and data shown in the table region. Ask the user what data to show in the table and generate the SQL statement from their description. You must only use tables and columns that already exist in the database.','string',null,1);
    team_ai.add_function('create_new_table_region','Creates a new table region','object','edit_functions.create_new_table_region');
       
    -- create_new_form_region(p_app_id in number, p_page_id in number, p_region_title in varchar2, p_source_table_name in varchar2)     
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_region_title','the title of the new region','string',null,1);
    team_ai.add_param('p_source_table_name','the name of the database table that the form should be used to edit. you must only provide the name of a table that already exists in the database','string',null,1);
    team_ai.add_function('create_new_form_region','creates a new form region','object','edit_functions.create_new_form_region');
      
    -- function create_new_button(p_app_id in number, p_page_id in number, p_parent_region_id in number, p_button_name in varchar2, p_button_type in number, p_primary_key_form_item_name in varchar2, p_target_page_id_on_cancel in number)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_parent_region_id','the id of the region in which the button should be created','number',null,1);
    team_ai.add_param('p_button_name','','string',null,1);
    v_enum_values := apex_t_varchar2('form_button_create', 'form_button_save', 'form_button_cancel', 'form_button_delete');
    team_ai.add_param('p_button_type','the type of button that should be created','string',v_enum_values,1);
    team_ai.add_param('p_primary_key_form_item_name','If this button is a create, save or delete button on a form page, this must contain the item name of the form''s primary key item','string',null,0);
    team_ai.add_param('p_target_page_id_on_cancel','If this button is a form_button_cancel, this must contain the page ID to which the cancel button should lead','number',null,0);
    team_ai.add_function('create_new_button','creates a new button inside a form region','object','edit_functions.create_new_button');
    
    -- create_new_link_button(p_app_id in number, p_page_id in number, p_parent_region_id in number, p_button_name in varchar2, p_target_page_id in number, p_button_position in varchar2)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_parent_region_id','the id of the region in which the button should be created','number',null,1);
    team_ai.add_param('p_button_name','','string',null,1);
    team_ai.add_param('p_target_page_id','The ID of the page that the linkbutton should lead to','number',null,1);
    v_enum_values := apex_t_varchar2('REGION_BODY', 'SORT_ORDER', 'NEXT', 'PREVIOUS', 'RIGHT_OF_IR_SEARCH_BAR');
    team_ai.add_param('p_button_position','The apex position of the button inside the region','string', v_enum_values, 1);
    team_ai.add_function('create_new_link_button','creates a new linkbutton that leads to a different page','object','edit_functions.create_new_link_button');
    
    -- create_new_branch(p_app_id in number, p_page_id in number, p_target_page_id in number)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','the page on which the branch should be created','number',null,1);
    team_ai.add_param('p_target_page_id','the target page that the branch should lead to after the page has been submitted','number',null,1);
    team_ai.add_function('create_new_branch','creates a branch on a page','object','edit_functions.create_new_branch');

/************************************************************************************
 *
 * Delete functions
 *
 ************************************************************************************/
 
    -- delete_page(p_app_id in number, p_page_id in number)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_function('delete_page','deletes the givne page in the given app','object','edit_functions.delete_page');

/************************************************************************************
 *
 * Edit function
 *
 ************************************************************************************/
     
    -- change_page_title(p_app_id in number, page_id in number, new_title in varchar2) 
    team_ai.add_param('p_app_id','the id of the APEX application that the page whos title should be changed belongs to','number',null,1);
    team_ai.add_param('p_page_id','the id of the APEX page whose title should be changed','number',null,1);
    team_ai.add_param('p_new_title','the new title of the APEX page. Always ask the user what the title should be.','string',null,1);
    team_ai.add_function('change_page_title','Changes the title of the APEX page with the given page_id inside the application with the given app_id','object','edit_functions.change_page_title');
    
    -- change_region_title(p_app_id in number, page_id in number, region_id in number, new_title in varchar2) 
    team_ai.add_param('p_app_id','the id of the APEX application that the page and region belong to','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the region is','number',null,1);
    team_ai.add_param('p_region_id','the id of the region whose title should be changed','number',null,1);
    team_ai.add_param('p_new_title','the new title of the region. Always ask the user what the title should be','string',null,1);
    team_ai.add_function('change_region_title','Changes the title of the region with the given region_id on the page with the given page_id inside the application with the given app_id','object','edit_functions.change_region_title');

    -- change_region_text(p_app_id in number, p_page_id in number,  p_region_id in number, p_new_region_text in varchar2)
    team_ai.add_param('p_app_id','the id of the APEX application that the page and region belong to','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the region is','number',null,1);
    team_ai.add_param('p_region_id','the id of the region whose text should be changed','number',null,1);
    team_ai.add_param('p_new_region_text','the new text inside the region','string',null,1);
    team_ai.add_function('change_region_text','Changes the text shown in the region with the given region_id on the page with the given page_id inside the application with the given app_id','object','edit_functions.change_region_text');
    
    -- change_region_column_label(p_app_id in number, p_page_id in number, p_column_id in number, p_new_label in varchar2)
    team_ai.add_param('p_app_id','the id of the APEX application that the page and region belong to','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the column is','number',null,1);
    team_ai.add_param('p_column_id','the id of the column that should be changed','number',null,1);
    team_ai.add_param('p_new_label','the new label that the column should have','string',null,1);
    team_ai.add_function('change_region_column_label','Changes the label of a table region''s column on the page with the given page_id inside the application with the given app_id','object','edit_functions.change_region_column_label');
    
    -- change_column_format_mask(p_app_id in number, p_page_id in number, p_column_id in number, p_new_format_mask in varchar2)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_column_id','','number',null,1);
    team_ai.add_param('p_new_format_mask','the new oracle apex format mask that the column should have','string',null,1);
    team_ai.add_function('change_column_format_mask','changes the format in which the content of a table region''s column is shown','object','edit_functions.change_column_format_mask');

    -- (p_app_id in number, p_page_id in number, p_region_id in number, p_column_id in number, p_new_column_type in varchar2, p_link_target_page_id in number default null, p_link_target_page_item_name in varchar2 default null, p_region_column_name in varchar2 default null)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_region_id','','number',null,1); 
    team_ai.add_param('p_column_id','','number',null,1); 
    v_enum_values := apex_t_varchar2('PLAIN_TEXT', 'LINK', 'HIDDEN');
    team_ai.add_param('p_new_column_type','The new type the column should be displayed as','string', v_enum_values, 1);
    -- LINK specific parameters
    team_ai.add_param('p_link_target_page_id','If p_new_column_type is LINK, this must contain the ID of the page that the link should point to','string',null,0);
    team_ai.add_param('p_link_target_page_item_name','If p_new_column_type is LINK, this must contain the name of the page item on the target page that the link should fill','string',null,0);
    team_ai.add_param('p_region_column_name','If p_new_column_type is LINK, this must contain the name of the sql statement column of the region whose value should be used to fill the target page item. You must provide the name given in the sql statement of the region and not the name of the table column in the database','string',null,0);
    team_ai.add_function('change_table_column_type','Changes the type of a column in a table region','object','edit_functions.change_table_column_type');
    

    -- Changes the link column in a table region to point to the given target 
    -- change_link_column_in_table_region(p_app_id in number, p_page_id in number, p_region_id in number, p_link_target_page_id in number, p_link_target_page_item_name in varchar2, p_region_column_name in varchar2)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','the id of the page on which the table region is','number',null,1);
    team_ai.add_param('p_region_id','the id of the table region in which the link column should be changed','number',null,1);
    team_ai.add_param('p_link_target_page_id','The id of the page that the link should point to','string',null,1);
    team_ai.add_param('p_link_target_page_item_name','The name of the page item on the target page that the link should fill','string',null,1);
    team_ai.add_param('p_region_column_name','The name of the sql statement column of the region whose value should be used to fill the target page item. you must provide the name given in the sql statement of the region and not the name of the table column in the database','string',null,1);
    team_ai.add_function('change_link_column_to_page_in_table_region','sets the link column in a table region to point to the given target','object','edit_functions.set_link_to_page_in_table_region');
     
    -- changes the sql statement that defines which columns exist in the table region (interactive report)
    -- change_table_region_sql_statement(p_app_id in number, p_page_id in number, p_region_id in number, p_new_sql_statement clob)     
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_region_id','','number',null,1);
    team_ai.add_param('p_new_sql_statement','the new source sql select-statement that defines the columns and data shown in the table region. You must only use tables and columns that already exist in the database.','string',null,1);
    team_ai.add_function('change_table_region_sql_statement','changes the sql statement that defines which columns exist in the table region','object','edit_functions.change_table_region_sql_statement');
     
    -- change_page_item_label(p_app_id in number, p_page_id in number, p_page_item_name in varchar2, p_new_label in varchar2)
    team_ai.add_param('p_app_id','','number',null,1);
    team_ai.add_param('p_page_id','','number',null,1);
    team_ai.add_param('p_page_item_name','the name of the item that should be changed','number',null,1);
    team_ai.add_param('p_new_label','the new label that the item should have','string',null,1);
    team_ai.add_function('change_page_item_label','Changes the label of a page item','object','edit_functions.change_page_item_label');
    
     
  end declare_all_functions_to_openai;

end "GPT_FUNCTION_DECLARATIONS";
/