class ZCL_PROXY definition
  public
  create public .

public section.

  interfaces ZIF_YOUR_PROCESS .
protected section.
private section.
ENDCLASS.


class ZCL_PROXY implementation.


  METHOD ZIF_YOUR_PROCESS~YOUR_PROCESS.
*** **** INSERT IMPLEMENTATION HERE **** ***
*"----------------------------------------------------------
* 通用 AIF 入站代理方法：只做转发，绝不写业务逻辑。
* 代理类会被 AIF 重新生成覆盖，业务必须放在处理类里。
*
* 替换点：
*   ZCL_PROCESS_CLASS              → 你的处理类
*   Z_YOUR_BAL_OBJECT / Z_YOUR_BAL_SUBOBJ → 你的应用日志对象（必须与 /AIF/CUST 登记一致）
*----------------------------------------------------------  *

* Main process
    ZCL_PROCESS_CLASS=>execute_async_ws( iv_input    = input
                                          iv_bal_object    = 'Z_YOUR_BAL_OBJECT'
                                          iv_bal_subobject = 'Z_YOUR_BAL_SUBOBJ' ).

  ENDMETHOD.
ENDCLASS.
