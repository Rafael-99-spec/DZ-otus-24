# ДЗ №24 Резервное копирование
### Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup
--------------------------------------------------------------------------------------------
- Для начала склонируем репозиторий с помощью - ```git clone https://github.com/Rafael-99-spec/DZ-otus-24```
- Далее зайдем в папку локального репозитория и поднимем наш vagrant-стенд командой - ```vagrant up``` 
- Зайдем на ВМ server, сразу создадим папку ```/var/backup``` для нашего нового репозитория. 
- Сразу создадим файловую систему ext4 на втором диске и смонтируем к папке ```/var/backup```, с дальнейшим вводом ИД нашего блочного устройства, для автоматического монтирования при каждом запуске системы.
```
[root@server vagrant]# df -hT
Filesystem     Type      Size  Used Avail Use% Mounted on
devtmpfs       devtmpfs  489M     0  489M   0% /dev
tmpfs          tmpfs     496M     0  496M   0% /dev/shm
tmpfs          tmpfs     496M  6.7M  489M   2% /run
tmpfs          tmpfs     496M     0  496M   0% /sys/fs/cgroup
/dev/sda1      xfs        40G  7.4G   33G  19% /
/dev/sdc       ext4      2.0G  6.0M  1.8G   1% /var/backup
tmpfs          tmpfs     100M     0  100M   0% /run/user/1000
```
- Далее перейдем на нашу клиентскую машину, откуда будем настроивать у резервное копирование на бекап-сервер.
- Для резервоного копирования будем использовать утилиту borgbackup . Для работы бекап сервера через borgbackup нам нужно будет включить ssh, причем репозиторий наш будет зашифрован, и поэтому цельях безпоасности будем использовать ssh-ключи, следовательно сгенерируем открытый и закрытый ключи, и сразу скопируем на наш бекап-сервер(то-есть на ВМ - server).
```
[root@client vagrant]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:Y822YnsdsipH/sdp4H5IbWOnf94aoI+FDxP8eGcWVhs root@client
The key's randomart image is:
+---[RSA 2048]----+
|                 |
|                 |
|               E.|
|         +     .o|
|        S *.. o. |
|       ..o+B*o.. |
|       oooBX+*=  |
|      ..oo=OO+ .o|
|       oo=++o.o+o|
+----[SHA256]-----+
[root@client vagrant]# ssh-copy-id root@192.168.111.10
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host '192.168.111.10 (192.168.111.10)' can't be established.
ECDSA key fingerprint is SHA256:8CxxfxZBocJXtMKMhBEvt1nkHfv5+aFm4m607jSuKlM.
ECDSA key fingerprint is MD5:eb:64:e3:a8:ab:b1:08:62:0d:67:b2:5b:70:f1:ca:39.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@192.168.111.10's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.111.10'"
and check to make sure that only the key(s) you wanted were added.

[root@client vagrant]# 
```
Далее перемещаемся в директорию /vagrant, тут лежит скрипт, который предназначен запуска бекапов, в определенное время каждый день. Сразу разрешим выполнение bash-скрипта.
```
[root@client vagrant]# cd /vagrant/
[root@client vagrant]# chmod +x backup.sh
```
После этого приступим к важнейшим шагам. Создадим репозиторию на удаленном бекап-сервере(ВМ - server). Далее экспортируем наш ключ сразу в наш удаленный репозиторий.
```
[root@client vagrant]# borg init -e repokey-blake2 192.168.111.10:/var/backup
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]: y
Your passphrase (between double-quotes): "123456789"
Make sure the passphrase displayed above is exactly what you wanted.

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://192.168.111.10/var/backup

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
[root@client vagrant]# borg key export root@192.168.111.10:/var/backup
output file to export key to expected
```
Далее создаем два systemd service и timer юнита, первый юнит предназначен для запуска самого баш-скрипта backup.sh, а второй юнит для запуска .service юнита каждые 5 минут. Оба файла выглядат след. образом
borg-backup.service
```
[root@client vagrant]# cat borg-backup.service 
[Unit]
Description=Start backup script

[Service]
Type=oneshot
ExecStart=/bin/sh /vagrant/backup.sh
```
borg-backup.timer
```
[root@client vagrant]# cat borg-backup.timer 
[Unit]
Description=Run required service once in 5 minute

[Timer]
OnActiveSec=0sec
OnBootSec=1min
OnCalendar=*:0/5
AccuracySec=1us
Unit=borg-backup.service

[Install]
WantedBy=multi-user.target
[root@client vagrant]# 
```
Теперь приступим к созданию юнитов, к их запуску и настройке для автозапуска во время запуска самой системы
```
[root@client vagrant]# cp /vagrant/borg-backup.service /etc/systemd/system/borg-backup.service
[root@client vagrant]# cp /vagrant/borg-backup.timer /etc/systemd/system/borg-backup.timer
[root@client vagrant]# systemctl enable borg-backup.service
[root@client vagrant]# systemctl enable borg-backup.timer
Created symlink from /etc/systemd/system/multi-user.target.wants/borg-backup.timer to /etc/systemd/system/borg-backup.timer.
[root@client vagrant]# systemctl start borg-backup.service
[root@client vagrant]# systemctl start borg-backup.timer
```
Отмечу сразу, что логирование у нах работает с помощью systemd-утилиты journalctl(команда journalctl -u ```borg-backup.service -n 65 > /var/log/borg.log ``` прописанная в backup.sh) 
Проверим работу нашего демона borg-backup.service. 

Ниже по 1-му выводу можно заметить, что каждый название каждого бекапа содержит название хоста(откуда получаем бекап), а также дату и время создания бекапа;  
```
[root@server vagrant]# borg list /var/backup/
Enter passphrase for key /var/backup: 
client-2020-09-08-17-55              Tue, 2020-09-08 17:55:01 [2ad5bf6d9f1e06e497b6624eb88c8bb0a46ef17ff9980ac121c12a58b4b4fe9d]
```
А по 2-му выводу, можем удостовериться, что бекап делается, каждые 5 минут
```
Sep 08 15:40:00 client systemd[1]: Starting Start backup script...
Sep 08 15:40:01 client sh[2873]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 15:40:02 client sh[2873]: ------------------------------------------------------------------------------
Sep 08 15:40:02 client sh[2873]: Archive name: client-2020-09-08-15-40
Sep 08 15:40:02 client sh[2873]: Archive fingerprint: f02a618d1ac1ce5c5197c8b797057f9b7e17d8a62386de5f3f03ab82c6795f64
Sep 08 15:40:02 client sh[2873]: Time (start): Tue, 2020-09-08 15:40:01
Sep 08 15:40:02 client sh[2873]: Time (end):   Tue, 2020-09-08 15:40:01
Sep 08 15:40:02 client sh[2873]: Duration: 0.42 seconds
Sep 08 15:40:02 client sh[2873]: Number of files: 1707
Sep 08 15:40:02 client sh[2873]: Utilization of max. archive size: 0%
Sep 08 15:40:02 client sh[2873]: ------------------------------------------------------------------------------
Sep 08 15:40:02 client sh[2873]: Original size      Compressed size    Deduplicated size
Sep 08 15:40:02 client sh[2873]: This archive:               32.25 MB             14.98 MB             26.40 kB
Sep 08 15:40:02 client sh[2873]: All archives:               64.51 MB             29.95 MB             11.84 MB
Sep 08 15:40:02 client sh[2873]: Unique chunks         Total chunks
Sep 08 15:40:02 client sh[2873]: Chunk index:                    1286                 3422
Sep 08 15:40:02 client sh[2873]: ------------------------------------------------------------------------------
Sep 08 15:40:03 client sh[2873]: Keeping archive: client-2020-09-08-15-40              Tue, 2020-09-08 15:40:01 [f02a618d1ac1ce5c5197c8b797057f9b7e17d8a62386de5f3f03ab82c6795f64]
Sep 08 15:40:03 client sh[2873]: Pruning archive: client-2020-09-08-15-38              Tue, 2020-09-08 15:38:33 [88473e5224f02ccb268dd433e0922eef1ccd1a3d8930832e7385994d6e2b2cd9] (1/1)
Sep 08 15:40:03 client systemd[1]: Started Start backup script.
Sep 08 15:45:00 client systemd[1]: Starting Start backup script...
Sep 08 15:45:01 client sh[2980]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 15:45:02 client sh[2980]: ------------------------------------------------------------------------------
Sep 08 15:45:02 client sh[2980]: Archive name: client-2020-09-08-15-45
Sep 08 15:45:02 client sh[2980]: Archive fingerprint: 7cc4ec39f8852237d2d773297306260e29a5e071c2fcd98a85af9ea0d426c734
Sep 08 15:45:02 client sh[2980]: Time (start): Tue, 2020-09-08 15:45:01
Sep 08 15:45:02 client sh[2980]: Time (end):   Tue, 2020-09-08 15:45:02
Sep 08 15:45:02 client sh[2980]: Duration: 0.41 seconds
Sep 08 15:45:02 client sh[2980]: Number of files: 1707
Sep 08 15:45:02 client sh[2980]: Utilization of max. archive size: 0%
Sep 08 15:45:02 client sh[2980]: ------------------------------------------------------------------------------
Sep 08 15:45:02 client sh[2980]: Original size      Compressed size    Deduplicated size
Sep 08 15:45:02 client sh[2980]: This archive:               32.25 MB             14.98 MB             26.41 kB
Sep 08 15:45:02 client sh[2980]: All archives:               64.51 MB             29.95 MB             11.84 MB
Sep 08 15:45:02 client sh[2980]: Unique chunks         Total chunks
Sep 08 15:45:02 client sh[2980]: Chunk index:                    1286                 3422
Sep 08 15:45:02 client sh[2980]: ------------------------------------------------------------------------------
Sep 08 15:45:03 client sh[2980]: Keeping archive: client-2020-09-08-15-45              Tue, 2020-09-08 15:45:01 [7cc4ec39f8852237d2d773297306260e29a5e071c2fcd98a85af9ea0d426c734]
Sep 08 15:45:03 client sh[2980]: Pruning archive: client-2020-09-08-15-40              Tue, 2020-09-08 15:40:01 [f02a618d1ac1ce5c5197c8b797057f9b7e17d8a62386de5f3f03ab82c6795f64] (1/1)
Sep 08 15:45:04 client systemd[1]: Started Start backup script.
Sep 08 15:50:00 client systemd[1]: Starting Start backup script...
Sep 08 15:50:01 client sh[3286]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 15:50:02 client sh[3286]: ------------------------------------------------------------------------------
Sep 08 15:50:02 client sh[3286]: Archive name: client-2020-09-08-15-50
Sep 08 15:50:02 client sh[3286]: Archive fingerprint: 1ec58fe1cb388e6e0d0b8f5eefc1ce907c36978c24f3de1a685c06f8537e909c
Sep 08 15:50:02 client sh[3286]: Time (start): Tue, 2020-09-08 15:50:01
Sep 08 15:50:02 client sh[3286]: Time (end):   Tue, 2020-09-08 15:50:01
```
