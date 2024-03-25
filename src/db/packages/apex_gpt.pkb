create or replace package body "APEX_GPT" as

/************************************************************************************
 *
 * Edit-Status Logging Procedures
 *
 ************************************************************************************/

  /*
   * update_edit_status
   *
   * Updates the editing status tracked in the TCH_REQUEST_STATUS table to the given function name
   */
  procedure update_edit_status (p_chat_session_id in tch_request_status.chat_session_id%type, 
                                p_answer_request_id in tch_request_status.tch_request_id%type, 
                                p_function_name in varchar2, 
                                p_lang in varchar)
  is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    apex_debug.info('p_answer_request_id: '|| p_answer_request_id);
    -- Update status for user according to the function that is being called
    insert into TCH_REQUEST_STATUS
    (
      CHAT_SESSION_ID,
      TCH_REQUEST_ID,
      TCH_FUNC_PROGRESS_TEXTS_ID
    )
    values
    (
      p_chat_session_id,
      p_answer_request_id,
      -- get the progress text ID of the progress text in the specified language - use german language when the specified language text does not exist
      (select nvl(lang.ID, de.ID)
        from TCH_FUNC_PROGRESS_TEXTS lang
        left join TCH_FUNC_PROGRESS_TEXTS de 
          on de.function_name = p_function_name and de.lang = 'DE'
       where lang.function_name = p_function_name
         and lang.lang = p_lang)
    );
    commit;
  end update_edit_status;


/************************************************************************************
 *
 * AI Message handling
 *
 ************************************************************************************/

  procedure get_gpt_response
  is 
    v_request clob;
    v_return clob;

    v_prompt_nr number;
    v_max_sequence_nr number;

    v_usage_tokens team_ai.t_usage_tokens;
  begin

    team_ai.debug_chat_messages;
    
    apex_gpt.init_new_chat_history;

    -- Enter User prompt into chat
    team_ai.add_chat_message(p_role    => 'user',                           
                             p_content => v('P' ||v('APP_PAGE_ID') || '_INPUT'));
                             
    select nvl(max(PROMPT_NR),0),nvl(max(sequence_nr),0)
      into v_prompt_nr,v_max_sequence_nr
      from TCH_CHAT_MESSAGE
     where CHAT_SESSION_ID = v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID'); 
     
    -- save the prompt in the DB for subsequent runs
    v_max_sequence_nr := v_max_sequence_nr + 1; 
    insert into TCH_CHAT_MESSAGE
    ( 
      CHAT_SESSION_ID,
      SEQUENCE_NR,
      PROMPT_NR,
      MESSAGE_TYPE,
      MESSAGE_TIMESTAMP,
      MESSAGE,
      MODEL
    )
    values      
    ( 
      v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID'),
      v_max_sequence_nr,
      v_prompt_nr+1,
      'user',
      current_date,
      v('P' ||v('APP_PAGE_ID') || '_INPUT'),
      v('P' ||v('APP_PAGE_ID') || '_MODEL')
    );                          

    --Send the request to OpenAI and get the full response
    
    --in out sequence number übergeben
    v_return := team_ai.get_plsql_chat_response(p_model => v('P' ||v('APP_PAGE_ID') || '_MODEL'),
                                                p_temperature => case v('P' ||v('APP_PAGE_ID') || '_TEMPERATURE') when 0 then 0
                                                                                  when 1 then 0.2
                                                                                  when 2 then 0.4
                                                                                  when 3 then 0.6
                                                                                  when 4 then 0.8
                                                                                  when 5 then 1
                                                                                  else 1.2 end,
                                                  p_usage_tokens => v_usage_tokens,
                                                  p_answer_request_id => v('P' ||v('APP_PAGE_ID') || '_ANSWER_REQUEST_ID'),
                                                  p_chat_session_id => v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID'),
                                                  p_lang => v('P' ||v('APP_PAGE_ID') || '_SPRACHE'),
                                                  p_max_sequence_nr => v_max_sequence_nr);  
    -- unescape markdown specific characters
    v_return := string_utils.markdown_to_html(v_return);                                                                
 
    select nvl(max(PROMPT_NR),0),nvl(max(sequence_nr),0)
      into v_prompt_nr,v_max_sequence_nr
      from TCH_CHAT_MESSAGE
     where CHAT_SESSION_ID = v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID');   
    
    -- insert Answer into DB
    v_max_sequence_nr := v_max_sequence_nr + 1;
    insert into TCH_CHAT_MESSAGE
    ( 
      CHAT_SESSION_ID,
      SEQUENCE_NR,
      PROMPT_NR,
      MESSAGE_TYPE,
      MESSAGE_TIMESTAMP,
      MESSAGE,
      MODEL,
      prompt_tokens,
      completion_tokens,
      total_tokens
    )
    values      
    ( 
      v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID'),
      v_max_sequence_nr,
      v_prompt_nr+1,
      'assistant',
      current_date,
      v_return,
      v('P' ||v('APP_PAGE_ID') || '_MODEL'),
      v_usage_tokens.prompt_tokens,
      v_usage_tokens.completion_tokens,
      v_usage_tokens.total_tokens
    );     
  
    apex_util.set_session_state('P' ||v('APP_PAGE_ID') || '_SEQ_NR', to_char(v_max_sequence_nr));

    --Return the response to the page
    apex_util.set_session_state('P' ||v('APP_PAGE_ID') || '_RETURN', v_return);
    if v('P' ||v('APP_PAGE_ID') || '_CLEAR_PROMPT_ON_EXECUTE') = 'Y'
    then
      apex_util.set_session_state('P' ||v('APP_PAGE_ID') || '_INPUT', null); 
    else
      apex_util.set_session_state('P' ||v('APP_PAGE_ID') || '_INPUT', v('P' ||v('APP_PAGE_ID') || '_INPUT'));
    end if;        
    
    commit;                                                 
  end ;




  procedure init_new_chat_history
  is
    v_system_prompt clob;
    v_language_prompt varchar2(256) := q'~You can understand any language but can only answer in ~';
  begin

    apex_debug.info('Initializing new chat history!');

    --Clear Previous chathistory
    team_ai.clear_chat_messages;

    -- build system prompt (with language amendment)
    v_system_prompt := v('P' ||v('APP_PAGE_ID') || '_SYSTEM_PROMPT');
    if upper(v('P' ||v('APP_PAGE_ID') || '_SPRACHE')) = 'DE'
    then
      v_system_prompt := v_system_prompt || v_language_prompt || 'German.';
    elsif upper(v('P' ||v('APP_PAGE_ID') || '_SPRACHE')) = 'FR'
    then
      v_system_prompt := v_system_prompt || v_language_prompt || 'French.';
    elsif upper(v('P' ||v('APP_PAGE_ID') || '_SPRACHE')) = 'EN'
    then
      v_system_prompt := v_system_prompt || v_language_prompt || 'English.';
    end if;

    apex_debug.info('System Prompt:');
    apex_debug.info(v_system_prompt);

    --Enter System Prompt into chat
    team_ai.add_chat_message(p_role    => 'system',
                             p_content => v_system_prompt);

    --Get Chat history from the database
    
    for v_line in (select *
                     from (select *
                             from TCH_CHAT_MESSAGE
                            where CHAT_SESSION_ID = v('P' ||v('APP_PAGE_ID') || '_CHAT_SESSION_ID')
                            order by sequence_nr desc)
                    order by sequence_nr)
    loop
        team_ai.add_chat_message(p_role           => nvl(v_line.MESSAGE_TYPE,'user'),
                                 p_content        => nvl(v_line.MESSAGE,' '),
                                 p_name           => v_line.FUNCTION_NAME,
                                 p_type           => v_line.type,
                                 p_tools_call_id  => v_line.tools_call_id,
                                 p_arguments      => v_line.arguments);                         
    end loop;

    -- tell model which functions are available
    gpt_function_declarations.declare_all_functions_to_openai;

    
  end ;

end "APEX_GPT";
/