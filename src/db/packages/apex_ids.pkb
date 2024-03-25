create or replace package body apex_ids is

  /*
   * Array type that stores ID numbers indexed by varchar identifiers for the IDs
   */
  TYPE t_num_array IS TABLE OF number
    INDEX BY varchar2(4000);
    
  /*
   * Package array that contains the IDs
   */    
  G_ID_ARRAY t_num_array; 

  /*
   * set_id
   *
   * Sets the ID indexed by the given name in the G_ID_ARRAY 
   */
  procedure set_id(p_name in varchar2,
                   p_id   in number)
  is
  begin
    G_ID_ARRAY(p_name) := p_id;
  end;                   
  
  /*
   * get_id
   *
   * returns the ID identified by the given name. If there is no ID for that name yet, a new ID is generated for it and it is added to the G_ID_ARRAY
   */
  function get_id(p_name in varchar2) 
  return number
  is
     v_id number;
  begin
     begin
        v_id := G_ID_ARRAY(p_name);
        
     exception
       when no_data_found then
       begin
         v_id := wwv_flow_id.next_val;
         set_id(p_name,v_id);
      end;  
     end; 
     return v_id;  
          
  end;
end apex_ids;  