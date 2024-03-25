create or replace package body "DB_UTILS" as

  /*
   * get_sql_columns_desc
   *
   * Returns: A table of records each containing the name and type (as varchar2) of a column that the given select statement returns
   */
  function get_sql_columns_desc(p_sql_stmt in clob)
  return t_sql_desc
  is
    c        NUMBER;
    d        NUMBER;
    col_cnt  INTEGER;
    rec_tab  DBMS_SQL.DESC_TAB;
    col_name VARCHAR2(50);
    col_type VARCHAR2(50);
    v_sql_description t_sql_desc := t_sql_desc();
  begin
    c := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(c, p_sql_stmt, DBMS_SQL.NATIVE);
    d := DBMS_SQL.EXECUTE(c);
    DBMS_SQL.DESCRIBE_COLUMNS(c, col_cnt, rec_tab);
  
    FOR i IN 1..col_cnt LOOP
      col_name := rec_tab(i).col_name;
      col_type := CASE rec_tab(i).col_type
                    WHEN 1 THEN 'STRING'--actually: 'VARCHAR2'. In apex imports, the column type for varchar2 columns is called 'STRING'
                    WHEN 2 THEN 'NUMBER'
                    WHEN 8 THEN 'LONG'
                    WHEN 12 THEN 'DATE'
                    WHEN 23 THEN 'RAW'
                    WHEN 69 THEN 'ROWID'
                    WHEN 96 THEN 'CHAR'
                    WHEN 112 THEN 'CLOB'
                    WHEN 113 THEN 'BLOB'
                    WHEN 180 THEN 'TIMESTAMP'
                    WHEN 181 THEN 'TIMESTAMP WITH TIME ZONE'
                    WHEN 231 THEN 'TIMESTAMP WITH LOCAL TIME ZONE'
                    ELSE 'OTHER'
                  END;
      v_sql_description.extend;
      v_sql_description(i) := column_desc(col_name, col_type, 'N');
      
      apex_debug.info('Column: ' || col_name || ' Type: ' || col_type || ' (' || rec_tab(i).col_type ||')');
    END LOOP;
  
    DBMS_SQL.CLOSE_CURSOR(c);
    return v_sql_description;
  exception
    WHEN OTHERS THEN
      IF DBMS_SQL.IS_OPEN(c) THEN
        DBMS_SQL.CLOSE_CURSOR(c);
      END IF;
      RAISE;
  end get_sql_columns_desc;
  
  /*
   * get_table_columns_desc
   *
   *  Returns: A table of records each containing the name, type (as varchar2), and whether it is part of the primary key of a column in the given table
   */
  function get_table_columns_desc(p_table_name in varchar2)
  return t_sql_desc
  is
    v_tab_description t_sql_desc := t_sql_desc();
    v_column_count_in_table number;
  begin
  
    --check if the table exists by checking how many columns are in the table
    SELECT count(*)
      into v_column_count_in_table
      from user_tab_columns
     WHERE upper(table_name) = upper(p_table_name);
     
    -- raise exception if there were no columns found 
    if v_column_count_in_table <= 0
    then
      raise no_data_found;
    end if;     
     
    -- loop over all columns and write their info into the record table 
    for column in (SELECT col.column_name, col.data_type, CASE WHEN pk.constraint_type = 'P' THEN 'Y' ELSE 'N' END AS is_primary_key
                     FROM user_tab_columns col
                     LEFT JOIN (SELECT constraint_type, column_name
                                  FROM user_cons_columns
                                  JOIN user_constraints ON user_cons_columns.constraint_name = user_constraints.constraint_name
                                 WHERE user_constraints.constraint_type = 'P'
                                   AND upper(user_cons_columns.table_name) = upper(p_table_name)) pk
                       ON col.column_name = pk.column_name
                    WHERE upper(table_name) = upper(p_table_name)
                    order by col.column_id)
    loop
      v_tab_description.extend;
      v_tab_description(v_tab_description.last) := column_desc(column.column_name, column.data_type, column.is_primary_key);
      
      apex_debug.info('Column: ' || column.column_name || ', Type: ' || column.data_type || ', Primary: ' || column.is_primary_key);
    END LOOP;
  
    return v_tab_description;
    
  end get_table_columns_desc; 

  /*
   * get_different_columns
   *
   * Returns: The column descriptions as a db_utils.column_desc that exist in p_first_columns_desc but do not exist in p_second_columns_desc
   *          Columns are equal if their name and type are the same (case insensitive).
   */
  function get_different_columns(p_first_columns_desc in db_utils.t_sql_desc, p_second_columns_desc in db_utils.t_sql_desc)
  return db_utils.t_sql_desc
  is
    v_column_still_exists boolean;
    p_different_columns   db_utils.t_sql_desc := db_utils.t_sql_desc();  
  begin
  
    for i in p_first_columns_desc.first .. p_first_columns_desc.last
    loop
      apex_debug.info('i = ' || i);
    
      -- go through each column in p_second_columns_desc and check if the current column from p_first_columns_desc still exists
      v_column_still_exists := false;
      for j in p_second_columns_desc.first .. p_second_columns_desc.last
      loop
      
        apex_debug.info('Comparing: (' || p_first_columns_desc(i).column_name || ', ' || p_first_columns_desc(i).column_type || ') with (' || p_second_columns_desc(j).column_name || ', ' || p_second_columns_desc(j).column_type || ')');
      
        -- columns are equal if their name and type are the same (case insensitive)
        if upper(p_first_columns_desc(i).column_name) = upper(p_second_columns_desc(j).column_name) and upper(p_first_columns_desc(i).column_type) = upper(p_second_columns_desc(j).column_type)
        then
          apex_debug.info('column still exists');
          v_column_still_exists := true;
          exit;
        end if;
      end loop;
      
      --if the current first column doesn't exist anymore, add it to the deleted columns
      if not v_column_still_exists
      then 
        apex_debug.info('adding column to differences list');
        p_different_columns.extend;
        p_different_columns(p_different_columns.last) := p_first_columns_desc(i);
      end if;
      
    end loop;
    
    
    apex_debug.info('p_different_columns: ' || p_different_columns.first || ', ' || p_different_columns.last);
    return p_different_columns;
    
  end get_different_columns; 

  /*
   * get_changed_columns_in_descs
   * 
   * Calculate which columns where added or deleted between the p_old_columns_desc and the p_new_columns_desc.
   *
   * Returns: (1) p_deleted_columns: the columns from p_old_columns_desc that do not exist in p_new_columns_desc
   *          (2) p_added_columns: the columns from p_new_columns_desc that do not exist in p_old_columns_desc 
   */
  procedure get_changed_columns_in_descs(p_old_columns_desc in db_utils.t_sql_desc, p_new_columns_desc in db_utils.t_sql_desc, p_deleted_columns in out db_utils.t_sql_desc, p_added_columns in out db_utils.t_sql_desc)
  is
    v_column_still_exists boolean;
  begin
    
    apex_debug.info('calc deleted columns');
    -- check which columns exist in the old but don't exist in the new column desc
    p_deleted_columns := db_utils.get_different_columns (p_first_columns_desc    => p_old_columns_desc
                                                        ,p_second_columns_desc   => p_new_columns_desc);
    
    apex_debug.info('calc added columns');
    -- check which columns exist in the new but didn't exist in the old column desc
    p_added_columns := db_utils.get_different_columns (p_first_columns_desc    => p_new_columns_desc 
                                                      ,p_second_columns_desc   => p_old_columns_desc);
    
  end get_changed_columns_in_descs;

  /*
   * get_desc_columns_table
   *
   * Returns: An apex_t_varchar2 of the column names in the provided sql desc, for usage in sql statements
   */
  function get_desc_columns_table(p_sql_desc in t_sql_desc)
  return apex_t_varchar2
  is
    v_columns apex_t_varchar2 := apex_t_varchar2();
  begin
  
    apex_debug.info('get_desc_columns_table: sql desc (count ' || p_sql_desc.count || '), first, last: ' || p_sql_desc.first || ', ' || p_sql_desc.last);
    
    for i in p_sql_desc.first .. p_sql_desc.last
    loop
      
      v_columns.extend;
      v_columns(i) := p_sql_desc(i).column_name;
    end loop;
    
    return v_columns;
      
  end;

end "DB_UTILS";
/