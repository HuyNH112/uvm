// =============================================================================
// hpdcache_seq_lib.sv — 13 Sequences (khớp UVM_HPDcache_11TCs.md)
// Fix: loại bỏ foreach({...}[j]), địa chỉ 56-bit đúng width
// =============================================================================
`ifndef HPDCACHE_SEQ_LIB_SV
`define HPDCACHE_SEQ_LIB_SV

// =============================================================================
// 1. Base sequence
// =============================================================================
class hpdcache_base_seq extends uvm_sequence #(hpdcache_seq_item);
    `uvm_object_utils(hpdcache_base_seq)

    int unsigned next_tid;

    function new(string name = "hpdcache_base_seq");
        super.new(name);
        next_tid = 0;
    endfunction

    function automatic hpdcache_req_tid_t get_tid();
        hpdcache_req_tid_t t = hpdcache_req_tid_t'(next_tid);
        next_tid = (next_tid + 1) % (1 << UVM_HPDCACHE_REQ_TRANS_ID_WIDTH);
        return t;
    endfunction

endclass : hpdcache_base_seq

// =============================================================================
// 2. hpdcache_rand_seq — Smoke: num_trans LOAD/STORE ngẫu nhiên
// =============================================================================
class hpdcache_rand_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_rand_seq)

    int unsigned num_trans;

    function new(string name = "hpdcache_rand_seq");
        super.new(name);
        num_trans = 10;
    endfunction

    task body();
        hpdcache_seq_item item;
        int i;
        for (i = 0; i < num_trans; i++) begin
            item = hpdcache_seq_item::type_id::create("rand_item");
            start_item(item);
            if ($urandom_range(0,1))
                item.set_random_load(get_tid());
            else
                item.set_random_store(get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_rand_seq

// =============================================================================
// 3. hpdcache_store_load_seq — TC 3.1/3.2: STORE→LOAD cùng addr
// =============================================================================
class hpdcache_store_load_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_store_load_seq)

    int unsigned num_pairs;

    function new(string name = "hpdcache_store_load_seq");
        super.new(name);
        num_pairs = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] pa;
        hpdcache_req_data_t               data;
        int p;
        for (p = 0; p < num_pairs; p++) begin
            pa   = {40'h00_0000_0100, 8'(p << 3), 8'h00};
            data = hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()});

            item = hpdcache_seq_item::type_id::create("sl_store");
            start_item(item);
            item.set_store_to_addr(pa, data, get_tid());
            finish_item(item);

            item = hpdcache_seq_item::type_id::create("sl_load");
            start_item(item);
            item.set_load_from_addr(pa, get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_store_load_seq

// =============================================================================
// 4. hpdcache_cross_cacheline_seq — TC 3.3: access gần cacheline boundary
// =============================================================================
class hpdcache_cross_cacheline_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_cross_cacheline_seq)

    int unsigned num_accesses;

    function new(string name = "hpdcache_cross_cacheline_seq");
        super.new(name);
        num_accesses = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        // offset 0x7F8 = last 8 bytes của cacheline (CL=64B, word=8B)
        // addr_offset[5:0]=0x38 (word offset trong CL), set=0
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] pa_end;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] pa_next;
        int i;
        for (i = 0; i < num_accesses; i++) begin
            pa_end  = {44'h0_0001_0000_0 + 44'(i*2), 12'hFF8};
            pa_next = pa_end + 64;

            item = hpdcache_seq_item::type_id::create("xcl_wr");
            start_item(item);
            item.set_store_to_addr(pa_end,
                hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()}),
                get_tid());
            finish_item(item);

            item = hpdcache_seq_item::type_id::create("xcl_rd");
            start_item(item);
            item.set_load_from_addr(pa_next, get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_cross_cacheline_seq

// =============================================================================
// 5. hpdcache_stride_seq — LOAD stride 64-byte
// =============================================================================
class hpdcache_stride_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_stride_seq)

    int unsigned num_accesses;
    int unsigned stride_bytes;

    function new(string name = "hpdcache_stride_seq");
        super.new(name);
        num_accesses = 32; // testplan PT2.0: num_accesses=32
        stride_bytes = 64;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] base_addr;
        int i;
        base_addr = 56'h00_0000_4000_0000;
        for (i = 0; i < num_accesses; i++) begin
            item = hpdcache_seq_item::type_id::create("stride_ld");
            start_item(item);
            item.set_load_from_addr(base_addr + (i * stride_bytes), get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_stride_seq

// =============================================================================
// 6. hpdcache_mshr_stress_seq — TC 4.4: 16 LOAD đến addr khác nhau → MSHR full
// =============================================================================
class hpdcache_mshr_stress_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_mshr_stress_seq)

    int unsigned num_miss;

    function new(string name = "hpdcache_mshr_stress_seq");
        super.new(name);
        num_miss = 16;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] base_addr;
        int i;
        base_addr = 56'h00_0000_2000_0000;
        for (i = 0; i < num_miss; i++) begin
            item = hpdcache_seq_item::type_id::create("mshr_miss");
            start_item(item);
            item.set_load_from_addr(base_addr + (i * 64), get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_mshr_stress_seq

// =============================================================================
// 7. hpdcache_wbuf_forwarding_seq — TC 3.2: STORE→LOAD ngay lập tức
// =============================================================================
class hpdcache_wbuf_forwarding_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_wbuf_forwarding_seq)

    int unsigned num_pairs;

    function new(string name = "hpdcache_wbuf_forwarding_seq");
        super.new(name);
        num_pairs = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] pa;
        hpdcache_req_data_t               data;
        int p;
        for (p = 0; p < num_pairs; p++) begin
            pa   = 56'h00_0000_5000_0000 + (p * 64);
            data = hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()});

            // STORE
            item = hpdcache_seq_item::type_id::create("wbuf_wr");
            start_item(item);
            item.set_store_to_addr(pa, data, get_tid());
            finish_item(item);

            // LOAD ngay lập tức — kỳ vọng wbuf forwarding
            item = hpdcache_seq_item::type_id::create("wbuf_rd");
            start_item(item);
            item.set_load_from_addr(pa, get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_wbuf_forwarding_seq

// =============================================================================
// 8. hpdcache_domino_mht1_seq — TC 4.1: Train A→B→C, replay A
// =============================================================================
class hpdcache_domino_mht1_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_domino_mht1_seq)

    int unsigned num_train_rounds;

    function new(string name = "hpdcache_domino_mht1_seq");
        super.new(name);
        num_train_rounds = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_A;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_B;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_C;
        int r;
        // Tags A/B/C spaced 4KB apart: distinct tag[43:12] fields
        // ensures separate MHT1 entries and avoids PLRU eviction
        // conflict across num_train_rounds=4 in an 8-way 64-set cache.
        addr_A = 56'h00_0001_0000_1000; // tag = 44'h0001_0000_1
        addr_B = 56'h00_0001_0000_2000; // tag = 44'h0001_0000_2
        addr_C = 56'h00_0001_0000_3000; // tag = 44'h0001_0000_3

        for (r = 0; r < num_train_rounds; r++) begin
            item = hpdcache_seq_item::type_id::create("mht1_A");
            start_item(item); item.set_load_from_addr(addr_A, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht1_B");
            start_item(item); item.set_load_from_addr(addr_B, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht1_C");
            start_item(item); item.set_load_from_addr(addr_C, get_tid()); finish_item(item);
        end

        // Replay A — prefetcher phát prefetch đến B
        item = hpdcache_seq_item::type_id::create("mht1_replay_A");
        start_item(item); item.set_load_from_addr(addr_A, get_tid()); finish_item(item);
    endtask

endclass : hpdcache_domino_mht1_seq

// =============================================================================
// 9. hpdcache_domino_mht2_seq — TC 4.2: Train A→B→X + C→B→Y, replay A→B
// =============================================================================
class hpdcache_domino_mht2_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_domino_mht2_seq)

    int unsigned num_train_rounds;

    function new(string name = "hpdcache_domino_mht2_seq");
        super.new(name);
        num_train_rounds = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_A;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_B;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_C;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_X;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_Y;
        int r;
        // 5 distinct tags, 4KB spacing — separate MHT2 entries.
        // XOR(tag_A, tag_B) != XOR(tag_C, tag_B) by construction.
        addr_A = 56'h00_0002_0000_1000; // tag_A
        addr_B = 56'h00_0002_0000_2000; // tag_B
        addr_C = 56'h00_0002_0000_3000; // tag_C
        addr_X = 56'h00_0002_0000_4000; // tag_X (A->B->X pattern)
        addr_Y = 56'h00_0002_0000_5000; // tag_Y (C->B->Y pattern)

        for (r = 0; r < num_train_rounds; r++) begin
            // Pattern 1: A→B→X
            item = hpdcache_seq_item::type_id::create("mht2_A");
            start_item(item); item.set_load_from_addr(addr_A, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht2_B1");
            start_item(item); item.set_load_from_addr(addr_B, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht2_X");
            start_item(item); item.set_load_from_addr(addr_X, get_tid()); finish_item(item);
            // Pattern 2: C→B→Y
            item = hpdcache_seq_item::type_id::create("mht2_C");
            start_item(item); item.set_load_from_addr(addr_C, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht2_B2");
            start_item(item); item.set_load_from_addr(addr_B, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("mht2_Y");
            start_item(item); item.set_load_from_addr(addr_Y, get_tid()); finish_item(item);
        end

        // Replay A→B
        item = hpdcache_seq_item::type_id::create("mht2_replay_A");
        start_item(item); item.set_load_from_addr(addr_A, get_tid()); finish_item(item);
        item = hpdcache_seq_item::type_id::create("mht2_replay_B");
        start_item(item); item.set_load_from_addr(addr_B, get_tid()); finish_item(item);
    endtask

endclass : hpdcache_domino_mht2_seq

// =============================================================================
// 10. hpdcache_hash_collision_seq — TC 4.3: 2 tag cùng XOR hash
// =============================================================================
class hpdcache_hash_collision_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_hash_collision_seq)

    int unsigned num_rounds;

    function new(string name = "hpdcache_hash_collision_seq");
        super.new(name);
        num_rounds = 8;
    endfunction

    task body();
        hpdcache_seq_item item;
        // Hai địa chỉ có cùng XOR hash trong MHT:
        // hash = tag[N:0] XOR tag[2N:N+1] → chọn addr sao cho XOR bằng nhau
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_P;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] addr_Q;
        int r;
        // Collision proof (domino_pkg: INDEX_WIDTH=10):
        // hash(tag) = tag[9:0]^tag[19:10]^tag[29:20]^tag[39:30]^tag[43:40]
        // tag_P = 44'h0000_0000_0001 → hash = 10'h001
        // tag_Q = 44'h0000_0000_0400 → [9:0]=0, [19:10]=0x001 → hash = 10'h001
        // Both map to MHT index 0x001 — guaranteed collision.
        addr_P = 56'h00_0000_0000_1000; // tag_P<<12
        addr_Q = 56'h00_0000_0040_0000; // tag_Q<<12
        for (r = 0; r < num_rounds; r++) begin
            item = hpdcache_seq_item::type_id::create("hash_P");
            start_item(item); item.set_load_from_addr(addr_P, get_tid()); finish_item(item);
            item = hpdcache_seq_item::type_id::create("hash_Q");
            start_item(item); item.set_load_from_addr(addr_Q, get_tid()); finish_item(item);
        end
    endtask

endclass : hpdcache_hash_collision_seq

// =============================================================================
// 11. hpdcache_domino_training_seq — Pattern {64,128,64,192,...} × num_patterns
// =============================================================================
class hpdcache_domino_training_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_domino_training_seq)

    int unsigned num_patterns;

    function new(string name = "hpdcache_domino_training_seq");
        super.new(name);
        num_patterns = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] base_addr;
        int offsets [4];
        int p, o;
        base_addr  = 56'h00_0004_0000_0000;
        offsets[0] = 64;
        offsets[1] = 128;
        offsets[2] = 64;
        offsets[3] = 192;
        for (p = 0; p < num_patterns; p++) begin
            for (o = 0; o < 4; o++) begin
                item = hpdcache_seq_item::type_id::create("dom_train");
                start_item(item);
                item.set_load_from_addr(base_addr + offsets[o], get_tid());
                finish_item(item);
            end
        end
    endtask

endclass : hpdcache_domino_training_seq

// =============================================================================
// 12. hpdcache_hit_under_miss_seq — TC 5.1: pre-warm + cold miss + warm hits
// =============================================================================
class hpdcache_hit_under_miss_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_hit_under_miss_seq)

    int unsigned num_hits;

    function new(string name = "hpdcache_hit_under_miss_seq");
        super.new(name);
        num_hits = 5;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] warm_addr;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] cold_addr;
        hpdcache_req_data_t               warm_data;
        int h;
        warm_addr = 56'h00_0005_0000_0000;
        cold_addr = 56'h00_0005_0001_0000;
        warm_data = hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()});

        // STORE để pre-warm
        item = hpdcache_seq_item::type_id::create("hum_store");
        start_item(item);
        item.set_store_to_addr(warm_addr, warm_data, get_tid());
        finish_item(item);

        // Cold miss
        item = hpdcache_seq_item::type_id::create("hum_cold");
        start_item(item);
        item.set_load_from_addr(cold_addr, get_tid());
        finish_item(item);

        // Warm hits while cold miss outstanding
        for (h = 0; h < num_hits; h++) begin
            item = hpdcache_seq_item::type_id::create("hum_warm");
            start_item(item);
            item.set_load_from_addr(warm_addr, get_tid());
            finish_item(item);
        end
    endtask

endclass : hpdcache_hit_under_miss_seq

// =============================================================================
// 13. hpdcache_pref_store_hazard_seq — TC 5.2: LOAD→STORE→LOAD cùng addr
// =============================================================================
class hpdcache_pref_store_hazard_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_pref_store_hazard_seq)

    int unsigned num_rounds;

    function new(string name = "hpdcache_pref_store_hazard_seq");
        super.new(name);
        num_rounds = 4;
    endfunction

    task body();
        hpdcache_seq_item item;
        logic [UVM_HPDCACHE_PA_WIDTH-1:0] pa;
        hpdcache_req_data_t               data;
        int r;
        pa = 56'h00_0006_0000_0000;
        for (r = 0; r < num_rounds; r++) begin
            data = hpdcache_req_data_t'({$urandom(),$urandom(),$urandom(),$urandom()});

            item = hpdcache_seq_item::type_id::create("psh_ld1");
            start_item(item); item.set_load_from_addr(pa, get_tid()); finish_item(item);

            item = hpdcache_seq_item::type_id::create("psh_st");
            start_item(item); item.set_store_to_addr(pa, data, get_tid()); finish_item(item);

            item = hpdcache_seq_item::type_id::create("psh_ld2");
            start_item(item); item.set_load_from_addr(pa, get_tid()); finish_item(item);
        end
    endtask

endclass : hpdcache_pref_store_hazard_seq

// =============================================================================
// 14. hpdcache_axi_stall_seq — TC 5.3: random inter-transaction delay
// =============================================================================
class hpdcache_axi_stall_seq extends hpdcache_base_seq;
    `uvm_object_utils(hpdcache_axi_stall_seq)

    int unsigned num_trans;
    int unsigned max_stall_cycles;

    function new(string name = "hpdcache_axi_stall_seq");
        super.new(name);
        num_trans        = 10;
        max_stall_cycles = 10; // testplan TC5.3: max_stall=10
    endfunction

    task body();
        hpdcache_seq_item item;
        int i;
        for (i = 0; i < num_trans; i++) begin
            item = hpdcache_seq_item::type_id::create("stall_ld");
            start_item(item);
            item.set_random_load(get_tid());
            item.delay_cycles = $urandom_range(0, max_stall_cycles);
            finish_item(item);
        end
    endtask

endclass : hpdcache_axi_stall_seq

`endif // HPDCACHE_SEQ_LIB_SV
