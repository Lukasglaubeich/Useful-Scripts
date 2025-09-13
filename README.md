# Useful Scripts
Some useful scripts for macos

## Checkrename.sh
This script tries to check wether a user / root rename was successfull. If you want to rename your user on macos visit this guide: https://support.apple.com/en-us/102547
The script does 5 checks:
1) whoami: checks what the currently logged in username is.
2) home directory: checks wether a home folder exists for the user
3) file system ownership: checks wether the files in said home folder are owned by the current user
4) Gets the record name NFSHomeDirectory
5) Compares 4) to current user
