#include "scorpio_uart.h"
//#define DEBUG

#define BUF_OUT_WR_SZ	11
#define BUF_OUT_RD_SZ 	9
#define BUF_IN_WR_SZ	6
#define BUF_IN_RD_SZ	8
#define MAX_INT_SHIFT	12
#define CRC_SZ		4

int init_uart(FILE *fp) {
	fp = fopen("/dev/uart_scorpio", "r+");
	if (fp == NULL) {
		printf("Cannot open file.\n");
		return -1;
	}

	return 0;
}

int write_msg(FILE *fp, int addr, int data) {
	int crc_int, input_crc;
	char crc_buf[CRC_SZ + 1];
	char in_buf[BUF_IN_WR_SZ];
	char out_buf[BUF_OUT_WR_SZ + MAX_INT_SHIFT];
	//fill message str "@W102FF"
	out_buf[0] = '@';
	out_buf[1] = 'W';
	sprintf(out_buf + 2, "%03X", addr);
	sprintf(out_buf + 5, "%02X", data);
	//get 16bit CRC of "@W102FF"
	crc_int = CRC16(out_buf, BUF_OUT_WR_SZ - CRC_SZ);
	sprintf(out_buf + 7, "%04X", crc_int);
#ifdef DEBUG
	printf("(Write) Output buf: %s; gen crc: %x\n", out_buf, crc_int);
#endif
	//sending message
	if (fp == NULL) {
		printf("(Write) Cannot write to uart file.\n");
		return -1;
	} else {
		fwrite(out_buf, BUF_OUT_WR_SZ, 1, fp);
		fread(in_buf, BUF_OUT_RD_SZ, 1, fp);
	}
#ifdef DEBUG
	printf("(Write) Input buf: %s\n", in_buf);
#endif

	if ((in_buf[0] == '@') && (in_buf[1] == 'Y')) {
		//check input crc
		crc_int = (int) CRC16(in_buf, BUF_IN_WR_SZ - CRC_SZ);
		memcpy(crc_buf, in_buf + BUF_IN_WR_SZ - CRC_SZ, CRC_SZ);
		crc_buf[CRC_SZ] = '\0';
		input_crc = (int) strtol(crc_buf, NULL, 16);
#ifdef DEBUG
		printf("(Write) Input str crc: %s; atoi crc : %x; calc crc: %x\n", crc_buf, input_crc, crc_int);
#endif
		if (input_crc != crc_int) {
			printf("(Write) Wrong message (different crc sums).\n");
			return -1;
		} else
			return 0;
	} else {
		if ((in_buf[0] == '@') && (in_buf[1] == 'N')) {
			printf("(Write) Negative message (@N...).\n");
		} else {
			printf("(Write) Wrong message (not exist '@Y...').\n");
		}
		return -1;
	}

}

int read_msg(FILE *fp, int addr) {
	int crc_int, input_crc, input_data;
	char crc_buf[CRC_SZ + 1];
	char data_buf[3];
	char in_buf[BUF_IN_RD_SZ];
	char out_buf[BUF_OUT_RD_SZ + MAX_INT_SHIFT];
	//fill message str "@R102"
	out_buf[0] = '@';
	out_buf[1] = 'W';
	sprintf(out_buf + 2, "%03X", addr);
	//get 16bit CRC of "@R102"
	crc_int = (int) CRC16(out_buf, BUF_OUT_RD_SZ - CRC_SZ);
	sprintf(out_buf + 5, "%04X", crc_int);
#ifdef DEBUG
	printf("(Read) Output str buf: %s; gen crc: %x.\n", out_buf, crc_int);
#endif
	//sending read request
	fwrite(out_buf, BUF_OUT_RD_SZ, 1, fp);
	if (fp == NULL) {
		printf("(Read) Cannot read from uart.\n");
		return -1;
	} else {
		fwrite(out_buf, BUF_OUT_RD_SZ, 1, fp);
		fread(in_buf, BUF_IN_RD_SZ, 1, fp);
	}
#ifdef DEBUG
	printf("(Read) Input buf: %s\n", in_buf);
#endif

	if ((in_buf[0] == '@') && (in_buf[1] == 'Y')) {
		//check input crc
		crc_int = (int) CRC16(in_buf, BUF_IN_RD_SZ - CRC_SZ);
		memcpy(crc_buf, in_buf + BUF_IN_RD_SZ - CRC_SZ, CRC_SZ);
		crc_buf[CRC_SZ] = '\0';
		input_crc = (int) strtol(crc_buf, NULL, 16);
#ifdef DEBUG
		printf("(Read) Input str crc %s; atoi crc : %x; calc crc: %x\n", crc_buf, input_crc, crc_int);
#endif
		if (input_crc != crc_int) {
			printf("(Read) Wrong message (different crc sums).\n");
			return -1;
		}
		//get data from message (2 bytes)
		memcpy(data_buf, in_buf + 2, 2);
		data_buf[3] = '\0';
		input_data = (int) strtol(data_buf, NULL, 16);
#ifdef DEBUG
		printf("(Read) Input data buf: %s; atoi data: %x.\n", data_buf, input_data);
#endif
		return input_data;
	} else {
		if ((in_buf[0] == '@') && (in_buf[1] == 'N')) {
			printf("(Read) Negative message (@N...).\n");
		} else {
			printf("(Read) Wrong message (not exist '@Y...').\n");
		}
		return -1;
	}
}

int close_uart(FILE *fp) {
	if (fp == NULL) {
		printf("Cannot close file.\n");
		return -1;
	} else {
		fclose(fp);
	}

	return 0;
}

unsigned short CRC16(char *puchMsg, int usDataLen) {
	unsigned char uchCRCHi = 0xFF; // high byte of CRC initialized
	unsigned char uchCRCLo = 0xFF; // low byte of CRC initialized
	unsigned int uIndex; // will index into CRC lookup table
	int i = usDataLen;

	while (i--) // pass through message buffer
	{
		uIndex = uchCRCLo ^ *puchMsg++; /* calculate the CRC */
		uchCRCLo = uchCRCHi ^ auchCRCHi[uIndex];
		uchCRCHi = auchCRCLo[uIndex];
	}

	return (uchCRCHi << 8 | uchCRCLo);
}

