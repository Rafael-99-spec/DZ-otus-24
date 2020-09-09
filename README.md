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
Sep 08 17:55:00 client systemd[1]: Starting Start backup script...
Sep 08 17:55:01 client sh[3476]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 17:55:02 client sh[3476]: ------------------------------------------------------------------------------
Sep 08 17:55:02 client sh[3476]: Archive name: client-2020-09-08-17-55
Sep 08 17:55:02 client sh[3476]: Archive fingerprint: 2ad5bf6d9f1e06e497b6624eb88c8bb0a46ef17ff9980ac121c12a58b4b4fe9d
Sep 08 17:55:02 client sh[3476]: Time (start): Tue, 2020-09-08 17:55:01
Sep 08 17:55:02 client sh[3476]: Time (end):   Tue, 2020-09-08 17:55:02
Sep 08 17:55:02 client sh[3476]: Duration: 0.37 seconds
Sep 08 17:55:02 client sh[3476]: Number of files: 1707
Sep 08 17:55:02 client sh[3476]: Utilization of max. archive size: 0%
Sep 08 17:55:02 client sh[3476]: ------------------------------------------------------------------------------
Sep 08 17:55:02 client sh[3476]: Original size      Compressed size    Deduplicated size
Sep 08 17:55:02 client sh[3476]: This archive:               32.25 MB             14.98 MB             26.44 kB
Sep 08 17:55:02 client sh[3476]: All archives:               64.51 MB             29.95 MB             11.84 MB
Sep 08 17:55:02 client sh[3476]: Unique chunks         Total chunks
Sep 08 17:55:02 client sh[3476]: Chunk index:                    1286                 3422
Sep 08 17:55:02 client sh[3476]: ------------------------------------------------------------------------------
Sep 08 17:55:03 client sh[3476]: Keeping archive: client-2020-09-08-17-55              Tue, 2020-09-08 17:55:01 [2ad5bf6d9f1e06e497b6624eb88c8bb0a46ef17ff9980ac121c12a58b4b4fe9d]
Sep 08 17:55:03 client sh[3476]: Pruning archive: client-2020-09-08-15-50              Tue, 2020-09-08 17:50:01 [1ec58fe1cb388e6e0d0b8f5eefc1ce907c36978c24f3de1a685c06f8537e909c] (1/1)
Sep 08 17:55:03 client systemd[1]: Started Start backup script.
Sep 08 18:00:00 client systemd[1]: Starting Start backup script...
Sep 08 18:00:01 client sh[3717]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 18:00:01 client sh[3717]: ------------------------------------------------------------------------------
Sep 08 18:00:01 client sh[3717]: Archive name: client-2020-09-08-18-00
Sep 08 18:00:01 client sh[3717]: Archive fingerprint: 27f9f20ada3ac69a56b5031df93af10c8ca815e8a7c9801e51a1ec8677926c3c
Sep 08 18:00:01 client sh[3717]: Time (start): Tue, 2020-09-08 18:00:01
Sep 08 18:00:01 client sh[3717]: Time (end):   Tue, 2020-09-08 18:00:01
Sep 08 18:00:01 client sh[3717]: Duration: 0.37 seconds
Sep 08 18:00:01 client sh[3717]: Number of files: 1707
Sep 08 18:00:01 client sh[3717]: Utilization of max. archive size: 0%
Sep 08 18:00:01 client sh[3717]: ------------------------------------------------------------------------------
Sep 08 18:00:01 client sh[3717]: Original size      Compressed size    Deduplicated size
Sep 08 18:00:01 client sh[3717]: This archive:               32.25 MB             14.98 MB             26.43 kB
Sep 08 18:00:01 client sh[3717]: All archives:               64.51 MB             29.95 MB             11.84 MB
Sep 08 18:00:01 client sh[3717]: Unique chunks         Total chunks
Sep 08 18:00:01 client sh[3717]: Chunk index:                    1286                 3422
Sep 08 18:00:01 client sh[3717]: ------------------------------------------------------------------------------
Sep 08 18:00:03 client sh[3717]: Keeping archive: client-2020-09-08-18-00              Tue, 2020-09-08 18:00:01 [27f9f20ada3ac69a56b5031df93af10c8ca815e8a7c9801e51a1ec8677926c3c]
Sep 08 18:00:03 client sh[3717]: Pruning archive: client-2020-09-08-17-55              Tue, 2020-09-08 17:55:01 [2ad5bf6d9f1e06e497b6624eb88c8bb0a46ef17ff9980ac121c12a58b4b4fe9d] (1/1)
Sep 08 18:00:03 client systemd[1]: Started Start backup script.
Sep 08 18:05:00 client systemd[1]: Starting Start backup script...
Sep 08 18:05:01 client sh[4039]: Creating archive at "192.168.111.10:/var/backup::{hostname}-{now:%Y-%m-%d-%H-%M}"
Sep 08 18:05:02 client sh[4039]: ------------------------------------------------------------------------------
Sep 08 18:05:02 client sh[4039]: Archive name: client-2020-09-08-18-05
Sep 08 18:05:02 client sh[4039]: Archive fingerprint: c15c18927d89d9d6ae57a556a9a7eafbd9e889831ea84057bf6b6833e124dbd6
Sep 08 18:05:02 client sh[4039]: Time (start): Tue, 2020-09-08 18:05:01
Sep 08 18:05:02 client sh[4039]: Time (end):   Tue, 2020-09-08 18:05:01
```
Для окончательной проверки создадим какой-нибудь документ, подождем минут 10, пока не получим бекап с новосозданной папкой. Потом удалим данную папку, и попробуем восстановить его из последнего бекапа. Данным способом мы будем имитировать ситуацию в которой сисадмин случайно удалил папку с важными файлами и ему необходимо как можно быстрее его востановить, и сделает он это с помошью восстановления всей директории /etc с резервной копии.
Например создаем файл important_ip_addresses
```
[root@client vagrant]# echo "192.168.111.10;192.168.111.11" > /etc/important_ip_addresses
[root@client vagrant]# ll /etc/important_ip_addresses 
-rw-r--r--. 1 root root 30 Sep  8 21:59 /etc/important_ip_addresses
```
Подождем минут 10, удалим наш файл и службы, после чего приступим к восстановлению резервной копии папки /etc.
```
[root@client vagrant]# systemctl stop borg-backup.timer
[root@client vagrant]# systemctl stop borg-backup.service
[root@client vagrant]# rm -r /etc/important_ip_addresses 
rm: remove regular file '/etc/important_ip_addresses'? y
[root@client vagrant]# 
```
Восстановим копию папки /etc из borgbackup 
```
[root@client vagrant]# borg list 192.168.111.10:/var/backup
Enter passphrase for key ssh://192.168.111.10/var/backup: 
client-2020-09-08-22-10              Tue, 2020-09-08 22:10:00 [dd25863e2246b42a45dc6a5095e37d00ad6b8e9bb542753e3f3667d9d28a5892]
[root@client vagrant]# borg extract --list 192.168.111.10:/var/backup::client-2020-09-08-21-10
```
И наконец посмотрим появился ли удаленный файл, 
