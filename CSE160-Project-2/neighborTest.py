from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("simple.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    #s.addChannel(s.COMMAND_CHANNEL);
    #s.addChannel(s.GENERAL_CHANNEL);
    #s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    #s.runTime(1);
    #s.ping(1, 2, "stuff");
    #s.runTime(1);
    s.runTime(1)
    s.ping(1, 19,"Hi");
    s.runTime(5);

    s.runTime(1);
    s.neighborDMP(1); # This is the node we want to check its neighbors
    s.runTime(1);

    s.neighborDMP(2);
    s.runTime(1);
    s.neighborDMP(3); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(4); # This is the node we want to checj its neighnors
    s.runTime(1);

    s.neighborDMP(5); # This is the node we want to checj its neighnors
    s.runTime(1);

    s.neighborDMP(6); # This is the node we want to checj its neighnors
    s.runTime(1);

    s.neighborDMP(7); # This is the node we want to checj its neighnors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(8); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(9); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(10); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(11); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(12); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(13); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(14); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(15); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(16); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(17); # This is the node we want to check its neighbors
    s.runTime(1);

    s.runTime(1);
    s.neighborDMP(18); # This is the node we want to check its neighbors
    s.runTime(1);

    s.neighborDMP(19); # This is the node we want to checj its neighnors
    s.runTime(1);

if __name__ == '__main__':
    main()
