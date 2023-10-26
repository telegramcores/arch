#https://gist.github.com/HardenedArray/4c1492f537d9785e19406eb5cd991735?permalink_comment_id=3298538
#mount -o remount,size=8G /run/archiso/cowspace
#pacman -Syu base-devel git --ignore linux

 
 # Create a new User:
 #   useradd -m -G wheel -s /bin/bash user
    # then:
 #   passwd user
    # then, since we will require sudo for vital future steps, do:
 #   EDITOR=nano visudo
    # and add:
 #   user ALL=(ALL) ALL
    # under User privilege specification.  Save the /etc/sudoers.tmp file.
    # Use ctrl-alt-f3, and login as 'user'
    # Build and install bcache-tools from AUR:
 #   git clone https://aur.archlinux.org/bcache-tools.git
 #   cd bcache-tools/
 #   makepkg -sri

#sudo -u user makepkg -sri --noconfirm
#sudo -u user git clone https://aur.archlinux.org/bcache-tools.git

loadkeys ru
setfont cyr-sun16

# Устанавливаем yay для возможности использования bcache-tools
#mount -o remount,size=8G /run/archiso/cowspace
#pacman -S --needed --noconfirm base-devel linux-zen 
#git clone https://aur.archlinux.org/yay.git
#cd yay
#makepkg -sri --noconfirm
#cd /
#yay -S --noconfirm bcache-tools


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
parted -a optimal --script $disk set 4 raid on
done
