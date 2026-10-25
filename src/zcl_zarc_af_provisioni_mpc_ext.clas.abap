CLASS zcl_zarc_af_provisioni_mpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_zarc_af_provisioni_mpc
  CREATE PUBLIC.

  PUBLIC SECTION.

*   Inbound deep insert: all fields as string, converted in DPC_EXT
*   (component names = ABAP field names of the OData properties)
    TYPES:
      BEGIN OF ts_item_in,
        item_no    TYPE string,
        bus_role   TYPE string,
        agr_name   TYPE string,
        agr_type   TYPE string,
        valid_from TYPE string,
        valid_to   TYPE string,
      END OF ts_item_in.
    TYPES tt_item_in TYPE STANDARD TABLE OF ts_item_in WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ts_request_in,
        req_id        TYPE string,
        first_name    TYPE string,
        last_name     TYPE string,
        pernr         TYPE string,
        email         TYPE string,
        sap_user      TYPE string,
        department    TYPE string,
        bukrs         TYPE string,
        target_sys    TYPE string,
        justification TYPE string,
        created_at    TYPE string,
        created_by    TYPE string,
        changed_at    TYPE string,
        changed_by    TYPE string,
        usertimezone  TYPE string,
        map_version   TYPE string,
        req_status    TYPE string,
        items         TYPE tt_item_in,
      END OF ts_request_in.

*   Outbound deep response: Request + Items (ABAP name ITEMS)
    TYPES BEGIN OF ts_request_deep.
    INCLUDE TYPE zcl_zarc_af_provisioni_mpc=>ts_request.
    TYPES items TYPE zcl_zarc_af_provisioni_mpc=>tt_joineritem.
    TYPES END OF ts_request_deep.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_zarc_af_provisioni_mpc_ext IMPLEMENTATION.

ENDCLASS.
