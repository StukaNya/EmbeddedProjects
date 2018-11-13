transcript on
vmap altera_ver C:/altera_pr/msim_lib/verilog_libs/altera_ver
vmap lpm_ver C:/altera_pr/msim_lib/verilog_libs/lpm_ver
vmap sgate_ver C:/altera_pr/msim_lib/verilog_libs/sgate_ver
vmap altera_mf_ver C:/altera_pr/msim_lib/verilog_libs/altera_mf_ver
vmap altera_lnsim_ver C:/altera_pr/msim_lib/verilog_libs/altera_lnsim_ver
vmap cyclonev_ver C:/altera_pr/msim_lib/verilog_libs/cyclonev_ver
vmap cyclonev_hssi_ver C:/altera_pr/msim_lib/verilog_libs/cyclonev_hssi_ver
vmap cyclonev_pcie_hip_ver C:/altera_pr/msim_lib/verilog_libs/cyclonev_pcie_hip_ver
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/ip_core/RAM2 {C:/altera_pr/NoiseEst/ip_core/RAM2/Ram2.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/ip_core/ALTFP_CONVERT {C:/altera_pr/NoiseEst/ip_core/ALTFP_CONVERT/Int16ToFloat.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/ip_core/ALTFP_ADD_SUB {C:/altera_pr/NoiseEst/ip_core/ALTFP_ADD_SUB/FpAdd.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/ip_core/ALTFP_MULT {C:/altera_pr/NoiseEst/ip_core/ALTFP_MULT/FpMult.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst {C:/altera_pr/NoiseEst/Cameralink.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst {C:/altera_pr/NoiseEst/Top.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/ip_core/RAM2 {C:/altera_pr/NoiseEst/ip_core/RAM2/RamInit.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst {C:/altera_pr/NoiseEst/CalculateMatrix.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst {C:/altera_pr/NoiseEst/TransferMatrix.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/db {C:/altera_pr/NoiseEst/db/mult_6ct.v}

vlog -vlog01compat -work work +incdir+C:/altera_pr/NoiseEst/simulation/modelsim {C:/altera_pr/NoiseEst/simulation/modelsim/Top.vt}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  Top_vlg_tst

add wave *
add wave {sim:/Top_vlg_tst/i1/place_pix[0]/CalculateMatrix_inst/*}
view structure
view signals
run -all
