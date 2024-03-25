  CREATE TABLE "TCH_CHAT_SESSION" 
   (	"ID" NUMBER DEFAULT ON NULL to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') NOT NULL ENABLE, 
	"TITLE" VARCHAR2(4000 CHAR) COLLATE "USING_NLS_COMP", 
	"THE_USER" VARCHAR2(4000 CHAR) COLLATE "USING_NLS_COMP", 
	"CREATED" DATE NOT NULL ENABLE, 
	"CREATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
	"UPDATED" DATE NOT NULL ENABLE, 
	"UPDATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
	"SYSTEM_PROMPT" CLOB COLLATE "USING_NLS_COMP", 
	"DELETED_FL" VARCHAR2(1) COLLATE "USING_NLS_COMP", 
	 CONSTRAINT "TCH_CHAT_SESSION_ID_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   )  DEFAULT COLLATION "USING_NLS_COMP" ;

  CREATE OR REPLACE EDITIONABLE TRIGGER "TCH_CHAT_SESSION_BIU" 
    before insert or update   
    on tch_chat_session  
    for each row  
begin  
    if inserting then  
        :new.created := sysdate;  
        :new.created_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
        :new.deleted_fl := coalesce(:new.deleted_fl,'0'); 
        :new.the_user := coalesce(:new.the_user,sys_context('APEX$SESSION','APP_USER'));  
    end if;  
    :new.updated := sysdate;  
    :new.updated_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
end tch_chat_session_biu;  
 

/
ALTER TRIGGER "TCH_CHAT_SESSION_BIU" ENABLE;