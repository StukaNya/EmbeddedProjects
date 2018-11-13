transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog -vlog01compat -work altera_ver {c:/altera/14.0/quartus/eda/sim_lib/altera_primitives.v}

vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog -vlog01compat -work lpm_ver {c:/altera/14.0/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog -vlog01compat -work sgate_ver {c:/altera/14.0/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog -vlog01compat -work altera_mf_ver {c:/altera/14.0/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_lnsim_ver
vmap altera_lnsim_ver ./verilog_libs/altera_lnsim_ver
vlog -sv -work altera_lnsim_ver {c:/altera/14.0/quartus/eda/sim_lib/altera_lnsim.sv}

vlib verilog_libs/cyclonev_ver
vmap cyclonev_ver ./verilog_libs/cyclonev_ver
vlog -vlog01compat -work cyclonev_ver {c:/altera/14.0/quartus/eda/sim_lib/mentor/cyclonev_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_ver {c:/altera/14.0/quartus/eda/sim_lib/mentor/cyclonev_hmi_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_ver {c:/altera/14.0/quartus/eda/sim_lib/cyclonev_atoms.v}

vlib verilog_libs/cyclonev_hssi_ver
vmap cyclonev_hssi_ver ./verilog_libs/cyclonev_hssi_ver
vlog -vlog01compat -work cyclonev_hssi_ver {c:/altera/14.0/quartus/eda/sim_lib/mentor/cyclonev_hssi_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_hssi_ver {c:/altera/14.0/quartus/eda/sim_lib/cyclonev_hssi_atoms.v}

vlib verilog_libs/cyclonev_pcie_hip_ver
vmap cyclonev_pcie_hip_ver ./verilog_libs/cyclonev_pcie_hip_ver
vlog -vlog01compat -work cyclonev_pcie_hip_ver {c:/altera/14.0/quartus/eda/sim_lib/mentor/cyclonev_pcie_hip_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_pcie_hip_ver {c:/altera/14.0/quartus/eda/sim_lib/cyclonev_pcie_hip_atoms.v}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work


vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/filter_blowout.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/TestHawk.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/hawk_capture.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/fifoH_capture.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/filter_frame_average.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/v.10.0/HDL {C:/altera_pr/v.10.0/HDL/filter_frame_average_tbt.v}

vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/FIFO/fifo_640x16.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/FIFO/fifo_w32r16.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/FIFO/fifo_640x10.v}

vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/ALTFP/MultFp.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/ALTFP/AddFp.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/ALTFP/Int16ToFloat.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/FIFO {C:/altera_pr/BlowOut/ALTFP/FpToInt16.v}

vlog -vlog01compat -work work +incdir+C:/altera_pr/BlowOut/simulation/modelsim {C:/altera_pr/BlowOut/simulation/modelsim/FilterBlowOut.vt}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  blow_out_tb


add wave -group BenchWaves *
add wave -group TestHawk sim:/blow_out_tb/UTestCamLink/*
add wave -group HawkCapture sim:/blow_out_tb/hvdcap_inst/*
add wave -group BlowOut sim:/blow_out_tb/tb_blow_out/* \
sim:/blow_out_tb/tb_blow_out/shift_mem \
sim:/blow_out_tb/tb_blow_out/sum \
sim:/blow_out_tb/tb_blow_out/out_shift_mem
add wave -group FrameAvTop sim:/blow_out_tb/tb_average/*
add wave -group FilterAv sim:/blow_out_tb/tb_average/average_filter/*

#add wave -group StreamBuf sim:/blow_out_tb/tb_blow_out/stream_buffer/*
#add wave -group BufDelay1 sim:/blow_out_tb/tb_blow_out/fifo_line_1d/*
#add wave -group BufDelay2 sim:/blow_out_tb/tb_blow_out/fifo_line_2d/*

view structure
view signals
run -all
