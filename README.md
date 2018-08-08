# ds_simulator
A simple doublespend-relay simulator

by @im_uname 2018

License: MIT

Simple simulator that demonstrates the probability that the
first-transmitted transaction is going to be mined next block versus the
second-transmitted, under different network conditions and
configurations.

nodecount is the total number of nodes on the network. I assume all nodes
follow the "default" configuration; variable configurations TODO
 
minercount is the number of mining nodes on the network, selected at
random among nodes (minercount < nodecount). Hashpower is assumed to be
evenly distributed among miners; variable hashpower TODO

loopcount is the number of times the simulation runs to arrive at
p_firstmined. Loop more for more robust statistics.

connections is the number of connections each node has outgoing. Nodes
will randomly find other nodes and connect to them, resulting in a
variable graph with each node having minimum # connections set by this
number.

interval is a crude approximation of how long an attacker delays between
sending tx1 and tx2, in # cycles. If 0, both tx are sent out at the exact
same time. 
 
trickle is a boolean of whether the network relays using "trickle" logic
where 25% of the unsent inventory (picked at random) is sent out every cycle. At
the end of 20 cycles any unsent inventory is emptied out regardless.
Trickling is per connection.
 
txflow is background tx that does not matter, but put in there to aid
trickle simulation. Recommended to use 1 each cycle, which is fairly
heavy load. Each tx is sent to a random node on the network.

relay is a boolean whether to switch on doublespend relay or not. False
means strictly first seen (node that received tx1 will reject tx2 and
vice versa); True implies tx1 and tx2 can co-exist on the same node. When
True, miner will mine the tx that first arrived.
 
assume all tx becomes "inflight" on the round they're sent out, and
arrives in inv next round. Variable latencies TODO
