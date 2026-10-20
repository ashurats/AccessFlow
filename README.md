# ZARC_AF – AccessFlow business role model

Customizing tables for the AccessFlow business role model (workshop deck "Archon Access Flow", 16.10.2026, page 9):
a business function maps to one composite role and its single roles. The audit log keeps the derived role changes per request (deck pages 7 and 13).

Package: `ZARC_AF` · Format: abapGit · Master language: EN

## Objects

| Object | Type | Content |
|---|---|---|
| ZARC_AF_BROLE | Table, delivery class C | Business role (function) → composite role, target system, owner |
| ZARC_AF_ROLE_MAP | Table, delivery class C | Single roles per business role: `I` = contained in composite, `O` = additionally requestable, critical flag |
| ZARC_AF_AUDITLOG | Table, delivery class A | Derived role changes per request number: ADD / KEEP / REMOVE with validity |
| ZARC_AF_BUS_ROLE | Domain + data element | CHAR 30 |
| ZARC_AF_ROLE_TYPE | Domain + data element | CHAR 1, fixed values I / O |
| ZARC_AF_MODE | Domain + data element | CHAR 1, fixed values U / R |
| ZARC_AF_ACTION | Domain + data element | CHAR 6, fixed values ADD / KEEP / REMOVE |
| ZARC_AF_DESCRIPTION | Data element | CHAR 60 |
| ZARC_AF_TARGET_SYS | Data element | CHAR 10, `<SID>_<client>` |
| ZARC_AF_REQ_ID | Data element | CHAR 20, AccessFlow request number |
| ZARC_AF_ITEM_NO | Data element | NUMC 3 |
| ZARC_AF_SEED_ROLEMODEL | Report | Loads the EWM sample role model (DEV/QA only) |

## Import into SAP

1. Push this folder to GitHub (the repository root contains `.abapgit.xml` and `src/`).
2. In SAP, run transaction `ZABAPGIT` (or report `ZABAPGIT_STANDALONE`).
3. Choose **New Online**, enter the GitHub URL, and choose package `ZARC_AF` (create it if it doesn't exist) with a workbench transport.
4. Choose **Pull** and activate all objects.
   - Without GitHub access from SAP: download the repository as a ZIP and use **New Offline → Import ZIP**.

## After the import

1. **SM30 maintenance** – SE54 → Generate table maintenance dialog for `ZARC_AF_BROLE` and `ZARC_AF_ROLE_MAP`:
   - function group `ZARC_AF_ROLE_MAINT`, authorization group `ZARC`
   - maintenance type one step, standard recording routine (customizing transport)
2. **Table logging** is switched on for both customizing tables. Basis must include the client in profile parameter `rec/client`, otherwise SCU3 shows no changes.
3. **Sample data** – run `ZARC_AF_SEED_ROLEMODEL` in DEV/QA, with the EWM `<SID>_<client>` as target system.
4. **Not included** – the foreign key from `AGR_NAME` to `AGR_DEFINE`, because the roles live in the EWM system. The derivation checks the roles instead.
