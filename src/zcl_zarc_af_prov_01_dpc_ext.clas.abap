CLASS zcl_zarc_af_prov_01_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_zarc_af_prov_01_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS /iwbep/if_mgw_appl_srv_runtime~create_deep_entity REDEFINITION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.

  PROTECTED SECTION.

    METHODS check_subscription_authority REDEFINITION.
    METHODS joineritemset_get_entityset REDEFINITION.
    METHODS joineritemset_get_entity REDEFINITION.
    METHODS requestset_get_entity REDEFINITION.

  PRIVATE SECTION.

    METHODS raise_business_error
      IMPORTING
        iv_message TYPE bapi_msg
      RAISING
        /iwbep/cx_mgw_busi_exception.

    METHODS to_date
      IMPORTING
        iv_value       TYPE string
        iv_field       TYPE string
        iv_item_no     TYPE zarc_af_item_no
        iv_default     TYPE d
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        /iwbep/cx_mgw_busi_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_01_dpc_ext IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
*----------------------------------------------------------------------*
*   POST /sap/opu/odata/sap/ZARC_AF_PROV_SRV/RequestSet
*   React "Save": request header + Items (one per SAP role), not approved
*   -> one row per item in ZARC_AF_JOINER, header fields repeated
*----------------------------------------------------------------------*
    CONSTANTS lc_end TYPE d VALUE '99991231'.

    DATA: ls_in      TYPE zcl_zarc_af_prov_01_mpc_ext=>ts_request_in,
          ls_result  TYPE zcl_zarc_af_prov_01_mpc_ext=>ts_request_deep,
          lt_rows    TYPE zcl_zarc_af_prov_01_mpc=>tt_joineritem,
          ls_head    TYPE zarc_af_joiner,
          ls_row     TYPE zarc_af_joiner,
          lt_names   TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line,
          lt_itemnos TYPE SORTED TABLE OF zarc_af_item_no WITH UNIQUE KEY table_line,
          lv_item_no TYPE zarc_af_item_no,
          lv_in_no   TYPE string,
          lv_exists  TYPE abap_bool,
          lv_ts      TYPE timestampl,
          lv_msg     TYPE bapi_msg,
          lv_set     TYPE string.
    FIELD-SYMBOLS <ls_item_in> TYPE zcl_zarc_af_prov_01_mpc_ext=>ts_item_in.

*   Entity set: from the tech context (iv_entity_set_name can be empty)
    IF io_tech_request_context IS BOUND.
      lv_set = io_tech_request_context->get_entity_set_name( ).
    ENDIF.
    IF lv_set IS INITIAL.
      lv_set = iv_entity_set_name.
    ENDIF.

    IF lv_set <> 'RequestSet' AND iv_entity_name <> 'Request'.
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

*   JSON body -> string structure (no DATS/NUMC conversion by Gateway)
    io_data_provider->read_entry_data( IMPORTING es_data = ls_in ).

*   Header fields -> table structure
    MOVE-CORRESPONDING ls_in TO ls_head.
    ls_head-mandt      = sy-mandt.
    ls_head-req_id     = to_upper( condense( ls_in-req_id ) ).
    ls_head-sap_user   = to_upper( condense( ls_in-sap_user ) ).
    ls_head-target_sys = to_upper( condense( ls_in-target_sys ) ).
*   Save = not yet approved. Approval only via Approve button (Provision)
    CLEAR ls_head-req_status.

    IF ls_in-pernr IS NOT INITIAL AND condense( ls_in-pernr ) CN '0123456789'.
      lv_msg = |Pernr { ls_in-pernr } must be numeric|.
      raise_business_error( lv_msg ).
    ENDIF.
    IF ls_in-department IS NOT INITIAL AND condense( ls_in-department ) CN '0123456789'.
      lv_msg = |Department { ls_in-department } must be a numeric org. unit (or empty)|.
      raise_business_error( lv_msg ).
    ENDIF.

    GET TIME STAMP FIELD lv_ts.
    IF ls_head-created_by IS INITIAL.
      ls_head-created_by = sy-uname.
    ENDIF.
    IF ls_head-created_at IS INITIAL.
      ls_head-created_at = |{ lv_ts TIMESTAMP = ISO }|.
    ENDIF.

*   Header checks
    IF ls_head-req_id IS INITIAL.
      lv_msg = 'ReqId is required'.
      raise_business_error( lv_msg ).
    ENDIF.
    IF ls_head-sap_user IS INITIAL OR ls_head-target_sys IS INITIAL.
      lv_msg = 'SapUser and TargetSys are required'.
      raise_business_error( lv_msg ).
    ENDIF.
    IF ls_in-items IS INITIAL.
      lv_msg = 'At least one item (SAP role) is required in Items'.
      raise_business_error( lv_msg ).
    ENDIF.

    SELECT SINGLE @abap_true FROM zarc_af_joiner
      WHERE req_id = @ls_head-req_id
      INTO @lv_exists.
    IF lv_exists = abap_true.
      lv_msg = |Request { ls_head-req_id } already exists|.
      raise_business_error( lv_msg ).
    ENDIF.

*   One row per item
    LOOP AT ls_in-items ASSIGNING <ls_item_in>.
      lv_item_no = lv_item_no + 1.
      ls_row = ls_head.

*     ItemNo optional - numbered in Items order if empty
      lv_in_no = condense( <ls_item_in>-item_no ).
      IF lv_in_no IS INITIAL.
        ls_row-item_no = lv_item_no.
      ELSEIF lv_in_no CO '0123456789' AND strlen( lv_in_no ) <= 4.
        ls_row-item_no = lv_in_no.
      ELSE.
        lv_msg = |ItemNo { lv_in_no } must be numeric, max. 4 digits|.
        raise_business_error( lv_msg ).
      ENDIF.

      ls_row-bus_role = <ls_item_in>-bus_role.
      ls_row-agr_name = to_upper( condense( <ls_item_in>-agr_name ) ).
      ls_row-agr_type = to_upper( condense( <ls_item_in>-agr_type ) ).

*     End date optional in the UI -> open-ended
      ls_row-valid_to = to_date( iv_value   = <ls_item_in>-valid_to
                                 iv_field   = `ValidTo`
                                 iv_item_no = ls_row-item_no
                                 iv_default = lc_end ).
* >>> INTEGRATION POINT: rule for VALID_FROM when React sends none
      ls_row-valid_from = to_date( iv_value   = <ls_item_in>-valid_from
                                   iv_field   = `ValidFrom`
                                   iv_item_no = ls_row-item_no
                                   iv_default = sy-datum ).

*     Item checks
      IF ls_row-agr_name IS INITIAL.
        lv_msg = |Item { ls_row-item_no }: AgrName is required|.
        raise_business_error( lv_msg ).
      ENDIF.
      IF ls_row-agr_type <> 'C' AND ls_row-agr_type <> 'S'.
        lv_msg = |Item { ls_row-item_no }: AgrType must be C (composite) or S (single)|.
        raise_business_error( lv_msg ).
      ENDIF.
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
      lv_msg = |Request { ls_head-req_id } could not be saved (duplicate key)|.
      raise_business_error( lv_msg ).
    ENDIF.

*   Response: created request with its items
    MOVE-CORRESPONDING ls_head TO ls_result.
    ls_result-items = lt_rows.

    copy_data_to_ref( EXPORTING is_data = ls_result
                      CHANGING  cr_data = er_deep_entity ).

  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
*----------------------------------------------------------------------*
*   POST /sap/opu/odata/sap/ZARC_AF_PROV_SRV/Provision?ReqId='REQ0001'
*   React button "Approve": 1. approve the saved request
*                           2. start provisioning
*   Plain POST only - not inside $batch (the run commits and calls RFC).
*----------------------------------------------------------------------*
    CONSTANTS lc_approved TYPE zarc_af_req_status VALUE 'APPROVED'.

    DATA: lt_items  TYPE zcl_zarc_af_prov_01_mpc=>tt_joineritem,
          lv_req_id TYPE zarc_af_req_id,
          lv_case   TYPE zarc_af_status,
          lv_msg    TYPE bapi_msg,
          lv_rej    TYPE abap_bool,
          lv_exists TYPE abap_bool.

    CASE iv_action_name.

      WHEN 'Provision'.
*       Parameter by OData name (ABAP name differs between SEGW versions)
        READ TABLE it_parameter INTO DATA(ls_parameter) WITH KEY name = 'ReqId'.
        IF sy-subrc <> 0.
          READ TABLE it_parameter INTO ls_parameter WITH KEY name = 'REQ_ID'.
        ENDIF.
        IF ls_parameter-value IS INITIAL.
          lv_msg = 'Parameter ReqId is missing'.
          raise_business_error( lv_msg ).
        ENDIF.
        lv_req_id = to_upper( ls_parameter-value ).

*       1. Approve: saved request (REQ_STATUS empty) -> APPROVED
        SELECT SINGLE @abap_true FROM zarc_af_joiner
          WHERE req_id = @lv_req_id
          INTO @lv_exists.
        IF lv_exists = abap_false.
          lv_msg = |Request { lv_req_id } not found|.
          raise_business_error( lv_msg ).
        ENDIF.

        UPDATE zarc_af_joiner
           SET req_status = @lc_approved,
               changed_by = @sy-uname
         WHERE req_id     = @lv_req_id
           AND req_status <> @lc_approved.
        IF sy-subrc = 0.
          COMMIT WORK.
        ENDIF.

*       2. Provisioning
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


  METHOD check_subscription_authority.

*   Subscriptions are not used by this service
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_not_impl_exc
      EXPORTING
        textid = /iwbep/cx_mgw_not_impl_exc=>method_not_implemented
        method = 'CHECK_SUBSCRIPTION_AUTHORITY'.

  ENDMETHOD.


  METHOD to_date.
*----------------------------------------------------------------------*
*   Accepts YYYYMMDD or YYYY-MM-DD; empty -> iv_default
*----------------------------------------------------------------------*
    DATA: lv_value TYPE string,
          lv_msg   TYPE bapi_msg.

    lv_value = condense( iv_value ).
    REPLACE ALL OCCURRENCES OF `-` IN lv_value WITH ``.

    IF lv_value IS INITIAL OR lv_value = '00000000'.
      rv_date = iv_default.
      RETURN.
    ENDIF.

    IF strlen( lv_value ) <> 8 OR lv_value CN '0123456789'.
      lv_msg = |Item { iv_item_no }: { iv_field } { iv_value } is not a valid date (YYYYMMDD)|.
      raise_business_error( lv_msg ).
    ENDIF.

    rv_date = lv_value.
    IF rv_date = '99991231'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING
        date                      = rv_date
      EXCEPTIONS
        plausibility_check_failed = 1
        OTHERS                    = 2.
    IF sy-subrc <> 0.
      lv_msg = |Item { iv_item_no }: { iv_field } { iv_value } is not a valid date|.
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
