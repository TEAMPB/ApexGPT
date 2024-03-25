create or replace package body "STRING_UTILS" as

  /*
   * markdown_to_html
   *
   * Replaces escaped Markdown-specific characters in the input string with original characters.
   * 
   * Returns: The string containing the unescaped markdown-specific characters
   */
  function markdown_to_html(
    p_input_text IN CLOB
  ) RETURN CLOB
  IS
    v_output_text CLOB;
  BEGIN
    v_output_text := REPLACE(p_input_text, '\\', '\');
    v_output_text := REPLACE(v_output_text, '\*', '*');
    v_output_text := REPLACE(v_output_text, '\_', '_');
    v_output_text := REPLACE(v_output_text, '\#', '#');
    v_output_text := REPLACE(v_output_text, '\+', '+');
    v_output_text := REPLACE(v_output_text, '\-', '-');
    v_output_text := REPLACE(v_output_text, '\.', '.');
    v_output_text := REPLACE(v_output_text, '\!', '!');
    v_output_text := REPLACE(v_output_text, '\(', '(');
    v_output_text := REPLACE(v_output_text, '\)', ')');
    v_output_text := REPLACE(v_output_text, '\[', '[');
    v_output_text := REPLACE(v_output_text, '\]', ']');
    v_output_text := REPLACE(v_output_text, '\{', '{');
    v_output_text := REPLACE(v_output_text, '\}', '}');
    v_output_text := REPLACE(v_output_text, '\<', '<');
    v_output_text := REPLACE(v_output_text, '\>', '>');
    v_output_text := REPLACE(v_output_text, '\|', '|');
    v_output_text := REPLACE(v_output_text, '<br/>', chr(13));
  
    RETURN v_output_text;
  END;

  /*
   * Split clob into individual lines where p_delim is the delimiter that marks the end of a line
   *
   * Source: https://stackoverflow.com/questions/67414603/how-do-we-split-a-clob-with-some-lines-with-more-than-32k-characters-line-by-l
   *
   * Returns: A table of clobs with each clob being a single line in the input clob
   */
  function split_clob_by_lines(p_clob in clob, p_delim in varchar2 default chr(10)) 
  return t_clob_table is
    row clob;
    l_begin number:=1;
    l_end number:=1;
    v_line_num number := 0;
    
    v_result_table t_clob_table := t_clob_table();
  begin

    while l_end > 0
      loop
        -- get next index in original string where the delimiter is
        l_end := instr(p_clob, p_delim, l_begin);
        -- output the found row
        v_result_table.extend;
        v_line_num := v_line_num + 1;
        v_result_table(v_line_num) := substr(p_clob, l_begin, case when l_end > 0 
                                                              then l_end - l_begin 
                                                              else length(p_clob) + length(p_delim) - l_begin 
                                                              end);
        l_begin := l_end + length(p_delim);
      end loop;

      return v_result_table;
  end split_clob_by_lines;
  
  
  /*
   * insert_line_into_array
   *
   * Inserts the given clob into the given apex clob table at the given index. The clob that currently sits at that index and all subsequent clobs get moved one index higher.
   * Thus, the array is one element longer after a call to this procedure.
   */
  procedure insert_line_into_array(p_clob_array in out apex_t_clob, p_line in clob, p_index in number)
  is
    v_curr_line clob;
    v_prev_line clob;
  begin
   
    v_curr_line := p_clob_array(p_index);
    p_clob_array(p_index) := p_line;
   
    for i in (p_index+1)..p_clob_array.last
    loop
      --insert the line that was saved in the previous loop iteration and save the line that is currently at that index for the next loop iteration
      v_prev_line := v_curr_line;
      v_curr_line := p_clob_array(i);
      p_clob_array(i) := v_prev_line;
    end loop;
    --after the above loop, v_curr_line holds the last line that now does not fit into the array anymore
    p_clob_array.extend;
    p_clob_array(p_clob_array.last) := v_curr_line;
    
  end insert_line_into_array;
  
  
  /*
   * insert_block_into_array
   *
   * Inserts the given block of clob lines into the given apex clob table starting at the given index. The clob that currently sits at that index and all subsequent clobs get moved to higher indices.
   * Thus, the array is longer after a call to this procedure by the amount of elements (lines) in the clob block.
   * Param: p_insert_clob_block: Must be a dense array, i.e., the indices must start at 1 and each index until the final one must exist in the array. There must be no gaps
   */
  procedure insert_block_into_array(p_clob_array in out apex_t_clob, p_insert_clob_block in out apex_t_clob, p_starting_index in number)
  is
    v_curr_line                     clob;
    v_prev_line                     clob;
    
    v_inserting_lines_count         number;
    v_last_index_before_insertion   number;
    v_curr_inserting_line_no        number;
  begin
  
    --apex_debug.info(' ################# PLSQL TO INSERT ################');
    --apex_import.debug_print_file_by_lines(p_insert_clob_block);
    --apex_debug.info('Starting to insert at index ' || p_starting_index);
  
    v_last_index_before_insertion := p_clob_array.last;
    v_inserting_lines_count := p_insert_clob_block.count;
    --apex_debug.info('v_last_index_before_insertion ' || v_last_index_before_insertion);
    --apex_debug.info('v_inserting_lines_count ' || v_inserting_lines_count);
  
    --apex_debug.info(' ################# FILE BEFORE INSERT ################');
    --apex_import.debug_print_file_by_lines(p_clob_array);
  
    -- extend the array by the number of lines to be inserted
    p_clob_array.extend(v_inserting_lines_count);
  
    -- move up the existing lines accordingly, to make space for the lines that should be inserted
    -- this is done from back to front, so the lines don't override eachother in the process
    for i in reverse p_starting_index..v_last_index_before_insertion
    loop
      apex_debug.info(i || ' => ' || (i + v_inserting_lines_count));
      p_clob_array(i + v_inserting_lines_count) := p_clob_array(i);
      p_clob_array(i) := '';
    end loop;
    
    --apex_debug.info(' ################# FILE MID INSERT ################');
    --apex_import.debug_print_file_by_lines(p_clob_array);
    
    -- now insert the lines from the clob block into the array
    v_curr_inserting_line_no := 0;
    for i in p_starting_index .. p_starting_index + v_inserting_lines_count - 1
    loop
      -- v_curr_inserting_line_no counts the index in p_insert_clob_block, because it starts at one, unlike the p_clob_array index i
      v_curr_inserting_line_no := v_curr_inserting_line_no + 1;
      
      apex_debug.info(i || ' => ' || v_curr_inserting_line_no);
      
      p_clob_array(i) := p_insert_clob_block(v_curr_inserting_line_no);
    end loop;
    
    apex_debug.info(' ################# FILE AFTER INSERT ################');
    apex_import.debug_print_file_by_lines(p_clob_array);
    
  end insert_block_into_array;  

  /*
   * make_dense_clob_collection
   *
   * Copies all element from p_sparse_clobs into a new apex_t_clob collection while remove indices that do not have a value.
   * Thus, making the indices in the new collection count up without gaps (dense)
   */
   function make_dense_clob_collection(p_sparse_clobs apex_t_clob)
   return apex_t_clob 
   is
      v_dense_clobs apex_t_clob := apex_t_clob();
      v_index number;
      v_dense_index number := 1;
  begin
      -- check if the input collection is not null
      if p_sparse_clobs.count > 0 then
          -- iterate over the sparse collection
          v_index := p_sparse_clobs.first;
          while v_index is not null loop
              -- copy the element into the dense collection
              v_dense_clobs.extend;
              v_dense_clobs(v_dense_index) := p_sparse_clobs(v_index);
              -- increment the dense index
              v_dense_index := v_dense_index + 1;
              -- move to the next index in the sparse collection
              v_index := p_sparse_clobs.next(v_index);
          end loop;
      end if;
  
      -- return the dense collection
      return v_dense_clobs;
  end make_dense_clob_collection;
 
  /*
   * escape_single_quote
   *
   * Takes in an input string where ' are not escaped and replaces each ' with '' to escape them. 
   * Returns: The resulting escaped string
   */
  function escape_single_quotes(p_input VARCHAR2) 
  return varchar2 is
  begin
    return replace(p_input, '''', '''''');
  end escape_single_quotes;

  /*
   * escape_single_quote (clob overrride)
   *
   * Takes in an input string where ' are not escaped and replaces each ' with '' to escape them. 
   * Returns: The resulting escaped string
   */
  function escape_single_quotes(p_input clob) 
  return clob is
  begin
    return replace(p_input, '''', '''''');
  end escape_single_quotes;
  
  /*
   * convert_to_valid_json
   *
   * converts a json function call that is surrounded by two { } instead of one to a valid call with one { }.
   */
  function convert_to_valid_json(p_raw_function_json clob)
  return clob 
  is
    v_occurence                 number := 1;
    v_instr_pos                 number := -1;
    v_opening_occurences        apex_t_number := apex_t_number();
    v_closing_occurences        apex_t_number := apex_t_number();
    
    v_raw_function_json         clob;
  begin
  
    v_raw_function_json := p_raw_function_json;
  
    while v_instr_pos != 0
    loop
      v_instr_pos := instr(v_raw_function_json, '{', 1, v_occurence);
      
      if v_instr_pos != 0
      then
        apex_debug.info('{ occurence ' || v_occurence || ': ' || v_instr_pos);
        v_opening_occurences.extend;
        v_opening_occurences(v_occurence) := v_instr_pos;
        v_occurence := v_occurence + 1;
      end if;

    end loop;

    if v_opening_occurences.last >= 2 and v_opening_occurences(1) < 5 and v_opening_occurences(2) - v_opening_occurences(1) < 5 
    then
      -- the string start with two { thus we have to remove the first opening and the last closing occurence

      -- find closing occurences
      v_occurence := 1;
      v_instr_pos := -1;
      while v_instr_pos != 0
      loop
        v_instr_pos := instr(v_raw_function_json, '}', 1, v_occurence);
        
        if v_instr_pos != 0
        then
          apex_debug.info('} occurence ' || v_occurence || ': ' || v_instr_pos);
          v_closing_occurences.extend;
          v_closing_occurences(v_occurence) := v_instr_pos;
          v_occurence := v_occurence + 1;
        end if;
      end loop;

      -- remove the outer { } 
      apex_debug.info('Removing outer { }');
      v_raw_function_json := substr(v_raw_function_json, v_opening_occurences(2), v_closing_occurences(v_closing_occurences.last) - v_opening_occurences(2)); 

      apex_debug.info(v_raw_function_json);
      return v_raw_function_json;
    else
      return v_raw_function_json;
    end if;

  end convert_to_valid_json;
  
  
  /*
   * remove_flow_call_from_id
   *
   * Removes the wwv_flow call around an ID value from an apex import file
   */
  function remove_flow_call_from_id(p_id_string in tch_apex_app_struct.apex_elem_id%type)
  return tch_apex_app_struct.apex_elem_id%type is
    v_start   number;
    v_end     number;
    
    v_elem_id tch_apex_app_struct.apex_elem_id%type;
  begin
    v_elem_id := p_id_string;
  
    v_start := instr(v_elem_id, '(', 1) + 1;-- the +1 ensures, that we do not include the '(' but start with the actual ID behind it
    v_end := instr(v_elem_id, ')', 1);
    v_elem_id := substr(v_elem_id, v_start, v_end - v_start);
    
    return v_elem_id;
  end;
  
  /*
   * remove_ticks_from_string
   *
   * Removes enclosing ' ' from the given string, if they are present. leading and trailing spaces outside the ' ' are removed as well.
   */
  function remove_ticks_from_string(p_string in varchar2)
  return varchar2 is
    v_result   varchar2(4000);
  begin
    v_result := trim(p_string);
    
    -- remove first and last character of the string, if they are '
    if p_string like q'~'%'~' 
    then
      v_result := substr(v_result, 2, LENGTH(v_result) - 2);   
    end if;
    
    return v_result;
  end remove_ticks_from_string;  
  
  /*
   * convert_clob_to_multiline_t_varchar2
   *
   * Converts the given clob containing linebreaks into an apex_t_varchar2 literal 
   */
  function convert_clob_to_multiline_t_varchar2(p_clob in clob)
  return clob
  is
    v_result_clob clob;
    v_linesplit_clob apex_t_clob;
  begin
    --split the clob into its individual lines
    v_linesplit_clob := apex_string.split_clobs(p_clob);
    
    -- add the first line of the clob to the result
    v_result_clob := q'~'~' || v_linesplit_clob(1) || q'~'~';
    
    -- if the clob contains more than one line, append the remaining ones
    if v_linesplit_clob.last > 1
    then
    
      for i in v_linesplit_clob.first + 1 .. v_linesplit_clob.last
      loop
        -- lines after the first one, always look like this: ,'<linecontent>'
        v_result_clob := v_result_clob || chr(10) || q'~,'~' ||v_linesplit_clob(i) || q'~'~';
      end loop;
    end if;
    
    return v_result_clob;
  end convert_clob_to_multiline_t_varchar2;

  /*
   * is_clob_single_line
   *
   * Returns: true if the given clob contains only one line
   *          false if it has multiple lines
   */
  function is_clob_single_line(p_clob in clob) 
  return boolean is
    l_lines_count number;
    v_linesplit_clob apex_t_clob;
  begin
    -- split clob into individual lines
    v_linesplit_clob := apex_string.split_clobs(p_clob);
  
    -- Check the number of lines
    if v_linesplit_clob.last > 1 then
      return false;
    else
      return true;
    end if;
  end;

end "STRING_UTILS";
/