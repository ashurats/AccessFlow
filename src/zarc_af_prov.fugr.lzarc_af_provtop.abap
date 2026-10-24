FUNCTION-POOL zarc_af_prov.

* Provisioning status = workshop document step 11; blank = no result yet
CONSTANTS:
  gc_req_approved TYPE zarc_af_req_status VALUE 'APPROVED',
  gc_success      TYPE zarc_af_status     VALUE 'SUCCESS',
  gc_no_change    TYPE zarc_af_status     VALUE 'NO_CHANGE',
  gc_partial      TYPE zarc_af_status     VALUE 'PARTIAL',
  gc_clarify      TYPE zarc_af_status     VALUE 'CLARIFY',
  gc_tech_error   TYPE zarc_af_status     VALUE 'TECH_ERROR',
  gc_unconfirmed  TYPE zarc_af_status     VALUE 'UNCONFIRMED',
  gc_type_comp    TYPE zarc_af_agr_type   VALUE 'C',
  gc_type_single  TYPE zarc_af_agr_type   VALUE 'S',
  gc_act_none     TYPE c LENGTH 1         VALUE 'N',
  gc_act_add      TYPE c LENGTH 1         VALUE 'A',
  gc_act_extend   TYPE c LENGTH 1         VALUE 'E',
  gc_act_verify   TYPE c LENGTH 1         VALUE 'V'.

TYPES: BEGIN OF ty_role,
         agr_name TYPE agr_name,
         is_comp  TYPE abap_bool,
         profile  TYPE xuprofile,
       END OF ty_role.

TYPES: BEGIN OF ty_rel,
         parent TYPE agr_name,
         child  TYPE agr_name,
       END OF ty_rel.

TYPES: BEGIN OF ty_action,
         item_no TYPE zarc_af_joiner-item_no,
         action  TYPE c LENGTH 1,
       END OF ty_action.

DATA: gt_items     TYPE STANDARD TABLE OF zarc_af_joiner,
      gt_current   TYPE STANDARD TABLE OF bapiagr,
      gt_merged    TYPE STANDARD TABLE OF bapiagr,
      gt_profiles  TYPE STANDARD TABLE OF bapiprof,
      gt_roles     TYPE STANDARD TABLE OF ty_role,
      gt_rel       TYPE STANDARD TABLE OF ty_rel,
      gt_action    TYPE STANDARD TABLE OF ty_action,
      gt_touched   TYPE STANDARD TABLE OF zarc_af_joiner-item_no WITH DEFAULT KEY,
      gv_req_id    TYPE zarc_af_joiner-req_id,
      gv_run_id    TYPE sysuuid_c32,
      gv_dest      TYPE rfcdest,
      gv_client    TYPE zarc_af_tgt_client,
      gv_target    TYPE zarc_af_joiner-target_sys,
      gv_user      TYPE xubname,
      gv_log_no    TYPE zarc_af_prov_log-log_no,
      gv_case      TYPE zarc_af_status,
      gv_case_msg  TYPE bapi_msg,
      gv_note      TYPE bapi_msg,
      gv_write_msg TYPE bapi_msg,
      gv_stop      TYPE abap_bool,
      gv_write     TYPE abap_bool,
      gv_verify    TYPE abap_bool,
      gv_locked    TYPE abap_bool,
      gv_connected TYPE abap_bool.
