CLASS zcl_zarc_af_prov_dpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_data
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS /iwbep/if_mgw_appl_srv_runtime~get_entityset REDEFINITION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.

    METHODS raise_business_error
      IMPORTING
        iv_message TYPE bapi_msg
      RAISING
        /iwbep/cx_mgw_busi_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_dpc IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_entityset.

    DATA: lt_entity TYPE zcl_zarc_af_prov_mpc=>tt_joineritem,
          lr_req    TYPE RANGE OF zarc_af_req_id,
          lv_msg    TYPE bapi_msg.

    CASE iv_entity_set_name.

      WHEN zcl_zarc_af_prov_mpc=>gc_joineritem_set.
*       GET .../JoinerItemSet?$filter=ReqId eq 'REQ0001'
        DATA(lo_filter) = io_tech_request_context->get_filter( ).
        DATA(lt_filter) = lo_filter->get_filter_select_options( ).

        READ TABLE lt_filter INTO DATA(ls_filter) WITH KEY property = 'REQ_ID'.
        IF sy-subrc <> 0.
          lv_msg = 'Filter on ReqId is required'.
          raise_business_error( lv_msg ).
        ENDIF.

        LOOP AT ls_filter-select_options INTO DATA(ls_so).
          APPEND VALUE #( sign   = ls_so-sign
                          option = ls_so-option
                          low    = ls_so-low
                          high   = ls_so-high ) TO lr_req.
        ENDLOOP.

        SELECT * FROM zarc_af_joiner
          WHERE req_id IN @lr_req
          ORDER BY req_id, item_no
          INTO TABLE @lt_entity.

        copy_data_to_ref( EXPORTING is_data = lt_entity
                          CHANGING  cr_data = er_entityset ).

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~get_entityset(
          EXPORTING
            iv_entity_name           = iv_entity_name
            iv_entity_set_name       = iv_entity_set_name
            iv_source_name           = iv_source_name
            it_filter_select_options = it_filter_select_options
            it_order                 = it_order
            is_paging                = is_paging
            it_navigation_path       = it_navigation_path
            it_key_tab               = it_key_tab
            iv_filter_string         = iv_filter_string
            iv_search_string         = iv_search_string
            io_tech_request_context  = io_tech_request_context
          IMPORTING
            er_entityset             = er_entityset
            es_response_context      = es_response_context ).

    ENDCASE.

  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.

    DATA: lt_items  TYPE zcl_zarc_af_prov_mpc=>tt_joineritem,
          lv_req_id TYPE zarc_af_req_id,
          lv_case   TYPE zarc_af_status,
          lv_msg    TYPE bapi_msg,
          lv_rej    TYPE abap_bool.

    CASE iv_action_name.

      WHEN zcl_zarc_af_prov_mpc=>gc_provision.
*       POST .../Provision?ReqId='REQ0001'  (plain POST, not inside $batch)
        DATA(lt_par) = io_tech_request_context->get_parameters( ).
        READ TABLE lt_par INTO DATA(ls_par) WITH KEY name = 'REQ_ID'.
        IF sy-subrc <> 0 OR ls_par-value IS INITIAL.
          lv_msg = 'Parameter ReqId is missing'.
          raise_business_error( lv_msg ).
        ENDIF.
        lv_req_id = ls_par-value.

        CALL FUNCTION 'Z_ARC_AF_PROVISION'
          EXPORTING
            iv_req_id      = lv_req_id
          IMPORTING
            ev_case_status = lv_case
            ev_message     = lv_msg
            ev_rejected    = lv_rej
          TABLES
            et_items       = lt_items.

*       Rejected = nothing processed or recorded (locked / not found / completed)
        IF lv_rej = abap_true.
          raise_business_error( lv_msg ).
        ENDIF.

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


  METHOD raise_business_error.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        textid  = /iwbep/cx_mgw_busi_exception=>business_error
        message = iv_message.

  ENDMETHOD.

ENDCLASS.
