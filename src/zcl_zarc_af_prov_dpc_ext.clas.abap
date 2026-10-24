CLASS zcl_zarc_af_prov_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_zarc_af_prov_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS /iwbep/if_mgw_appl_srv_runtime~create_deep_entity REDEFINITION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.

  PROTECTED SECTION.

    METHODS joineritemset_get_entityset REDEFINITION.
    METHODS joineritemset_get_entity REDEFINITION.
    METHODS requestset_get_entity REDEFINITION.

  PRIVATE SECTION.

    METHODS raise_business_error
      IMPORTING
        iv_message TYPE bapi_msg
      RAISING
        /iwbep/cx_mgw_busi_exception.

    METHODS check_date
      IMPORTING
        iv_date    TYPE d
        iv_field   TYPE string
        iv_item_no TYPE zarc_af_item_no
      RAISING
        /iwbep/cx_mgw_busi_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_dpc_ext IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
*----------------------------------------------------------------------*
*   POST /sap/opu/odata/sap/ZARC_AF_PROV_SRV/RequestSet
*   React "Continue to review": request header + Items (one per SAP role)
*   -> one row per item in ZARC_AF_JOINER, header fields repeated
*----------------------------------------------------------------------*
    DATA: ls_deep    TYPE zcl_zarc_af_prov_mpc=>ts_request_deep,
          ls_result  TYPE zcl_zarc_af_prov_mpc=>ts_request_deep,
          lt_rows    TYPE zcl_zarc_af_prov_mpc=>tt_joineritem,
          ls_row     TYPE zarc_af_joiner,
          lt_names   TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line,
          lt_itemnos TYPE SORTED TABLE OF zarc_af_item_no WITH UNIQUE KEY table_line,
          lv_item_no TYPE zarc_af_item_no,
          lv_exists  TYPE abap_bool,
          lv_ts      TYPE timestampl,
          lv_ts_c    TYPE string,
          lv_msg     TYPE bapi_msg.
    FIELD-SYMBOLS <ls_in> TYPE zarc_af_joiner.

    IF iv_entity_set_name <> 'RequestSet'.
      super->/iwbep/if_mgw_appl_srv_runtime~create_deep_entity(
        EXPORTING
          iv_entity_name          = iv_entity_name
          iv_entity_set_name      = iv_entity_set_name
          iv_source_name          = iv_source_name
          io_data_provider        = io_data_provider
          it_key_tab              = it_key_tab
          it_navigation_path      = it_navigation_path
          io_expand               = io_expand
          io_tech_request_context = io_tech_request_context
        IMPORTING
          er_deep_entity          = er_deep_entity ).
      RETURN.
    ENDIF.

*   JSON body -> deep structure (Items -> component ITEMS)
    io_data_provider->read_entry_data( IMPORTING es_data = ls_deep ).

    ls_deep-sap_user   = to_upper( ls_deep-sap_user ).
    ls_deep-target_sys = to_upper( ls_deep-target_sys ).
    ls_deep-req_status = to_upper( ls_deep-req_status ).

*   Header checks
    IF ls_deep-req_id IS INITIAL.
      lv_msg = 'ReqId is required'.
      raise_business_error( lv_msg ).
    ENDIF.
    IF ls_deep-sap_user IS INITIAL OR ls_deep-target_sys IS INITIAL.
      lv_msg = 'SapUser and TargetSys are required'.
      raise_business_error( lv_msg ).
    ENDIF.
    IF ls_deep-items IS INITIAL.
      lv_msg = 'At least one item (SAP role) is required in Items'.
      raise_business_error( lv_msg ).
    ENDIF.

    SELECT SINGLE @abap_true FROM zarc_af_joiner
      WHERE req_id = @ls_deep-req_id
      INTO @lv_exists.
    IF lv_exists = abap_true.
      lv_msg = |Request { ls_deep-req_id } already exists|.
      raise_business_error( lv_msg ).
    ENDIF.

    GET TIME STAMP FIELD lv_ts.
    lv_ts_c = |{ lv_ts TIMESTAMP = ISO }|.

*   One row per item
    LOOP AT ls_deep-items ASSIGNING <ls_in>.
      lv_item_no = lv_item_no + 1.

      CLEAR ls_row.
      MOVE-CORRESPONDING ls_deep TO ls_row.          " header fields
      ls_row-mandt      = sy-mandt.
      ls_row-item_no    = COND #( WHEN <ls_in>-item_no IS INITIAL THEN lv_item_no
                                  ELSE <ls_in>-item_no ).
      ls_row-bus_role   = <ls_in>-bus_role.
      ls_row-agr_name   = to_upper( <ls_in>-agr_name ).
      ls_row-agr_type   = to_upper( <ls_in>-agr_type ).
      ls_row-valid_from = <ls_in>-valid_from.
      ls_row-valid_to   = <ls_in>-valid_to.

*     End date optional in the UI -> open-ended
      IF ls_row-valid_to IS INITIAL OR ls_row-valid_to CO ' '.
        ls_row-valid_to = '99991231'.
      ENDIF.
* >>> INTEGRATION POINT: rule for VALID_FROM when React sends none
      IF ls_row-valid_from IS INITIAL OR ls_row-valid_from CO ' '.
        ls_row-valid_from = sy-datum.
      ENDIF.

      IF ls_row-created_by IS INITIAL.
        ls_row-created_by = sy-uname.
      ENDIF.
      IF ls_row-created_at IS INITIAL.
        ls_row-created_at = lv_ts_c.
      ENDIF.

*     Item checks
      IF ls_row-agr_name IS INITIAL.
        lv_msg = |Item { ls_row-item_no }: AgrName is required|.
        raise_business_error( lv_msg ).
      ENDIF.
      IF ls_row-agr_type <> 'C' AND ls_row-agr_type <> 'S'.
        lv_msg = |Item { ls_row-item_no }: AgrType must be C (composite) or S (single)|.
        raise_business_error( lv_msg ).
      ENDIF.
      check_date( iv_date = ls_row-valid_from iv_field = `ValidFrom` iv_item_no = ls_row-item_no ).
      check_date( iv_date = ls_row-valid_to   iv_field = `ValidTo`   iv_item_no = ls_row-item_no ).
      IF ls_row-valid_to < ls_row-valid_from.
        lv_msg = |Item { ls_row-item_no }: ValidTo is before ValidFrom|.
        raise_business_error( lv_msg ).
      ENDIF.
      INSERT ls_row-agr_name INTO TABLE lt_names.
      IF sy-subrc <> 0.
        lv_msg = |Role { ls_row-agr_name } is sent more than once|.
        raise_business_error( lv_msg ).
      ENDIF.
      INSERT ls_row-item_no INTO TABLE lt_itemnos.
      IF sy-subrc <> 0.
        lv_msg = |ItemNo { ls_row-item_no } is sent more than once|.
        raise_business_error( lv_msg ).
      ENDIF.

      APPEND ls_row TO lt_rows.
    ENDLOOP.

*   Save. Gateway commits at the end of the request (no COMMIT here,
*   so the call also works inside a $batch changeset).
    INSERT zarc_af_joiner FROM TABLE lt_rows ACCEPTING DUPLICATE KEYS.
    IF sy-dbcnt <> lines( lt_rows ).
      lv_msg = |Request { ls_deep-req_id } could not be saved (duplicate key)|.
      raise_business_error( lv_msg ).
    ENDIF.

*   Response: created request with its items
    READ TABLE lt_rows INTO ls_row INDEX 1.
    MOVE-CORRESPONDING ls_row TO ls_result.
    ls_result-items = lt_rows.

    copy_data_to_ref( EXPORTING is_data = ls_result
                      CHANGING  cr_data = er_deep_entity ).

  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
*----------------------------------------------------------------------*
*   POST /sap/opu/odata/sap/ZARC_AF_PROV_SRV/Provision?ReqId='REQ0001'
*   Triggered by React button "Approve Req ID".
*   Plain POST only - not inside $batch (the run commits and calls RFC).
*----------------------------------------------------------------------*
    DATA: lt_items  TYPE zcl_zarc_af_prov_mpc=>tt_joineritem,
          lv_req_id TYPE zarc_af_req_id,
          lv_case   TYPE zarc_af_status,
          lv_msg    TYPE bapi_msg,
          lv_rej    TYPE abap_bool.

    CASE iv_action_name.

      WHEN 'Provision'.
*       Parameters come with their ABAP field name (upper case)
        DATA(lt_parameter) = io_tech_request_context->get_parameters( ).
        READ TABLE lt_parameter INTO DATA(ls_parameter) WITH KEY name = 'REQ_ID'.
        IF sy-subrc <> 0 OR ls_parameter-value IS INITIAL.
          lv_msg = 'Parameter ReqId is missing'.
          raise_business_error( lv_msg ).
        ENDIF.
        lv_req_id = ls_parameter-value.

* >>> INTEGRATION POINT: provisioning function module
        CALL FUNCTION 'Z_ARC_AF_PROVISION'
          EXPORTING
            iv_req_id      = lv_req_id
          IMPORTING
            ev_case_status = lv_case
            ev_message     = lv_msg
            ev_rejected    = lv_rej
          TABLES
            et_items       = lt_items.

*       Rejected = nothing processed or recorded
*       (request locked by another run / not found / already completed)
        IF lv_rej = abap_true.
          raise_business_error( lv_msg ).
        ENDIF.

*       All items of the request with CaseStatus/CaseMsg/ProvStatus/ProvMsg
        copy_data_to_ref( EXPORTING is_data = lt_items
                          CHANGING  cr_data = er_data ).

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~execute_action(
          EXPORTING
            iv_action_name          = iv_action_name
            it_parameter            = it_parameter
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_data                 = er_data ).

    ENDCASE.

  ENDMETHOD.


  METHOD joineritemset_get_entityset.
*----------------------------------------------------------------------*
*   GET .../JoinerItemSet?$filter=ReqId eq 'REQ0001'
*   GET .../RequestSet('REQ0001')/Items   and   $expand=Items
*----------------------------------------------------------------------*
    DATA: lr_req_id TYPE RANGE OF zarc_af_req_id,
          lv_req_id TYPE zarc_af_req_id,
          lv_msg    TYPE bapi_msg.

*   Navigation from Request
    IF io_tech_request_context->get_source_entity_type_name( ) = 'Request'.
      DATA(lt_source_keys) = io_tech_request_context->get_source_keys( ).
      READ TABLE lt_source_keys INTO DATA(ls_source_key) WITH KEY name = 'REQ_ID'.
      IF sy-subrc = 0.
        lv_req_id = ls_source_key-value.
      ENDIF.
      SELECT * FROM zarc_af_joiner
        WHERE req_id = @lv_req_id
        ORDER BY item_no
        INTO TABLE @et_entityset.
      RETURN.
    ENDIF.

*   Direct access - filter on ReqId required
    DATA(lt_filter) = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    READ TABLE lt_filter INTO DATA(ls_filter) WITH KEY property = 'REQ_ID'.
    IF sy-subrc <> 0.
      lv_msg = 'Filter on ReqId is required'.
      raise_business_error( lv_msg ).
    ENDIF.

    LOOP AT ls_filter-select_options INTO DATA(ls_select_option).
      APPEND VALUE #( sign   = ls_select_option-sign
                      option = ls_select_option-option
                      low    = ls_select_option-low
                      high   = ls_select_option-high ) TO lr_req_id.
    ENDLOOP.

    SELECT * FROM zarc_af_joiner
      WHERE req_id IN @lr_req_id
      ORDER BY req_id, item_no
      INTO TABLE @et_entityset.

  ENDMETHOD.


  METHOD joineritemset_get_entity.
*----------------------------------------------------------------------*
*   GET .../JoinerItemSet(ReqId='REQ0001',ItemNo='0001')
*----------------------------------------------------------------------*
    DATA: lv_req_id  TYPE zarc_af_req_id,
          lv_item_no TYPE zarc_af_item_no,
          lv_msg     TYPE bapi_msg.

    DATA(lt_keys) = io_tech_request_context->get_keys( ).

    READ TABLE lt_keys INTO DATA(ls_key) WITH KEY name = 'REQ_ID'.
    IF sy-subrc = 0.
      lv_req_id = ls_key-value.
    ENDIF.
    READ TABLE lt_keys INTO ls_key WITH KEY name = 'ITEM_NO'.
    IF sy-subrc = 0.
      lv_item_no = ls_key-value.
    ENDIF.

    SELECT SINGLE * FROM zarc_af_joiner
      WHERE req_id  = @lv_req_id
        AND item_no = @lv_item_no
      INTO @er_entity.
    IF sy-subrc <> 0.
      lv_msg = |Item { lv_item_no } of request { lv_req_id } not found|.
      raise_business_error( lv_msg ).
    ENDIF.

  ENDMETHOD.


  METHOD requestset_get_entity.
*----------------------------------------------------------------------*
*   GET .../RequestSet('REQ0001')   (header = first item)
*----------------------------------------------------------------------*
    DATA: lv_req_id TYPE zarc_af_req_id,
          ls_row    TYPE zarc_af_joiner,
          lv_msg    TYPE bapi_msg.

    DATA(lt_keys) = io_tech_request_context->get_keys( ).
    READ TABLE lt_keys INTO DATA(ls_key) WITH KEY name = 'REQ_ID'.
    IF sy-subrc = 0.
      lv_req_id = ls_key-value.
    ENDIF.

    SELECT * FROM zarc_af_joiner
      WHERE req_id = @lv_req_id
      ORDER BY item_no
      INTO @ls_row
      UP TO 1 ROWS.
    ENDSELECT.
    IF sy-subrc <> 0.
      lv_msg = |Request { lv_req_id } not found|.
      raise_business_error( lv_msg ).
    ENDIF.

    MOVE-CORRESPONDING ls_row TO er_entity.

  ENDMETHOD.


  METHOD check_date.

    DATA lv_msg TYPE bapi_msg.

    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING
        date                      = iv_date
      EXCEPTIONS
        plausibility_check_failed = 1
        OTHERS                    = 2.
    IF sy-subrc <> 0 AND iv_date <> '99991231'.
      lv_msg = |Item { iv_item_no }: { iv_field } { iv_date } is not a valid date (format YYYYMMDD)|.
      raise_business_error( lv_msg ).
    ENDIF.

  ENDMETHOD.


  METHOD raise_business_error.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        textid  = /iwbep/cx_mgw_busi_exception=>business_error
        message = iv_message.

  ENDMETHOD.

ENDCLASS.
