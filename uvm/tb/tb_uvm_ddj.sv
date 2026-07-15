import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// 1. Interface
// -----------------------------------------------------------------------------
interface mole_if (
    input logic clk,
    input logic reset
);
    logic        tick_ms;
    logic        game_reset;
    logic [ 2:0] game_state;
    logic        spawn_valid;
    logic [ 5:0] spawn_mask;
    logic [17:0] spawn_type_flat;
    logic        hit_valid;
    logic [ 2:0] hit_area;
    logic [ 5:0] active_mask;
    logic [17:0] mole_type_flat;
    logic [ 5:0] hit_anim_mask;
    logic        scored_hit_valid;
    logic [ 2:0] scored_mole_type;
    logic        green_hit;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output tick_ms, game_reset, game_state, spawn_valid, spawn_mask, spawn_type_flat, hit_valid, hit_area;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input tick_ms, game_reset, game_state, spawn_valid, spawn_mask, spawn_type_flat, hit_valid, hit_area;
        input active_mask, mole_type_flat, hit_anim_mask, scored_hit_valid, scored_mole_type, green_hit;
    endclocking
endinterface

// -----------------------------------------------------------------------------
// 2. Sequence Item
// -----------------------------------------------------------------------------
class mole_seq_item extends uvm_sequence_item;
    `uvm_object_utils(mole_seq_item)

    // 랜덤 입력 변수
    rand logic        [2:0] spawn_area;
    rand logic        [2:0] mole_type;
    rand logic        [2:0] hit_area;
    rand logic        [2:0] game_state;
    rand int unsigned       wait_ticks;

    // 출력 모니터링 변수
    logic                   scored_hit_valid;
    logic             [2:0] scored_mole_type;

    // 제약 조건
    constraint c_area {
        spawn_area inside {[0 : 5]};
        hit_area inside {[0 : 5]};
    }
    constraint c_type {mole_type inside {[1 : 4]};}  // NORMAL, RED, GREEN, BLUE
    constraint c_ticks {
        wait_ticks inside {[400 : 1300]};
    }  // 타임아웃 테스트를 위한 범위

    function new(string name = "mole_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string spawn_str;
        string out_str;

        // 1. 스폰된 두더지 타입을 문자열로 변환
        case (mole_type)
            3'd1: spawn_str = "NORMAL";
            3'd2: spawn_str = "RED";
            3'd3: spawn_str = "GREEN";
            3'd4: spawn_str = "BLUE";
            default: spawn_str = "NONE";
        endcase

        // 2. 타격 결과를 CATCH / LOSE로 변환
        // scored_mole_type이 5(MISS_MATCH)이거나 타임아웃 처리된 경우 LOSE
        if (scored_mole_type == 3'd5) begin
            out_str = "LOSE";
        end  // 유효한 두더지 타입(1~4)을 반환받은 경우 CATCH
        else if (scored_mole_type >= 3'd1 && scored_mole_type <= 3'd4) begin
            out_str = "CATCH";
        end else begin
            out_str = "NONE";
        end

        return $sformatf(
            "Stage: %0d | Spawn: Area %0d, %s | Hit: Area %0d | Wait: %0d ms | Result: %s",
            game_state,
            spawn_area,
            spawn_str,
            hit_area,
            wait_ticks,
            out_str
        );
    endfunction

endclass

// -----------------------------------------------------------------------------
// 3. Sequence
// -----------------------------------------------------------------------------
class mole_rand_seq extends uvm_sequence #(mole_seq_item);
    `uvm_object_utils(mole_rand_seq)

    function new(string name = "mole_rand_seq");
        super.new(name);
    endfunction

    task body();
        mole_seq_item item;
        int stages[3] = '{1, 2, 3};  // STAGE 1, 2, 3

        foreach (stages[i]) begin
            // 각 스테이지별 500회 반복 
            repeat (500) begin
                item = mole_seq_item::type_id::create("item");
                start_item(item);
                if (!item.randomize() with {game_state == stages[i];}) begin
                    `uvm_fatal(get_type_name(), "Randomization failed")
                end
                finish_item(item);
            end
        end
    endtask
endclass

// -----------------------------------------------------------------------------
// 4. Driver
// -----------------------------------------------------------------------------
class mole_driver extends uvm_driver #(mole_seq_item);
    `uvm_component_utils(mole_driver)

    virtual mole_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mole_if)::get(this, "", "s_if", s_if)) begin
            `uvm_fatal(get_type_name(), "Interface not found in config db");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        mole_seq_item item;

        // 초기화
        s_if.drv_cb.tick_ms <= 1'b0;
        s_if.drv_cb.game_reset <= 1'b0;
        s_if.drv_cb.spawn_valid <= 1'b0;
        s_if.drv_cb.hit_valid <= 1'b0;

        wait (s_if.reset == 0);
        @(s_if.drv_cb);

        forever begin
            seq_item_port.get_next_item(item);

            // 1. 상태 설정 및 스폰
            s_if.drv_cb.game_state <= item.game_state;
            s_if.drv_cb.spawn_valid <= 1'b1;
            s_if.drv_cb.spawn_mask <= (1 << item.spawn_area);
            s_if.drv_cb.spawn_type_flat <= (item.mole_type << (item.spawn_area * 3));
            @(s_if.drv_cb);
            s_if.drv_cb.spawn_valid <= 1'b0;
            s_if.drv_cb.spawn_mask  <= 6'd0;

            // 2. 타이머 대기 (tick_ms 발생)
            repeat (item.wait_ticks) begin
                s_if.drv_cb.tick_ms <= 1'b1;
                @(s_if.drv_cb);
            end
            s_if.drv_cb.tick_ms   <= 1'b0;

            // 3. 타격 발생
            s_if.drv_cb.hit_valid <= 1'b1;
            s_if.drv_cb.hit_area  <= item.hit_area;
            @(s_if.drv_cb);
            s_if.drv_cb.hit_valid <= 1'b0;

            // 출력 반영을 위한 1클럭 대기
            @(s_if.drv_cb);

            seq_item_port.item_done();
        end
    endtask
endclass

// -----------------------------------------------------------------------------
// 5. Monitor
// -----------------------------------------------------------------------------
class mole_monitor extends uvm_monitor;
    `uvm_component_utils(mole_monitor)
    uvm_analysis_port #(mole_seq_item) ap;

    virtual mole_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual mole_if)::get(this, "", "s_if", s_if)) begin
            `uvm_fatal(get_type_name(), "Interface not found in config db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        mole_seq_item item;
        int tick_count;

        forever begin
            @(s_if.mon_cb);

            // 스폰 캡처
            if (s_if.mon_cb.spawn_valid) begin
                item = mole_seq_item::type_id::create("item");
                item.game_state = s_if.mon_cb.game_state;
                for (int i = 0; i < 6; i++) begin
                    if (s_if.mon_cb.spawn_mask[i]) begin
                        item.spawn_area = i;
                        item.mole_type  = s_if.mon_cb.spawn_type_flat[i*3+:3];
                    end
                end
                tick_count = 0;
            end

            // 시간 경과 카운트
            if (s_if.mon_cb.tick_ms) begin
                tick_count++;
            end

            // 타격 및 결과 캡처
            if (s_if.mon_cb.hit_valid && item != null) begin
                automatic mole_seq_item captured_item = item;
                item = null;

                captured_item.hit_area = s_if.mon_cb.hit_area;
                captured_item.wait_ticks = tick_count;

                fork
                    begin
                        // DUT 연산 완료 후 다음 클럭에서 출력 캡처
                        @(s_if.mon_cb);
                        captured_item.scored_hit_valid = s_if.mon_cb.scored_hit_valid;
                        captured_item.scored_mole_type = s_if.mon_cb.scored_mole_type;

                        `uvm_info(get_type_name(), $sformatf(
                                  "[MON] %s", captured_item.convert2string()),
                                  UVM_HIGH)
                        ap.write(captured_item);
                    end
                join_none
            end
        end
    endtask
endclass


class mole_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mole_scoreboard)

    int pass_cnt = 0;
    int fail_cnt = 0;

    // 세분화된 결과 카운터
    int catch_cnt = 0;
    int lose_wrong_area_cnt = 0;
    int lose_timeout_cnt = 0;
    int lose_timeout_wrong_area_cnt = 0;

    uvm_analysis_imp #(mole_seq_item, mole_scoreboard) ap_imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(mole_seq_item item);
        int expected_hold_ms;
        logic exp_hit_valid;
        logic [2:0] exp_mole_type;
        string exp_result_str;

        // 1. 스테이지에 따른 기준 시간 산출
        case (item.game_state)
            3'd1: expected_hold_ms = 1200;
            3'd2: expected_hold_ms = 800;
            3'd3: expected_hold_ms = 500;
            default: expected_hold_ms = 500;
        endcase

        // 2. 기대값 계산, 실패 원인 판별 및 카운트 누적
        exp_hit_valid = 1'b1;  // 설계상 타격 시 무조건 1 출력
        
        if (item.wait_ticks < expected_hold_ms) begin
            // [시간 내 타격]
            if (item.spawn_area == item.hit_area) begin
                exp_mole_type = item.mole_type;
                exp_result_str = "CATCH";
                catch_cnt++;
            end else begin
                exp_mole_type = 3'd5;
                exp_result_str = "LOSE (WRONG_AREA)";
                lose_wrong_area_cnt++;
            end
        end else begin
            // [시간 초과 타격]
            exp_mole_type = 3'd5;
            if (item.spawn_area == item.hit_area) begin
                exp_result_str = "LOSE (TIMEOUT)";
                lose_timeout_cnt++;
            end else begin
                exp_result_str = "LOSE (TIMEOUT & WRONG_AREA)";
                lose_timeout_wrong_area_cnt++;
            end
        end

        // 3. DUT 결과 비교
        if (item.scored_hit_valid !== exp_hit_valid || item.scored_mole_type !== exp_mole_type) begin
            fail_cnt++;
            `uvm_error("SCB_FAIL", $sformatf(
                "Mismatch! Expected: %s | Actual DUT Out: %s",
                exp_result_str, item.convert2string()
            ))
        end else begin
            pass_cnt++;
            // 성공 로그에도 스코어보드가 판단한 상세 결과(exp_result_str)를 추가
            `uvm_info("SCB_PASS", $sformatf(
                "Match! Expected: %s | Actual DUT Out: %s", 
                exp_result_str, item.convert2string()
            ), UVM_HIGH)
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "======= SCOREBOARD SUMMARY ======", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("TOTAL CHECKS: %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("MATCH: %0d, ERROR: %0d", pass_cnt, fail_cnt), UVM_LOW)

        // 세분화된 통계 출력
        `uvm_info(get_type_name(), "--- DETAILED RESULT STATS ---", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  [1] CATCH                     : %0d", catch_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  [2] LOSE (WRONG_AREA)         : %0d", lose_wrong_area_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  [3] LOSE (TIMEOUT)            : %0d", lose_timeout_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  [4] LOSE (TIMEOUT & WRONG_AREA): %0d", lose_timeout_wrong_area_cnt), UVM_LOW)
        `uvm_info(get_type_name(), "-----------------------------", UVM_LOW)

        if (fail_cnt > 0) `uvm_error(get_type_name(), "TEST FAILED!")
        else `uvm_info(get_type_name(), "TEST PASSED!", UVM_LOW)
    endfunction

endclass

class mole_coverage extends uvm_subscriber #(mole_seq_item);
    `uvm_component_utils(mole_coverage)

    mole_seq_item item;

    covergroup mole_cg;
        option.per_instance = 1;

        // 1. 단일 Coverpoint 정의
        cp_game_state: coverpoint item.game_state {
            bins stage1 = {1};
            bins stage2 = {2};
            bins stage3 = {3};
        }

        cp_mole_type: coverpoint item.mole_type {
            bins normal = {1};
            bins red    = {2};
            bins green  = {3};
            bins blue   = {4};
        }

        cp_spawn_area: coverpoint item.spawn_area {
            bins area[] = {[0:5]}; // 0부터 5까지 각각의 bin 생성
        }

        cp_hit_area: coverpoint item.hit_area {
            bins area[] = {[0:5]};
        }

        // 결과(scored_mole_type) 분류: 1~4는 CATCH, 5는 LOSE
        cp_result: coverpoint item.scored_mole_type {
            bins catch_res = {[1:4]};
            bins lose_res  = {5};
        }

        // 2. Cross Coverage 정의
        // [스테이지 x 두더지 종류] 모든 스테이지에서 모든 종류의 두더지가 나왔는지 확인
        cross_state_type: cross cp_game_state, cp_mole_type;

        // [스폰 구역 x 타격 구역] 6x6 매트릭스로 정위치 타격과 엉뚱한 구역 타격 케이스 확인
        cross_area: cross cp_spawn_area, cp_hit_area;

        // [스테이지 x 결과] 모든 스테이지에서 각각 CATCH와 LOSE가 발생했는지 확인
        cross_state_result: cross cp_game_state, cp_result;

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mole_cg = new();
    endfunction

    virtual function void write(mole_seq_item t);
        this.item = t;
        mole_cg.sample(); // 트랜잭션이 들어올 때마다 커버리지 샘플링
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        `uvm_info(get_type_name(), "\n=======================================", UVM_LOW)
        `uvm_info(get_type_name(), "       COVERAGE REPORT        ", UVM_LOW)
        `uvm_info(get_type_name(), "=======================================", UVM_LOW)

        // 1. 단일 Coverpoint 커버리지 출력
        `uvm_info(get_type_name(), "[ 1. 개별 조건 (Coverpoints) ]", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Game State (1~3단계)    : %6.2f%%", mole_cg.cp_game_state.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Mole Type (4종류)       : %6.2f%%", mole_cg.cp_mole_type.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Spawn Area (0~5구역)    : %6.2f%%", mole_cg.cp_spawn_area.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Hit Area (0~5구역)      : %6.2f%%", mole_cg.cp_hit_area.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Hit Result (성공/실패)  : %6.2f%%", mole_cg.cp_result.get_coverage()), UVM_LOW)

        // 2. Cross 커버리지 출력
        `uvm_info(get_type_name(), "\n[ 2. 복합 조건 (Cross Coverage) ]", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - State x Type (12 조합)  : %6.2f%%", mole_cg.cross_state_type.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - Area Matrix (36 조합)   : %6.2f%%", mole_cg.cross_area.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  - State x Result (6 조합) : %6.2f%%", mole_cg.cross_state_result.get_coverage()), UVM_LOW)

        // 3. 총합 커버리지
        `uvm_info(get_type_name(), "---------------------------------------", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  >> 최종 Overall Coverage  : %6.2f%%", mole_cg.get_inst_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), "=======================================\n", UVM_LOW)
    endfunction
endclass

// -----------------------------------------------------------------------------
// 7. Agent, Env, Test, Top
// -----------------------------------------------------------------------------
class mole_agent extends uvm_agent;
    `uvm_component_utils(mole_agent)
    mole_driver drv;
    mole_monitor mon;
    uvm_sequencer #(mole_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = mole_driver::type_id::create("drv", this);
        mon = mole_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(mole_seq_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class mole_env extends uvm_env;
    `uvm_component_utils(mole_env)
    
    mole_agent      agt;
    mole_scoreboard sb;
    mole_coverage   cov; // 커버리지 컴포넌트 추가

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = mole_agent::type_id::create("agt", this);
        sb  = mole_scoreboard::type_id::create("sb", this);
        cov = mole_coverage::type_id::create("cov", this); // 생성
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(sb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export); // 모니터와 커버리지 연결
    endfunction
endclass

class mole_rand_test extends uvm_test;
    `uvm_component_utils(mole_rand_test)
    mole_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mole_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mole_rand_seq seq;
        phase.raise_objection(this);
        seq = mole_rand_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass

module tb_mole_uvm ();
    logic clk;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
    end

    mole_if s_if (
        clk,
        reset
    );

    mole_state_manager dut (
        .clk(clk),
        .reset(reset),
        .tick_ms(s_if.tick_ms),
        .game_reset(s_if.game_reset),
        .game_state(s_if.game_state),
        .spawn_valid(s_if.spawn_valid),
        .spawn_mask(s_if.spawn_mask),
        .spawn_type_flat(s_if.spawn_type_flat),
        .hit_valid(s_if.hit_valid),
        .hit_area(s_if.hit_area),
        .active_mask(s_if.active_mask),
        .mole_type_flat(s_if.mole_type_flat),
        .hit_anim_mask(s_if.hit_anim_mask),
        .scored_hit_valid(s_if.scored_hit_valid),
        .scored_mole_type(s_if.scored_mole_type),
        .green_hit(s_if.green_hit)
    );

    initial begin
        uvm_config_db#(virtual mole_if)::set(null, "*", "s_if", s_if);
        run_test("mole_rand_test");
    end
endmodule
