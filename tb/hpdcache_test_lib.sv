`ifndef HPDCACHE_TEST_LIB_SV
`define HPDCACHE_TEST_LIB_SV

// ============================================================================
// hpdcache_test_lib.sv
// Sequences and Tests cho HPDcache UVM Testbench (cv32a6_imac_sv32)
// Testplan: Load/Store basic, MSHR stress, Write-buffer, Domino prefetcher
// ============================================================================

// ============================================================================
// BASE SEQUENCE
// ============================================================================
class hpdcache_base_seq extends uvm_sequence #(hpdcache_seq_item);
    `uvm_object_utils(hpdcache_base_seq)

    function new(string name = "hpdcache_base_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "hpdcache_base_seq body: override me!", UVM_LOW)
    endtask
endclass : hpdcache_base_seq

// ============================================================================
// SEQ 1: Random Load/Store
// ============================================================================
class hpdcache_rand_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_rand_seq)

    int unsigned num_trans = 20;

    function new(string name = "hpdcache_rand_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item item;
        repeat (num_trans) begin
            item = hpdcache_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("SEQ", "Randomize that bai!")
            finish_item(item);
            `uvm_info("SEQ", $sformatf("RAND[%0d]: %s", num_trans, item.convert2string()), UVM_HIGH)
        end
    endtask
endclass : hpdcache_rand_seq

// ============================================================================
// SEQ 2: Store-Then-Load (verify scoreboard data forwarding)
// ============================================================================
class hpdcache_store_load_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_store_load_seq)

    int unsigned num_pairs = 8;

    function new(string name = "hpdcache_store_load_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item store_item, load_item;
        hpdcache_req_addr_t store_addr;

        repeat (num_pairs) begin
            store_item = hpdcache_seq_item::type_id::create("store_item");
            load_item  = hpdcache_seq_item::type_id::create("load_item");

            // STORE
            start_item(store_item);
            if (!store_item.randomize() with {
                op   == hpdcache_pkg::HPDCACHE_REQ_STORE;
                size == 3'b011;
            }) `uvm_fatal("SEQ", "Randomize STORE that bai!")
            finish_item(store_item);
            store_addr = {store_item.addr_tag, store_item.addr_offset};
            `uvm_info("SEQ", $sformatf("STORE: %s", store_item.convert2string()), UVM_MEDIUM)

            // LOAD cung dia chi
            start_item(load_item);
            if (!load_item.randomize() with {
                op         == hpdcache_pkg::HPDCACHE_REQ_LOAD;
                size       == 3'b011;
                addr_tag   == store_item.addr_tag;
                addr_offset == store_item.addr_offset;
            }) `uvm_fatal("SEQ", "Randomize LOAD that bai!")
            finish_item(load_item);
            `uvm_info("SEQ", $sformatf("LOAD : %s", load_item.convert2string()), UVM_MEDIUM)
        end
    endtask
endclass : hpdcache_store_load_seq

// ============================================================================
// SEQ 3: Sequential Stride (kích hoạt Domino prefetcher)
// Truy cap lien tiep tang dan theo stride = 1 cacheline (64 bytes)
// ============================================================================
class hpdcache_stride_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_stride_seq)

    int unsigned  num_accesses = 16;
    logic [17:0]  base_tag     = 18'h1_0000;  // PA[31:14]

    function new(string name = "hpdcache_stride_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item item;
        // 1 cacheline = 64 bytes = offset tang 64 moi buoc
        // offset [13:0]: tang 6'b100_0000 (bit 6) moi buoc
        for (int i = 0; i < num_accesses; i++) begin
            item = hpdcache_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                op          == hpdcache_pkg::HPDCACHE_REQ_LOAD;
                size        == 3'b011;
                addr_tag    == 18'(base_tag + 18'(i >> 8));
                addr_offset == 14'(i * 64);
            }) `uvm_fatal("SEQ", "Randomize stride that bai!")
            finish_item(item);
            `uvm_info("SEQ",
                $sformatf("STRIDE[%0d]: PA=0x%08h", i, {item.addr_tag, item.addr_offset}),
                UVM_MEDIUM)
        end
    endtask
endclass : hpdcache_stride_seq

// ============================================================================
// SEQ 4: MSHR Stress — nhieu miss lien tiep den cac dia chi khac nhau
// Muc tich: fill het MSHR (16 entries), kiem tra khong deadlock
// ============================================================================
class hpdcache_mshr_stress_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_mshr_stress_seq)

    int unsigned num_miss = 16;  // bang MSHR_SETS

    function new(string name = "hpdcache_mshr_stress_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item item;
        // Phat nhieu LOAD toi cac cacheline khac nhau (dam bao miss)
        for (int i = 0; i < num_miss; i++) begin
            item = hpdcache_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                op          == hpdcache_pkg::HPDCACHE_REQ_LOAD;
                size        == 3'b011;
                // Moi request toi mot set khac nhau
                addr_tag    == 18'(18'h0_0001 + 18'(i));
                addr_offset == 14'h0000;
            }) `uvm_fatal("SEQ", "Randomize MSHR stress that bai!")
            finish_item(item);
            `uvm_info("SEQ",
                $sformatf("MSHR_STRESS[%0d]: PA=0x%08h", i, {item.addr_tag, item.addr_offset}),
                UVM_MEDIUM)
        end
    endtask
endclass : hpdcache_mshr_stress_seq

// ============================================================================
// SEQ 5: Write-buffer forwarding
// STORE roi ngay lap tuc LOAD cung dia chi — kiem tra wbuf forwarding
// ============================================================================
class hpdcache_wbuf_forwarding_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_wbuf_forwarding_seq)

    int unsigned num_pairs = 4;

    function new(string name = "hpdcache_wbuf_forwarding_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item item;
        hpdcache_req_addr_t tgt_addr;
        logic [63:0] tgt_data;

        repeat (num_pairs) begin
            // Random data va dia chi
            void'(std::randomize(tgt_data));

            // STORE
            item = hpdcache_seq_item::type_id::create("store");
            start_item(item);
            if (!item.randomize() with {
                op    == hpdcache_pkg::HPDCACHE_REQ_STORE;
                size  == 3'b011;
                wdata == {1{tgt_data}};
                be    == 8'hFF;
            }) `uvm_fatal("SEQ", "Randomize WBUF store that bai!")
            tgt_data        = item.wdata[0];
            item.addr_tag    = item.addr_tag;
            item.addr_offset = item.addr_offset;
            finish_item(item);
            `uvm_info("SEQ", $sformatf("WBUF STORE: %s", item.convert2string()), UVM_MEDIUM)

            // LOAD ngay sau (kiem tra forwarding)
            begin
                hpdcache_seq_item litem;
                litem = hpdcache_seq_item::type_id::create("load");
                start_item(litem);
                if (!litem.randomize() with {
                    op          == hpdcache_pkg::HPDCACHE_REQ_LOAD;
                    size        == 3'b011;
                    addr_tag    == item.addr_tag;
                    addr_offset == item.addr_offset;
                }) `uvm_fatal("SEQ", "Randomize WBUF load that bai!")
                finish_item(litem);
                `uvm_info("SEQ", $sformatf("WBUF LOAD : %s", litem.convert2string()), UVM_MEDIUM)
            end
        end
    endtask
endclass : hpdcache_wbuf_forwarding_seq

// ============================================================================
// SEQ 6: Domino Prefetcher Training
// Tao pattern truy cap co thu tu de Domino MHT hoc va prefetch
// ============================================================================
class hpdcache_domino_training_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_domino_training_seq)

    int unsigned  num_patterns  = 4;   // so lan lap pattern
    int unsigned  pattern_len   = 8;   // so access moi pattern
    logic [17:0]  base_tag      = 18'h2_0000;

    function new(string name = "hpdcache_domino_training_seq");
        super.new(name);
    endfunction

    task body();
        hpdcache_seq_item item;

        // Pattern: A -> B -> C -> D -> ... (stride khong deu, Domino se hoc)
        // Offset tang theo fibonacci-like: 64, 128, 64, 192, 64, 128...
        automatic int unsigned offsets[] = '{64, 128, 64, 192, 64, 128, 64, 256};

        repeat (num_patterns) begin
            for (int i = 0; i < pattern_len; i++) begin
                item = hpdcache_seq_item::type_id::create("item");
                start_item(item);
                if (!item.randomize() with {
                    op          == hpdcache_pkg::HPDCACHE_REQ_LOAD;
                    size        == 3'b011;
                    addr_tag    == base_tag;
                    addr_offset == 14'(offsets[i % offsets.size()]);
                }) `uvm_fatal("SEQ", "Randomize Domino pattern that bai!")
                finish_item(item);
                `uvm_info("SEQ",
                    $sformatf("DOMINO[%0d]: PA=0x%08h", i, {item.addr_tag, item.addr_offset}),
                    UVM_HIGH)
            end
        end
    endtask
endclass : hpdcache_domino_training_seq

// ============================================================================
// TEST 1: Smoke test (base_test da xu ly)
// ============================================================================
// hpdcache_base_test cung la test chay duoc (5 random transactions)

// ============================================================================
// TEST 2: Random Load/Store
// ============================================================================
class hpdcache_rand_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_rand_test)

    function new(string name = "hpdcache_rand_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_rand_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== RAND TEST: 20 random LOAD/STORE ===", UVM_LOW)
        seq = hpdcache_rand_seq::type_id::create("seq");
        seq.num_trans = 20;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_rand_test

// ============================================================================
// TEST 3: Store-Load verification
// ============================================================================
class hpdcache_store_load_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_store_load_test)

    function new(string name = "hpdcache_store_load_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_store_load_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== STORE-LOAD TEST: data forwarding verification ===", UVM_LOW)
        seq = hpdcache_store_load_seq::type_id::create("seq");
        seq.num_pairs = 8;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_store_load_test

// ============================================================================
// TEST 4: Stride prefetcher stimulus
// ============================================================================
class hpdcache_stride_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_stride_test)

    function new(string name = "hpdcache_stride_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_stride_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== STRIDE TEST: activate stride prefetcher ===", UVM_LOW)
        seq = hpdcache_stride_seq::type_id::create("seq");
        seq.num_accesses = 16;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_stride_test

// ============================================================================
// TEST 5: MSHR stress test
// ============================================================================
class hpdcache_mshr_stress_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_mshr_stress_test)

    function new(string name = "hpdcache_mshr_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_mshr_stress_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== MSHR STRESS TEST: fill all MSHR entries ===", UVM_LOW)
        seq = hpdcache_mshr_stress_seq::type_id::create("seq");
        seq.num_miss = 16;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_mshr_stress_test

// ============================================================================
// TEST 6: Write-buffer forwarding test
// ============================================================================
class hpdcache_wbuf_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_wbuf_test)

    function new(string name = "hpdcache_wbuf_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_wbuf_forwarding_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== WBUF FORWARDING TEST ===", UVM_LOW)
        seq = hpdcache_wbuf_forwarding_seq::type_id::create("seq");
        seq.num_pairs = 4;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_wbuf_test

// ============================================================================
// TEST 7: Domino prefetcher training
// ============================================================================
class hpdcache_domino_test extends hpdcache_base_test;
    `uvm_component_utils(hpdcache_domino_test)

    function new(string name = "hpdcache_domino_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hpdcache_domino_training_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== DOMINO PREFETCHER TRAINING TEST ===", UVM_LOW)
        seq = hpdcache_domino_training_seq::type_id::create("seq");
        seq.num_patterns = 4;
        seq.pattern_len  = 8;
        seq.start(env.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass : hpdcache_domino_test

`endif // HPDCACHE_TEST_LIB_SV