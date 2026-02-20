This is the place where all the images and scripts are stored. If you are looking for the main application, please visit [here](https://github.com/EXALAB/AnLinux-App)

To open an issue, please visit [here](https://github.com/EXALAB/AnLinux-App/issues)



## Bootstraping System

Note: [Ubuntu](https://www.ubuntu.com/), [Debian](https://www.debian.org/), [Kali](https://www.kali.org/), [Parrot Security OS](https://www.parrotsec.org/), [BackBox](https://www.backbox.org) are generated using the scripts located at Scripts/Bootstrap. Others are official images without modification.

Supported Versions in Bootstrap Scripts:
- Ubuntu: 24.04 (Noble Numbat)
- Debian: 12 (Bookworm)
- Kali: Rolling
- Parrot: Rolling
- BackBox: 9 (Noble base)

You will need to install some packages first:

> sudo apt-get install qemu-user-static debian-archive-keyring debootstrap

(Note: `debootstrap` is required for Debian, Kali, and Parrot scripts. Ubuntu and BackBox scripts use official `ubuntu-base` tarballs but require `wget`, `tar`, and root privileges for `chroot`.)

Then go to [Bootstrap](https://github.com/EXALAB/Anlinux-Resources/tree/master/Scripts/Bootstrap) and download the bootstrap.sh script. (It is important to follow instructions before running bootstrap.sh if there any.)

To bootstrap a system, simply run:

> ./bootstrap.sh architecture /path/to/bootstrap
   
For example: 

> ./bootstrap.sh armhf /home/user/ubuntu/armhf
