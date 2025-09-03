# Wireguard -> tun2socks -> socks proxy (+ dnscrypt proxy) на Debian или Ubuntu

### Настраиваем хостинг с доступом через wireguard и пробросом его трафика через socks proxy на другой сервер

Этот текст не является howto в привычном смысле. 
Это памятка для автора, чтобы на новом хостинге пройти по чеклисту и поднять тот же сервис за пять минут.

Часть скриптов – результат вайбкодинга с chatgpt, которые я оставил, как есть.
Также смотрите [disclaimer.](#disclaimer)

<!-- TOC -->
  * [iptables](#iptables)
  * [wireguard](#wireguard)
  * [dnscrypt-proxy](#dnscrypt-proxy)
  * [socks proxy](#socks-proxy)
  * [tun2socks](#tun2socks)
  * [отладка](#отладка)
  * [disclaimer](#disclaimer)
<!-- TOC -->

При работе на хостинге лучше настроить себе удобный терминал и tmux. 
Например, как описано [здесь](https://github.com/olegnet/shell-config-files)

В процессе конфигурирования удобно на одном терминале запустить `journalctl -f` и наблюдать там результат выполнения
команд.

Если нет проблем с местом, лучше сразу поставить всё, что может пригодиться
```shell
apt install htop btop joe net-tools curl wget axel tmux util-linux wireguard iptables iptables-persistent tcpdump lsof
```

Все команды выполняются от `root`, так что `sudo` или `sudo -s` подразумевается.


## iptables

На свежую VM на хостинге лучше сначала нужно поставить iptables и настроить базовые ограничения файрвола.

```shell
apt install iptables iptables-persistent netfilter-persistent
```

Запускаем [all.sh](iptables/all.sh)

Проверяем результат `iptables -L -v -n` и, если всё хорошо, сохраняем `netfilter-persistent save`


## wireguard

Wireguard под разные платформы можно взять здесь [wireguard.com](https://www.wireguard.com/)

Ставим пакеты
```shell
apt install wireguard
```

Создаём в `/etc/wireguard` [wg0.conf](wireguard/wg0.conf) с приватным ключём и секцией для первого пира.
`wg genkey` и `wg pubkey`, всё как обычно.

Новых можно добавлять скриптом [add-wg-peer.sh](wireguard/add-wg-peer.sh)

В зависимости от ваших целей, может быть хорошей идеей делать бекап файла `wg0.conf` после каждого добавления пользователя.

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


## socks proxy

Может быть любой socks proxy, который работает с tun2socks.

В моём случае это был обычный [xray.](https://github.com/XTLS/Xray-core)

Мне подошла более старая [версия 25.3.6.](https://github.com/XTLS/Xray-core/releases/download/v25.3.6/Xray-linux-64.zip)
Распакуем её в `/opt/xray`.

Пример той части конфигурации, которая релевантна нашему сценарию [config.json](xray/config.json)

Вот такой сервис сочинил мне chatgpt [xray.service](xray/xray.service) для автозапуска.
Сложим его в `/etc/systemd/system/xray.service`. 

Для работы этого скрипта нужно создать пользователя `xray`
```shell
useradd --system --no-create-home --shell /usr/sbin/nologin xray
```

Запускаем сервис
```shell
systemctl daemon-reload
systemctl enable xray.service
systemctl start xray.service
```

Проверяем, что запустился `ss -plntu|grep :1080`.


## tun2socks

Теперь нужно из socks proxy сделать интерфейс tun0.

Возьмём [tun2socks](https://github.com/xjasonlyu/tun2socks)

Я использовал этот файл [tun2socks-linux-amd64.zip](https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-linux-amd64.zip)

Распакуем его в `/opt/tun2socks/tun2socks`.

Вот такой скрипт для запуска в итоге собрали мы с chatgpt [tun2socks.service](tun2socks/tun2socks.service)

Для его работы нужно один раз добавить строку `200 tunroute` в файл `/etc/iproute2/rt_tables`

```shell
systemctl daemon-reload
systemctl enable tun2socks.service
systemctl start tun2socks.service
```

Теперь можно взять настроенного выше клиента wireguard и проверить, как выглядит например `ifconfig.me`.
В браузере или через тот же curl.


## Отладка

Напомню, всё это время у нас был открыт терминал с командой `journalctl -f`.
Также отлично помогают команды
```shell
ip a
ip route
ss -plntu
lsof -i :53 -n
iptables -L -v -n
curl ifconfig.me
curl --interface tun0 ifconfig.me
curl --proxy socks5://x.x.x.x:1080 ifconfig.me
nslookup ifconfig.me
tcpdump -i tun0 -n
tcpdump -i wg0 -n
```

Иногда хорошей идеей будет взять кусок лога с ошибкой и показать chatgpt.


## Disclaimer

Автор делится личным опытом, полученным на собственном оборудовании, и не призывает ни повторять,
ни избегать описанных действий.
Все возможные последствия использования этой информации остаются на ответственности читателя.

