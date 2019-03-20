#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/protocol.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include <limits.h>

enum{
   MAX_NEIGHBORS = 20
};

module Node{

     uses interface Boot;
     uses interface SplitControl as AMControl;
     uses interface Receive;
     uses interface SimpleSend as Sender;
     uses interface CommandHandler;

     /* START */
     uses interface Random;
     uses interface Timer<TMilli> as periodicTimer;
     uses interface Timer<TMilli> as periodicTimer2;
     uses interface Timer<TMilli> as periodicTimer3;
     uses interface List<pack> as packet_List;
     uses interface nList<pack> as neighbor_List;
     uses interface List<pack> as struct_List;
     /* END */
}


implementation{

   pack sendPackage;

   uint16_t start_time_neighbor_discovery, start_time_linkstate, start_time_dijkstra;

   //linkstate structure. Stores all neighbors of the node + cost
   uint8_t neighborsToSend[MAX_NEIGHBORS];

   //linkState linkStatePack;                                 //Empty Linkstate struct aka does not work

   uint8_t lookupTable[MAX_NEIGHBORS][2];                     //Array that stores next hop node id
   //uint8_t lsupdated[MAX_NEIGHBORS];

   //Dijsktras Global Variables
   uint8_t routingTable[MAX_NEIGHBORS+1][MAX_NEIGHBORS+1]; //Final Routing Table
   uint8_t V = MAX_NEIGHBORS+1;                              //number of nodes on Network
   uint32_t k = 0;
   uint8_t count;
   uint8_t nextDest;

   //Implemented Fuctions
   void linkStateUpdate();
   void dijkstra(uint8_t graph[V][V], uint8_t src);
   uint8_t lookup(uint8_t dest);
   void printLookup();
   void neighbor_discovery();

    

   
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
  

   event void Boot.booted(){

      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");

      start_time_neighbor_discovery = (call Random.rand16()%6000 + 7000);
      start_time_linkstate = (call Random.rand16()%4000 + 3050);
      start_time_dijkstra = (call Random.rand16()%8000 + 5000);
   }

   event void AMControl.startDone(error_t err){
      
      uint16_t i, j;

      

      dbg(GENERAL_CHANNEL, "Random time generated for neighbor discovery: %lums \n", start_time_neighbor_discovery);
      dbg(GENERAL_CHANNEL, "Random time generated for linkState: %lums \n", start_time_linkstate);
      dbg(GENERAL_CHANNEL, "Random time generated for dijkstra: %lums \n", start_time_dijkstra);

      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n\n\n");

         //neighbor discovery initiated
         call periodicTimer.startPeriodic(start_time_neighbor_discovery);
         call periodicTimer2.startPeriodic(start_time_linkstate);
         call periodicTimer3.startPeriodic(start_time_dijkstra);

        // for(i = 0; i<MAX_NEIGHBORS; i++){
         //	lsupdated[i] = 0;
         //}

         for(j = 0; j<MAX_NEIGHBORS; j++){
         	lookupTable[j][0] = j+1;
         	lookupTable[j][1] = 0;
         }

         neighbor_discovery();
         linkStateUpdate();
         dijkstra(routingTable, TOS_NODE_ID);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      uint16_t i, j;

      if(len==sizeof(pack)){

          pack* myMsg = (pack*) payload;

          

           if(myMsg->protocol == PROTOCOL_LINKSTATE && myMsg->dest != AM_BROADCAST_ADDR){
            dbg(ROUTING_CHANNEL, "Link State protocol Packet Received\n");
            //logPack(myMsg);
           }


          if(myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY || myMsg->protocol == PROTOCOL_LINKSTATE){

               for(i = 0; i < call packet_List.size(); i++){

                  pack pkg = call packet_List.get(i);

                   if(myMsg->protocol == PROTOCOL_PINGREPLY){

                    //Used to output message content
                    //logPack(myMsg);

                    //For package acknowledgement, for ping reply
                    if(myMsg->seq == pkg.seq && myMsg->seq == 0){

                         myMsg->TTL = 0;

                         dbg(PING_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
                         dbg(PING_CHANNEL, "---Ping Reply Acknowledged---\n");
                         dbg(PING_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n");

                         call packet_List.remove(i); //remove previously seen package

                         return msg;
                    }
                    else if(myMsg->seq == pkg.seq){

                         dbg(PING_CHANNEL,"-----Ping Reply Message-----\n");
                         dbg(PING_CHANNEL,"Received from: Node (%lu) \n", myMsg->src);
                         dbg(PING_CHANNEL,"Sending to:    Node (%lu) \n", pkg.src);

                         myMsg->src = pkg.src;

                         call packet_List.remove(i); //remove previously seen package

                         makePack(myMsg, TOS_NODE_ID, myMsg->dest, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq - 1, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

                         call Sender.send(*myMsg, pkg.src );
                         dbg(FLOODING_CHANNEL, "\n\n");
                         return msg;
                    }

                  }

                    if(myMsg->protocol == PROTOCOL_PING ){
                        //      
                      if((myMsg->seq > pkg.seq)){

                         dbg(GENERAL_CHANNEL, "\n\n\n");
                         dbg(GENERAL_CHANNEL, "******************************************************\n");
                         dbg(GENERAL_CHANNEL, " Node %lu Already Visited, Dropping package from Node %lu \n", pkg.src, myMsg->src);
                         dbg(GENERAL_CHANNEL, "******************************************************\n");
                         dbg(GENERAL_CHANNEL, "\n\n\n");
                         myMsg->TTL = 0;

                         return msg;
                    }
              }

            }

              if(myMsg->protocol == PROTOCOL_PING){

                  call packet_List.pushfront(*myMsg);
              }



               dbg(FLOODING_CHANNEL, "Node (%lu) Received Packet from Node (%lu) with seq: %lu\n", TOS_NODE_ID, myMsg->src, myMsg->seq);
               call packet_List.pushfront(*myMsg);
               dbg(FLOODING_CHANNEL, "\n");

              if(myMsg->dest == TOS_NODE_ID ){

                        pack sendpkg = call packet_List.front();
                        myMsg->TTL = MAX_TTL;

                        dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
                        dbg(GENERAL_CHANNEL, "Ping Packet Delivered!!!\n");
                        dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
                        dbg(GENERAL_CHANNEL, "Ping Reply initiated...\n\n\n");

                        makePack(myMsg, TOS_NODE_ID, myMsg->src, myMsg->TTL, PROTOCOL_PINGREPLY, myMsg->seq-1, "reply", PACKET_MAX_PAYLOAD_SIZE);
                        call Sender.send(*myMsg, myMsg->src);
                        return msg;

              }else if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_LINKSTATE){

                dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");
                dbg(GENERAL_CHANNEL, "Routing Packet Delivered!!!\n");
                
                logPack(myMsg);
                dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n");
                return msg;

              }else if(myMsg->dest == AM_BROADCAST_ADDR){


                if(myMsg->src == TOS_NODE_ID){
                  return msg;
                } 

                //&& lsupdated[myMsg->src] == 0

                if(myMsg->TTL != 0 ){
                    //lsupdated[myMsg->src] = 1;
                    
                    for(j = 0; j < MAX_NEIGHBORS+1; j++){
                      for(k = 0; k < MAX_NEIGHBORS+1; k++){
                        if (myMsg->src == j){
                          routingTable[j][k] = myMsg->payload[k];
                        }
                      }

                }

                    makePack(myMsg, myMsg->src, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq+1, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(*myMsg, AM_BROADCAST_ADDR);
                    return msg;
                }


                return msg;

              }else if (myMsg->dest != AM_BROADCAST_ADDR){
                    
                    if(myMsg->protocol == PROTOCOL_LINKSTATE){
                      if(lookup(myMsg->dest) == 0){
                        // dbg(ROUTING_CHANNEL, "BAD1");
                    	   return msg;
                      }else{
                        uint8_t looktmp = lookup(myMsg->dest);

                        dbg(ROUTING_CHANNEL, "Not Reached Destination Node (%lu)\n", myMsg->dest);
                        dbg(ROUTING_CHANNEL, "Lookup table to Node (%lu) next hop is Node (%lu)\n", myMsg->dest, looktmp);
                        printLookup();
                        dbg(ROUTING_CHANNEL, "Packet will be forwarded\n");
                        dbg(ROUTING_CHANNEL, "Sending Out...\n\n\n\n");
                
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_LINKSTATE, myMsg->seq+1, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                        //dbg(ROUTING_CHANNEL, "~~~~~~~~~~~~~~~~~Package Info~~~~~~~~~~~~~~~~~~\n");
                        //logPack(myMsg);
                        //dbg(ROUTING_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n");
                        call Sender.send(sendPackage, looktmp);
                        return msg;
                      }
                    }else{

                    if( myMsg->TTL != 0 ){
                        dbg(FLOODING_CHANNEL, "Sending Out...\n");
                        dbg(FLOODING_CHANNEL, "\n");
                        makePack(myMsg, myMsg->src, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                        dbg(FLOODING_CHANNEL, "~~~~~~~~~~~~~~~~~Package Info~~~~~~~~~~~~~~~~~~\n");
                        logPack(myMsg);
                        dbg(FLOODING_CHANNEL, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n");
                        call Sender.send(*myMsg, AM_BROADCAST_ADDR);
                        return msg;
                    }
                    dbg(FLOODING_CHANNEL, "Packet Timed Out\n\n");
                }
              }

               dbg(GENERAL_CHANNEL,"BAD");
               return msg;
            }

          if(myMsg->protocol == PROTOCOL_NEIGHBOR){

             myMsg->seq += 1;

             // One Jump to location One Jump back
             if(myMsg->seq == 2){

                  uint16_t size = call neighbor_List.size();

                  for(k = 0; k < size; k++){

                       // getting contents
                       pack pkg = call neighbor_List.get(k);

                       // if stored src == current src
                       if(pkg.src == myMsg->src) {
                            return msg;
                       }
                  }


                  call neighbor_List.pushfront(*myMsg);
             }
              if(myMsg->seq = 1){

                  myMsg->TTL = 0;
                  makePack(myMsg, TOS_NODE_ID, myMsg->src, 1, PROTOCOL_NEIGHBOR, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  call Sender.send(*myMsg, myMsg->dest);
             }

             return msg;
          }

       return msg;
      }

      dbg(GENERAL_CHANNEL, "RECEIVE ERROR!!! %d\n", len);
      return msg;
   }



   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){

        pack tempPack;
        
      	//dbg(GENERAL_CHANNEL, "derivative %lu \n", lookup(destination));

        nextDest = lookup(destination);
	      dbg(GENERAL_CHANNEL, "PING EVENT, DESTINATION: %lu\n", destination);
        dbg(ROUTING_CHANNEL, "Looking up table to Node (%lu) next hop is Node (%lu)\n", destination, nextDest);
        if(nextDest == 0){
                        dbg(ROUTING_CHANNEL, "cannot send pack\n");
           
        }else{
	      makePack(&sendPackage, TOS_NODE_ID, destination, 19, PROTOCOL_LINKSTATE, 1, payload, PACKET_MAX_PAYLOAD_SIZE);

	      tempPack = sendPackage;
	      makePack(&tempPack, TOS_NODE_ID, destination, 19, PROTOCOL_LINKSTATE, 1 , payload, PACKET_MAX_PAYLOAD_SIZE);
	      call packet_List.pushfront(tempPack);
        dbg(ROUTING_CHANNEL, "Sending Out...\n\n\n\n");
	      call Sender.send(sendPackage, nextDest);
      }
  	   
   }



   event void periodicTimer.fired(){
	   neighbor_discovery();
   }

	 event void periodicTimer2.fired(){

		  uint8_t i;
		  //for(i = 0; i < MAX_NEIGHBORS; i++){
			// lsupdated[i] = 0;
		  //}

      linkStateUpdate();
   }

   event void periodicTimer3.fired(){

      dijkstra(routingTable, TOS_NODE_ID);  
   }


   event void CommandHandler.printNeighbors(){

      uint32_t i;

      dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~Printing Neighbor List~~~~~~~~~~~~~~~\n");
      dbg(GENERAL_CHANNEL,"Node: %lu  has %lu Neighbor(s)......\n", TOS_NODE_ID , call neighbor_List.size());

      for(i = 0; i < call neighbor_List.size() ; i++){

        pack neighbor = call neighbor_List.get(i);
        dbg(NEIGHBOR_CHANNEL, "Neighbor %lu: %lu \n", i+1, neighbor.src);
      }

      dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~Done Printing~~~~~~~~~~~~~~~~~~~~~~~~\n\n\n");
   }




   //These two shits(printRouteTable, printLinkState) might be helpful
   //and prob need to be implemented before we submit
   event void CommandHandler.printRouteTable(){
    uint16_t i, j;

    dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~Routing Table~~~~~~~~~~~~~~~\n");

    for(i = 0; i < MAX_NEIGHBORS; i++){
                for(j = 0; j < MAX_NEIGHBORS; j++){
                    dbg(ROUTING_CHANNEL, "%lu  ",routingTable[i][j]);
                }
              dbg(ROUTING_CHANNEL, "\n");
        }
    dbg(GENERAL_CHANNEL, "~~~~~~~~~~~~~~~Done Printing~~~~~~~~~~~~~~~~~~~~~~~~\n\n\n");
   }

   event void CommandHandler.printLinkState(){
    printLookup();
   }






   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   //A witchcraft cauldron that mixes all of the package ingredients into a message form
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
   }

   //function that discovers neighbors and makes linkstate update
   void neighbor_discovery(){

        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, PROTOCOL_NEIGHBOR, 0, "Neighbor Discovery Payload", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }


////////////////////////////////////////////////Linkstate START///////////////////////////////////////////

   //This function essentially has one job
   //which is to broadcast the current node neighbor list
   //to all its friends
   void linkStateUpdate(){

     uint32_t i, j;

     pack tmpNeighborPack;

      for(i = 0; i < call neighbor_List.size(); i++){

         tmpNeighborPack = call neighbor_List.get(i);
         neighborsToSend[tmpNeighborPack.src] = 1;

         //Add your neighbors to routing table
         for(j = 1; j < MAX_NEIGHBORS; j++){
			     for(k = 1; k < MAX_NEIGHBORS; k++){
      				if (TOS_NODE_ID == j){
      					if(tmpNeighborPack.src == k)
      							routingTable[j][k] = 1;
      					}
      				}
			   }

      }

      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKSTATE, 0, (uint8_t*) neighborsToSend, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }

////////////////////////////////////////////////Linkstate END///////////////////////////////////////////








////////////////////////////////////////////////Lookup Table START///////////////////////////////////////////

  uint8_t lookup(uint8_t desti){

  			if(lookupTable[desti-1][1] == 0){
  				dbg(ROUTING_CHANNEL, "Im sorry I have no knoledge for the next node\n Packet will be droped :(\n\n");
          printLookup();
  				return 0;
  			}else{
  				return lookupTable[desti-1][1];
  			}

  }

  void printLookup(){
  	uint8_t i;
  	dbg(GENERAL_CHANNEL, "Printing lookupTable: \n");
  	for(i = 0; i < MAX_NEIGHBORS; i++){
  		dbg(ROUTING_CHANNEL, "%lu   %lu\n\n", lookupTable[i][0], lookupTable[i][1]);
  	}
  }

////////////////////////////////////////////////Lookup Table END///////////////////////////////////////////








////////////////////////////////////////////////Djkstra START///////////////////////////////////////////



	void printPath(int8_t parent[], uint8_t j, uint8_t final_dest){


		if(parent[j] == -1){
			return;
		}

		printPath(parent, parent[j], final_dest);

		//dbg(ROUTING_CHANNEL, "%d \n", j);

    if(count == 0){
      //dbg(ROUTING_CHANNEL, "--%d \n", final_dest);
      lookupTable[final_dest-1][1] = j;
      //dbg(ROUTING_CHANNEL, "**%d \n", j);
    }
    count++;

	}

	int minDistance(uint8_t dist[], uint8_t sptSet[]){

		// Initialize min value
		uint8_t min;
		uint8_t v;
		uint8_t min_index;

		min = INT_MAX;
		min_index;

		for (v = 0; v < V; v++)
			if (sptSet[v] == 0 && dist[v] <= min)
				min = dist[v], min_index = v;

		return min_index;
	}


	int printSolution(uint8_t dist[], uint8_t n, int8_t parent[]){

		uint8_t i, src = TOS_NODE_ID;

		//dbg(ROUTING_CHANNEL, "Vertex\t Distance\tPath \n");
		for ( i = 1; i < V; i++){

			//printf("\n%d -> %d \t\t %d\t\t%d ", src, i, dist[i], src);
			//dbg(ROUTING_CHANNEL, "%d -> %d \t distance: %d\n", src, i , dist[i]);
			//dbg(ROUTING_CHANNEL, ("\n%d -> %d \t\t %d\t\t%d \n", src, i, dist[i], src));

      count = 0;
			printPath(parent, i, i);
		}
	}


	void dijkstra(uint8_t graph[V][V], uint8_t src){

		uint8_t dist[V];
		uint8_t sptSet[V];
		int8_t parent[V];
		uint8_t i;
		uint8_t v;
		uint8_t u;
		uint8_t j, count;



		for (i = 0; i < V; i++){
			dist[i] = INT_MAX;
			sptSet[i] = 0;
			parent[i] = -1;
		}


		dist[src] = 0;
		for (count = 0; count < V - 1; count++){
			u = minDistance(dist, sptSet);
			sptSet[u] = 1;

			for (v = 0; v < V; v++)
				if (!sptSet[v]){
					if(dist[u] + graph[u][v] < dist[v]){
						if(graph[u][v]){
							parent[v] = u;
							dist[v] = dist[u] + graph[u][v];
						}
					}
				}
		}

		printSolution(dist, V, parent);
		//dbg(ROUTING_CHANNEL, "\n------------------ \n");
	}

////////////////////////////////////////////////Djkstra END///////////////////////////////////////////

}
