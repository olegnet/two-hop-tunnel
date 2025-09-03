#!/bin/sh -x

iptables -P INPUT DROP
iptables -P FORWARD DROP

iptables -P OUTPUT ACCEPT

# Очистить все текущие правила
iptables -F   # Flush all rules in all chains
iptables -X   # Delete all user-defined chains

# Разрешить трафик на loopback интерфейсе
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить входящие соединения для уже установленных или связанных сессий
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешить входящие SSH-соединения
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# Лучше конечно прописать туда ваш IP, если он постоянный, или перевесить ssh на другой порт
#iptables -A INPUT -p tcp -s 111.222.333.444 --dport 22 -j ACCEPT

# Разрешить входящие UDP-соединения на порт WireGuard
iptables -A INPUT -p udp --dport 55555 -j ACCEPT

# Разрешить запросы DNS от WireGuard
iptables -A INPUT -p tcp -i wg0 --dport 53 -j ACCEPT
iptables -A INPUT -p udp -i wg0 --dport 53 -j ACCEPT

# Разрешить форвардинг трафика из WireGuard в тоннель
iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o wg0 -j ACCEPT
