TC ?= spi_rand_test         #Test Class
SEED ?= 1234               #Random Seed 패턴 생성


VCS_OPTS := -full64 -sverilog
VCS_OPTS += -ntb_opts uvm-1.2
VCS_OPTS += -timescale=1ns/1ps
VCS_OPTS += -debug_access+all -kdb -lca
VCS_OPTS += +incdir+./tb
VCS_OPTS += -cm line+cond+fsm+tgl+branch+assert

#SIM_OPTS := +UVM_TESTNAME=$(TC)
SIM_OPTS += +UVM_VERBOSITY=UVM_HIGH
SIM_OPTS += +ntb_random_seed=$(SEED)
SIM_OPTS += -cm line+cond+fsm+tgl+branch+assert
SIM_OPTS += -cm_dir coverage.vdb
SIM_OPTS += -cm_name sim1

VERDI_OPTS := -covdir coverage.vdb -dbdir simv.daidir -ssf novas.fsdb

.PHONY: compile sim clean

compile:
	vcs $(VCS_OPTS) -f filelist.f -o simv
	@echo "vcs 컴파일 실행 중.."

sim: compile
	./simv $(SIM_OPTS)
	@echo "시뮬레이션 실행 중.."

verdi: sim
	verdi $(VERDI_OPTS) &

vw: sim
	verdi -dbdir simv.daidir -ssf novas.fsdb &

vc: sim
	verdi -cov -covdir coverage.vdb &

clean:
	@rm -rf simv* csrc .key *.h *.log *.fsdb novas* *.conf *Log

