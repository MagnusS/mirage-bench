# code from http://stackoverflow.com/questions/3898363/python-dns-resolver-set-specific-dns-server
import dns.resolver,sys
import socket

resolver_ip = sys.argv[1]
print "Using",resolver_ip," as DNS server"

hostname = sys.argv[2]
print "Resolving hostname",hostname

port = 80

my_resolver = dns.resolver.Resolver()

# 8.8.8.8 is Google's public DNS server
my_resolver.nameservers = [resolver_ip]

answer = my_resolver.query(hostname)
for rdata in answer:
    ip = rdata.to_text() # just use first answer returned
    break

sock = socket.socket()
sock.connect((ip, port))
print "Connected. Shutting down socket..."
sock.shutdown(1)
sock.close()

print "Connect/disconnect to ip",ip,"port",port,"done"

