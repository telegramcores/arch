# arch
## Предварительная настройка для установки RAID на bcache
Сеть настроена, доступ в Интернет есть - действуем далее:
1. Так как потребуется компиляция и дополнительные пакеты увеличиваем пространство 

   **mount -o remount,size=8G /run/archiso/cowspace**

2. Дополнительные пакеты
   
   **pacman -Syu base-devel git --ignore linux --noconfirm**
   
   **mkdir /mnt/arch**
   
4. Так как makepkg нельзя выполнять от root, придется создать нового пользователя
   
   **useradd -m -G wheel -s /bin/bash user**
   
   **usermod --password 123 user** // пароль для user - 123
   
   **EDITOR=nano visudo** // прописываем **user ALL=(ALL) ALL**
   
5. Заходим в сеанс пользователя и устанавливаем пакет

   **su - user**
   
   **git clone https://aur.archlinux.org/bcache-tools.git**
   
   **cd bcache-tools/**
   
   **makepkg -sri** // один раз вводим пароль, остальные запросы подтверждаем
   
   **sudo cp bcache-tools-1.1.1-1-x86_64.pkg.tar.xz /mnt/arch** тут повнимательнее, после компиляции создается файл (обращаем внимание на имя файла) , его копируем в /mnt/arch
   
   **exit** // выходим из сеанса user
   
6. Появляется возможность использовать make-bcache  
