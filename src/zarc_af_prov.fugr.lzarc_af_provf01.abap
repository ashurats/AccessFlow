*&---------------------------------------------------------------------*
*& Include LZARC_AF_PROVF01 - AccessFlow provisioning subroutines
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Init
*&---------------------------------------------------------------------*
FORM init USING iv_req_id TYPE zarc_af_joiner-req_id.
  CLEAR: gt_items, gt_current, gt_merged, gt_profiles, gt_roles, gt_rel,
         gt_action, gt_touched, gv_run_id, gv_dest, gv_client, gv_target,
         gv_user, gv_log_no, gv_case, gv_case_msg, gv_note, gv_write_msg,
         gv_stop, gv_write, gv_verify, gv_locked, gv_connected.
  gv_req_id = iv_req_id.
ENDFORM.

*&---------------------------------------------------------------------*
*& Lock whole request (scope 1: lock survives COMMIT WORK)
*&---------------------------------------------------------------------*
FORM lock_request CHANGING cv_ok  TYPE abap_bool
                           cv_msg TYPE bapi_msg.
  cv_ok = abap_false.
  CALL FUNCTION 'ENQUEUE_EZARC_AF_REQ'
    EXPORTING
      mode_zarc_af_joiner = 'E'
      mandt               = sy-mandt
      req_id              = gv_req_id
      _scope              = '1'
    EXCEPTIONS
      foreign_lock        = 1
      system_failure      = 2
      OTHERS              = 3.
  CASE sy-subrc.
    WHEN 0.
      cv_ok     = abap_true.
      gv_locked = abap_true.
    WHEN 1.
      cv_msg = |Request { gv_req_id } is already being processed by { sy-msgv1 }|.
    WHEN OTHERS.
      cv_msg = |Lock for request { gv_req_id } could not be set|.
  ENDCASE.
ENDFORM.

FORM unlock_request.
  CHECK gv_locked = abap_true.
  CALL FUNCTION 'DEQUEUE_EZARC_AF_REQ'
    EXPORTING
      mode_zarc_af_joiner = 'E'
      mandt               = sy-mandt
      req_id              = gv_req_id
      _scope              = '1'.
  gv_locked = abap_false.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 2: load work order
*&---------------------------------------------------------------------*
FORM load_items CHANGING cv_ok  TYPE abap_bool
                         cv_msg TYPE bapi_msg.
  DATA ls_item TYPE zarc_af_joiner.

  cv_ok = abap_false.
  SELECT * FROM zarc_af_joiner
    WHERE req_id = @gv_req_id
    ORDER BY item_no
    INTO TABLE @gt_items.
  IF gt_items IS INITIAL.
    cv_msg = |Request { gv_req_id } not found|.
    RETURN.
  ENDIF.

  READ TABLE gt_items INTO ls_item INDEX 1.
  IF ls_item-case_status = gc_success OR ls_item-case_status = gc_no_change.
    cv_msg = |Request { gv_req_id } is already completed ({ ls_item-case_status })|.
    RETURN.
  ENDIF.

  gv_user   = ls_item-sap_user.
  gv_target = ls_item-target_sys.

  SELECT MAX( log_no ) FROM zarc_af_prov_log
    WHERE req_id = @gv_req_id
    INTO @gv_log_no.

  cv_ok = abap_true.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 3: prerequisites before any SAP write
*&---------------------------------------------------------------------*
FORM gate_check CHANGING cv_ok  TYPE abap_bool
                         cv_msg TYPE bapi_msg.
  DATA: ls_item  TYPE zarc_af_joiner,
        lt_names TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line.

  cv_ok = abap_false.

  LOOP AT gt_items INTO ls_item.
    IF ls_item-req_status <> gc_req_approved.
      cv_msg = |Item { ls_item-item_no }: request not approved (status { ls_item-req_status })|.
      RETURN.
    ENDIF.
    IF ls_item-sap_user IS INITIAL OR ls_item-target_sys IS INITIAL
       OR ls_item-agr_name IS INITIAL
       OR ls_item-valid_from IS INITIAL OR ls_item-valid_to IS INITIAL.
      cv_msg = |Item { ls_item-item_no }: SAP user, target system, role or validity missing|.
      RETURN.
    ENDIF.
    IF ls_item-valid_to < ls_item-valid_from.
      cv_msg = |Item { ls_item-item_no }: validity end is before validity start|.
      RETURN.
    ENDIF.
    IF ls_item-agr_type <> gc_type_comp AND ls_item-agr_type <> gc_type_single.
      cv_msg = |Item { ls_item-item_no }: role type must be C (composite) or S (single)|.
      RETURN.
    ENDIF.
    IF ls_item-sap_user <> gv_user OR ls_item-target_sys <> gv_target.
      cv_msg = |Item { ls_item-item_no }: all items must have the same SAP user and target system|.
      RETURN.
    ENDIF.
    INSERT ls_item-agr_name INTO TABLE lt_names.
    IF sy-subrc <> 0.
      cv_msg = |Role { ls_item-agr_name } is requested more than once|.
      RETURN.
    ENDIF.
  ENDLOOP.

  SELECT SINGLE rfc_dest, tgt_client FROM zarc_af_sysconn
    WHERE target_sys = @gv_target
    INTO (@gv_dest, @gv_client).
  IF sy-subrc <> 0 OR gv_dest IS INITIAL.
    cv_msg = |No connection configured for target system { gv_target } (ZARC_AF_SYSCONN)|.
    RETURN.
  ENDIF.

* >>> INTEGRATION POINT: "scheduled implementation time reached"
*     No scheduling field exists - the manual Approve button is the trigger.
* >>> INTEGRATION POINT: "required checks completed per process rules"
*     e.g. SoD result once AccessFlow stores it on the request.

  cv_ok = abap_true.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 3: on hold = no status value, reason in CASE_MSG + log
*&---------------------------------------------------------------------*
FORM set_on_hold USING iv_msg TYPE bapi_msg.
  DATA ls_dummy TYPE zarc_af_joiner.
  CLEAR gv_case.
  gv_case_msg = |On hold: { iv_msg }|.
  PERFORM write_log USING ls_dummy 'GATE' 'E' iv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Start run: RUN_ID committed before the first RFC call
*&---------------------------------------------------------------------*
FORM start_run.
  FIELD-SYMBOLS <ls_item> TYPE zarc_af_joiner.

  TRY.
      gv_run_id = cl_system_uuid=>create_uuid_c32_static( ).
    CATCH cx_uuid_error.
      gv_run_id = |{ sy-datum }{ sy-uzeit }|.
  ENDTRY.

* Reset results of earlier runs - except unclear items (step 12)
  LOOP AT gt_items ASSIGNING <ls_item>
       WHERE prov_status <> gc_success
         AND prov_status <> gc_no_change
         AND prov_status <> gc_unconfirmed.
    CLEAR: <ls_item>-prov_status, <ls_item>-prov_msg.
  ENDLOOP.

  CLEAR: gv_case, gv_case_msg.
  PERFORM save_items.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 4: connect to target system / client
*&---------------------------------------------------------------------*
FORM connect_target.
  DATA: lv_rfcmsg TYPE c LENGTH 255,
        lv_msg    TYPE bapi_msg,
        ls_dummy  TYPE zarc_af_joiner.

  CALL FUNCTION 'RFC_PING' DESTINATION gv_dest
    EXCEPTIONS
      system_failure        = 1 MESSAGE lv_rfcmsg
      communication_failure = 2 MESSAGE lv_rfcmsg
      OTHERS                = 3.
  IF sy-subrc <> 0.
    lv_msg = |Target { gv_target } ({ gv_dest }) not reachable: { lv_rfcmsg }|.
    PERFORM stop_open_items USING gc_tech_error lv_msg.
    RETURN.
  ENDIF.

  gv_connected = abap_true.
  lv_msg = |Connected to { gv_target } via { gv_dest }, client { gv_client }|.
  PERFORM write_log USING ls_dummy 'CONNECT' 'S' lv_msg.
ENDFORM.

FORM close_connection.
  CHECK gv_connected = abap_true.
  CALL FUNCTION 'RFC_CONNECTION_CLOSE'
    EXPORTING
      destination          = gv_dest
    EXCEPTIONS
      destination_not_open = 1
      OTHERS               = 2.
  gv_connected = abap_false.
ENDFORM.

*&---------------------------------------------------------------------*
*& Read user detail in target (steps 5/7 and 10)
*& cv_rc: 0 = ok, 1 = user not found, 2 = technical error
*&---------------------------------------------------------------------*
FORM read_user_detail TABLES   ct_agr  STRUCTURE bapiagr
                               ct_prof STRUCTURE bapiprof
                      CHANGING cv_rc   TYPE i
                               cv_msg  TYPE bapi_msg
                               cs_lock TYPE uslock.
  DATA: lt_return TYPE STANDARD TABLE OF bapiret2,
        ls_return TYPE bapiret2,
        lv_rfcmsg TYPE c LENGTH 255.

  CLEAR: ct_agr[], ct_prof[], cv_rc, cv_msg, cs_lock.

* CACHE_RESULTS = space: read-back must not return a cached list
  CALL FUNCTION 'BAPI_USER_GET_DETAIL' DESTINATION gv_dest
    EXPORTING
      username              = gv_user
      cache_results         = space
    IMPORTING
      islocked              = cs_lock
    TABLES
      profiles              = ct_prof
      activitygroups        = ct_agr
      return                = lt_return
    EXCEPTIONS
      system_failure        = 1 MESSAGE lv_rfcmsg
      communication_failure = 2 MESSAGE lv_rfcmsg
      OTHERS                = 3.
  IF sy-subrc <> 0.
    cv_rc  = 2.
    cv_msg = |RFC error reading user { gv_user }: { lv_rfcmsg }|.
    RETURN.
  ENDIF.

  LOOP AT lt_return INTO ls_return WHERE type CA 'EA'.
    IF ls_return-id = '01' AND ls_return-number = '124'.   " user does not exist
      cv_rc = 1.
    ELSE.
      cv_rc = 2.
    ENDIF.
    cv_msg = ls_return-message.
    RETURN.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 5: SAP user exists and belongs to the person
*&---------------------------------------------------------------------*
FORM check_user.
  DATA: lv_rc    TYPE i,
        lv_msg   TYPE bapi_msg,
        ls_lock  TYPE uslock,
        ls_item  TYPE zarc_af_joiner,
        ls_dummy TYPE zarc_af_joiner,
        lt_pernr TYPE STANDARD TABLE OF persno,
        lv_pernr TYPE persno.

  PERFORM read_user_detail TABLES gt_current gt_profiles
                           CHANGING lv_rc lv_msg ls_lock.
  CASE lv_rc.
    WHEN 1.
      lv_msg = |SAP user { gv_user } not found in { gv_target }: { lv_msg }|.
      PERFORM stop_open_items USING gc_clarify lv_msg.
      RETURN.
    WHEN 2.
      PERFORM stop_open_items USING gc_tech_error lv_msg.
      RETURN.
  ENDCASE.

* >>> INTEGRATION POINT: user <-> person association.
*     Reads PA0105/0001 in the system where AccessFlow runs (HR source).
  READ TABLE gt_items INTO ls_item INDEX 1.
  IF ls_item-pernr IS NOT INITIAL.
    SELECT DISTINCT pernr FROM pa0105
      WHERE subty = '0001'
        AND usrid = @gv_user
        AND begda <= @sy-datum
        AND endda >= @sy-datum
      INTO TABLE @lt_pernr.
    IF lines( lt_pernr ) <> 1.
      lv_msg = |SAP user { gv_user } is not uniquely assigned to a person (PA0105, { lines( lt_pernr ) } hits)|.
      PERFORM stop_open_items USING gc_clarify lv_msg.
      RETURN.
    ENDIF.
    READ TABLE lt_pernr INTO lv_pernr INDEX 1.
    IF lv_pernr <> ls_item-pernr.
      lv_msg = |SAP user { gv_user } belongs to personnel no. { lv_pernr }, not { ls_item-pernr }|.
      PERFORM stop_open_items USING gc_clarify lv_msg.
      RETURN.
    ENDIF.
  ENDIF.

* User lock is reported, never removed
  IF ls_lock-glob_lock = 'L' OR ls_lock-local_lock = 'L' OR ls_lock-wrng_logon = 'L'.
    gv_note = |User { gv_user } is locked in { gv_target }; lock not removed by provisioning|.
  ENDIF.

  lv_msg = |User { gv_user } confirmed; { lines( gt_current ) } current role assignments read|.
  PERFORM write_log USING ls_dummy 'USER' 'S' lv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 6: validate whole package before the first write
*&---------------------------------------------------------------------*
FORM validate_roles.
  DATA: ls_item  TYPE zarc_af_joiner,
        ls_role  TYPE ty_role,
        ls_rel   TYPE ty_rel,
        lt_val   TYPE string_table,
        lv_val   TYPE string,
        lv_rc    TYPE i,
        lv_msg   TYPE bapi_msg,
        lv_cond  TYPE string,
        lv_clar  TYPE abap_bool,
        ls_dummy TYPE zarc_af_joiner.

  LOOP AT gt_items INTO ls_item
       WHERE prov_status <> gc_success AND prov_status <> gc_no_change.

* >>> INTEGRATION POINT: replace the reads below with ArcRecMan validation
    CLEAR ls_role.
    ls_role-agr_name = ls_item-agr_name.
    lv_cond = |AGR_NAME = '{ ls_item-agr_name }'|.

*   Exists in target?
    PERFORM rfc_read USING 'AGR_DEFINE' 'AGR_NAME' lv_cond space
                     CHANGING lt_val lv_rc lv_msg.
    IF lv_rc <> 0.
      PERFORM stop_open_items USING gc_tech_error lv_msg.
      RETURN.
    ENDIF.
    IF lt_val IS INITIAL.
      lv_msg = |Role { ls_item-agr_name } does not exist in { gv_target }|.
      PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
      lv_clar = abap_true.
      CONTINUE.
    ENDIF.

*   Composite or single?
    PERFORM rfc_read USING 'AGR_FLAGS' 'FLAG_VALUE' lv_cond `FLAG_TYPE = 'COLL_AGR'`
                     CHANGING lt_val lv_rc lv_msg.
    IF lv_rc <> 0.
      PERFORM stop_open_items USING gc_tech_error lv_msg.
      RETURN.
    ENDIF.
    READ TABLE lt_val INTO lv_val INDEX 1.
    IF sy-subrc = 0 AND lv_val = 'X'.
      ls_role-is_comp = abap_true.
    ENDIF.

    IF ( ls_role-is_comp = abap_true  AND ls_item-agr_type <> gc_type_comp ) OR
       ( ls_role-is_comp = abap_false AND ls_item-agr_type <> gc_type_single ).
      lv_msg = |Role { ls_item-agr_name } has a different type than requested ({ ls_item-agr_type })|.
      PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
      lv_clar = abap_true.
      CONTINUE.
    ENDIF.

    IF ls_role-is_comp = abap_true.
*     Composite: must contain single roles; children kept for overlap check
      PERFORM rfc_read USING 'AGR_AGRS' 'CHILD_AGR' lv_cond space
                       CHANGING lt_val lv_rc lv_msg.
      IF lv_rc <> 0.
        PERFORM stop_open_items USING gc_tech_error lv_msg.
        RETURN.
      ENDIF.
      IF lt_val IS INITIAL.
        lv_msg = |Composite role { ls_item-agr_name } contains no single roles|.
        PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
        lv_clar = abap_true.
        CONTINUE.
      ENDIF.
      LOOP AT lt_val INTO lv_val.
        ls_rel-parent = ls_item-agr_name.
        ls_rel-child  = lv_val.
        APPEND ls_rel TO gt_rel.
      ENDLOOP.
    ELSE.
*     Single: generated profile = technically deployed
      PERFORM rfc_read USING 'AGR_1016' 'PROFILE' lv_cond space
                       CHANGING lt_val lv_rc lv_msg.
      IF lv_rc <> 0.
        PERFORM stop_open_items USING gc_tech_error lv_msg.
        RETURN.
      ENDIF.
      READ TABLE lt_val INTO lv_val INDEX 1.
      IF sy-subrc <> 0 OR lv_val IS INITIAL.
        lv_msg = |Role { ls_item-agr_name } has no generated profile in { gv_target }|.
        PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
        lv_clar = abap_true.
        CONTINUE.
      ENDIF.
      ls_role-profile = lv_val.

*     Composites containing this single (for overlap check)
      lv_cond = |CHILD_AGR = '{ ls_item-agr_name }'|.
      PERFORM rfc_read USING 'AGR_AGRS' 'AGR_NAME' lv_cond space
                       CHANGING lt_val lv_rc lv_msg.
      IF lv_rc <> 0.
        PERFORM stop_open_items USING gc_tech_error lv_msg.
        RETURN.
      ENDIF.
      LOOP AT lt_val INTO lv_val.
        ls_rel-parent = lv_val.
        ls_rel-child  = ls_item-agr_name.
        APPEND ls_rel TO gt_rel.
      ENDLOOP.
    ENDIF.

    APPEND ls_role TO gt_roles.
  ENDLOOP.

  IF lv_clar = abap_true.
    lv_msg = 'Package stopped before any change - role check failed for at least one item'.
    PERFORM stop_open_items USING space lv_msg.
    RETURN.
  ENDIF.

  lv_msg = |All { lines( gt_roles ) } requested roles validated in { gv_target }|.
  PERFORM write_log USING ls_dummy 'ROLES' 'S' lv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Generic remote single-field read (fallback until ArcRecMan is wired)
*& cv_rc: 0 = ok (ct_val may be empty), 2 = technical error
*&---------------------------------------------------------------------*
FORM rfc_read USING    iv_table TYPE csequence
                       iv_field TYPE csequence
                       iv_cond1 TYPE csequence
                       iv_cond2 TYPE csequence
              CHANGING ct_val   TYPE string_table
                       cv_rc    TYPE i
                       cv_msg   TYPE bapi_msg.
  DATA: lt_opt    TYPE STANDARD TABLE OF rfc_db_opt,
        ls_opt    TYPE rfc_db_opt,
        lt_fld    TYPE STANDARD TABLE OF rfc_db_fld,
        ls_fld    TYPE rfc_db_fld,
        lt_data   TYPE STANDARD TABLE OF tab512,
        ls_data   TYPE tab512,
        lv_tab    TYPE tabname,
        lv_val    TYPE string,
        lv_subrc  TYPE sy-subrc,
        lv_rfcmsg TYPE c LENGTH 255.

  CLEAR: ct_val, cv_rc, cv_msg.
  lv_tab = iv_table.

  ls_opt-text = iv_cond1.
  APPEND ls_opt TO lt_opt.
  IF iv_cond2 IS NOT INITIAL.
    ls_opt-text = |AND { iv_cond2 }|.
    APPEND ls_opt TO lt_opt.
  ENDIF.
  ls_fld-fieldname = iv_field.
  APPEND ls_fld TO lt_fld.

  CALL FUNCTION 'RFC_READ_TABLE' DESTINATION gv_dest
    EXPORTING
      query_table           = lv_tab
      delimiter             = '|'
    TABLES
      options               = lt_opt
      fields                = lt_fld
      data                  = lt_data
    EXCEPTIONS
      table_not_available   = 1
      table_without_data    = 2
      option_not_valid      = 3
      field_not_valid       = 4
      not_authorized        = 5
      data_buffer_exceeded  = 6
      system_failure        = 7 MESSAGE lv_rfcmsg
      communication_failure = 8 MESSAGE lv_rfcmsg
      OTHERS                = 9.
  lv_subrc = sy-subrc.

  IF lv_subrc = 0 OR lv_subrc = 2.
    LOOP AT lt_data INTO ls_data.
      lv_val = ls_data-wa.
      CONDENSE lv_val.
      APPEND lv_val TO ct_val.
    ENDLOOP.
  ELSE.
    cv_rc  = 2.
    cv_msg = |Technical error reading { iv_table } in { gv_target } (rc { lv_subrc }) { lv_rfcmsg }|.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 7: composite / direct single overlap -> clarification
*&---------------------------------------------------------------------*
FORM check_overlap.
  DATA: ls_item TYPE zarc_af_joiner,
        ls_rel  TYPE ty_rel,
        lv_msg  TYPE bapi_msg,
        lv_clar TYPE abap_bool.

  LOOP AT gt_items INTO ls_item
       WHERE prov_status <> gc_success AND prov_status <> gc_no_change.
    IF ls_item-agr_type = gc_type_comp.
      LOOP AT gt_rel INTO ls_rel WHERE parent = ls_item-agr_name.
        IF line_exists( gt_items[ agr_name = ls_rel-child ] ) OR
           line_exists( gt_current[ agr_name = ls_rel-child ] ).
          lv_msg = |Composite { ls_item-agr_name } contains { ls_rel-child }, also requested or directly assigned - assignment rule not defined|.
          PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
          lv_clar = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ELSE.
      LOOP AT gt_rel INTO ls_rel WHERE child = ls_item-agr_name.
        IF line_exists( gt_items[ agr_name = ls_rel-parent ] ) OR
           line_exists( gt_current[ agr_name = ls_rel-parent ] ).
          lv_msg = |Single { ls_item-agr_name } is contained in composite { ls_rel-parent }, also requested or assigned - assignment rule not defined|.
          PERFORM set_item USING ls_item-item_no gc_clarify lv_msg.
          lv_clar = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

  IF lv_clar = abap_true.
    lv_msg = 'Package stopped before any change - composite/single overlap requires clarification'.
    PERFORM stop_open_items USING space lv_msg.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 7: change list; merged list = current direct roles + changes
*&---------------------------------------------------------------------*
FORM build_delta.
  DATA: ls_action  TYPE ty_action,
        ls_new     TYPE bapiagr,
        lv_from_m1 TYPE d,
        lv_to_p1   TYPE d,
        lv_covered TYPE abap_bool,
        lv_done    TYPE abap_bool,
        lv_msg     TYPE bapi_msg.
  FIELD-SYMBOLS: <ls_item> TYPE zarc_af_joiner,
                 <ls_agr>  TYPE bapiagr.

* >>> VERIFY IN A4H: ACTIVITYGROUPS must contain direct assignments only.
*     If indirect singles from composites appear, filter them here
*     (AGR_USERS-COL_FLAG = 'X') - otherwise they become direct assignments.
  gt_merged = gt_current.

  LOOP AT gt_items ASSIGNING <ls_item>
       WHERE prov_status <> gc_success AND prov_status <> gc_no_change.

    CLEAR ls_action.
    ls_action-item_no = <ls_item>-item_no.

*   Already covered for the whole requested period?
    lv_covered = abap_false.
    LOOP AT gt_merged ASSIGNING <ls_agr> WHERE agr_name = <ls_item>-agr_name.
      IF <ls_agr>-from_dat <= <ls_item>-valid_from AND <ls_agr>-to_dat >= <ls_item>-valid_to.
        lv_covered = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_covered = abap_true.
      IF <ls_item>-prov_status = gc_unconfirmed.
        ls_action-action = gc_act_verify.          " earlier unclear write - confirm via read-back
        gv_verify = abap_true.
      ELSE.
        ls_action-action = gc_act_none.
        lv_msg = |Requested access already present in { gv_target }|.
        PERFORM set_item USING <ls_item>-item_no gc_no_change lv_msg.
      ENDIF.
      APPEND ls_action TO gt_action.
      CONTINUE.
    ENDIF.

*   Overlapping or adjacent entry -> extend (never shorten)
    lv_from_m1 = <ls_item>-valid_from - 1.
    lv_to_p1   = <ls_item>-valid_to.
    IF lv_to_p1 < '99991231'.
      lv_to_p1 = lv_to_p1 + 1.
    ENDIF.

    lv_done = abap_false.
    LOOP AT gt_merged ASSIGNING <ls_agr> WHERE agr_name = <ls_item>-agr_name.
      IF <ls_agr>-from_dat <= lv_to_p1 AND <ls_agr>-to_dat >= lv_from_m1.
        IF <ls_item>-valid_from < <ls_agr>-from_dat.
          <ls_agr>-from_dat = <ls_item>-valid_from.
        ENDIF.
        IF <ls_item>-valid_to > <ls_agr>-to_dat.
          <ls_agr>-to_dat = <ls_item>-valid_to.
        ENDIF.
        lv_done = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_done = abap_true.
      ls_action-action = gc_act_extend.
    ELSE.
      CLEAR ls_new.
      ls_new-agr_name = <ls_item>-agr_name.
      ls_new-from_dat = <ls_item>-valid_from.
      ls_new-to_dat   = <ls_item>-valid_to.
      APPEND ls_new TO gt_merged.
      ls_action-action = gc_act_add.
    ENDIF.
    APPEND ls_action TO gt_action.
    gv_write = abap_true.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Steps 8 + 9: write full merged list, log attempt and response
*&---------------------------------------------------------------------*
FORM write_assignments.
  DATA: ls_action TYPE ty_action,
        lt_return TYPE STANDARD TABLE OF bapiret2,
        ls_return TYPE bapiret2,
        lv_rfcmsg TYPE c LENGTH 255,
        lv_msg    TYPE bapi_msg,
        lv_msgty  TYPE bapi_mtype,
        lv_failed TYPE abap_bool.
  FIELD-SYMBOLS <ls_item> TYPE zarc_af_joiner.

* 1. Mark "sent, not confirmed" and commit BEFORE calling SAP
  LOOP AT gt_action INTO ls_action WHERE action = gc_act_add OR action = gc_act_extend.
    READ TABLE gt_items ASSIGNING <ls_item> WITH KEY item_no = ls_action-item_no.
    CHECK sy-subrc = 0.
    <ls_item>-retry_cnt = <ls_item>-retry_cnt + 1.
    IF ls_action-action = gc_act_add.
      lv_msg = |Assign { <ls_item>-agr_name } { <ls_item>-valid_from DATE = ISO } - { <ls_item>-valid_to DATE = ISO }|.
    ELSE.
      lv_msg = |Extend validity of { <ls_item>-agr_name } to cover { <ls_item>-valid_from DATE = ISO } - { <ls_item>-valid_to DATE = ISO }|.
    ENDIF.
    PERFORM write_log USING <ls_item> 'ATTEMPT' 'I' lv_msg.
    lv_msg = 'Change sent to SAP - not yet confirmed'.
    PERFORM set_item USING <ls_item>-item_no gc_unconfirmed lv_msg.
  ENDLOOP.
  PERFORM save_items.

* 2. One call for the whole package. The list REPLACES all direct roles,
*    therefore gt_merged = current direct roles + changes.
  CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN' DESTINATION gv_dest
    EXPORTING
      username              = gv_user
    TABLES
      activitygroups        = gt_merged
      return                = lt_return
    EXCEPTIONS
      system_failure        = 1 MESSAGE lv_rfcmsg
      communication_failure = 2 MESSAGE lv_rfcmsg
      OTHERS                = 3.

  IF sy-subrc <> 0.
*   Timeout / connection loss: SAP may have saved - outcome unclear
    lv_msgty = 'E'.
    lv_msg   = |RFC error, outcome unclear: { lv_rfcmsg }|.
  ELSE.
    LOOP AT lt_return INTO ls_return WHERE type CA 'EA'.
      lv_failed = abap_true.
      lv_msg    = ls_return-message.
      EXIT.
    ENDLOOP.
    IF lv_failed = abap_true.
      lv_msgty = 'E'.
    ELSE.
*     >>> VERIFY IN A4H: whether the user BAPIs commit themselves.
*     Explicit commit in the same remote session is harmless either way.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' DESTINATION gv_dest
        EXPORTING
          wait                  = 'X'
        EXCEPTIONS
          system_failure        = 1 MESSAGE lv_rfcmsg
          communication_failure = 2 MESSAGE lv_rfcmsg
          OTHERS                = 3.
      lv_msgty = 'S'.
      READ TABLE lt_return INTO ls_return WITH KEY type = 'S'.
      IF sy-subrc = 0.
        lv_msg = ls_return-message.
      ELSE.
        lv_msg = 'Role assignment accepted by SAP'.
      ENDIF.
    ENDIF.
  ENDIF.
  gv_write_msg = lv_msg.

* 3. Step 9: technical response per executed item
  LOOP AT gt_action INTO ls_action WHERE action = gc_act_add OR action = gc_act_extend.
    READ TABLE gt_items ASSIGNING <ls_item> WITH KEY item_no = ls_action-item_no.
    CHECK sy-subrc = 0.
    PERFORM write_log USING <ls_item> 'RESPONSE' lv_msgty lv_msg.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 10: read back - only a confirmed read closes an item
*&---------------------------------------------------------------------*
FORM read_back.
  DATA: lt_agr     TYPE STANDARD TABLE OF bapiagr,
        lt_prof    TYPE STANDARD TABLE OF bapiprof,
        ls_action  TYPE ty_action,
        ls_role    TYPE ty_role,
        ls_lock    TYPE uslock,
        lv_rc      TYPE i,
        lv_msg     TYPE bapi_msg,
        lv_covered TYPE abap_bool.
  FIELD-SYMBOLS: <ls_item> TYPE zarc_af_joiner,
                 <ls_agr>  TYPE bapiagr.

  PERFORM read_user_detail TABLES lt_agr lt_prof
                           CHANGING lv_rc lv_msg ls_lock.
  IF lv_rc <> 0.
    lv_msg = |Read-back failed, implementation not confirmed: { lv_msg }|.
    LOOP AT gt_action INTO ls_action WHERE action <> gc_act_none.
      READ TABLE gt_items ASSIGNING <ls_item> WITH KEY item_no = ls_action-item_no.
      CHECK sy-subrc = 0.
      PERFORM set_item USING <ls_item>-item_no gc_unconfirmed lv_msg.
      PERFORM write_log USING <ls_item> 'READBACK' 'E' lv_msg.
    ENDLOOP.
    RETURN.
  ENDIF.

  LOOP AT gt_action INTO ls_action WHERE action <> gc_act_none.
    READ TABLE gt_items ASSIGNING <ls_item> WITH KEY item_no = ls_action-item_no.
    CHECK sy-subrc = 0.

    lv_covered = abap_false.
    LOOP AT lt_agr ASSIGNING <ls_agr> WHERE agr_name = <ls_item>-agr_name.
      IF <ls_agr>-from_dat <= <ls_item>-valid_from AND <ls_agr>-to_dat >= <ls_item>-valid_to.
        lv_covered = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_covered = abap_false.
      lv_msg = |Not present in { gv_target } after write. SAP: { gv_write_msg }|.
      PERFORM set_item USING <ls_item>-item_no gc_tech_error lv_msg.
      PERFORM write_log USING <ls_item> 'READBACK' 'E' lv_msg.
      CONTINUE.
    ENDIF.

*   Post-processing: single role valid today -> profile must be in user master
    IF <ls_item>-agr_type = gc_type_single
       AND <ls_item>-valid_from <= sy-datum AND <ls_item>-valid_to >= sy-datum.
      READ TABLE gt_roles INTO ls_role WITH KEY agr_name = <ls_item>-agr_name.
      IF sy-subrc = 0 AND ls_role-profile IS NOT INITIAL
         AND NOT line_exists( lt_prof[ bapiprof = ls_role-profile ] ).
        lv_msg = |Assigned, but profile { ls_role-profile } not yet in user master - user comparison pending|.
        PERFORM set_item USING <ls_item>-item_no gc_unconfirmed lv_msg.
        PERFORM write_log USING <ls_item> 'READBACK' 'W' lv_msg.
        CONTINUE.
      ENDIF.
    ENDIF.

    lv_msg = |Confirmed in { gv_target }: { <ls_item>-valid_from DATE = ISO } - { <ls_item>-valid_to DATE = ISO }|.
    PERFORM set_item USING <ls_item>-item_no gc_success lv_msg.
    PERFORM write_log USING <ls_item> 'READBACK' 'S' lv_msg.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Step 11: overall case status (no automatic rollback)
*&---------------------------------------------------------------------*
FORM close_case.
  DATA: ls_item   TYPE zarc_af_joiner,
        ls_dummy  TYPE zarc_af_joiner,
        lv_open   TYPE abap_bool,
        lv_conf   TYPE abap_bool,
        lv_unconf TYPE abap_bool,
        lv_tech   TYPE abap_bool,
        lv_clar   TYPE abap_bool.

  LOOP AT gt_items INTO ls_item.
    CASE ls_item-prov_status.
      WHEN gc_success.
        lv_conf = abap_true.
      WHEN gc_no_change.
      WHEN gc_unconfirmed.
        lv_unconf = abap_true. lv_open = abap_true.
      WHEN gc_tech_error.
        lv_tech = abap_true.   lv_open = abap_true.
      WHEN gc_clarify.
        lv_clar = abap_true.   lv_open = abap_true.
      WHEN OTHERS.
        lv_open = abap_true.                       " blank = not processed
    ENDCASE.
  ENDLOOP.

  IF lv_open = abap_false.
    IF lv_conf = abap_true.
      gv_case     = gc_success.
      gv_case_msg = 'Successfully implemented'.
    ELSE.
      gv_case     = gc_no_change.
      gv_case_msg = 'Successfully completed - no change required'.
    ENDIF.
  ELSEIF lv_unconf = abap_true.
    gv_case     = gc_unconfirmed.
    gv_case_msg = 'Implementation not yet confirmed'.
  ELSEIF lv_conf = abap_true.
    gv_case     = gc_partial.
    gv_case_msg = 'Partially implemented'.
  ELSEIF lv_tech = abap_true.
    gv_case     = gc_tech_error.
    gv_case_msg = 'Technical error'.
  ELSEIF lv_clar = abap_true.
    gv_case     = gc_clarify.
    gv_case_msg = 'Clarification required'.
  ELSE.
    CLEAR gv_case.
    gv_case_msg = 'Not processed'.
  ENDIF.

  IF gv_note IS NOT INITIAL.
    gv_case_msg = |{ gv_case_msg }. { gv_note }|.
  ENDIF.

  PERFORM write_log USING ls_dummy 'CASE' 'I' gv_case_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Helpers
*&---------------------------------------------------------------------*
FORM set_item USING iv_item_no TYPE zarc_af_joiner-item_no
                    iv_status  TYPE csequence
                    iv_msg     TYPE csequence.
  FIELD-SYMBOLS <ls_item> TYPE zarc_af_joiner.
  READ TABLE gt_items ASSIGNING <ls_item> WITH KEY item_no = iv_item_no.
  CHECK sy-subrc = 0.
  <ls_item>-prov_status = iv_status.
  <ls_item>-prov_msg    = iv_msg.
  GET TIME STAMP FIELD <ls_item>-prov_at.
  IF NOT line_exists( gt_touched[ table_line = iv_item_no ] ).
    APPEND iv_item_no TO gt_touched.
  ENDIF.
ENDFORM.

* Stop package: open items not yet set in this run get iv_status
* (blank = not processed). Items with unclear outcome stay UNCONFIRMED.
FORM stop_open_items USING iv_status TYPE csequence
                           iv_msg    TYPE csequence.
  DATA ls_dummy TYPE zarc_af_joiner.
  FIELD-SYMBOLS <ls_item> TYPE zarc_af_joiner.

  LOOP AT gt_items ASSIGNING <ls_item>
       WHERE prov_status <> gc_success
         AND prov_status <> gc_no_change
         AND prov_status <> gc_unconfirmed.
    IF line_exists( gt_touched[ table_line = <ls_item>-item_no ] ).
      CONTINUE.
    ENDIF.
    <ls_item>-prov_status = iv_status.
    <ls_item>-prov_msg    = iv_msg.
    GET TIME STAMP FIELD <ls_item>-prov_at.
  ENDLOOP.

  PERFORM write_log USING ls_dummy 'STOP' 'E' iv_msg.
  gv_stop = abap_true.
ENDFORM.

FORM save_items.
  FIELD-SYMBOLS <ls_item> TYPE zarc_af_joiner.
  LOOP AT gt_items ASSIGNING <ls_item>.
    <ls_item>-case_status = gv_case.
    <ls_item>-case_msg    = gv_case_msg.
    IF gv_run_id IS NOT INITIAL.
      <ls_item>-run_id = gv_run_id.
    ENDIF.
  ENDLOOP.
  MODIFY zarc_af_joiner FROM TABLE gt_items.
  COMMIT WORK.
ENDFORM.

FORM write_log USING is_item  TYPE zarc_af_joiner
                     iv_step  TYPE csequence
                     iv_msgty TYPE csequence
                     iv_msg   TYPE csequence.
  DATA ls_log TYPE zarc_af_prov_log.

  gv_log_no = gv_log_no + 1.
  ls_log-mandt      = sy-mandt.
  ls_log-req_id     = gv_req_id.
  ls_log-log_no     = gv_log_no.
  ls_log-run_id     = gv_run_id.
  ls_log-item_no    = is_item-item_no.
  ls_log-step       = iv_step.
  ls_log-target_sys = gv_target.
  ls_log-tgt_client = gv_client.
  ls_log-sap_user   = gv_user.
  ls_log-agr_name   = is_item-agr_name.
  ls_log-valid_from = is_item-valid_from.
  ls_log-valid_to   = is_item-valid_to.
  ls_log-msgty      = iv_msgty.
  ls_log-msg        = iv_msg.
  GET TIME STAMP FIELD ls_log-log_at.
  INSERT zarc_af_prov_log FROM ls_log.
ENDFORM.
