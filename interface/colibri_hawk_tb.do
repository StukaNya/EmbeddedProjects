transcript on
vmap altera_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/altera_ver
vmap lpm_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/lpm_ver
vmap sgate_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/sgate_ver
vmap altera_mf_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/altera_mf_ver
vmap altera_lnsim_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/altera_lnsim_ver
vmap cyclonev_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/cyclonev_ver
vmap cyclonev_hssi_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/cyclonev_hssi_ver
vmap cyclonev_pcie_hip_ver C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/MSim_lib/verilog_libs/cyclonev_pcie_hip_ver
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work


#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/factor_fifo_64w32r16 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/factor_fifo_64w32r16/factor_fifo_64w32r16.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/factor_fifo_64x16 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/factor_fifo_64x16/factor_fifo_64x16.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/frame_fifo_1kx16 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/frame_fifo_1kx16/frame_fifo_1kx16.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/BURST_FIFO_1024_x16 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/BURST_FIFO_1024_x16/burst_fifo_1024_x16.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/video_out_dc_fifo_1kx8 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/video_out_dc_fifo_1kx8/video_out_dc_fifo_1kx8.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/TEST_PATTERN {C:/altera_pr/Korsar/colibri_hawk/MGF/TEST_PATTERN/test_pattern_generator.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/fifo_32x17 {C:/altera_pr/Korsar/colibri_hawk/MGF/FIFO/fifo_32x17/fifo_32x17.v}
#RX
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/SDI_RX.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii/sdi_ii_0001.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_rx_protocol.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_hd_crc.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_hd_extract_ln.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_3gb_demux.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_trs_aligner.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_descrambler.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_format.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_receive.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_vpid_extract.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_trsmatch.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_hd_dual_link.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_RX_sim/sdi_ii_rx_protocol/mentor/src_hdl/sdi_ii_fifo_retime.v}
#TX
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/SDI_TX.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii/sdi_ii_0001.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/altera_reset_controller {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/altera_reset_controller/altera_reset_controller.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/altera_reset_controller {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/altera_reset_controller/altera_reset_synchronizer.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_tx_protocol.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_hd_crc.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_hd_insert_ln.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_scrambler.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_transmit.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_vpid_insert.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_trsmatch.v} 
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl {C:/altera_pr/Korsar/colibri_hawk/MGF/SDI/SDI_TX_sim/sdi_ii_tx_protocol/mentor/src_hdl/sdi_ii_sd_bits_conv.v}


vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/modelsim {C:/altera_pr/Korsar/colibri_hawk/SYSTEM/simulation/modelsim/colibri_hawk.vt}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/video_correction/video_correction.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/video_correction/lpddr_burst_driver_16bit.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/video_correction/hawk_videoAddTemp.v}
#vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/dallas_DS18B20.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL/video_correction {C:/altera_pr/Korsar/colibri_hawk/HDL/video_correction/test_video_generator_640x480_ycbcr.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/video_out_controller.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/pal_timing_generator.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/colorbars.v}
vlog -vlog01compat -work work +incdir+C:/altera_pr/Korsar/colibri_hawk/HDL {C:/altera_pr/Korsar/colibri_hawk/HDL/custom_sdi_tx.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  colibri_hawk_vlg_tst

add wave -group all_waves {sim:/colibri_hawk_vlg_tst/*}
#add wave -group correction {sim:/colibri_hawk_vlg_tst/video_cor_inst/*}
#add wave -group dallas_ds18b20 {sim:/colibri_hawk_vlg_tst/onewire_ds1820/*}
add wave -group test_stream {sim:/colibri_hawk_vlg_tst/test_video_inst/*}
add wave -group pal_generator {sim:/colibri_hawk_vlg_tst/vid_out_ctrl_inst/*}
add wave -group dci_rx {sim:/colibri_hawk_vlg_tst/sdi_rx_inst/*}
add wave -group dci_tx {sim:/colibri_hawk_vlg_tst/sdi_tx_inst/*}
add wave -group generator {sim:/colibri_hawk_vlg_tst/bt656/*}
add wave -group custom_tx {sim:/colibri_hawk_vlg_tst/custom_tx_inst/*}
add wave -group custom_rx {sim:/colibri_hawk_vlg_tst/custom_rx_inst/*}

view structure
view signals
run 1000 us