CLASS zcl_zarc_af_prov_mpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_model
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ts_joineritem TYPE zarc_af_joiner.
    TYPES tt_joineritem TYPE STANDARD TABLE OF ts_joineritem WITH DEFAULT KEY.

    TYPES: BEGIN OF ts_provision,
             req_id TYPE zarc_af_req_id,
           END OF ts_provision.

    CONSTANTS gc_joineritem     TYPE /iwbep/if_mgw_med_odata_types=>ty_e_med_entity_name VALUE 'JoinerItem' ##NO_TEXT.
    CONSTANTS gc_joineritem_set TYPE /iwbep/med_external_name VALUE 'JoinerItemSet' ##NO_TEXT.
    CONSTANTS gc_provision      TYPE /iwbep/med_external_name VALUE 'Provision' ##NO_TEXT.

    METHODS define REDEFINITION.
    METHODS get_last_modified REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.

    METHODS define_joineritem
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS define_provision
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS add_string_property
      IMPORTING
        io_entity TYPE REF TO /iwbep/if_mgw_odata_entity_typ
        iv_name   TYPE /iwbep/med_external_name
        iv_field  TYPE fieldname
        iv_length TYPE i
        iv_key    TYPE abap_bool DEFAULT abap_false
        iv_filter TYPE abap_bool DEFAULT abap_false
      RAISING
        /iwbep/cx_mgw_med_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_mpc IMPLEMENTATION.


  METHOD define.

    model->set_schema_namespace( 'ZARC_AF_PROV_SRV' ).

    define_joineritem( ).
    define_provision( ).

  ENDMETHOD.


  METHOD define_joineritem.

    DATA: lo_entity TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
          lo_prop   TYPE REF TO /iwbep/if_mgw_odata_property,
          lo_set    TYPE REF TO /iwbep/if_mgw_odata_entity_set.

    lo_entity = model->create_entity_type( iv_entity_type_name = gc_joineritem
                                           iv_def_entity_set   = abap_false ).

*   Keys
    add_string_property( io_entity = lo_entity iv_name = 'ReqId'         iv_field = 'REQ_ID'        iv_length = 20  iv_key = abap_true iv_filter = abap_true ).
    add_string_property( io_entity = lo_entity iv_name = 'ItemNo'        iv_field = 'ITEM_NO'       iv_length = 4   iv_key = abap_true ).

*   Request data (written by React)
    add_string_property( io_entity = lo_entity iv_name = 'FirstName'     iv_field = 'FIRST_NAME'    iv_length = 40 ).
    add_string_property( io_entity = lo_entity iv_name = 'LastName'      iv_field = 'LAST_NAME'     iv_length = 40 ).
    add_string_property( io_entity = lo_entity iv_name = 'Pernr'         iv_field = 'PERNR'         iv_length = 8 ).
    add_string_property( io_entity = lo_entity iv_name = 'Email'         iv_field = 'EMAIL'         iv_length = 241 ).
    add_string_property( io_entity = lo_entity iv_name = 'SapUser'       iv_field = 'SAP_USER'      iv_length = 12 ).
    add_string_property( io_entity = lo_entity iv_name = 'Department'    iv_field = 'DEPARTMENT'    iv_length = 8 ).
    add_string_property( io_entity = lo_entity iv_name = 'Bukrs'         iv_field = 'BUKRS'         iv_length = 4 ).
    add_string_property( io_entity = lo_entity iv_name = 'TargetSys'     iv_field = 'TARGET_SYS'    iv_length = 10 ).
    add_string_property( io_entity = lo_entity iv_name = 'BusRole'       iv_field = 'BUS_ROLE'      iv_length = 30 ).
    add_string_property( io_entity = lo_entity iv_name = 'ValidFrom'     iv_field = 'VALID_FROM'    iv_length = 8 ).
    add_string_property( io_entity = lo_entity iv_name = 'ValidTo'       iv_field = 'VALID_TO'      iv_length = 8 ).
    add_string_property( io_entity = lo_entity iv_name = 'Justification' iv_field = 'JUSTIFICATION' iv_length = 255 ).
    add_string_property( io_entity = lo_entity iv_name = 'CreatedAt'     iv_field = 'CREATED_AT'    iv_length = 32 ).
    add_string_property( io_entity = lo_entity iv_name = 'CreatedBy'     iv_field = 'CREATED_BY'    iv_length = 12 ).
    add_string_property( io_entity = lo_entity iv_name = 'ChangedAt'     iv_field = 'CHANGED_AT'    iv_length = 32 ).
    add_string_property( io_entity = lo_entity iv_name = 'ChangedBy'     iv_field = 'CHANGED_BY'    iv_length = 12 ).
    add_string_property( io_entity = lo_entity iv_name = 'Usertimezone'  iv_field = 'USERTIMEZONE'  iv_length = 6 ).
    add_string_property( io_entity = lo_entity iv_name = 'AgrName'       iv_field = 'AGR_NAME'      iv_length = 30 ).
    add_string_property( io_entity = lo_entity iv_name = 'AgrType'       iv_field = 'AGR_TYPE'      iv_length = 1 ).
    add_string_property( io_entity = lo_entity iv_name = 'MapVersion'    iv_field = 'MAP_VERSION'   iv_length = 20 ).
    add_string_property( io_entity = lo_entity iv_name = 'ReqStatus'     iv_field = 'REQ_STATUS'    iv_length = 20 ).

*   Provisioning result (written by ABAP)
    add_string_property( io_entity = lo_entity iv_name = 'CaseStatus'    iv_field = 'CASE_STATUS'   iv_length = 20 ).
    add_string_property( io_entity = lo_entity iv_name = 'CaseMsg'       iv_field = 'CASE_MSG'      iv_length = 220 ).
    add_string_property( io_entity = lo_entity iv_name = 'ProvStatus'    iv_field = 'PROV_STATUS'   iv_length = 20 ).
    add_string_property( io_entity = lo_entity iv_name = 'ProvMsg'       iv_field = 'PROV_MSG'      iv_length = 220 ).
    add_string_property( io_entity = lo_entity iv_name = 'RunId'         iv_field = 'RUN_ID'        iv_length = 32 ).
    add_string_property( io_entity = lo_entity iv_name = 'RetryCnt'      iv_field = 'RETRY_CNT'     iv_length = 3 ).

*   PROV_AT: TIMESTAMPL (DEC 21,7) exposed as decimal
    lo_prop = lo_entity->create_property( iv_property_name  = 'ProvAt'
                                          iv_abap_fieldname = 'PROV_AT' ).
    lo_prop->set_type_edm_decimal( ).
    lo_prop->set_precison( iv_precision = 7 ).
    lo_prop->set_maxlength( iv_max_length = 21 ).
    lo_prop->set_creatable( abap_false ).
    lo_prop->set_updatable( abap_false ).
    lo_prop->set_sortable( abap_false ).
    lo_prop->set_filterable( abap_false ).

    lo_entity->bind_structure( iv_structure_name   = 'ZARC_AF_JOINER'
                               iv_bind_conversions = abap_false ).

    lo_set = lo_entity->create_entity_set( gc_joineritem_set ).
    lo_set->set_creatable( abap_false ).
    lo_set->set_updatable( abap_false ).
    lo_set->set_deletable( abap_false ).
    lo_set->set_pageable( abap_false ).
    lo_set->set_addressable( abap_true ).
    lo_set->set_has_ftxt_search( abap_false ).
    lo_set->set_subscribable( abap_false ).

  ENDMETHOD.


  METHOD define_provision.

    DATA: lo_action TYPE REF TO /iwbep/if_mgw_odata_action,
          lo_param  TYPE REF TO /iwbep/if_mgw_odata_parameter.

    lo_action = model->create_action( gc_provision ).
    lo_action->set_return_entity_type( gc_joineritem ).
    lo_action->set_return_entity_set( gc_joineritem_set ).
    lo_action->set_http_method( 'POST' ).
    lo_action->set_return_multiplicity( 'N' ).

    lo_param = lo_action->create_input_parameter( iv_parameter_name = 'ReqId'
                                                  iv_abap_fieldname = 'REQ_ID' ).
    lo_param->set_type_edm_string( ).
    lo_param->set_maxlength( iv_max_length = 20 ).

    lo_action->bind_input_structure( iv_structure_name   = 'ZCL_ZARC_AF_PROV_MPC=>TS_PROVISION'
                                     iv_bind_conversions = abap_false ).

  ENDMETHOD.


  METHOD add_string_property.

    DATA lo_prop TYPE REF TO /iwbep/if_mgw_odata_property.

    lo_prop = io_entity->create_property( iv_property_name  = iv_name
                                          iv_abap_fieldname = iv_field ).
    IF iv_key = abap_true.
      lo_prop->set_is_key( ).
    ENDIF.
    lo_prop->set_type_edm_string( ).
    lo_prop->set_maxlength( iv_max_length = iv_length ).
    lo_prop->set_creatable( abap_false ).
    lo_prop->set_updatable( abap_false ).
    lo_prop->set_sortable( abap_false ).
    lo_prop->set_nullable( abap_false ).
    lo_prop->set_filterable( iv_filter ).

  ENDMETHOD.


  METHOD get_last_modified.

*   Bump this timestamp whenever DEFINE changes, so the metadata cache refreshes
    CONSTANTS lc_gen_date_time TYPE timestamp VALUE '20261023200000'.

    rv_last_modified = super->get_last_modified( ).
    IF rv_last_modified LT lc_gen_date_time.
      rv_last_modified = lc_gen_date_time.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
