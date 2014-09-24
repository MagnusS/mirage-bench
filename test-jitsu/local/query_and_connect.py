# code from http://stackoverflow.com/questions/3898363/python-dns-resolver-set-specific-dns-server
import dns.resolver,sys
import socket
import time

if len(sys.argv) < 3:
    print "usage:",sys.argv[0],"[dns ip]","[domain]","{get}"
    print 
    print "Uses the DNS to resolve the domain and connect to it on port 80. If get is specified, a HTTP get request is sent and the script waits for the first data before exiting."
    sys.exit(-1)

resolver_ip = sys.argv[1]
print "Using",resolver_ip," as DNS server"

hostname = sys.argv[2]
print "Resolving hostname",hostname

send_get = (len(sys.argv) > 3 and sys.argv[3] == "get")
print "Sending GET / HTTP/1.0 after connect"

port = 80
reply = None

my_resolver = dns.resolver.Resolver()

# 8.8.8.8 is Google's public DNS server
t0 = time.time()
my_resolver.nameservers = [resolver_ip]

answer = my_resolver.query(hostname)
for rdata in answer:
    ip = rdata.to_text() # just use first answer returned
    break

sock = socket.socket()
sock.connect((ip, port))

if send_get:
    sock.sendall("GET / HTTP/1.0\r\n\r\n")
    while reply==None or len(reply)==0: # just catch first reply
        reply = sock.recv(4096)

print "# Time from python:"
print time.time() - t0
sock.shutdown(2)
sock.close()

print "Connect/disconnect to ip",ip,"port",port,"done"

