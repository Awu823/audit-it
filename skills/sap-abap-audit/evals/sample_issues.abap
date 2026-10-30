*&---------------------------------------------------------------------*
*& Report ZDEMO_AUDIT
*&---------------------------------------------------------------------*
REPORT zdemo_audit.

TABLES: ekko, ekpo.

DATA: lv_ebeln TYPE ebeln,
      lv_sum   TYPE netwr.

DATA lt_ekko TYPE TABLE OF ekko.

* TODO: 需要补充校验逻辑

SELECT * FROM ekko INTO TABLE @DATA(lt_all). " SELECT *

SELECT * FROM ekpo.
  " 缺少 INTO
ENDSELECT.

SELECT * FROM ekpo
  WHERE ebeln = @lv_ebeln.

LOOP AT lt_ekko INTO DATA(ls_ekko).
  MODIFY lt_ekko FROM ls_ekko INDEX 1.  " positioned write -> fires MODIFY_INSERT_IN_LOOP
  COMMIT WORK.
ENDLOOP.

DATA lt_buf TYPE TABLE OF ekpo.
SELECT * FROM ekpo INTO TABLE @lt_buf
  FOR ALL ENTRIES IN @lt_buf
  WHERE ebeln = @lt_buf-ebeln.

DATA(lv_txt) = 'x'.
CONCATENATE lv_ebeln lv_txt INTO lv_txt.

READ TABLE lt_ekko INTO DATA(ls_wa) INDEX 1.

PERFORM do_something.

DATA(lv_dyn) = 'SELECT * FROM ekko WHERE ebeln = ''' && lv_ebeln && ''''.

SELECT * FROM usr02 INTO TABLE @DATA(lt_user).

FORM do_something.
ENDFORM.
