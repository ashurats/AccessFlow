CLASS zcl_zarc_af_prov_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_zarc_af_prov_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.

  PROTECTED SECTION.

    METHODS joineritemset_get_entityset REDEFINITION.
    METHODS joineritemset_get_entity REDEFINITION.

  PRIVATE SECTION.

    METHODS raise_business_error
      IMPORTING
        iv_message TYPE bapi_msg
      RAISING
        /iwbep/cx_mgw_busi_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_dpc_ext IMPLEMENTATION.


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
*   Status view, and the read after an HTTP timeout on Provision.
*----------------------------------------------------------------------*
    DATA: lr_req_id TYPE RANGE OF zarc_af_req_id,
          lv_msg    TYPE bapi_msg.

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


  METHOD raise_business_error.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        textid  = /iwbep/cx_mgw_busi_exception=>business_error
        message = iv_message.

  ENDMETHOD.

ENDCLASS.
