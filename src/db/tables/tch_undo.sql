
CREATE TABLE "TCH_UNDO" 
(	
  "ID" NUMBER DEFAULT ON NULL to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') NOT NULL ENABLE, 
  "IMPORT_FILE" clob NOT NULL,
  "IMPORT_FILE_NAME" varchar2(4000) NOT NULL,
  "USER_NAME" VARCHAR2(4000) NOT NULL,

  "CREATED" DATE NOT NULL ENABLE, 
  "CREATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "UPDATED" DATE NOT NULL ENABLE, 
  "UPDATED_BY" VARCHAR2(255 CHAR) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 

  CONSTRAINT "TCH_UNDO_ID_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
)  DEFAULT COLLATION "USING_NLS_COMP" ;

CREATE INDEX "TCH_UNDO_I1" ON "TCH_UNDO" ("USER_NAME");

CREATE SEQUENCE TCH_UNDO_ID_SEQ minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 nocache noorder nocycle nokeep noscale global;

CREATE OR REPLACE EDITIONABLE TRIGGER "TCH_UNDO_BIU" 
  before insert or update   
  on TCH_UNDO  
  for each row  
begin  
  if(updating or inserting) and :new.ID is null
  then
    :new.ID := TCH_UNDO_ID_SEQ.nextval;
  end if;
    
  if inserting then  
      :new.created := sysdate;  
      :new.created_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
  end if;  
  :new.updated := sysdate;  
  :new.updated_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
end TCH_UNDO_BIU;  


/
ALTER TRIGGER "TCH_UNDO_BIU" ENABLE;

-- changes 21.11.2023
alter table tch_undo add IMPORT_FILE_NAME varchar2(4000);
alter table tch_undo modify IMPORT_FILE_NAME not null;