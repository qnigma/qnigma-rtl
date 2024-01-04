package color_pkg;

  task color_reset          (); $display("\x1b[0m ");endtask
  task color_black          (); $write("\x1b[30m");  endtask
  task color_red            (); $write("\x1b[31m");  endtask
  task color_green          (); $write("\x1b[32m");  endtask
  task color_yellow         (); $write("\x1b[33m");  endtask
  task color_blue           (); $write("\x1b[34m");  endtask
  task color_magenta        (); $write("\x1b[35m");  endtask
  task color_cyan           (); $write("\x1b[36m");  endtask
  task color_white          (); $write("\x1b[37m");  endtask
  task color_bright_black   (); $write("\x1b[90m");  endtask
  task color_bright_red     (); $write("\x1b[91m");  endtask
  task color_bright_green   (); $write("\x1b[92m");  endtask
  task color_bright_yellow  (); $write("\x1b[93m");  endtask
  task color_bright_blue    (); $write("\x1b[94m");  endtask
  task color_bright_magenta (); $write("\x1b[95m");  endtask
  task color_bright_cyan    (); $write("\x1b[96m");  endtask
  task color_bright_white   (); $write("\x1b[97m");  endtask
  
  task display_pass   (); 
      color_bright_green();
      $write("[PASS]");
      color_reset();
  endtask
  
  task display_fail   (); 
      color_bright_red();
      $write("[FAIL]");
      color_reset();
  endtask

endpackage