#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"
#include "../../includes/am_types.h"


configuration NodeC{
}
implementation {

     components MainC;
     components Node;
     components new AMReceiverC(AM_PACK) as GeneralReceive;

     Node -> MainC.Boot;

     Node.Receive -> GeneralReceive;

     components ActiveMessageC;
     Node.AMControl -> ActiveMessageC;

     components new SimpleSendC(AM_PACK);
	 Node.Sender -> SimpleSendC;

 	 components CommandHandlerC;
	 Node.CommandHandler -> CommandHandlerC;

     /* START */

     // Random
     components RandomC as Random;
     Node.Random -> Random;

     // Timer
     components new TimerMilliC() as myTimerC;
     Node.periodicTimer -> myTimerC;

     components new TimerMilliC() as myTimerC2;
     Node.periodicTimer2 -> myTimerC2;

     components new TimerMilliC() as myTimerC3;
     Node.periodicTimer3 -> myTimerC3;

     // List of  Packets for FLOODING
     components new ListC(pack, 19);
     Node.packet_List -> ListC;

     // List of  Packets for Neighbors
     components new nListC(pack, 2);
     Node.neighbor_List -> nListC;


     //Our failed attempt to make a linkstate structure

     //List for LinkState
     //components new ListC(pack 19);
     //Node.struct_List -> ListC;

    /* END */
}
