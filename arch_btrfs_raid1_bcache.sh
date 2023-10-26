loadkeys ru
setfont cyr-sun16

# Устанавливаем bcache-tools
pacman -S --needed --noconfirm base-devel 
git clone https://aur.archlinux.org/bcache-tools.git
cd bcache-tools
makepkg -sri --noconfirm
cd ~


# Разметка диска (здесь требуется перечислить диски, которые будут формировать raid1, в данном случае как пример sda и sdb)
for disk in /dev/sda /dev/sdb 
do
echo "---create "$disk"1 bios_grub ---"
parted -a optimal --script $disk mklabel gpt
parted -a optimal --script $disk mkpart primary 1MiB 3MiB
parted -a optimal --script $disk name 1 grub
parted -a optimal --script $disk set 1 bios_grub on
echo "---create "$disk"2 boot ---"
parted -a optimal --script $disk mkpart primary 3MiB 259MiB
parted -a optimal --script $disk name 2 boot
parted -a optimal --script $disk set 2 boot on
echo "---create "$disk"3 swap ---"
parted -a optimal --script $disk mkpart primary 259MiB 16GiB
parted -a optimal --script $disk name 3 swap
echo "---create "$disk"4 raid ---"
parted -s -- $disk mkpart primary 16GiB 100%
parted -a optimal --script $disk name 4 btrfsraid
#parted -a optimal --script $disk set 4 raid on
done

# Создаем bcache на основе размеченных дисков
make-bcache -B /dev/sda4
make-bcache -B /dev/sdb4

# Допустим, /dev/sdc у нас SSD для кэша, тогда
#parted -s -- /dev/sdc mkpart primary 1MiB 100%
#parted -a optimal --script /dev/sdc name 1 bcache
make-bcache -C /dev/sdс

# Связываем кэшируемые устройства
cset_uuid=`bcache-super-show /dev/sdc | grep 'cset' | awk '{print $2}'`
echo $cset_uuid > /sys/block/bcache0/bcache/attach
echo $cset_uuid > /sys/block/bcache1/bcache/attach

mkfs.fat -F32 /dev/sda2
mkfs.fat -F32 /dev/sdb2
mkswap /dev/sda3
swapon /dev/sda3
mkfs.btrfs -f -L btrfsraid -m raid1 -d raid1 /dev/bcache0 /dev/bcache1

echo "LABEL=btrfs /mnt/arch btrfs defaults,noatime  0 0" >> /etc/fstab
systemctl daemon-reload
mkdir /mnt/arch
mount /mnt/arch 
btrfs subvolume create /mnt/arch/@ 
btrfs subvolume create /mnt/arch/@home 
btrfs subvolume create /mnt/arch/@var
btrfs subvolume create /mnt/arch/@share
btrfs subvolume create /mnt/arch/@admman
umount /mnt/arch

mount -o defaults,noatime,autodefrag,discard=async,subvol=@ /dev/bcache0 /mnt/arch
mkdir -p /mnt/arch/{home,var,share,admman}
mount -o autodefrag,noatime,space_cache=v2,compress=zstd:3,discard=async,subvol=@home /dev/bcache0 /mnt/arch/home
mount -o autodefrag,noatime,space_cache=v2,compress=zstd:3,discard=async,subvol=@var  /dev/bcache0 /mnt/arch/var
mount -o autodefrag,noatime,space_cache=v2,compress=zstd:3,discard=async,subvol=@share /dev/bcache0 /mnt/arch/share
mount -o autodefrag,noatime,space_cache=v2,compress=zstd:3,discard=async,subvol=@admman /dev/bcache0 /mnt/arch/admman

pacman -Sy --noconfirm --noprogressbar --quiet reflector
pacman -S --noconfirm --needed --noprogressbar --quiet reflector
reflector -l 3 --sort rate --protocol https --country Russia --save /etc/pacman.d/mirrorlist
pacstrap /mnt/arch base base-devel linux-zen linux-firmware nano dhcpcd netctl bash-completion linux-zen-headers archlinux-keyring

mount --types proc /proc /mnt/arch/proc && mount --rbind /sys /mnt/arch/sys && mount --make-rslave /mnt/arch/sys && mount --rbind /dev /mnt/arch/dev && mount --make-rslave /mnt/arch/dev && mount --bind /run /mnt/arch/run && mount --make-slave /mnt/arch/run

echo -e "\e[31m--- inside chroot ---\e[0m"
chroot_dir=/mnt/arch
chroot $chroot_dir /bin/bash << "CHROOT"
export PS1="(chroot) $PS1" 
export EDITOR=nano
echo "archserv" > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen 
locale-gen
echo 'LANG="ru_RU.UTF-8"' > /etc/locale.conf
echo 'KEYMAP=ru' >> /etc/vconsole.conf
echo 'FONT=cyr-sun16' >> /etc/vconsole.conf

mount /dev/sda2 /boot

pacman -Syy --noconfirm

echo '/dev/sda2 /boot vfat defaults 0 2' >> /etc/fstab
echo -e "\e[31m--- Установка soft and settings ---\e[0m"
echo '/dev/sda3 none swap sw 0 0' >> /etc/fstab
blkid /dev/bcache0 | awk '{print $3" / btrfs defaults,noatime,autodefrag,space_cache=v2,compress=zstd:3,subvol=@  0 0"}' >> /etc/fstab
blkid /dev/bcache0 | awk '{print $3" /home btrfs noatime,autodefrag,space_cache=v2,compress=zstd:3,subvol=@home  0 0"}' >> /etc/fstab
blkid /dev/bcache0 | awk '{print $3" /var btrfs noatime,autodefrag,space_cache=v2,compress=zstd:3,subvol=@var  0 0"}' >> /etc/fstab
blkid /dev/bcache0 | awk '{print $3" /share btrfs noatime,autodefrag,space_cache=v2,compress=zstd:3,subvol=@share  0 0"}' >> /etc/fstab
blkid /dev/bcache0 | awk '{print $3" /admman btrfs noatime,autodefrag,space_cache=v2,compress=zstd:3,subvol=@admman  0 0"}' >> /etc/fstab

echo 'Раскомментируем репозиторий multilib Для работы 32-битных приложений в 64-битной системе.'
echo '[multilib]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
pacman -Syy

pacman -S --noconfirm tmux htop mc iotop lm_sensors smartmontools sudo ntfs-3g screen parted btop wpa_supplicant snapper openssh openbsd-netcat git

touch /etc/resolv.conf
cat << EOF >> /etc/resolv.conf
nameserver 192.168.1.1
EOF

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

###########################
#-- samba ---
chmod 777 /share
pacman -S samba --noconfirm
touch /etc/samba/smb.conf
cat << EOF >> /etc/samba/smb.conf
[GLOBAL]
workgroup = WORKGROUP
server role = standalone server
security = user
browseable = yes
map to guest = Bad User
[share]
path = /share
read only = No
browseable = yes
guest ok = yes
create mask = 0777
directory mask = 0777
EOF
systemctl enable smb.service
############################

#настройка wifi
touch /etc/wpa_supplicant/wpa_supplicant.conf
wpa_passphrase Keenetic-4742 zamochek >> /etc/wpa_supplicant/wpa_supplicant.conf
systemctl enable wpa_supplicant.service
systemctl enable dhcpcd.service
systemctl enable sshd.service

pacman -S --noconfirm linux-zen linux-zen-headers
mkinitcpio -p linux-zen
pacman -S grub efibootmgr --noconfirm
echo 'GRUB_CMDLINE_LINUX="iommu=pt intel_iommu=on pcie_acs_override=downstream,multifunction nofb"' >> /etc/default/grub
grub-install --target=$(lscpu | head -n1 | sed 's/^[^:]*:[[:space:]]*//')-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\e[31m--- Последний этап установки! ---\e[0m"
echo -e "\e[31m--- Сделай вход в chroot: chroot /mnt/arch ---\e[0m"
echo -e "\e[31m--- Создай пароль root: passwd ---\e[0m"
echo -e "\e[33m--- Создать пользователя: useradd -m <name> ---\e[0m"
echo -e "\e[33m--- Создать пароль пользователя: passwd <name> ---\e[0m"
echo -e "\e[33m--- Добавить права суперпользователя аналогично root: visudo ---\e[0m"
echo -e "\e[31m--- После ввода пароля наберите exit ---\e[0m"

CHROOT
