  CREATE TABLE "TCH_REQUEST_STATUS" 
   (	
      "ID" NUMBER NOT NULL ENABLE, 
      "CHAT_SESSION_ID" NUMBER, 
      "TCH_REQUEST_ID" NUMBER,
	  "TCH_FUNC_PROGRESS_TEXTS_ID" NUMBER,
      "CREATED" DATE NOT NULL ENABLE, 
      "CREATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
      "UPDATED" DATE NOT NULL ENABLE, 
      "UPDATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
      CONSTRAINT "TCH_REQUEST_STATUS_ID_PK" PRIMARY KEY ("ID") USING INDEX  ENABLE
   )  DEFAULT COLLATION "USING_NLS_COMP";

  ALTER TABLE "TCH_REQUEST_STATUS" ADD CONSTRAINT "TCH_REQUEST_STATUS_CHAT_SESSION_FK" FOREIGN KEY ("CHAT_SESSION_ID")
	  REFERENCES "TCH_CHAT_SESSION" ("ID") ON DELETE CASCADE ENABLE;
	  
  ALTER TABLE "TCH_REQUEST_STATUS" ADD CONSTRAINT "TCH_FUNC_PROGRESS_TEXTS_ID_FK" FOREIGN KEY ("TCH_FUNC_PROGRESS_TEXTS_ID")
	  REFERENCES "TCH_FUNC_PROGRESS_TEXTS" ("ID") ON DELETE CASCADE ENABLE;

  CREATE INDEX "TCH_REQUEST_STATUS_I1" ON "TCH_REQUEST_STATUS" ("CHAT_SESSION_ID");
  CREATE INDEX "TCH_REQUEST_STATUS_I2" ON "TCH_REQUEST_STATUS" ("TCH_REQUEST_ID");

  CREATE SEQUENCE TCH_REQUEST_STATUS_ID_SEQ minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 nocache noorder nocycle nokeep noscale global;
  CREATE SEQUENCE TCH_REQUEST_STATUS_REQ_ID_SEQ minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 nocache noorder nocycle nokeep noscale global;

  CREATE OR REPLACE EDITIONABLE TRIGGER "TCH_REQUEST_STATUS_BIU" 
    before insert or update   
    on TCH_REQUEST_STATUS  
    for each row  
begin  
    if(updating or inserting) and :new.tch_request_id is null
    then
      :new.tch_request_id := TCH_REQUEST_STATUS_REQ_ID_SEQ.nextval;
    end if;

    if(updating or inserting) and :new.ID is null
    then
      :new.ID := TCH_REQUEST_STATUS_ID_SEQ.nextval;
    end if;

    if inserting then  
        :new.created := sysdate;  
        :new.created_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
    end if;  
    :new.updated := sysdate;  
    :new.updated_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
end TCH_REQUEST_STATUS_BIU;  
 
/
ALTER TRIGGER "TCH_REQUEST_STATUS_BIU" ENABLE;
