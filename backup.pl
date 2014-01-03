use strict;
use warnings;
use v5.10;

use Getopt::Long;

use iOSSMSBackup;
my $directory;
my $css;
GetOptions("directory_path=s" => \$directory, "css=s" => \$css);

my $ios_backup = iOSSMSBackup->new({backup_directory => $directory, css => $css});
if ($ios_backup){
    $ios_backup->export_messages();
}else{
    print "no backup";
}
