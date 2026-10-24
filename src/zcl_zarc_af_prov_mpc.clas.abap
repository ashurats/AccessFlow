CLASS zcl_zarc_af_prov_mpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_model
  CREATE PUBLIC.

  PUBLIC SECTION.

*   Function import Provision - input parameters
    TYPES:
      BEGIN OF ts_provision,
        req_id TYPE c LENGTH 20,
      END OF ts_provision.

*   Entity type JoinerItem = table ZARC_AF_JOINER
    TYPES ts_joineritem TYPE zarc_af_joiner.
    TYPES tt_joineritem TYPE STANDARD TABLE OF ts_joineritem WITH DEFAULT KEY.

    CONSTANTS gc_joineritem TYPE /iwbep/if_mgw_med_odata_types=>ty_e_med_entity_name VALUE 'JoinerItem' ##NO_TEXT.

    METHODS define REDEFINITION.
    METHODS get_last_modified REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.

    METHODS define_joineritem
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS define_actions
      RAISING
        /iwbep/cx_mgw_med_exception.

    METHODS add_property
      IMPORTING
        io_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ
        iv_name        TYPE /iwbep/med_external_name
        iv_abap_field  TYPE fieldname
        iv_length      TYPE i
        iv_key         TYPE abap_bool DEFAULT abap_false
        iv_filterable  TYPE abap_bool DEFAULT abap_false
      RAISING
        /iwbep/cx_mgw_med_exception.

ENDCLASS.



CLASS zcl_zarc_af_prov_mpc IMPLEMENTATION.


  METHOD define.

    model->set_schema_namespace( 'ZARC_AF_PROV_SRV' ).

    define_joineritem( ).
    define_actions( ).

  ENDMETHOD.


  METHOD define_joineritem.
*----------------------------------------------------------------------*
*   Entity type JoinerItem / entity set JoinerItemSet
*----------------------------------------------------------------------*
    DATA: lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
          lo_entity_set  TYPE REF TO /iwbep/if_mgw_odata_entity_set,
          lo_property    TYPE REF TO /iwbep/if_mgw_odata_property.

    lo_entity_type = model->create_entity_type( iv_entity_type_name = 'JoinerItem'
                                                iv_def_entity_set   = abap_false ).

*   Keys
    add_property( io_entity_type = lo_entity_type iv_name = 'ReqId'         iv_abap_field = 'REQ_ID'        iv_length = 20  iv_key = abap_true iv_filterable = abap_true ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ItemNo'        iv_abap_field = 'ITEM_NO'       iv_length = 4   iv_key = abap_true ).

*   Request data (written by React)
    add_property( io_entity_type = lo_entity_type iv_name = 'FirstName'     iv_abap_field = 'FIRST_NAME'    iv_length = 40 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'LastName'      iv_abap_field = 'LAST_NAME'     iv_length = 40 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Pernr'         iv_abap_field = 'PERNR'         iv_length = 8 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Email'         iv_abap_field = 'EMAIL'         iv_length = 241 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'SapUser'       iv_abap_field = 'SAP_USER'      iv_length = 12 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Department'    iv_abap_field = 'DEPARTMENT'    iv_length = 8 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Bukrs'         iv_abap_field = 'BUKRS'         iv_length = 4 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'TargetSys'     iv_abap_field = 'TARGET_SYS'    iv_length = 10 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'BusRole'       iv_abap_field = 'BUS_ROLE'      iv_length = 30 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ValidFrom'     iv_abap_field = 'VALID_FROM'    iv_length = 8 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ValidTo'       iv_abap_field = 'VALID_TO'      iv_length = 8 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Justification' iv_abap_field = 'JUSTIFICATION' iv_length = 255 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'CreatedAt'     iv_abap_field = 'CREATED_AT'    iv_length = 32 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'CreatedBy'     iv_abap_field = 'CREATED_BY'    iv_length = 12 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ChangedAt'     iv_abap_field = 'CHANGED_AT'    iv_length = 32 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ChangedBy'     iv_abap_field = 'CHANGED_BY'    iv_length = 12 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'Usertimezone'  iv_abap_field = 'USERTIMEZONE'  iv_length = 6 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'AgrName'       iv_abap_field = 'AGR_NAME'      iv_length = 30 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'AgrType'       iv_abap_field = 'AGR_TYPE'      iv_length = 1 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'MapVersion'    iv_abap_field = 'MAP_VERSION'   iv_length = 20 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ReqStatus'     iv_abap_field = 'REQ_STATUS'    iv_length = 20 ).

*   Provisioning result (written by ABAP)
    add_property( io_entity_type = lo_entity_type iv_name = 'CaseStatus'    iv_abap_field = 'CASE_STATUS'   iv_length = 20 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'CaseMsg'       iv_abap_field = 'CASE_MSG'      iv_length = 220 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ProvStatus'    iv_abap_field = 'PROV_STATUS'   iv_length = 20 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'ProvMsg'       iv_abap_field = 'PROV_MSG'      iv_length = 220 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'RunId'         iv_abap_field = 'RUN_ID'        iv_length = 32 ).
    add_property( io_entity_type = lo_entity_type iv_name = 'RetryCnt'      iv_abap_field = 'RETRY_CNT'     iv_length = 3 ).

*   PROV_AT is TIMESTAMPL (DEC 21,7)
    lo_property = lo_entity_type->create_property( iv_property_name  = 'ProvAt'
                                                   iv_abap_fieldname = 'PROV_AT' ).
    lo_property->set_type_edm_decimal( ).
    lo_property->set_precison( iv_precision = 7 ).
    lo_property->set_maxlength( iv_max_length = 21 ).
    lo_property->set_creatable( abap_false ).
    lo_property->set_updatable( abap_false ).
    lo_property->set_sortable( abap_false ).
    lo_property->set_nullable( abap_false ).
    lo_property->set_filterable( abap_false ).

    lo_entity_type->bind_structure( iv_structure_name   = 'ZCL_ZARC_AF_PROV_MPC=>TS_JOINERITEM'
                                    iv_bind_conversions = abap_false ).

    lo_entity_set = lo_entity_type->create_entity_set( 'JoinerItemSet' ).
    lo_entity_set->set_creatable( abap_false ).
    lo_entity_set->set_updatable( abap_false ).
    lo_entity_set->set_deletable( abap_false ).
    lo_entity_set->set_pageable( abap_false ).
    lo_entity_set->set_addressable( abap_true ).
    lo_entity_set->set_has_ftxt_search( abap_false ).
    lo_entity_set->set_subscribable( abap_false ).

  ENDMETHOD.


  METHOD define_actions.
*----------------------------------------------------------------------*
*   Function import Provision (POST, returns JoinerItemSet, 0..n)
*----------------------------------------------------------------------*
    DATA: lo_action    TYPE REF TO /iwbep/if_mgw_odata_action,
          lo_parameter TYPE REF TO /iwbep/if_mgw_odata_parameter.

    lo_action = model->create_action( 'Provision' ).
    lo_action->set_return_entity_type( 'JoinerItem' ).
    lo_action->set_return_entity_set( 'JoinerItemSet' ).
    lo_action->set_http_method( 'POST' ).
    lo_action->set_return_multiplicity( 'N' ).

    lo_parameter = lo_action->create_input_parameter( iv_parameter_name = 'ReqId'
                                                      iv_abap_fieldname = 'REQ_ID' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( iv_max_length = 20 ).

    lo_action->bind_input_structure( iv_structure_name   = 'ZCL_ZARC_AF_PROV_MPC=>TS_PROVISION'
                                     iv_bind_conversions = abap_false ).

  ENDMETHOD.


  METHOD add_property.

    DATA lo_property TYPE REF TO /iwbep/if_mgw_odata_property.

    lo_property = io_entity_type->create_property( iv_property_name  = iv_name
                                                   iv_abap_fieldname = iv_abap_field ).
    IF iv_key = abap_true.
      lo_property->set_is_key( ).
    ENDIF.
    lo_property->set_type_edm_string( ).
    lo_property->set_maxlength( iv_max_length = iv_length ).
    lo_property->set_creatable( abap_false ).
    lo_property->set_updatable( abap_false ).
    lo_property->set_sortable( abap_false ).
    lo_property->set_nullable( abap_false ).
    lo_property->set_filterable( iv_filterable ).

  ENDMETHOD.


  METHOD get_last_modified.

*   Change this value whenever DEFINE changes, so the metadata cache refreshes
    CONSTANTS lc_gen_date_time TYPE timestamp VALUE '20261024030000'.

    rv_last_modified = super->get_last_modified( ).
    IF rv_last_modified LT lc_gen_date_time.
      rv_last_modified = lc_gen_date_time.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
