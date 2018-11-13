

#include <stdio.h>
#include <io.h>
#include <system.h>
#include <string.h>
#include <alt_types.h>
#include "hawk_cmd_regs.h"
#include "altera_avalon_timer_regs.h"
#include "sys/alt_alarm.h"
#include "scorpio_uart.h"

/******************************************************
 * Constants
*******************************************************/
#define DEBUG
//Hardcoded addresses from hardware
#define RAM_TABLES_BASE		0x04000000
#define RAM_TABLES_SIZE		0x00200000

/******************************************************
 *
 * Global variables
*******************************************************/
alt_u32* const ram_tables = (alt_u32*)RAM_TABLES_BASE;

//Scorpio uart
FILE *scorpio_fp = NULL;

//Timer alarm flag modified in callback
volatile unsigned char timer_event_flag = 0;
alt_u32 timer_subdiv = 0;
alt_alarm ts;

/******************************************************
 * Main functions
*******************************************************/
alt_u32 alarm_handler(void* context)
{
	timer_event_flag=1;
	return 1;
}


static void init(void)
{
//	register_sys_timer_interrupt();
	FILE *temp_fp = NULL;
	init_uart(temp_fp);
	if (temp_fp == NULL)
	{
		scorpio_fp = fopen("/dev/uart_scorpio", "r+");
		printf ("Open file (scorpio): %x\n", (unsigned int)scorpio_fp);
	}
	else
	{
		printf ("Open file (temp): %x\n", (unsigned int)temp_fp);
		scorpio_fp = temp_fp;
	}

	alt_alarm_start(&ts, 1, alarm_handler, NULL);
	//Ethernet connection
//	init_bridge_irq();
}


static void run(void)
{
	int addr, data, response;
	addr = 0x102;
	data = 0x03;
	while (1)
	{
		if (timer_event_flag)
		{
			timer_event_flag = 0;
			timer_subdiv++;
			if (timer_subdiv >= 1000)
			{
				if (scorpio_fp != NULL)
				{
					addr++;
					data++;
					response = write_msg(scorpio_fp, addr, data);
					printf("(Main) Response of write_msg: %x\n", response);
					response = read_msg(scorpio_fp, addr);
					printf("(Main) Response of read_msg: %x\n", response);
				}
			}
		}
	}

	close_uart(scorpio_fp);
}


int main(void)
{
/*
	FILE *fp = NULL;
	fp = fopen ("/dev/uart_scorpio", "r+");

	int addr, data, response;
	addr = 0x100;
	data = 0x03;
	//response = write_msg(fp, addr, data);
	//response = read_msg(fp, 0x102);

	response = CRC16("@R102", 5);
	printf("CRC @R102 (5 symbols) %x\n", response);
	response = CRC16("@R102", 6);
	printf("CRC @R102 (6 symbols) %x\n", response);

	response = CRC16("@W10003", 7);
	printf("CRC @W10003 (7 symbols) %x\n", response);
	response = CRC16("@W10003", 8);
	printf("CRC @W10003 (8 symbols) %x\n", response);

	response = (int)strtol("FD71", NULL, 16);
	printf("strtol: %x", response);
	close_uart(fp);
	*/

	init();
	run();

	return 0;
}

