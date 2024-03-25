CREATE TABLE TCH_APEX_APP_STRUCT
 (	ID                      NUMBER NOT NULL ENABLE, 
    apex_elem_id            VARCHAR2(4000 char),
    parent_apex_elem_id     VARCHAR2(4000 char), 
    import_file_start_line  NUMBER NOT NULL, 
    elem_type               VARCHAR2(256 char) NOT NULL,
    elem_name               varchar2(4000 char),
    session_id              VARCHAR2(256 char) NOT NULL,
    
    CREATED DATE NOT NULL ENABLE, 
    CREATED_BY VARCHAR2(255 CHAR) NOT NULL ENABLE, 
    UPDATED DATE NOT NULL ENABLE, 
    UPDATED_BY VARCHAR2(255 CHAR) NOT NULL ENABLE, 
    
     CONSTRAINT "TCH_APEX_APP_STRUCT_ID_PK" PRIMARY KEY ("ID")
    USING INDEX  ENABLE, 
     CONSTRAINT "TCH_APEX_APP_STRUCT_VAL1" CHECK (elem_type in ('PAGE', 'PAGE_PLUG', 'PARAM'))
 )  DEFAULT COLLATION "USING_NLS_COMP" ;

CREATE INDEX "TCH_APEX_APP_STRUCT_I1" ON "TCH_APEX_APP_STRUCT" (APEX_ELEM_ID);
CREATE INDEX "TCH_APEX_APP_STRUCT_I2" ON "TCH_APEX_APP_STRUCT" (parent_apex_elem_id);
CREATE INDEX "TCH_APEX_APP_STRUCT_I3" ON "TCH_APEX_APP_STRUCT" (session_id);
CREATE SEQUENCE TCH_APEX_APP_STRUCT_ID_SEQ minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 nocache noorder nocycle nokeep noscale global;

CREATE OR REPLACE EDITIONABLE TRIGGER "TCH_APEX_APP_STRUCT_BIU" 
    before insert or update   
    on TCH_APEX_APP_STRUCT  
    for each row  
begin  
    if(updating or inserting) and :new.ID is null
    then
      :new.ID := TCH_APEX_APP_STRUCT_ID_SEQ.nextval;
    end if;

    if inserting then  
        :new.created := sysdate;  
        :new.created_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
    end if;  
    :new.updated := sysdate;  
    :new.updated_by := coalesce(sys_context('APEX$SESSION','APP_USER'),user);  
end TCH_APEX_APP_STRUCT_BIU;
/
ALTER TRIGGER "TCH_APEX_APP_STRUCT_BIU" ENABLE;

alter table TCH_APEX_APP_STRUCT modify session_id VARCHAR2(256 char) not null;
alter table TCH_APEX_APP_STRUCT modify import_file_start_line NUMBER NOT NULL;
alter table TCH_APEX_APP_STRUCT modify elem_type VARCHAR2(256 char) NOT NULL;

alter table TCH_APEX_APP_STRUCT add elem_name varchar2(4000 char);

-- 24.11.2023, 11.12.2023, 22.01.2024
alter table TCH_APEX_APP_STRUCT
drop constraint TCH_APEX_APP_STRUCT_VAL1;

alter table TCH_APEX_APP_STRUCT
add constraint TCH_APEX_APP_STRUCT_VAL1
check (elem_type in ('PAGE', 'PAGE_PLUG', 'PAGE_ITEM', 'WORKSHEET', 'WORKSHEET_COLUMN', 'WORKSHEET_REPORT', 'PARAM'));  
    