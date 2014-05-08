iOSMessageExport
================
This is not exactly the best way to use Perl. However, I wanted to create it as simple and readable as I possibly could so that others would be able to modify the code to better suit them. Also, if you are not a programmer, you may find this difficult. You can email me for help but if you need something more user friendly, there's a lot of paid apps out there that are more elegant :) 


Notes

* Emojis would only show up when viewing the pages in Safari. 
* Images and videos are visible within the message threads, but all other content is linked. 
* Files are overwritten without checking to see if one already exists. 
* If you get an error about the DateTime module, please see this CPAN article on installing modules: http://www.cpan.org/modules/INSTALL.html
* This does not support group texts. It just adds the text sent from a user to that user's thread with you. This is basically a bug, but I haven't figured out how to do group texts yet. 

Basic steps: 

1. Make a directory somewhere 
    ```
    mkdir ~/Desktop/iOSBackup
    ```
2. Add this repository to your ~/Desktop/iOSBackup directory 
    ```
    cd ~/Desktop/iOSBackup

    git clone git@github.com:chelseybaker/iOSMessageExport.git
    ```
3. I reccomend copying your iTunes backup into your ~/Desktop/iOSBackup folder, just in case something bad happens (as I am not responsible for your misfortunes). Run backup.pl passing the backup directory. 
    ```
    perl iOSMessageExport/backup.pl --directory_path 9b9f73759fad7b31e330dd26bf7f745acccf1869/
    ```
    If you see an error that iOSSMSBackup cannot be found, you may need to run 
    ```
    export PERLLIB=iOSMessageExport/
    ```

4. An _export folder will be created in your working directory with all of your files! 
