transcript on
vmap altera_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/altera_ver
vmap lpm_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/lpm_ver
vmap sgate_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/sgate_ver
vmap altera_mf_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/altera_mf_ver
vmap altera_lnsim_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/altera_lnsim_ver
vmap cyclonev_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/cyclonev_ver
vmap cyclonev_hssi_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/cyclonev_hssi_ver
vmap cyclonev_pcie_hip_ver C:/altera_pr/CLinkTest/Msim_lib/verilog_libs/cyclonev_pcie_hip_ver
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/altera_pr/CLinkTest {C:/altera_pr/CLinkTest/CLinkGen.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/CLinkTest/FIFO {C:/altera_pr/CLinkTest/FIFO/fifo_128kx16.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/CLinkTest {C:/altera_pr/CLinkTest/CLinkConvert.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/CLinkTest/simulation/modelsim {C:/altera_pr/CLinkTest/simulation/modelsim/CLinkConvert.vt}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  CLinkConvert_vlg_tst


add wave -group BenchWaves *
add wave -group CLinkGen sim:/CLinkConvert_vlg_tst/CLink_generator/*
add wave -group CLinkConvert sim:/CLinkConvert_vlg_tst/CLink_converter/*

view structure
view signals
run -all