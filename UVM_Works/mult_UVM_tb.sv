`include "uvm_macros.svh"
import uvm_pkg::*;
 




//*******************************************************************************************

//"transaction" normal bir isimlendirme . Genellikle veri paketi classı icin kullaniliyor
// Okuyan kisi transactionu gorunce bunun bir sequnec item oldugunu anlar . 
// Böylece sequencer -> driver hattinda veri tasinmak icin kullanildigi anlasilir .
// uvm_sequence_item'den nesneleri uretip drivera gonderebilcez 
class transaction extends uvm_sequence_item; 
  `uvm_object_utils(transaction)  // uvm factory'e kaydediliyor . Her yerde create() ile uretilmesini saglar 
  	// print, copy, compare, clone gibi islemleri yapilabilir --> tr.(print) yazilirsa cikti = name, type, size, value
  	// bu islemler uvm_object icindeki fonksiyonlardir . Bu makro ile otomatik cagrilabilir
    rand bit [3:0] a; // ayni degerlerle degiskenleri tekrar tanimladim
    rand bit [3:0] b; // a ve b squence ile uretilip driver ile DUT'a surulecek
    bit [7:0] y; // sonuc DUT'tan monitor ile alinip , bu transaction class'indaki bu y degerine yazilmali
  	// y degeri alindiktan sonra scoreboarda tekrar bu sinif kullanilarak tasinir . 
    
  function new(input string path = "transaction"); // isim vermeseydim otomatik transaction olarak isimlendirilirdi new()
    super.new(path); // super.new(transaction); demek olur . Super ile de parent class'a erisilebilir olur.
  endfunction // burda extend oldugu icin base class transaction olur. Parent class'da sequence_item olur. 
endclass 
 


//*******************************************************************************************



class generator extends uvm_sequence#(transaction); // hangi item turuyle veri uretip gondercegini belritir . 
  `uvm_object_utils(generator) // factory kayit 			// burda mesela sequence , tranaction turu veri uretip gonderir 
    transaction tr;
  function new(input string path = "generator"); 
     super.new(path);  // factory icin lazim
   endfunction
  // virtual body'i sanal yapar. Alt siniflar bunu override edip uzerine yazabilir. 
  // uvm kendi cagirir , ama benim yazdigim islemleri calistirir
  virtual task body(); // ana islemler buraya yazilir. Sequencer tarafindan otomatik cagrilir. body() uvm ozel fonksiyondur
    repeat(15) // dongu olmasa sadece 1 kere  tr = transaction::type_id::create("tr"); calisirdi. 1 nesne uretilirdi. 
     begin
       tr = transaction::type_id::create("tr"); // class olan "tr" cagrilip burda tr adinda yaratilir. "abc" de yazilabilir
       start_item(tr); // degerleri DRIVER'a gondermek icin start_item("class_ismi") verilmelidir. get_next_item ile driver alir
       assert(tr.randomize());  // assert ile deger atamasi yapilir . Dogruysa devam eder, yanlissa durur.
       // random veri uretimi basarilimi bunu kontrol eder.  
       `uvm_info("SEQ", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y),UVM_MEDIUM);
       finish_item(tr); // gonderimin tamamlandigini belirtmek icin. Driver artik tr.a ve tr.b ile DUT'a veri surebilir 
     end
   endtask
endclass



//*******************************************************************************************
 


class drv extends uvm_driver#(transaction); //uvm_driver template class. hangi item turunu isleyecegini bilmeli 
  // bu nedenle bir nevi parametre gibi # kullanilarak item belirtilir.
  `uvm_component_utils(drv) // factory'e kayit . create ile uretilebilir hale getirilir
 
  transaction tr; // driver'in isleyip DUT'a surucegi veri . tr icinde a, b, y var
  virtual mul_if mif; // interface instance'i . DUT'a veri bu interface uzerinden gonderilir
 
  function new(input string path = "drv", uvm_component parent = null); // constructor. sinif ilk olustugunda calisir
    super.new(path,parent); // parent sinifa (uvm_driver) isim ve parent gonderilir
  endfunction // constructor bitisi
 
  virtual function void build_phase(uvm_phase phase); // ust siniftaki fonksiyon alt sinif tarafindan override edilebilir
    super.build_phase(phase); // super ile alt sinif , ust sinifi cagirip kullanabilir.
    if(!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface"); // interface alinamazsa hata verir
  endfunction // build_phase bitisi
  
   virtual task run_phase(uvm_phase phase); // driver’in esas calistigi yer . veriler burda DUT'a surulur
      tr = transaction::type_id::create("tr"); // bir tane transaction nesnesi yaratildi . veri buraya yazilacak
     forever begin // sim boyunca dongu . surekli yeni veri bekleniyor
       seq_item_port.get_next_item(tr);  // start_item(tr) ile baslatilan islemi driver bu get_next_item ile alir . 
       
        mif.a <= tr.a; // tr icindeki a degeri DUT'a interface uzerinden veriliyor
        mif.b <= tr.b; // b de ayni sekilde suruluyor
       `uvm_info("DRV", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE); // log mesaji yaziliyor
        seq_item_port.item_done(); // bu tr tamamlandi bilgisi veriliyor . finish_item ile uyumlu
        #20;   // veri otursun diye biraz bekleniyor . test uyumlulugu icin
      end // forever bitisi
   endtask // run_phase bitisi
 
endclass // driver sinifi kapanisi




//*******************************************************************************************



class mon extends uvm_monitor; // monitor sinifi. DUT cikislarini okuyup transaction'a cevirir
`uvm_component_utils(mon) // factory kaydi. create ile uretilebilmesi icin gerekli
 
uvm_analysis_port#(transaction) send; // monitor scoreboard'a veri gondermek icin analysis_port kullanir
transaction tr; // veriler bu nesneye yazilir ve sonra send.write ile gonderilir
virtual mul_if mif; // DUT'a bagli olan interface . burdan sinyaller okunur
 
    function new(input string inst = "mon", uvm_component parent = null); // constructor fonksiyonu
    super.new(inst,parent); // parent sinifa gonderiliyor. uvm_monitor
    endfunction // constructor bitisi
    
    virtual function void build_phase(uvm_phase phase); // build_phase: yapisal kurulum asamasi
    super.build_phase(phase); // ust sinifin build_phase’i de calistirilir
    tr = transaction::type_id::create("tr"); // transaction sinifindan bir nesne olusturuldu
    send = new("send", this); // analysis_port instance'i olusturuldu. adi "send"
    if(!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif)) // interface config_db'den cekiliyor
      `uvm_error("drv","Unable to access Interface"); // eger interface alinamazsa hata verilir
    endfunction // build_phase kapanisi
    
    virtual task run_phase(uvm_phase phase); // monitor’un esas calistigi kisim . sinyaller burda okunur
    forever begin // sim boyunca surekli calisir
    #20; // sinyallerin oturmasi icin bekleniyor . driver ile senkronize
    tr.a = mif.a; // interface uzerinden DUT'a giden a degeri alinir
    tr.b = mif.b; // b degeri de ayni sekilde alinir
    tr.y = mif.y; // y yani cikis degeri DUT'tan alinip tr'ye yazilir
    `uvm_info("MON", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE); // log yazdiriliyor
    send.write(tr); // bu tr nesnesi scoreboard'a gonderiliyor
    end // forever kapanisi
   endtask  // run_phase kapanisi
 
endclass // mon sinifi bitisi
 


//*******************************************************************************************



class sco extends uvm_scoreboard; // scoreboard sinifi. monitor'dan gelen veriyi alip dogruluk kontrolu yapar
`uvm_component_utils(sco) // factory kaydi. create ile bu sinif uretilebilir hale gelir
 
  uvm_analysis_imp#(transaction,sco) recv; // monitor'dan gelen tr nesneleri bu port ile alinir. write fonksiyonu tetiklenir
 
 
    function new(input string inst = "sco", uvm_component parent = null); // constructor. inst ismi veriliyor, parent component atanıyor
    super.new(inst,parent); // parent sinifa gonderiliyor. uvm_scoreboard
    endfunction // constructor kapanisi
    
    virtual function void build_phase(uvm_phase phase); // build phase . burada analysis port olusturuluyor
    super.build_phase(phase); // uvm_scoreboard’in build_phase’i de cagriliyor
    recv = new("recv", this); // analysis_imp olusturuldu. ismi "recv", sahibi bu sinif (this)
    endfunction // build phase bitisi
    
  virtual function void write(transaction tr); // monitor'dan gelen transaction buraya gelir. dogrulama burada yapilir
      if(tr.y == (tr.a * tr.b)) // DUT sonucu dogruysa test passed
         `uvm_info("SCO", $sformatf("Test Passed -> a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_FULL) // log bilgisi
      else // sonuc hataliysa test failed mesaji verir
         `uvm_error("SCO", $sformatf("Test Failed -> a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y)) // hata logu yazdirilir
      
    $display("----------------------------------------------------------------"); // gorunurlugu arttirmak icin ayirici cizgi
    endfunction // write fonksiyonu kapanisi
 
endclass // sco sinifi bitisi
 


//******************************************************************************************* 



class agent extends uvm_agent; // agent sinifi . driver, monitor ve sequencer burada toplanir
`uvm_component_utils(agent) // factory kaydi . agent sinifi create ile uretilebilir hale gelir
 
function new(input string inst = "agent", uvm_component parent = null); // constructor fonksiyonu
super.new(inst,parent); // parent sinifa (uvm_agent) inst ve parent bilgisi gonderilir
endfunction // constructor bitisi
 
 drv d; // driver nesnesi . DUT'a veri surecek kisim
 uvm_sequencer#(transaction) seqr; // sequencer nesnesi . sequence ile driver arasinda veri aktarimi saglar
 mon m; // monitor nesnesi . DUT'tan veri okuyup scoreboard'a iletecek
 
 
virtual function void build_phase(uvm_phase phase); // build phase. tum component'lar burada yaratilir
super.build_phase(phase); // ust sinif build_phase fonksiyonu da calistiriliyor
 d = drv::type_id::create("d",this); // driver instance'i olusturuluyor
 m = mon::type_id::create("m",this); // monitor instance'i olusturuluyor
 seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this); // sequencer instance'i yaratildi
endfunction // build phase bitisi
 
virtual function void connect_phase(uvm_phase phase); // baglantilar bu phase'de yapilir
super.connect_phase(phase); // ust sinifin connect_phase'i de calistiriliyor
d.seq_item_port.connect(seqr.seq_item_export); // driver ile sequencer arasindaki baglanti kuruluyor
endfunction // connect phase bitisi
 
endclass // agent sinifi bitisi


//*******************************************************************************************


class env extends uvm_env; // env sinifi. agent ve scoreboard bu yapida bir araya gelir
`uvm_component_utils(env) // factory kaydi. create ile uretilebilir hale gelir
 
function new(input string inst = "env", uvm_component c); // constructor fonksiyonu . inst ismi veriliyor
super.new(inst,c); // parent sinifa gonderiliyor (uvm_env)
endfunction // constructor kapanisi
 
agent a; // agent instance'i . icinde driver, monitor, sequencer var
sco s; // scoreboard instance'i . dogruluk kontrolu burada yapilir
 
virtual function void build_phase(uvm_phase phase); // build phase. yapisal nesneler burada olusur
super.build_phase(phase); // ust sinifin build_phase'i de calistirilir
  a = agent::type_id::create("a",this); // agent olusturuluyor . parent bu sinif
  s = sco::type_id::create("s", this); // scoreboard olusturuluyor
endfunction // build phase bitisi
 
virtual function void connect_phase(uvm_phase phase); // connect phase . component'larin portlari baglanir
super.connect_phase(phase); // ust sinifin connect phase'i cagriliyor
a.m.send.connect(s.recv); // monitor'dan gelen veri scoreboard'a baglandi
endfunction // connect phase kapanisi
 
endclass // env sinifi bitisi



//******************************************************************************************* 
 


class test extends uvm_test; // ana test sinifi. run_test("test") ile baslayan kisim burasi
`uvm_component_utils(test) // factory kaydi. create ile uretilebilir hale gelir
 
function new(input string inst = "test", uvm_component c); // constructor. inst ismi ve parent verilir
super.new(inst,c); // parent sinifa aktarilir (uvm_test)
endfunction // constructor bitisi
 
env e; // env instance. icinde agent ve scoreboard barindirir
generator gen; // sequence sinifi. veri uretimi buradan yapilir
 
virtual function void build_phase(uvm_phase phase); // build phase. yapisal nesneler burada olusur
super.build_phase(phase); // ust sinif build phase'i cagrilir
  e   = env::type_id::create("env",this); // env instance'i yaratildi
  gen = generator::type_id::create("gen"); // generator instance'i yaratildi
endfunction // build phase bitisi
 
virtual task run_phase(uvm_phase phase); // run phase. testin asil calistigi kisim
phase.raise_objection(this); // simulation erken bitmesin diye objection kaldirildi
gen.start(e.a.seqr); // generator baslatiliyor. e -> env, a -> agent, seqr -> sequencer
#20; // biraz bekleniyor (zorunlu degil)
phase.drop_objection(this); // objection dusuruldu, sim artik bitebilir
endtask // run phase bitisi
endclass // test sinifi bitisi

 

 
//******************************************************************************************* 



module tb;
  initial begin
    uvm_top.set_report_verbosity_level(UVM_LOW); // global seviye düşük
	end
 
  mul_if mif(); // interface instance'i olusturuldu. a, b, y sinyallerini icinde barindiriyor
  
  mul dut (.a(mif.a), .b(mif.b), .y(mif.y)); // DUT (design under test) olan "mul" modulu interface ile baglandi
 
  initial 
  begin
    // interface'i UVM ortamina tanitiyoruz. test, driver, monitor gibi yerlerde bu isimle erisilecek
    uvm_config_db #(virtual mul_if)::set(null, "*", "mif", mif); 
    run_test("test"); // "test" isimli uvm_test sinifi calistiriliyor
  end
 
  initial begin
    $dumpfile("dump.vcd"); // waveform cikti dosyasi olusturuluyor (vcd formatinda)
    $dumpvars; // tum sinyaller dump ediliyor (waveform icin gerekli)
  end
endmodule

 
 