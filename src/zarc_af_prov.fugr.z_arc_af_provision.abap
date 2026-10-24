FUNCTION z_arc_af_provision.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_REQ_ID) TYPE  ZARC_AF_REQ_ID
*"  EXPORTING
*"     VALUE(EV_CASE_STATUS) TYPE  ZARC_AF_STATUS
*"     VALUE(EV_MESSAGE) TYPE  BAPI_MSG
*"     VALUE(EV_REJECTED) TYPE  ABAP_BOOL
*"  TABLES
*"      ET_ITEMS STRUCTURE  ZARC_AF_JOINER OPTIONAL
*"----------------------------------------------------------------------
  DATA: lv_ok  TYPE abap_bool,
        lv_msg TYPE bapi_msg.

  PERFORM init USING iv_req_id.

* Step 3: not already processed by another run (lock)
  PERFORM lock_request CHANGING lv_ok lv_msg.
  IF lv_ok = abap_false.
    ev_rejected = abap_true.
    ev_message  = lv_msg.
    RETURN.
  ENDIF.

* Step 2: load work order; reject if missing or completed
  PERFORM load_items CHANGING lv_ok lv_msg.
  IF lv_ok = abap_false.
    PERFORM unlock_request.
    ev_rejected = abap_true.
    ev_message  = lv_msg.
    RETURN.
  ENDIF.

* Step 3: prerequisites - failure means no SAP change, reason saved
  PERFORM gate_check CHANGING lv_ok lv_msg.
  IF lv_ok = abap_false.
    PERFORM set_on_hold USING lv_msg.
  ELSE.
    PERFORM start_run.
    PERFORM connect_target.                                  " step 4
    IF gv_stop = abap_false. PERFORM check_user.     ENDIF.  " step 5 + read current (7)
    IF gv_stop = abap_false. PERFORM validate_roles. ENDIF.  " step 6
    IF gv_stop = abap_false. PERFORM check_overlap.  ENDIF.  " step 7 overlap rule
    IF gv_stop = abap_false. PERFORM build_delta.    ENDIF.  " step 7 change list
    IF gv_stop = abap_false AND gv_write = abap_true.
      PERFORM write_assignments.                             " steps 8 + 9
    ENDIF.
    IF gv_stop = abap_false AND ( gv_write = abap_true OR gv_verify = abap_true ).
      PERFORM read_back.                                     " step 10
    ENDIF.
    PERFORM close_case.                                      " step 11
  ENDIF.

  PERFORM save_items.
  PERFORM close_connection.
  PERFORM unlock_request.

  ev_case_status = gv_case.
  ev_message     = gv_case_msg.
  et_items[]     = gt_items.

ENDFUNCTION.
