`include "uvm_macros.svh"
import uvm_pkg::*;

//==================== DUT ====================
module mul(input [3:0] a,b, output [7:0] y);
  assign y = a * b;
endmodule

//==================== IF =====================
interface mul_if;
  logic [3:0] a;
  logic [3:0] b;
  logic [7:0] y;
endinterface

//==================== TRANSACTION =============
class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)
  rand bit [3:0] a;
  rand bit [3:0] b;
       bit [7:0] y;
  function new(string path="transaction"); super.new(path); endfunction
endclass

//==================== SEQUENCE ================
class generator extends uvm_sequence#(transaction);
  `uvm_object_utils(generator)
  transaction tr;
  function new(string path="generator"); super.new(path); endfunction
  virtual task body();
    repeat (15) begin
      tr = transaction::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize());
      `uvm_info("SEQ", $sformatf("a:%0d b:%0d y:%0d", tr.a, tr.b, tr.y), UVM_MEDIUM)
      finish_item(tr);
    end
  endtask
endclass

//==================== DRIVER ==================
class drv extends uvm_driver#(transaction);
  `uvm_component_utils(drv)
  transaction tr;
  virtual mul_if mif;
  function new(string path="drv", uvm_component parent=null); super.new(path,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif))
      `uvm_error("DRV","Unable to access Interface")
  endfunction
  virtual task run_phase(uvm_phase phase);
    tr = transaction::type_id::create("tr");
    forever begin
      seq_item_port.get_next_item(tr);
      mif.a <= tr.a; mif.b <= tr.b;
      `uvm_info("DRV", $sformatf("a:%0d b:%0d y:%0d", tr.a, tr.b, tr.y), UVM_NONE)
      seq_item_port.item_done();
      #20;
    end
  endtask
endclass

//==================== MONITOR =================
class mon extends uvm_monitor;
  `uvm_component_utils(mon)
  uvm_analysis_port#(transaction) send;
  transaction tr;
  virtual mul_if mif;
  function new(string inst="mon", uvm_component parent=null); super.new(inst,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr   = transaction::type_id::create("tr");
    send = new("send", this);
    if (!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif))
      `uvm_error("MON","Unable to access Interface")
  endfunction
  virtual task run_phase(uvm_phase phase);
    forever begin
      #20;
      tr.a = mif.a; tr.b = mif.b; tr.y = mif.y;
      `uvm_info("MON", $sformatf("a:%0d b:%0d y:%0d", tr.a, tr.b, tr.y), UVM_NONE)
      send.write(tr);
    end
  endtask
endclass

//==================== SCOREBOARD ==============
class sco extends uvm_scoreboard;
  `uvm_component_utils(sco)
  uvm_analysis_imp#(transaction,sco) recv;
  function new(string inst="sco", uvm_component parent=null); super.new(inst,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
  endfunction
  virtual function void write(transaction tr);
    if (tr.y == (tr.a * tr.b))
      `uvm_info("SCO", $sformatf("PASS a:%0d b:%0d y:%0d", tr.a, tr.b, tr.y), UVM_FULL)
    else
      `uvm_error("SCO", $sformatf("FAIL a:%0d b:%0d y:%0d", tr.a, tr.b, tr.y))
  endfunction
endclass

//==================== COVERAGE SUBSCRIBER =====
class cov extends uvm_subscriber#(transaction);
  `uvm_component_utils(cov)
  bit [3:0] cov_a, cov_b;
  covergroup cg;
    cp_a: coverpoint cov_a { bins all[] = {[0:15]}; }
    cp_b: coverpoint cov_b { bins all[] = {[0:15]}; }
    cross_ab: cross cp_a, cp_b;
  endgroup
  function new(string name="cov", uvm_component parent=null); super.new(name,parent); cg=new(); endfunction
  virtual function void write(transaction t);
    cov_a = t.a; cov_b = t.b; cg.sample();
  endfunction
  virtual function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Functional coverage = %0.2f%%", cg.get_inst_coverage()), UVM_NONE)
  endfunction
endclass

//==================== AGENT ===================
class agent extends uvm_agent;
  `uvm_component_utils(agent)
  drv d; mon m; uvm_sequencer#(transaction) seqr;
  function new(string inst="agent", uvm_component parent=null); super.new(inst,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    d = drv::type_id::create("d", this);
    m = mon::type_id::create("m", this);
    seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
  endfunction
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

//==================== ENV =====================
class env extends uvm_env;
  `uvm_component_utils(env)
  agent a; sco s; cov c;
  function new(string inst="env", uvm_component parent=null); super.new(inst,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a = agent::type_id::create("a", this);
    s = sco  ::type_id::create("s", this);
    c = cov  ::type_id::create("c", this);
  endfunction
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.m.send.connect(s.recv);
    a.m.send.connect(c.analysis_export); // monitor → coverage
  endfunction
endclass

//==================== TEST ====================
class test extends uvm_test;
  `uvm_component_utils(test)
  env e; generator gen;
  function new(string inst="test", uvm_component parent=null); super.new(inst,parent); endfunction
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e   = env      ::type_id::create("env", this);
    gen = generator::type_id::create("gen");
  endfunction
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    gen.start(e.a.seqr);
    #20;
    phase.drop_objection(this);
  endtask
endclass

//==================== TB TOP ==================
module tb;
  initial begin
    uvm_top.set_report_verbosity_level(UVM_LOW); // global threshold
  end

  mul_if mif();
  mul dut(.a(mif.a), .b(mif.b), .y(mif.y));

  initial begin
    uvm_config_db#(virtual mul_if)::set(null, "*", "mif", mif);
    run_test("test");
  end

  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
  end
endmodule