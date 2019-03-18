# CSE160-Computer_Networks-Project_2

Project 2: Link State Protocol

Design Decisions

Part 1: Receiving Packets
  For this project we first decided to build up our project using the implementation we had for
flooding. This meant that for the “receive” function we had to modify just a few lines to start receiving link state protocol messages. In us “receive” function we have two sections, the first one is for checking all the message containing protocols such as ping, ping reply and link state. The second section involves the simplest protocol which is neighbor discovery. For the ping, ping reply and link state section we started by checking if we had seen the message before. After learning that the message was new we checked the three main types of messages that we were supposed to receive. The first check was to find out if the message is for this node which meant that there was no other action than to receive the message. The second and third check was to see if the destination was (AM broadcast) or (Node). If the destination is (AM broadcast) it means that it’s a link state message that includes neighbors of a node. If the destination of the package received is a (Node) it means that it should be forwarded either through flooding or the link state lookup table. For this project we are specifically using the lookup table that we created with the link state messages to forward our ping messages.

Part 2: Creating Link State Packets
  For creating link state packets, we used an array to store the neighbor information of the node
trying to send the link state information. The structure was arranged by assigning each index a specific node. If there was a neighbor connection, we would assign that node index the cost and if there was no connection we assigned a value of zero. After creating the specific link state packet, we decided to send it to all of the other nodes using the flooding protocol we previously implemented on project 1.

Part 3: Receiving Link State Packets and Creating the Routing Table
  Initially when we receive link state packets from other nodes we store them in a new array which
would tell us all of the nodes neighbors and their cost to reach each neighbor. In reality this table gives us enough information to build the topology of the network which in turn allows us to find the shortest path to every node. To calculate this shortest path, we implemented a version of Dijkstra’s algorithm that gave us the shortest path to reach every node in the network. After calculating the shortest paths of all nodes, we then created our goal product which is the routing table. The information that this routing table holds is a two-dimensional array of the next node that should receive the message.

Part 4: Timers
  Ultimately our link state protocol would not be very efficient if we did not implement timers to
prevent the immense amount of information from running continuously. In result we decided to use three timers, the first one was for neighbor discovery, then a second timer for making and sending link state packages to nodes, the third timer was used to recalculate Dijkstra’s and update the routing table. Each timer had a different time to run, the shortest timer is neighbor discovery, then a little longer timer would be for link state and longer for Dijkstra’s and updating routing table. We mainly decided to assign time in this order to allow neighbor discovery and link state packages propagate through the network first before calculating our routing table. This is very beneficial for updating the routing table since it would prevent useless recalculations of Dijkstra’s with old information.
