# Wireguard -> tun2socks -> socks proxy (+ dnscrypt proxy) на Ubuntu

<!-- TOC -->
* [Wireguard -> tun2socks -> socks proxy (+ dnscrypt proxy) на Ubuntu](#wireguard---tun2socks---socks-proxy--dnscrypt-proxy-на-ubuntu)
  * [iptables](#iptables)
  * [wireguard](#wireguard)
  * [dnscrypt-proxy](#dnscrypt-proxy)
  * [xray](#xray)
  * [tun2socks](#tun2socks)
<!-- TOC -->

Настраиваем хостинг с доступом через wireguard и пробросом его трафика через socks proxy на другой сервер.

При работе на хостинге лучше настроить себе удобный терминал и tmux. 
Например, как описано [здесь](https://github.com/olegnet/shell-config-files)

В процессе конфигурирования удобно на одном терминале запустить `journalctl -f` и наблюдать там результат выполнения
команд.


## iptables

На свежую VM на хостинге лучше сначала нужно поставить iptables и настроить базовые ограничения файрвола.

```shell
apt install iptables iptables-persistent netfilter-persistent
```

[all.sh](iptables/all.sh)

и если всё хорошо, `netfilter-persistent save`


## wireguard

Wireguard под разные платформы можно взять здесь [wireguard.com](https://www.wireguard.com/)

Ставим пакеты
```shell
apt install wireguard
```

Создаём в `/etc/wireguard` [wg0.conf](wireguard/wg0.conf) с приватным ключём и секцией для первого пира.
`wg genkey` и `wg pubkey`, всё как обычно.

Новых можно добавлять скриптом [add-wg-peer.sh](wireguard/add-wg-peer.sh)

Автор этого замечательного скрипта конечно chatgpt. Не забудьте поменять там ENDPOINT.

Запускаем
```shell
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

Проверить факт соединения можно сразу: взять другой компьютер или телефон и использовать сгенерированную конфигурацию.
На сервере можно посмотреть командой `wg`

```shell
interface: wg0
  public key: ...
  private key: (hidden)
  listening port: 55555

peer: ...
  endpoint: ...
  allowed ips: 10.8.100.2/32
  latest handshake: 2 seconds ago
  transfer: 70.18 KiB received, 68.28 KiB sent
  persistent keepalive: every 25 seconds
```

Сразу в `/etc/sysctl.conf` включаем ip_forward и выключаем IPv6

```properties
net.ipv4.ip_forward=1

net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

## dnscrypt-proxy

```shell
apt install dnscrypt-proxy
```

Меняем в `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` `listen_addresses` и по-вкусу `server_names`
```toml
listen_addresses = ['127.0.0.1:53', '10.8.100.1:53']
server_names = ['cloudflare', 'quad9-dnscrypt-ip4-no-filter']
```

Выключаем systemd-resolved и dnscrypt-proxy.socket, чтобы можно было слушать порт 53
```shell
systemctl disable --now systemd-resolved
systemctl disable --now dnscrypt-proxy.socket
systemctl enable --now dnscrypt-proxy.service
```

Проверяем, что запустился `ss -plntu|grep :53`.

Заменяем содержимое `/etc/resolv.conf`. Это может быть симлинк. Тогда лучше его сначала удалить и создать новый файл.
```shell
nameserver 127.0.0.1
nameserver 10.8.100.1
```

Проверяем `nslookup example.com` или `dig example.com`


## xray

## tun2socks

[tun2socks-linux-amd64.zip](https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-amd64.zip)

journalctl -n -f
watch -n 1 conntrack -C
