#include <stdlib.h>

#include <FreeRTOS.h>
#include <xil_cache_l.h>
#include <xil_io.h>

#include <lwip/init.h>
#include <lwip/sockets.h>
#include <lwip/sys.h>
#include <netif/xadapter.h>
#include <xparameters_ps.h>

#include "xqspips.h"
#include "xiicps.h"
//#include <lwipopts.h>

#include "local.h"
#include "control.h"
#include "pl_regs.h"
#include "qspi_flash.h"

psc_key* the_server;

struct ScaleFactorType scalefactors[4];
XQspiPs QspiInstance;
XIicPs IicPsInstance0;	    // si570
XIicPs IicPsInstance1;      // eeprom, one-wire

uint32_t git_hash;


static
void client_event(void *pvt, psc_event evt, psc_client *ckey)
{
    if(evt!=PSC_CONN)
        return;
    // send some "static" information once when a new client connects.
    struct {
        uint32_t git_hash;
        uint32_t serial;
    } msg = {
        .git_hash = htonl(git_hash),
        .serial = 0, // TODO: read from EEPROM
    };
    (void)pvt;

    psc_send_one(ckey, 0x100, sizeof(msg), &msg);
}

static
void client_msg(void *pvt, psc_client *ckey, uint16_t msgid, uint32_t msglen, void *msg)
{
    (void)pvt;

	//xil_printf("In Client_Msg:  MsgID=%d   MsgLen=%d\r\n",msgid,msglen);


    //blink front panel LED
    Xil_Out32(XPAR_M_AXI_BASEADDR + IOC_ACCESS_REG, 1);
    Xil_Out32(XPAR_M_AXI_BASEADDR + IOC_ACCESS_REG, 0);

    switch(msgid) {
        case 0:
        	glob_settings(msg);
        	break;

        case 1:
        case 2:
        case 3:
        case 4:
         	chan_settings(msgid,msg,msglen);
            break;
        case 101:
        	write_ramptable(1,msg,msglen);
            break;
        case 102:
        case 103:
        case 104:
            break;
    }



}

static
void on_startup(void *pvt, psc_key *key)
{
    (void)pvt;
    (void)key;
    lstats_setup();
    sadata_setup();
    snapshot_setup();
    console_setup();
}

static
void realmain(void *arg)
{
    (void)arg;

    printf("Main thread running\n");

    {
        net_config conf = {};
        sdcard_handle(&conf);
        InitSettingsfromQspi();
        net_setup(&conf);

    }

    discover_setup();
    //tftp_setup();

    const psc_config conf = {
        .port = 3000,
        .start = on_startup,
        .conn = client_event,
        .recv = client_msg,
    };
    
    psc_run(&the_server, &conf);
    while(1) {
        fprintf(stderr, "ERROR: PSC server loop returns!\n");
        sys_msleep(1000);
    }
}

void print_firmware_version()
{

    time_t epoch_time;
    struct tm *human_time;
    char timebuf[80];

    xil_printf("Module ID Number: %x\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + ID));
    xil_printf("Module Version Number: %x\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + VERSION));
    xil_printf("Project ID Number: %x\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + PRJ_ID));
    xil_printf("Project Version Number: %x\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + PRJ_VERSION));
    //compare to git commit with command: git rev-parse --short HEAD
    xil_printf("Git Checksum: %x\r\n", Xil_In32(XPAR_M_AXI_BASEADDR + PRJ_SHASUM));
    epoch_time = Xil_In32(XPAR_M_AXI_BASEADDR + PRJ_TIMESTAMP);
    human_time = localtime(&epoch_time);
    strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", human_time);
    xil_printf("Project Compilation Timestamp: %s\r\n", timebuf);
}



void InitSettingsfromQspi() {

    u32 chan;
    u8 readbuf[FLASH_PAGE_SIZE];

    // global values - hardcode for now
    Xil_Out32(XPAR_M_AXI_BASEADDR + EVR_INJ_EVENTNUM_REG, 10);
    Xil_Out32(XPAR_M_AXI_BASEADDR + EVR_PM_EVENTNUM_REG, 10);

    //channel values, readfromflash and write FPGA registers
    for (chan=1; chan<=4; chan++) {
       xil_printf("Channel : %d\r\n",chan);
   	   QspiFlashRead(chan*FLASH_SECTOR_SIZE, FLASH_PAGE_SIZE, readbuf);
       QspiDisperseData(chan,readbuf);
       xil_printf("\r\n\r\n");
    }

}



int main(void) {

	u32 i, base;
	//float multa = 3.14;
	//float multb = -1.5;
	//u32 multres;
	//MsgUnion multres, multa, multb;




    xil_printf("Power Supply Controller\r\n");
    print_firmware_version();

	init_i2c();
	prog_si570();
	QspiFlashInit();

   //multa.f = 4.3456;
   //multb.f = -100.5;

   //base = Xil_In32(XPAR_M_AXI_BASEADDR + DPID_SETPTOUT_REG + 0x200);

	//Xil_Out32(XPAR_M_AXI_BASEADDR + MULTA_REG, multa.u);
	//Xil_Out32(XPAR_M_AXI_BASEADDR + MULTB_REG, multb.u);

    usleep(100);



    //multres.u = Xil_In32(XPAR_M_AXI_BASEADDR + MULTRES_REG);
    //converter.u = multres;
    //printf("Mult Result = %f\n",multres.f);


	//EVR reset
    xil_printf("Resetting EVR GTX...\r\n");
	Xil_Out32(XPAR_M_AXI_BASEADDR + EVR_RESET_REG, 0);

	//Set Fault Enable Register - Move to gateware
	for (i=1;i<5;i++) {
	       base = XPAR_M_AXI_BASEADDR + i * CHBASEADDR;
	       Xil_Out32(base + FAULT_MASK_REG,0x1FEF);
	}



    sys_thread_new("main", realmain, NULL, THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);

    // Run threads.  Does not return.
    vTaskStartScheduler();
    // never reached
    return 42;
}
