from scapy.all import *

def error(msg):
	print "!",msg,"(",sys.argv[1],")"
	raise Exception(msg)

if len(sys.argv) == 0:
	raise Exception("Needs pcap file as param 1")

myreader = PcapReader(sys.argv[1])

FIN=0x01
SYN=0x02
RST=0x04
PSH=0x08
ACK=0x10
URG=0x20
ECE=0x40
CWR=0x80

# search for the following in this order:
# 1. dns query, store source ip as client_ip
# 2. dns response, store ip as vm_ip
# 3. SYN to vm_ip from client_ip
# 4. SYN/ACK to client_ip from vm_ip
# 5. ACK from client_ip
# 6. data

vm_ip = None
vm_name = None
client_ip = None
t0 = None


# 1
for p in myreader:
	if DNS in p and p[DNS].opcode == 0 and p[DNS].qr == 0: # query
		t0 = p.time
		vm_name = p[DNS].qd.qname
		client_ip = p[IP].src
		print '#',p.time-t0,"dns query for",vm_name,"from",client_ip
		break

if t0 == None:
	error("DNS query not found!")


# 2
for p in myreader:
	if DNS in p and p[DNS].opcode == 0 and p[DNS].qr == 1: # query response
		if p[IP].dst == client_ip and p[DNS].an.rrname == vm_name:
			vm_ip = p[DNS].an.rdata
			print '#',p.time-t0,"dns query response for",vm_name,", has ip",vm_ip
			break

if vm_ip == None:
	error("DNS query response not found!")

# 3
syn_ok = False
tcp_seq = None
for p in myreader:
	if TCP in p and p[TCP].flags == SYN and p[IP].src == client_ip and p[IP].dst == vm_ip:
		tcp_seq = p[TCP].seq
		syn_ok = True
		print '#',p.time-t0,"first SYN from",client_ip,"seq",tcp_seq
		break

if not syn_ok:
	error("SYN from %s to %s not found" % (client_ip, vm_ip))

#4 
synack_ok = False
tcp_ack = None
for p in myreader:
	if TCP in p and p[TCP].flags == SYN and p[IP].src == client_ip and p[IP].dst == vm_ip and p[TCP].seq == tcp_seq:
		print '#',p.time-t0,"SYN retransmit from",client_ip,"seq",tcp_seq
		continue
	if TCP in p and p[TCP].flags == (SYN|ACK) and p[IP].src == vm_ip and p[IP].dst == client_ip and p[TCP].ack == tcp_seq+1:
		tcp_seq = p[TCP].seq # set new seq
		tcp_ack = p[TCP].ack
		print '#',p.time-t0,"SYN/ACK from",p[IP].src,"ack",p[TCP].ack,"seq",p[TCP].seq
		synack_ok = True
		break

if not synack_ok:
	error("SYNACK from %s to %s not found" % (vm_ip, client_ip))

#5
ack_ok=False
for p in myreader:
	if TCP in p and p[TCP].flags == ACK and p[IP].src == client_ip and p[IP].dst == vm_ip and p[TCP].ack == tcp_seq+1 and p[TCP].seq == tcp_ack:
		print '#',p.time-t0,"ACK from",client_ip,"seq",p[TCP].seq,"ack",p[TCP].ack
		print p.time-t0
		ack_ok = True
		break

if not ack_ok:
	error("No ACK found.")
