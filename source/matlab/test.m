fid=0
channel = 1
%               Instruction format
%     16bit       16bit       16bit       16bit
%|<---------->|<--------->|<--------->|<--------->|
%|  reserved  |instruction| reg addr  |  payload  |
%--------------------------------------------------
% instruction=0xffff -> write
% instruction=0x0000 -> read
%Simple test
%Write register file 0x00 with value 1234
data=int32([7899 65535]);
riffa = Riffa(fid);
sent = riffa.send(channel, data, length(data), 0, 1, 0);
%Read register file 0x00 by sending a read command
%TODO:Read three times to get the correct value....
data=int32([0 0]);
sent = riffa.send(channel, data, length(data), 0, 1, 0);
[recvd, resp] = riffa.recv(channel, length(data), 0);
riffa.close();