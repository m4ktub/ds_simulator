function [p_firstmined,std_firstmined,firsttable] = ds_simulator(nodecount,minercount,loopcount,connections,interval,trickle,relay)

% ds_simulator, by @im_uname 2018
%
% License: MIT
%
% Simple simulator that demonstrates the probability that the
% first-transmitted transaction is going to be mined next block versus the
% second-transmitted, under different network conditions and
% configurations.
%
% nodecount is the total number of nodes on the network. I assume all nodes
% follow the "default" configuration; variable configurations TODO
% 
% minercount is the number of mining nodes on the network, selected at
% random among nodes (minercount < nodecount). Hashpower is assumed to be
% evenly distributed among miners; variable hashpower TODO
%
% loopcount is the number of times the simulation runs to arrive at
% p_firstmined. Loop more for more robust statistics.
%
% connections is the number of connections each node has outgoing. Nodes
% will randomly find other nodes and connect to them, resulting in a
% variable graph with each node having minimum # connections set by this
% number.
%
% interval is a crude approximation of how long an attacker delays between
% sending tx1 and tx2, in # cycles. If 0, both tx are sent out at the exact
% same time. 
% 
% trickle is a boolean of whether the network relays using "trickle" logic
% where 25% of the unsent inventory (picked at random) is sent out every cycle. At
% the end of 20 cycles any unsent inventory is emptied out regardless.
% Trickling is per connection.
% 
% txflow is background tx that does not matter, but put in there to aid
% trickle simulation. Recommended to use 1 each cycle, which is fairly
% heavy load. Each tx is sent to a random node on the network.
% 
% relay is a boolean whether to switch on doublespend relay or not. False
% means strictly first seen (node that received tx1 will reject tx2 and
% vice versa); True implies tx1 and tx2 can co-exist on the same node. When
% True, miner will mine the tx that first arrived
%
% assume all tx becomes "inflight" on the round they're sent out, and
% arrives in inv next round. Variable latencies TODO

% first generate structures and fill it with node inventories per
% connection

% constants, can be variable later

txflow = 1;

inventory = 100; % number << 1000, simulate initial inventory state

% null outputs

p_firstmined = 1;

std_firstmined = 0;

firsttable = zeros(loopcount,1);

for h = 1:loopcount
    disp(['perm loop' num2str(h)])
    coinnet = struct;
    
    % pick miners at random
    mining = randperm(nodecount,minercount);
    
    % start a connections table for this loop
    conntable = [];
    
    % fill inventories
    
    for i = 1:nodecount

        coinnet(i).mempool = [];
        coinnet(i).inflight = [];
        % create connections
        peerpool = [1:i-1,i+1:nodecount];
        peerids = randperm(size(peerpool,2),connections);
        outgoing = peerpool(peerids);
        % add to the conntable
        conntemp = [repmat(i,1,connections);outgoing]';
        conntable = [conntable ; conntemp];
        for j = 1:connections
            coinnet(i).conn(j).id = outgoing(j);
            coinnet(i).conn(j).inv = randperm(1000,inventory);
            coinnet(i).conn(j).invsent = [];
            coinnet(i).mempool = sunique([coinnet(i).mempool coinnet(i).conn(j).inv]);
        end
    end
    
    % match outgoing connections to their destination, fill those inv as
    % well
    
    for i = 1:size(conntable,1)
        % check if a reverse does not already exist
        if ismember([conntable(i,2) conntable(i,1)],conntable,'rows')
            continue
        else
            coinnet(conntable(i,2)).conn(end+1).id = conntable(i,1);
            coinnet(conntable(i,2)).conn(end).inv = randperm(1000,inventory);
            coinnet(conntable(i,2)).conn(end).invsent = [];
            coinnet(conntable(i,2)).mempool =...
                sunique([coinnet(conntable(i,2)).mempool coinnet(conntable(i,2)).conn(end).inv]);
            conntable = [conntable;[conntable(i,2) conntable(i,1)]];
        end
    end
        
    % start the loop proper! tx1 is added to inv of node 1 at
    % beginning of each cycle. tx2 is added to inv of node 2 after
    % interval.
    
    count = 1;
    randtx = 1003;
    while true
        % add tx1 to node1 inv
        if count == 1
            for j = 1:size(coinnet(1).conn,2)
                coinnet(1).conn(j).inv = [coinnet(1).conn(j).inv,1001];
                coinnet(1).mempool = [coinnet(1).mempool, 1001];
            end
        end
        
        % add tx2 to node2 inv if time is up
        if count == interval + 1
            coinnet(2).mempool = [coinnet(2).mempool,1002];
            if ~relay % tx2 will never relay if tx1 is already seen and no ds relay
                coinnet(2).mempool = ridsecond(coinnet(2).mempool);
            end
            
            for j = 1:size(coinnet(2).conn,2)
                coinnet(2).conn(j).inv = [coinnet(2).conn(j).inv,1002];
                if ~relay
                    coinnet(2).conn(j).inv = ridsecond(coinnet(2).conn(j).inv);
                end
                
            end
        end
        
        % add a random tx, count of which determined by txflow, to a random
        % node
        for g = 1:txflow
            randomnode = randperm(nodecount,1);
            coinnet(randomnode).mempool = [coinnet(randomnode).mempool,randtx];
            for j = 1:size(coinnet(randomnode).conn,2)
                coinnet(randomnode).conn(j).inv = [coinnet(randomnode).conn(j).inv,randtx];
            end
            % increment randtx "id"
            randtx = randtx + 1;
        end
        
        % add tx in flight from previous round to mempool and inv of its destination
        sendorder = randperm(nodecount,nodecount);
        for ii = 1:nodecount
            i = sendorder(ii);
            coinnet(i).mempool = sunique([coinnet(i).mempool coinnet(i).inflight]);
            if ~relay % tx2 will never relay if tx1 is already seen and no ds relay
                coinnet(i).mempool = ridsecond(coinnet(i).mempool);
            end
            for j = 1:size(coinnet(i).conn,2)
                deducted = coinnet(i).inflight(~ismember(coinnet(i).inflight,coinnet(i).conn(j).invsent));
                coinnet(i).conn(j).inv = sunique([coinnet(i).conn(j).inv deducted]);
                if ~relay
                    coinnet(i).conn(j).inv = ridsecond(coinnet(i).conn(j).inv);
                end
            end
            coinnet(i).inflight = []; % cleanout, decrease memory use
            
            
        end
        
        
        % start relaying! put inv content into destination inflights
        for ii = 1:nodecount
            i = sendorder(ii);
            for j = 1:size(coinnet(i).conn,2)
                if ~trickle
                    % immediate relay
                    coinnet(coinnet(i).conn(j).id).inflight =...
                        sunique([coinnet(coinnet(i).conn(j).id).inflight,...
                        coinnet(i).conn(j).inv]);
                    coinnet(i).conn(j).invsent =...
                        sunique([coinnet(i).conn(j).invsent,...
                        coinnet(i).conn(j).inv]);
                    coinnet(i).conn(j).inv = [];
                        
                else
                    % trickle relay; mimic "25% chosen at random to relay"
                    % rule
                    if isempty(coinnet(i).conn(j).inv)
                        continue
                    end
                    flag = rand(size(coinnet(i).conn(j).inv));
                    flag = flag < 0.25;
                    if sum(flag) == 0
                        continue
                    end
                    invflight = coinnet(i).conn(j).inv(flag);
                    coinnet(i).conn(j).inv = coinnet(i).conn(j).inv(~flag);
                    coinnet(coinnet(i).conn(j).id).inflight =...
                        sunique([coinnet(coinnet(i).conn(j).id).inflight,...
                        invflight]);
                    coinnet(i).conn(j).invsent =...
                        sunique([coinnet(i).conn(j).invsent,...
                        invflight]);
                    
                end
                
                
            end
        end
        
        count = count + 1;
        % escape if all nodes have either tx1 or tx2
        count1 = 0;
        count2 = 0;
        for i = 1:nodecount
            mempoolfirst = ridsecond(coinnet(i).mempool);
            if ismember(1001,mempoolfirst)
                count1 = count1 + 1;
            elseif ismember(1002,mempoolfirst)
                count2 = count2 + 1;
            end
        end
        if count1 + count2 == nodecount
            break
        end
    end
    
    % tabulate miner probability to mine tx1
    miner1 = 0;
    
    for i = 1:minercount
        minerfirst = ridsecond(coinnet(mining(i)).mempool);
        if ismember(1001,minerfirst)
            miner1 = miner1 + 1;
        end
    end
    firsttable(h) = miner1 / minercount;
    p = mean(firsttable(1:h));
    stdnum = std(firsttable(1:h));
    disp([num2str(firsttable(h)) ' ' num2str(p) ' ' num2str(stdnum)])
end

p_firstmined = mean(firsttable);
std_firstmined = std(firsttable);

end

% subfunction to eliminate the second-seen from tx1 and tx2 if relay ==
% false
function output = ridsecond(input)
    if ~ismember(1001,input) || ~ismember(1002,input)
        output = input;
    else
        pos1 = find(input == 1001);
        pos2 = find(input == 1002);
        
        if pos1 < pos2
            output = input;
            output(pos2) = [];
        else 
            output = input;
            output(pos1) = [];
        end
    end
    
end

function output = sunique(input)
  [~, i, ~] = unique(input, 'first');
  output = input(sort(i));
end
