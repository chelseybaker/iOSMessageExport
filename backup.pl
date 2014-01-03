use strict;
use warnings;
use v5.10;
use iOSSMSBackup;

my $ios_backup = iOSSMSBackup->new($ARGV[0]);
if ($ios_backup){
    $ios_backup->export_messages();
}else{
    print "no backup";
}
