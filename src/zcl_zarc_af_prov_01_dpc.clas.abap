CLASS zcl_zarc_af_prov_01_dpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_data
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS /iwbep/if_mgw_appl_srv_runtime~get_entityset REDEFINITION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~get_entity REDEFINITION.

  PROTECTED SECTION.

    METHODS joineritemset_get_entityset
      IMPORTING
        !iv_entity_name           TYPE string
        !iv_entity_set_name       TYPE string
        !iv_source_name           TYPE string
        !it_filter_select_options TYPE /iwbep/t_mgw_select_option
        !is_paging                TYPE /iwbep/s_mgw_paging
        !it_key_tab               TYPE /iwbep/t_mgw_name_value_pair
        !it_navigation_path       TYPE /iwbep/t_mgw_navigation_path
        !it_order                 TYPE /iwbep/t_mgw_sorting_order
        !iv_filter_string         TYPE string
        !iv_search_string         TYPE string
        !io_tech_request_context  TYPE REF TO /iwbep/if_mgw_req_entityset OPTIONAL
      EXPORTING
        !et_entityset             TYPE zcl_zarc_af_prov_01_mpc=>tt_joineritem
        !es_response_context      TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_context
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

    METHODS joineritemset_get_entity
      IMPORTING
        !iv_entity_name          TYPE string
        !iv_entity_set_name      TYPE string
        !iv_source_name          TYPE string
        !it_key_tab              TYPE /iwbep/t_mgw_name_value_pair
        !it_navigation_path      TYPE /iwbep/t_mgw_navigation_path
        !io_tech_request_context TYPE REF TO /iwbep/if_mgw_req_entity OPTIONAL
      EXPORTING
        !er_entity               TYPE zcl_zarc_af_prov_01_mpc=>ts_joineritem
        !es_response_context     TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_entity_cntxt
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

    METHODS requestset_get_entity
      IMPORTING
        !iv_entity_name          TYPE string
        !iv_entity_set_name      TYPE string
        !iv_source_name          TYPE string
        !it_key_tab              TYPE /iwbep/t_mgw_name_value_pair
        !it_navigation_path      TYPE /iwbep/t_mgw_navigation_path
        !io_tech_request_context TYPE REF TO /iwbep/if_mgw_req_entity OPTIONAL
      EXPORTING
        !er_entity               TYPE zcl_zarc_af_prov_01_mpc=>ts_request
        !es_response_context     TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_entity_cntxt
      RAISING
        /iwbep/cx_mgw_busi_exception
        /iwbep/cx_mgw_tech_exception.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_zarc_af_prov_01_dpc IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_entityset.

    DATA: lt_joineritem     TYPE zcl_zarc_af_prov_01_mpc=>tt_joineritem,
          lv_entityset_name TYPE string.

    lv_entityset_name = io_tech_request_context->get_entity_set_name( ).

    CASE lv_entityset_name.

      WHEN 'JoinerItemSet'.
        joineritemset_get_entityset(
          EXPORTING
            iv_entity_name           = iv_entity_name
            iv_entity_set_name       = iv_entity_set_name
            iv_source_name           = iv_source_name
            it_filter_select_options = it_filter_select_options
            is_paging                = is_paging
            it_key_tab               = it_key_tab
            it_navigation_path       = it_navigation_path
            it_order                 = it_order
            iv_filter_string         = iv_filter_string
            iv_search_string         = iv_search_string
            io_tech_request_context  = io_tech_request_context
          IMPORTING
            et_entityset             = lt_joineritem
            es_response_context      = es_response_context ).

        copy_data_to_ref( EXPORTING is_data = lt_joineritem
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


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_entity.

    DATA: ls_joineritem     TYPE zcl_zarc_af_prov_01_mpc=>ts_joineritem,
          ls_request        TYPE zcl_zarc_af_prov_01_mpc=>ts_request,
          lv_entityset_name TYPE string.

    lv_entityset_name = io_tech_request_context->get_entity_set_name( ).

    CASE lv_entityset_name.

      WHEN 'JoinerItemSet'.
        joineritemset_get_entity(
          EXPORTING
            iv_entity_name          = iv_entity_name
            iv_entity_set_name      = iv_entity_set_name
            iv_source_name          = iv_source_name
            it_key_tab              = it_key_tab
            it_navigation_path      = it_navigation_path
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_entity               = ls_joineritem
            es_response_context     = es_response_context ).

        IF ls_joineritem IS NOT INITIAL.
          copy_data_to_ref( EXPORTING is_data = ls_joineritem
                            CHANGING  cr_data = er_entity ).
        ELSE.
          CLEAR er_entity.
        ENDIF.

      WHEN 'RequestSet'.
        requestset_get_entity(
          EXPORTING
            iv_entity_name          = iv_entity_name
            iv_entity_set_name      = iv_entity_set_name
            iv_source_name          = iv_source_name
            it_key_tab              = it_key_tab
            it_navigation_path      = it_navigation_path
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_entity               = ls_request
            es_response_context     = es_response_context ).

        IF ls_request IS NOT INITIAL.
          copy_data_to_ref( EXPORTING is_data = ls_request
                            CHANGING  cr_data = er_entity ).
        ELSE.
          CLEAR er_entity.
        ENDIF.

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~get_entity(
          EXPORTING
            iv_entity_name          = iv_entity_name
            iv_entity_set_name      = iv_entity_set_name
            iv_source_name          = iv_source_name
            it_key_tab              = it_key_tab
            it_navigation_path      = it_navigation_path
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_entity               = er_entity
            es_response_context     = es_response_context ).

    ENDCASE.

  ENDMETHOD.


  METHOD joineritemset_get_entityset.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_not_impl_exc
      EXPORTING
        textid = /iwbep/cx_mgw_not_impl_exc=>method_not_implemented
        method = 'JOINERITEMSET_GET_ENTITYSET'.

  ENDMETHOD.


  METHOD joineritemset_get_entity.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_not_impl_exc
      EXPORTING
        textid = /iwbep/cx_mgw_not_impl_exc=>method_not_implemented
        method = 'JOINERITEMSET_GET_ENTITY'.

  ENDMETHOD.


  METHOD requestset_get_entity.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_not_impl_exc
      EXPORTING
        textid = /iwbep/cx_mgw_not_impl_exc=>method_not_implemented
        method = 'REQUESTSET_GET_ENTITY'.

  ENDMETHOD.

ENDCLASS.
